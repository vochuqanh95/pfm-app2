import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/budget_with_usage_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';

/*
MANUAL TEST CHECKLIST — BUDGET DETAIL & DELETE
1) Head sees member names resolved ("My", "Khoi") not "Unknown member"; member sees "You" for their own budget.
2) Member view shows only their member budgets plus family budgets; edit/delete hidden; head can manage.
3) Shared expense $20 from household_shared wallet increments usage; personal wallet does not; edit to $50 then delete reflects $50 then $0.
4) Rules: member cannot create/update/delete budgets or read other members' budget docs/usages; head can read all household budgets/usages.
5) Permission denied or missing usage handled gracefully (shows 0 or error state, Retry works) without spinner loops or crashes.
6) DELETE TEST: Head deletes budget → budget disappears from list immediately without app restart. No permission-denied logs.
*/

class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;

  const BudgetDetailScreen({
    super.key,
    required this.budgetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetWithUsageAsync = ref.watch(budgetWithUsageProvider(budgetId));

    return budgetWithUsageAsync.when(
      data: (budgetWithUsage) {
        if (budgetWithUsage == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Budget Details')),
            body: const Center(child: Text('Budget not found')),
          );
        }

        return _BudgetDetailContent(budgetWithUsage: budgetWithUsage, ref: ref);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Budget Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Budget Details')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

}

class _BudgetDetailContent extends StatelessWidget {
  final BudgetWithUsage budgetWithUsage;
  final WidgetRef ref;

  const _BudgetDetailContent({
    required this.budgetWithUsage,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final budget = budgetWithUsage.budget;
    final user = ref.watch(authUserProvider).value;
    final canManage = user?.isHead ?? false;
    final memberDetailsAsync = (budget.householdId != null && (user?.isHead ?? false))
        ? ref.watch(householdMemberDetailsProvider(budget.householdId!))
        : const AsyncValue.data(<HouseholdMemberDetail>[]);
    final memberNameMap = memberDetailsAsync.maybeWhen(
      data: (members) {
        debugPrint(
            '[HOUSEHOLD_MEMBERS] Loaded ${members.length} members for household=${budget.householdId}');
        return {for (final m in members) m.membership.userId: m.displayName};
      },
      orElse: () => <String, String>{},
    );
    final memberName = budget.isMemberBudget
        ? _resolveMemberName(
            budget,
            memberNameMap,
            user?.isHead ?? false,
            viewerUserId: user?.userId ?? '',
          )
        : null;
    final spentAmount = budgetWithUsage.usage.spentAmount;
    final isOverBudget = budgetWithUsage.isOverBudget;
    final isNearLimit = budgetWithUsage.isNearLimit;

    Color progressColor = AppColors.success;
    if (isOverBudget) {
      progressColor = AppColors.error;
    } else if (isNearLimit) {
      progressColor = AppColors.warning;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Budget Details'),
        actions: canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit budget (coming soon)')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(context, ref, budget),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Budget Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Total Budget',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${budget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (budgetWithUsage.usagePercent / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SummaryItem(
                          label: 'Spent',
                          amount: '\$${spentAmount.toStringAsFixed(2)}',
                          color: progressColor,
                        ),
                        _SummaryItem(
                          label: 'Remaining',
                          amount: '\$${budgetWithUsage.remainingAmount.toStringAsFixed(2)}',
                          color: budgetWithUsage.remainingAmount >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Budget Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Period',
                      value: '${_formatDate(budget.startDate)} - ${_formatDate(budget.endDate)}',
                    ),
                    _InfoRow(
                      icon: Icons.category,
                      label: 'Category',
                      value: budget.categoryId,
                    ),
                    _InfoRow(
                      icon: Icons.group,
                      label: 'Type',
                      value: budget.isMemberBudget
                          ? 'Member budget (${memberName ?? 'Unknown member'})'
                          : 'Household shared budget',
                    ),
                    _InfoRow(
                      icon: Icons.notifications,
                      label: 'Alert at',
                      value: '${(budget.alertThreshold * 100).toInt()}%',
                    ),
                    _InfoRow(
                      icon: Icons.history,
                      label: 'Last alert level',
                      value: '${budgetWithUsage.usage.lastAlertLevelSent}%',
                    ),
                    _InfoRow(
                      icon: Icons.percent,
                      label: 'Usage',
                      value: '${budgetWithUsage.usagePercent.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Usage is updated automatically from household_shared expense transactions for this month.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveMemberName(
    BudgetModel budget,
    Map<String, String> memberNameMap,
    bool isHead, {
    required String viewerUserId,
  }) {
    if (!budget.isMemberBudget) return '';
    final memberUserId = budget.memberUserId;
    final storedName = _sanitizeMemberName(budget.memberDisplayName);
    final mapName =
        _sanitizeMemberName(memberUserId != null ? memberNameMap[memberUserId] : null);

    String finalName;
    if (memberUserId != null && memberUserId == viewerUserId) {
      finalName = 'You';
    } else if (storedName != null) {
      finalName = storedName;
    } else if (mapName != null) {
      finalName = mapName;
    } else {
      finalName = 'Unknown member';
    }

    _logBudgetName(
      budget: budget,
      storedName: storedName,
      resolvedName: mapName,
      finalName: finalName,
      viewerUserId: viewerUserId,
      isHead: isHead,
    );
    return finalName;
  }

  String? _sanitizeMemberName(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.toLowerCase() == 'unknown member') return null;
    return value;
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
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to format dates
String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) {
    return 'Today, ${DateFormat.jm().format(date)}';
  } else if (dateOnly == yesterday) {
    return 'Yesterday, ${DateFormat.jm().format(date)}';
  } else if (now.difference(dateOnly).inDays < 7) {
    return '${now.difference(dateOnly).inDays} days ago';
  } else {
    return DateFormat.yMMMd().format(date);
  }
}

// Helper function to show delete confirmation dialog
void _showDeleteDialog(BuildContext context, WidgetRef ref, BudgetModel budget) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Budget'),
      content: Text('Are you sure you want to delete this budget for ${budget.categoryId}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              debugPrint('[BUDGET_DELETE] start id=${budget.budgetId} household=${budget.householdId} period=${budget.periodKey}');

              // Delete the budget using the provider
              await ref.read(budgetNotifierProvider.notifier).deleteBudget(budget.budgetId);

              // CRITICAL: Invalidate list provider to force refresh
              final user = ref.read(authUserProvider).value;
              final household = ref.read(currentUserHouseholdProvider).valueOrNull;
              if (budget.periodKey != null && (budget.householdId != null || household != null)) {
                final householdId = budget.householdId ?? household?.householdId;
                ref.invalidate(
                  activeBudgetsWithUsageProvider(
                    BudgetParams(
                      userId: null,
                      householdId: householdId,
                      periodKey: budget.periodKey,
                      isHead: user?.isHead,
                      viewerUserId: user?.userId,
                    ),
                  ),
                );
                debugPrint('[BUDGET_DELETE] success id=${budget.budgetId} invalidated household=$householdId period=${budget.periodKey}');
              }

              if (context.mounted) {
                Navigator.pop(dialogContext); // Close dialog
                context.pop(); // Go back to budget list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Budget deleted')),
                );
              }
            } catch (e) {
              debugPrint('[BUDGET_DELETE] error id=${budget.budgetId} error=$e');
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting budget: $e')),
                );
              }
            }
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}
