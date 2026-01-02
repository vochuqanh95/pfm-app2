"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions = require("firebase-functions");
const admin = require("firebase-admin");
/*
MANUAL TEST CHECKLIST - BUDGET CF
1) Member shared expense increments: member creates $100 expense from household_shared wallet -> member + family budgets +100.
2) Personal wallet no increment: member creates expense from personal wallet -> no budget usage change.
3) Update delta: edit $100 -> $150 -> budgets +50 delta.
4) Delete reversal: delete tx -> budgets reversed accordingly.
5) Month change: edit date to next month -> subtract old month, add new month usage.
*/
admin.initializeApp();
const db = admin.firestore();
const walletScopeCache = new Map();
const getPeriodKey = (date) => {
    const d = date.toDate();
    return `${d.getFullYear().toString().padStart(4, '0')}-${(d.getMonth() + 1)
        .toString()
        .padStart(2, '0')}`;
};
const getWalletScope = async (walletId) => {
    if (walletScopeCache.has(walletId)) {
        return walletScopeCache.get(walletId) ?? null;
    }
    const snap = await db.collection('wallets').doc(walletId).get();
    if (!snap.exists) {
        walletScopeCache.set(walletId, null);
        return null;
    }
    const scope = snap.get('scope') ?? null;
    walletScopeCache.set(walletId, scope);
    return scope;
};
const fetchMemberBudgets = async (householdId, periodKey, memberUid) => {
    // Query with minimal fields to avoid composite index dependency
    // Filter budget_type and member_user_id in memory
    const query = await db
        .collection('budgets')
        .where('household_id', '==', householdId)
        .where('period_key', '==', periodKey)
        .where('archived', '==', false)
        .get();
    const docs = query.docs
        .filter((doc) => {
        const data = doc.data();
        return data.budget_type === 'member' && data.member_user_id === memberUid;
    })
        .map((doc) => ({
        ...doc.data(),
        budgetId: doc.id,
    }));
    console.log('[BUDGET_CF] query member budgets household=%s period=%s uid=%s count=%d (filtered from %d)', householdId, periodKey, memberUid, docs.length, query.docs.length);
    return docs;
};
const fetchFamilyBudgets = async (householdId, periodKey) => {
    // Query with minimal fields to avoid composite index dependency
    // Filter budget_type in memory
    const query = await db
        .collection('budgets')
        .where('household_id', '==', householdId)
        .where('period_key', '==', periodKey)
        .where('archived', '==', false)
        .get();
    const docs = query.docs
        .filter((doc) => {
        const data = doc.data();
        return data.budget_type === 'family';
    })
        .map((doc) => ({
        ...doc.data(),
        budgetId: doc.id,
    }));
    console.log('[BUDGET_CF] query family budgets household=%s period=%s count=%d (filtered from %d)', householdId, periodKey, docs.length, query.docs.length);
    return docs;
};
const buildTxnContext = async (snap) => {
    const data = snap.data();
    const walletId = data?.wallet_id ?? null;
    const walletScope = walletId ? await getWalletScope(walletId) : null;
    const actorUserId = data?.actor_user_id ?? data?.user_id ?? null;
    const householdId = data?.household_id ?? null;
    const amount = Number(data?.amount ?? 0);
    const date = data?.date;
    const periodKey = date ? getPeriodKey(date) : null;
    const eligible = data?.type === 'expense' &&
        householdId != null &&
        walletScope === 'household_shared' &&
        periodKey != null;
    return {
        txnId: snap.id,
        actorUserId,
        householdId,
        amount,
        type: data?.type,
        walletId,
        walletScope,
        periodKey,
        eligible,
        rawDate: date ? date.toDate().toISOString() : undefined,
    };
};
const thresholds = [80, 90, 100];
const shouldNotifyLevel = (spent, limit, lastLevel) => {
    if (limit <= 0)
        return 0;
    const percent = (spent / limit) * 100;
    let level = 0;
    for (const t of thresholds) {
        if (percent >= t)
            level = t;
    }
    return level > lastLevel ? level : 0;
};
const resolveHeadUserId = async (householdId, fallback) => {
    if (fallback)
        return fallback;
    const snap = await db
        .collection('household_members')
        .where('household_id', '==', householdId)
        .where('role', 'in', ['head', 'owner'])
        .limit(1)
        .get();
    if (snap.empty)
        return null;
    return snap.docs[0].data().user_id ?? null;
};
const createNotifications = async (userIds, budgetId, level) => {
    if (userIds.length === 0 || level === 0)
        return;
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    userIds.forEach((uid) => {
        const ref = db.collection('notifications').doc();
        batch.set(ref, {
            user_id: uid,
            type: 'budget_alert',
            title: `Budget ${level}%`,
            message: `A budget hit ${level}% of its limit.`,
            read_status: false,
            sent_at: now,
            related_entity_type: 'budget',
            related_entity_id: budgetId,
        });
    });
    await batch.commit();
};
const applyUsageDelta = async (budget, periodKey, delta, actorUserId, txnData, walletScope) => {
    if (delta === 0)
        return;
    if (txnData && !matchBudget(budget, txnData, actorUserId))
        return;
    const usageRef = db.collection('budget_usages').doc(`${budget.budgetId}_${periodKey}`);
    let newLevelToNotify = 0;
    let recipients = [];
    await db.runTransaction(async (txn) => {
        const snap = await txn.get(usageRef);
        const data = snap.exists ? snap.data() ?? {} : {};
        const spent = Number(data.spent_amount ?? 0);
        const lastLevel = Number(data.last_alert_level_sent ?? 0);
        const nextSpent = Math.max(0, spent + delta);
        const limit = Number(budget.amount ?? budget['limit_amount'] ?? 0);
        const level = shouldNotifyLevel(nextSpent, limit, lastLevel);
        const payload = {
            budget_id: budget.budgetId,
            household_id: budget.household_id ?? null,
            period_key: periodKey,
            spent_amount: nextSpent,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
            budget_type: budget.budget_type ?? null,
            member_user_id: budget.member_user_id ?? null,
        };
        if (level > 0) {
            payload['last_alert_level_sent'] = level;
            newLevelToNotify = level;
        }
        else {
            payload['last_alert_level_sent'] = lastLevel;
        }
        console.log('[BUDGET_CF_USAGE_WRITE] budget=%s usage_doc=%s period=%s delta=%s spent_before=%s spent_after=%s actor=%s wallet_scope=%s', budget.budgetId, usageRef.id, periodKey, delta, spent, nextSpent, actorUserId ?? 'unknown', walletScope ?? 'unknown');
        txn.set(usageRef, payload, { merge: true });
        if (level > 0) {
            const head = budget.created_by;
            const targets = new Set();
            if (head)
                targets.add(head);
            if (budget.budget_type === 'member' && budget.member_user_id) {
                targets.add(budget.member_user_id);
            }
            recipients = Array.from(targets);
        }
    });
    if (newLevelToNotify > 0 && recipients.length > 0) {
        await createNotifications(recipients, budget.budgetId, newLevelToNotify);
    }
};
const matchBudget = (budget, txn, actorUserId) => {
    if (budget.archived)
        return false;
    if (budget.wallet_scope_filter && budget.wallet_scope_filter !== 'household_shared') {
        return false;
    }
    if (budget.budget_type === 'member' && budget.member_user_id) {
        if (actorUserId !== budget.member_user_id)
            return false;
    }
    return true;
};
const applyContextDelta = async (ctx, delta, txnData) => {
    if (!ctx.eligible || !ctx.periodKey || !ctx.householdId || delta === 0) {
        console.log('[BUDGET_CF] skip applyDelta eligible=%s period=%s household=%s delta=%s', ctx.eligible, ctx.periodKey, ctx.householdId, delta);
        return;
    }
    const memberBudgets = ctx.actorUserId
        ? await fetchMemberBudgets(ctx.householdId, ctx.periodKey, ctx.actorUserId)
        : [];
    const familyBudgets = await fetchFamilyBudgets(ctx.householdId, ctx.periodKey);
    console.log('[BUDGET_CF] matchedBudgets member=%d family=%d period=%s delta=%s actor=%s wallet_scope=%s household=%s', memberBudgets.length, familyBudgets.length, ctx.periodKey, delta, ctx.actorUserId ?? 'null', ctx.walletScope ?? 'null', ctx.householdId);
    let appliedCount = 0;
    for (const budget of [...memberBudgets, ...familyBudgets]) {
        if (!matchBudget(budget, txnData, ctx.actorUserId)) {
            console.log('[BUDGET_CF] skip budget=%s type=%s member=%s (match failed)', budget.budgetId, budget.budget_type, budget.member_user_id ?? 'null');
            continue;
        }
        await applyUsageDelta(budget, ctx.periodKey, delta, ctx.actorUserId, txnData, ctx.walletScope);
        appliedCount++;
    }
    console.log('[BUDGET_CF] applied delta to %d budgets', appliedCount);
};
const handleCreate = async (snap) => {
    const ctx = await buildTxnContext(snap);
    const data = snap.data() ?? {};
    console.log('[BUDGET_CF] event=create txn=%s type=%s amount=%s period=%s wallet=%s scope=%s actor=%s household=%s eligible=%s', snap.id, data.type, data.amount, ctx.periodKey, ctx.walletId, ctx.walletScope, ctx.actorUserId, ctx.householdId, ctx.eligible);
    if (!ctx.eligible)
        return;
    await applyContextDelta(ctx, ctx.amount, data);
};
const handleDelete = async (snap) => {
    const ctx = await buildTxnContext(snap);
    const data = snap.data() ?? {};
    console.log('[BUDGET_CF] event=delete txn=%s type=%s amount=%s period=%s wallet=%s scope=%s actor=%s household=%s eligible=%s', snap.id, data.type, data.amount, ctx.periodKey, ctx.walletId, ctx.walletScope, ctx.actorUserId, ctx.householdId, ctx.eligible);
    if (!ctx.eligible)
        return;
    await applyContextDelta(ctx, -ctx.amount, data);
};
const handleUpdate = async (before, after) => {
    const beforeCtx = await buildTxnContext(before);
    const afterCtx = await buildTxnContext(after);
    const beforeData = before.data() ?? {};
    const afterData = after.data() ?? {};
    console.log('[BUDGET_CF] event=update txn=%s amountBefore=%s amountAfter=%s actorBefore=%s actorAfter=%s householdBefore=%s householdAfter=%s eligibleBefore=%s eligibleAfter=%s periodBefore=%s periodAfter=%s scopeBefore=%s scopeAfter=%s', after.id, beforeCtx.amount, afterCtx.amount, beforeCtx.actorUserId, afterCtx.actorUserId, beforeCtx.householdId, afterCtx.householdId, beforeCtx.eligible, afterCtx.eligible, beforeCtx.periodKey, afterCtx.periodKey, beforeCtx.walletScope, afterCtx.walletScope);
    const sameBucket = beforeCtx.eligible &&
        afterCtx.eligible &&
        beforeCtx.periodKey === afterCtx.periodKey &&
        beforeCtx.householdId === afterCtx.householdId &&
        beforeCtx.actorUserId === afterCtx.actorUserId &&
        beforeCtx.walletScope === afterCtx.walletScope;
    if (sameBucket) {
        const delta = afterCtx.amount - beforeCtx.amount;
        await applyContextDelta(afterCtx, delta, afterData);
        return;
    }
    if (beforeCtx.eligible) {
        await applyContextDelta(beforeCtx, -beforeCtx.amount, beforeData);
    }
    if (afterCtx.eligible) {
        await applyContextDelta(afterCtx, afterCtx.amount, afterData);
    }
};
exports.onTransactionCreate = functions.firestore
    .document('transactions/{transactionId}')
    .onCreate(async (snap) => {
    await handleCreate(snap);
});
exports.onTransactionUpdate = functions.firestore
    .document('transactions/{transactionId}')
    .onUpdate(async (change) => {
    await handleUpdate(change.before, change.after);
});
exports.onTransactionDelete = functions.firestore
    .document('transactions/{transactionId}')
    .onDelete(async (snap) => {
    await handleDelete(snap);
});
//# sourceMappingURL=index.js.map