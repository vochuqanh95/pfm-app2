import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../models/budget_with_usage_model.dart';

class BudgetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'budgets';
  static const String _usageCollection = 'budget_usages';

  // Create budget
  Future<String> createBudget(BudgetModel budget) async {
    final docRef = await _firestore.collection(_collection).add(budget.toFirestore());
    return docRef.id;
  }

  // Get budget by ID
  Future<BudgetModel?> getBudgetById(String budgetId) async {
    final doc = await _firestore.collection(_collection).doc(budgetId).get();
    if (!doc.exists) return null;
    return BudgetModel.fromFirestore(doc);
  }

  // DISABLED: Personal budgets not supported (budgets are household-only)
  Future<List<BudgetModel>> getPersonalBudgets(String userId) async {
    debugPrint('[BUDGET_REPO] getPersonalBudgets DISABLED - budgets are household-only');
    return [];
  }

  // Get household budgets
  Future<List<BudgetModel>> getHouseholdBudgets(String householdId) async {
    final query = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .get();

    return query.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();
  }

  // Get active budgets (household-based only, NO user_id query)
  Future<List<BudgetModel>> getActiveBudgets({
    String? userId, // IGNORED - budgets are household-only
    String? householdId,
    String? periodKey,
    bool? isHead,
    String? viewerUserId,
  }) async {
    // CRITICAL: householdId is REQUIRED
    if (householdId == null) {
      debugPrint('[BUDGET_REPO] getActiveBudgets householdId=null -> returning empty');
      return [];
    }

    debugPrint(
        '[BUDGET_REPO] fetchBudgets role=${isHead == true ? 'head' : 'member'} viewer=$viewerUserId household=$householdId period=$periodKey');

    Query query = _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('archived', isEqualTo: false);

    if (periodKey != null) {
      query = query.where('period_key', isEqualTo: periodKey);
    }

    final result = await query.get();
    var budgets = result.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();

    // Filter for members: only family + own member budgets
    if (isHead == false && viewerUserId != null) {
      budgets = budgets.where((budget) =>
          budget.budgetType == 'family' ||
          (budget.budgetType == 'member' && budget.memberUserId == viewerUserId)).toList();
    }

    debugPrint('[BUDGET_REPO] fetchBudgets returned count=${budgets.length}');
    return budgets;
  }

  Future<List<BudgetModel>> getHeadBudgets({
    required String householdId,
    required String periodKey,
  }) async {
    final query = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('period_key', isEqualTo: periodKey)
        .where('archived', isEqualTo: false)
        .get();
    final budgets = query.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();
    debugPrint(
        '[BUDGET_REPO] head budgets query: household=$householdId period=$periodKey count=${budgets.length}');
    return budgets;
  }

  Future<List<BudgetModel>> getMemberBudgets({
    required String householdId,
    required String periodKey,
    required String memberUserId,
  }) async {
    final memberQuery = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('period_key', isEqualTo: periodKey)
        .where('budget_type', isEqualTo: 'member')
        .where('member_user_id', isEqualTo: memberUserId)
        .where('archived', isEqualTo: false)
        .get();
    final memberBudgets = memberQuery.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();

    final familyQuery = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('period_key', isEqualTo: periodKey)
        .where('budget_type', isEqualTo: 'family')
        .where('archived', isEqualTo: false)
        .get();
    final familyBudgets = familyQuery.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();

    final budgets = [...familyBudgets, ...memberBudgets];
    debugPrint(
        '[BUDGET_REPO] member budgets query: uid=$memberUserId household=$householdId period=$periodKey count=${budgets.length} (family=${familyBudgets.length} member=${memberBudgets.length})');
    return budgets;
  }

  // Get budget by category (DEPRECATED - budgets are household-based only)
  Future<BudgetModel?> getBudgetByCategory({
    required String categoryId,
    String? userId, // IGNORED
    String? householdId,
  }) async {
    // CRITICAL: householdId is REQUIRED (budgets are household-based only)
    if (householdId == null) {
      debugPrint('[BUDGET_REPO] getBudgetByCategory householdId=null -> returning null');
      return null;
    }

    Query query = _firestore
        .collection(_collection)
        .where('category_id', isEqualTo: categoryId)
        .where('household_id', isEqualTo: householdId);

    final result = await query.limit(1).get();
    if (result.docs.isEmpty) return null;
    return BudgetModel.fromFirestore(result.docs.first);
  }

  // Update budget
  Future<void> updateBudget(BudgetModel budget) async {
    await _firestore
        .collection(_collection)
        .doc(budget.budgetId)
        .update(budget.toFirestore());
  }

  // Delete budget
  Future<void> deleteBudget(String budgetId) async {
    await _firestore.collection(_collection).doc(budgetId).delete();
  }

  Future<void> setMemberDisplayName({
    required String budgetId,
    required String displayName,
  }) async {
    await _firestore
        .collection(_collection)
        .doc(budgetId)
        .update({'member_display_name': displayName});
  }

  // Stream budgets for Head (all household budgets)
  Stream<List<BudgetModel>> streamBudgetsForHead({
    required String householdId,
    required String periodKey,
  }) {
    debugPrint(
        '[BUDGET_STREAM] role=head household=$householdId period=$periodKey subscribed');
    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('period_key', isEqualTo: periodKey)
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final budgets = snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList();
      debugPrint('[BUDGET_STREAM] update count=${budgets.length} household=$householdId period=$periodKey');
      return budgets;
    });
  }

  // Stream budgets for Member (family + own member budgets)
  Stream<List<BudgetModel>> streamBudgetsForMember({
    required String householdId,
    required String periodKey,
    required String memberUserId,
  }) {
    debugPrint(
        '[BUDGET_STREAM] role=member household=$householdId period=$periodKey viewer=$memberUserId subscribed');
    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('period_key', isEqualTo: periodKey)
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      // Filter in memory: family budgets + own member budgets
      final budgets = snapshot.docs
          .map((doc) => BudgetModel.fromFirestore(doc))
          .where((budget) =>
              budget.budgetType == 'family' ||
              (budget.budgetType == 'member' && budget.memberUserId == memberUserId))
          .toList();
      debugPrint(
          '[BUDGET_STREAM] update count=${budgets.length} household=$householdId period=$periodKey viewer=$memberUserId');
      return budgets;
    });
  }

  // Legacy stream budgets (kept for compatibility)
  // DEPRECATED: Use streamBudgetsForHead() or streamBudgetsForMember() instead
  Stream<List<BudgetModel>> streamBudgets({
    String? userId, // IGNORED
    String? householdId,
    String? periodKey,
    bool? isHead,
    String? viewerUserId,
  }) {
    debugPrint('[BUDGET_REPO] streamBudgets DEPRECATED - use streamBudgetsForHead/Member instead');

    // CRITICAL: householdId is REQUIRED (budgets are household-based only)
    if (householdId == null) {
      debugPrint('[BUDGET_REPO] streamBudgets householdId=null -> returning empty stream');
      return Stream.value([]);
    }

    Query query = _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('archived', isEqualTo: false);

    if (periodKey != null) {
      query = query.where('period_key', isEqualTo: periodKey);
    }

    return query.snapshots().map(
          (query) => query.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList(),
        );
  }

  // Check if budget exceeded
  Future<bool> isBudgetExceeded({
    required String budgetId,
    required double spent,
  }) async {
    final budget = await getBudgetById(budgetId);
    if (budget == null) return false;
    return spent > budget.amount;
  }

  // Check if alert threshold reached
  Future<bool> isAlertThresholdReached({
    required String budgetId,
    required double spent,
  }) async {
    final budget = await getBudgetById(budgetId);
    if (budget == null) return false;
    return spent >= (budget.amount * budget.alertThreshold);
  }

  // ---- USAGE HELPERS ----

  String usageDocId(String budgetId, String periodKey) => '${budgetId}_$periodKey';

  Future<BudgetUsage?> getBudgetUsage({
    required String budgetId,
    required String periodKey,
    required String? householdId,
    String? viewerRole,
    String? viewerUserId,
  }) async {
    if (householdId == null) {
      debugPrint(
          '[BUDGET_USAGE] skip fetch budgetId=$budgetId period=$periodKey household=null');
      return null;
    }
    try {
      // PREFERRED: Direct doc fetch by ID (no query, no permission issues)
      final docRef =
          _firestore.collection(_usageCollection).doc(usageDocId(budgetId, periodKey));
      final snap = await docRef.get();
      final data = snap.data();

      debugPrint(
          '[BUDGET_USAGE] fetch usageDocId=${docRef.id} role=${viewerRole ?? 'unknown'} viewer=${viewerUserId ?? 'n/a'} exists=${snap.exists} spent=${data?['spent_amount'] ?? 0}');

      if (!snap.exists || data == null) {
        // No usage doc yet - return default (spent=0)
        return BudgetUsage(periodKey: periodKey, spentAmount: 0);
      }

      return BudgetUsage(
        periodKey: data['period_key'] ?? periodKey,
        spentAmount: (data['spent_amount'] ?? 0.0).toDouble(),
        lastAlertLevelSent: (data['last_alert_level_sent'] ?? 0) as int,
        updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      );
    } on FirebaseException catch (e) {
      debugPrint(
          '[BUDGET_USAGE] fetch FAILED usageDocId=${budgetId}_$periodKey role=${viewerRole ?? 'unknown'} error=${e.code}');
      // On permission-denied or other error, return default (spent=0)
      return BudgetUsage(periodKey: periodKey, spentAmount: 0);
    }
  }

  // PREFERRED: Watch usage by deterministic doc ID (no query, no permission issues)
  Stream<BudgetUsage?> watchUsage({
    required String budgetId,
    required String periodKey,
  }) {
    final docId = usageDocId(budgetId, periodKey);
    debugPrint('[BUDGET_USAGE] watch usageDocId=$docId');

    return _firestore
        .collection(_usageCollection)
        .doc(docId)
        .snapshots()
        .map((doc) {
      final exists = doc.exists;
      final data = doc.data();

      debugPrint(
          '[BUDGET_USAGE] watch usageDocId=$docId allowed=true exists=$exists spent=${data?['spent_amount'] ?? 0}');

      if (!exists || data == null) {
        // No usage doc yet - return null (caller treats as 0)
        return null;
      }

      return BudgetUsage(
        periodKey: data['period_key'] ?? periodKey,
        spentAmount: (data['spent_amount'] ?? 0.0).toDouble(),
        lastAlertLevelSent: (data['last_alert_level_sent'] ?? 0) as int,
        updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      );
    }).handleError((error) {
      debugPrint('[BUDGET_USAGE] watch usageDocId=$docId error=$error');
      // On permission error, return null (caller treats as 0)
      return null;
    });
  }

  // Legacy stream (deprecated, use watchUsage instead)
  Stream<BudgetUsage> streamBudgetUsage(String budgetId, String periodKey) {
    return watchUsage(budgetId: budgetId, periodKey: periodKey).map(
        (usage) => usage ?? BudgetUsage(periodKey: periodKey, spentAmount: 0));
  }
}
