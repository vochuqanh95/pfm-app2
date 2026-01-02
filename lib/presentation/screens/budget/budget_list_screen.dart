import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/budget_with_usage_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/household_provider.dart';

/*
MANUAL TEST PLAN & RESULTS — BUDGET LIST (Issue A & B Fixes)

=== ISSUE A: DELETE MUST UPDATE LIST INSTANTLY ===
T1 — Delete refresh:
  Steps: Head creates 2 budgets → delete 1 → verify it disappears immediately (no restart)
  Expected: Deleted budget removed from list within 1 second
  Result: [ ] PASS / [ ] FAIL
  Notes: Watch logs: [BUDGET_DELETE] success, [BUDGET_LIST] stream update

=== ISSUE B: MEMBER TRANSACTIONS MUST INCREMENT BUDGETS ===
T2 — Member attribution:
  Steps: Member "Khoi" creates $20 expense from household_shared wallet
  Expected: Khoi's member budget spent increases by $20 within 5 seconds
  Result: [ ] PASS / [ ] FAIL
  Notes: Watch CF logs: [BUDGET_CF] event=create eligible=true, [BUDGET_CF] applied delta to N budgets

T3 — Delta edit:
  Steps: Edit $20 expense → change to $50
  Expected: Budget increases by +$30 (delta)
  Result: [ ] PASS / [ ] FAIL
  Notes: Watch CF logs: [BUDGET_CF] event=update delta=30

T4 — Delete transaction:
  Steps: Delete the $50 expense
  Expected: Budget decreases by $50
  Result: [ ] PASS / [ ] FAIL
  Notes: Watch CF logs: [BUDGET_CF] event=delete delta=-50

T5 — Wallet scope guard:
  Steps: Khoi creates $15 expense from personal wallet
  Expected: Budget usage UNCHANGED (only household_shared counts)
  Result: [ ] PASS / [ ] FAIL
  Notes: Watch CF logs: [BUDGET_CF] eligible=false (wallet scope check)

T6 — Permissions:
  Steps: Member tries to delete budget / access other members' budgets
  Expected: Delete button hidden; no permission-denied logs for budget_usages reads
  Result: [ ] PASS / [ ] FAIL
  Notes: Check Firestore rules enforce head-only write, member read restrictions

=== EXISTING TESTS (from previous fixes) ===
1) Head opens Budgets for a month: member budgets show real names (e.g., "My", "Khoi"), never "Unknown member".
2) Member (Khoi) opens Budgets: sees only their member budgets plus family budgets; no other members; add button hidden.
3) Permission denied or missing usage: list shows stable error/empty state with Retry, no infinite spinner or crash.
4) Shared expense ($20) from household_shared wallet increments Khoi budget usage for that month; personal wallet does not.
5) Edit shared expense $20→$50 updates usage to $50; deleting it resets usage to $0.
6) Rules: member cannot create/update/delete budgets or read other members' budget docs/usages; head can read all household budgets/usages.
*/

class BudgetListScreen extends ConsumerStatefulWidget {
  const BudgetListScreen({super.key});

  @override
  ConsumerState<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends ConsumerState<BudgetListScreen> {
  DateTime _selectedMonth = DateTime.now();
  final Set<String> _backfilledBudgetIds = {};
  final Map<String, String> _resolvedMemberNames = {};
  final Set<String> _pendingMemberLookups = {};

  // Alert checking removed - Cloud Functions handle budget alerts automatically

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);
    final periodKey =
        '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}';

    return authState.when(
      data: (UserModel? user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login')),
          );
        }

        final householdId = householdAsync.valueOrNull?.householdId ?? user.householdId;
        final roleLabel = user.isHead ? 'head' : 'member';
        final memberDetailsAsync = (householdId != null && user.isHead)
            ? ref.watch(householdMemberDetailsProvider(householdId))
            : const AsyncValue.data(<HouseholdMemberDetail>[]);

        // PHASE A FIX: Use STREAM provider for real-time updates
        final budgetsWithUsageAsync = ref.watch(
          activeBudgetsWithUsageStreamProvider(
            BudgetParams(
              userId: householdId == null ? user.userId : null,
              householdId: householdId,
              periodKey: periodKey,
              isHead: user.isHead,
              viewerUserId: user.userId,
            ),
          ),
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Budgets'),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedMonth,
                    firstDate: DateTime(DateTime.now().year - 1, 1, 1),
                    lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    initialEntryMode: DatePickerEntryMode.calendarOnly,
                  );
                  if (picked != null) {
                    setState(() => _selectedMonth = picked);
                  }
                },
              ),
              if (user.isHead)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/add-budget'),
                ),
            ],
          ),
          body: budgetsWithUsageAsync.when(
            data: (budgetsWithUsage) {
              final memberNameMap = memberDetailsAsync.maybeWhen(
                data: (members) {
                  debugPrint(
                      '[HOUSEHOLD_MEMBERS] Loaded ${members.length} members for household=$householdId');
                  return {
                    for (final m in members) m.membership.userId: m.displayName,
                  };
                },
                orElse: () => <String, String>{},
              );

              debugPrint(
                  '[BUDGET_UI] rebuild role=$roleLabel month=$periodKey items=${budgetsWithUsage.length} household=$householdId');
              for (final bwu in budgetsWithUsage.take(3)) {
                debugPrint(
                    '[BUDGET_LIST] budget=${bwu.budget.budgetId} type=${bwu.budget.budgetType} member_user_id=${bwu.budget.memberUserId} stored_name=${bwu.budget.memberDisplayName} spent=${bwu.usage.spentAmount}');
              }

              if (budgetsWithUsage.isEmpty) {
                debugPrint('[BUDGET_LIST] EMPTY state reached, provider returned 0 items');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No budgets yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a budget to track your spending',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (user.isHead) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-budget'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Budget'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
              itemCount: budgetsWithUsage.length,
              itemBuilder: (context, index) {
                final budgetWithUsage = budgetsWithUsage[index];
                final resolvedName = budgetWithUsage.budget.isMemberBudget
                    ? _resolveMemberName(
                        budgetWithUsage.budget,
                        memberNameMap,
                        user.isHead,
                        viewerUserId: user.userId,
                      )
                    : null;

                return _BudgetCard(
                  budgetWithUsage: budgetWithUsage,
                  memberNameOverride: resolvedName,
                );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load budgets: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  String? _resolveMemberName(
    BudgetModel budget,
    Map<String, String> memberNameMap,
    bool isHead, {
    required String viewerUserId,
  }) {
    if (!budget.isMemberBudget) return null;
    final memberUserId = budget.memberUserId;
    final storedName = _sanitizeMemberName(budget.memberDisplayName);
    final mapName = _sanitizeMemberName(memberUserId != null ? memberNameMap[memberUserId] : null);
    final cachedName =
        _sanitizeMemberName(memberUserId != null ? _resolvedMemberNames[memberUserId] : null);

    String finalName;
    if (memberUserId != null && memberUserId == viewerUserId) {
      finalName = 'You';
    } else if (storedName != null) {
      finalName = storedName;
    } else if (mapName != null) {
      finalName = mapName;
    } else if (cachedName != null) {
      finalName = cachedName;
    } else {
      finalName = 'Unknown member';
      _triggerAsyncMemberLookup(budget);
    }

    final resolvedLookup = mapName ?? cachedName;
    _logBudgetName(
      budget: budget,
      storedName: storedName,
      resolvedName: resolvedLookup,
      finalName: finalName,
      viewerUserId: viewerUserId,
      isHead: isHead,
    );

    if (isHead &&
        resolvedLookup != null &&
        resolvedLookup.isNotEmpty &&
        finalName != 'You' &&
        !_isValidMemberName(budget.memberDisplayName)) {
      _maybeBackfillMemberName(
        budget,
        resolvedLookup,
      );
    }

    return finalName;
  }

  String? _sanitizeMemberName(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.toLowerCase() == 'unknown member') return null;
    return value;
  }

  bool _isValidMemberName(String? raw) => _sanitizeMemberName(raw) != null;

  Future<void> _triggerAsyncMemberLookup(BudgetModel budget) async {
    final memberUserId = budget.memberUserId;
    final householdId = budget.householdId;
    if (memberUserId == null || householdId == null) return;
    if (_pendingMemberLookups.contains(memberUserId)) return;
    _pendingMemberLookups.add(memberUserId);
    try {
      final resolved = await ref.read(memberNameResolverProvider).resolveMemberName(
            householdId: householdId,
            memberUserId: memberUserId,
          );
      final sanitized = _sanitizeMemberName(resolved);
      if (sanitized != null && mounted) {
        setState(() {
          _resolvedMemberNames[memberUserId] = sanitized;
        });
        final isHead = ref.read(authUserProvider).value?.isHead ?? false;
        if (isHead && !_isValidMemberName(budget.memberDisplayName)) {
          _maybeBackfillMemberName(budget, sanitized);
        }
      }
    } finally {
      _pendingMemberLookups.remove(memberUserId);
    }
  }

  void _logBudgetName({
    required BudgetModel budget,
    required String? storedName,
    required String? resolvedName,
    required String finalName,
    required String viewerUserId,
    required bool isHead,
  }) {
    debugPrint(
        '[BUDGET_NAME] budget=${budget.budgetId} member_user_id=${budget.memberUserId} stored=${storedName ?? 'null'} resolved=${resolvedName ?? 'null'} final=$finalName viewer=$viewerUserId role=${isHead ? 'head' : 'member'}');
  }

  Future<void> _maybeBackfillMemberName(
    BudgetModel budget,
    String displayName,
  ) async {
    if (displayName == 'You' || displayName.trim().isEmpty) return;
    if (_backfilledBudgetIds.contains(budget.budgetId)) return;
    _backfilledBudgetIds.add(budget.budgetId);
    try {
      await ref.read(budgetRepositoryProvider).setMemberDisplayName(
            budgetId: budget.budgetId,
            displayName: displayName,
          );
      debugPrint(
          '[BUDGET_BACKFILL] Updating budget=${budget.budgetId} member_display_name=$displayName');
    } catch (e) {
      debugPrint(
          '[BUDGET_BACKFILL] Failed to update budget=${budget.budgetId} error=$e');
    }
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetWithUsage budgetWithUsage;
  final String? memberNameOverride;

  const _BudgetCard({
    required this.budgetWithUsage,
    this.memberNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final budget = budgetWithUsage.budget;
    final spent = budgetWithUsage.usage.spentAmount;
    final percentage = budgetWithUsage.usagePercent;
    final isOverBudget = budgetWithUsage.isOverBudget;
    final isNearLimit = budgetWithUsage.isNearLimit;

    Color progressColor = AppColors.success;
    if (isOverBudget) {
      progressColor = AppColors.error;
    } else if (isNearLimit) {
      progressColor = AppColors.warning;
    }

    final title = budget.budgetType == 'member'
        ? 'Member Budget'
        : 'Family Budget';
    final subtitle = budget.budgetType == 'member'
        ? 'Member: ${memberNameOverride ?? budget.memberDisplayName ?? 'Unknown member'}'
        : 'Household shared wallets';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/budget-detail/${budget.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.pie_chart,
                      color: progressColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.simpleCurrency().format(spent),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                      Text(
                        'of ${NumberFormat.simpleCurrency().format(budget.amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}% used',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${budgetWithUsage.usage.lastAlertLevelSent}% alerted',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
