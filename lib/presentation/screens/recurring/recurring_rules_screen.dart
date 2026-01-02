// Manual Testing Checklist:
// [ ] Screen shows all recurring rules for the current user/household
// [ ] Rules display name (category + note), amount, wallet, frequency, next run date, status
// [ ] Tapping a rule opens the detail view
// [ ] Pause/Resume toggle works correctly
// [ ] Delete button shows confirmation and deletes the rule
// [ ] Edit button opens edit form (to be implemented)
// [ ] Empty state shows when no recurring rules exist
// [ ] Head users can see all household rules
// [ ] Member users only see their own rules
// [ ] Active and Paused rules are visually distinct

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/recurring_rule_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/repositories/recurring_rule_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/wallet_provider.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Recurring Transactions')),
        body: const Center(child: Text('Unable to load user information.')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recurring Transactions')),
            body: const Center(child: Text('You must be signed in.')),
          );
        }

        final householdAsync = ref.watch(currentUserHouseholdProvider);
        final householdId = householdAsync.maybeWhen(
          data: (household) => household?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Recurring Transactions'),
          ),
          body: _RecurringRulesList(
            userId: user.userId,
            householdId: householdId,
            isHead: user.isHead,
          ),
        );
      },
    );
  }
}

class _RecurringRulesList extends ConsumerWidget {
  final String userId;
  final String householdId;
  final bool isHead;

  const _RecurringRulesList({
    required this.userId,
    required this.householdId,
    required this.isHead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(_recurringRulesStreamProvider(userId));

    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) {
          return _EmptyState();
        }

        // Separate active and paused rules
        final activeRules = rules.where((r) => r.isActive).toList();
        final pausedRules = rules.where((r) => !r.isActive).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (activeRules.isNotEmpty) ...[
              const _SectionHeader(title: 'Active'),
              const SizedBox(height: 8),
              ...activeRules.map((rule) => _RecurringRuleCard(
                    rule: rule,
                    onTap: () => _showRuleDetail(context, ref, rule),
                    onToggle: () => _toggleRuleStatus(ref, rule),
                    onDelete: () => _deleteRule(context, ref, rule),
                  )),
            ],
            if (pausedRules.isNotEmpty) ...[
              if (activeRules.isNotEmpty) const SizedBox(height: 24),
              const _SectionHeader(title: 'Paused'),
              const SizedBox(height: 8),
              ...pausedRules.map((rule) => _RecurringRuleCard(
                    rule: rule,
                    onTap: () => _showRuleDetail(context, ref, rule),
                    onToggle: () => _toggleRuleStatus(ref, rule),
                    onDelete: () => _deleteRule(context, ref, rule),
                  )),
            ],
          ],
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
            const SizedBox(height: 16),
            const Text(
              'Failed to load recurring rules',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.invalidate(_recurringRulesStreamProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRuleDetail(
      BuildContext context, WidgetRef ref, RecurringRuleModel rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _RecurringRuleDetailSheet(
          rule: rule,
          onEdit: () {
            Navigator.pop(context);
            // TODO: Navigate to edit recurring rule screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Edit recurring rule - To be implemented'),
              ),
            );
          },
          onDelete: () {
            Navigator.pop(context);
            _deleteRule(context, ref, rule);
          },
          onToggle: () {
            Navigator.pop(context);
            _toggleRuleStatus(ref, rule);
          },
        ),
      ),
    );
  }

  Future<void> _toggleRuleStatus(WidgetRef ref, RecurringRuleModel rule) async {
    if (rule.ruleId == null) return;
    try {
      await ref
          .read(_recurringRuleRepositoryProvider)
          .toggleActive(rule.ruleId!, !rule.isActive);
    } catch (e) {
      // Error handling would show a snackbar in production
      debugPrint('Error toggling rule status: $e');
    }
  }

  Future<void> _deleteRule(
      BuildContext context, WidgetRef ref, RecurringRuleModel rule) async {
    if (rule.ruleId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Rule'),
        content: const Text(
          'Are you sure you want to delete this recurring rule? This will not affect past transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(_recurringRuleRepositoryProvider)
            .deleteRecurringRule(rule.ruleId!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Recurring rule deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete rule: $e')),
          );
        }
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _RecurringRuleCard extends ConsumerWidget {
  final RecurringRuleModel rule;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringRuleCard({
    required this.rule,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = rule.templateType == 'expense';
    final color = isExpense ? AppColors.error : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    radius: 20,
                    child: Icon(
                      isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (rule.templateNote != null && rule.templateNote!.isNotEmpty)
                              ? rule.templateNote!
                              : (rule.templateCategoryId ?? 'Unknown'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<WalletModel?>(
                          future: ref
                              .read(walletRepositoryProvider)
                              .getWalletById(rule.walletId),
                          builder: (context, snapshot) {
                            final walletName =
                                snapshot.data?.name ?? 'Unknown Wallet';
                            return Text(
                              '$walletName · ${_getFrequencyLabel(rule.frequency)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isExpense ? '-' : '+'}\$${(rule.templateAmount ?? 0.0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (!rule.isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Paused',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Next: ${rule.nextDate != null ? DateFormat('MMM dd, yyyy').format(rule.nextDate!) : 'Not set'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      rule.isActive ? Icons.pause_circle : Icons.play_circle,
                      color: rule.isActive ? AppColors.warning : AppColors.success,
                    ),
                    onPressed: onToggle,
                    tooltip: rule.isActive ? 'Pause' : 'Resume',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFrequencyLabel(Frequency frequency) {
    switch (frequency) {
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.monthly:
        return 'Monthly';
      case Frequency.yearly:
        return 'Yearly';
    }
  }
}

class _RecurringRuleDetailSheet extends ConsumerWidget {
  final RecurringRuleModel rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _RecurringRuleDetailSheet({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = rule.templateType == 'expense';
    final color = isExpense ? AppColors.error : AppColors.success;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Text(
                  '${isExpense ? '-' : '+'}\$${(rule.templateAmount ?? 0.0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getFrequencyLabel(rule.frequency),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!rule.isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Paused',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Details
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: Icons.repeat,
                    label: 'Frequency',
                    value: _getFrequencyLabel(rule.frequency),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.event,
                    label: 'Next Transaction',
                    value: rule.nextDate != null
                        ? DateFormat('MMM dd, yyyy').format(rule.nextDate!)
                        : 'Not set',
                  ),
                  const SizedBox(height: 16),
                  if (rule.endDate != null) ...[
                    _DetailRow(
                      icon: Icons.event_busy,
                      label: 'End Date',
                      value: DateFormat('MMM dd, yyyy').format(rule.endDate!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FutureBuilder<WalletModel?>(
                    future: ref
                        .read(walletRepositoryProvider)
                        .getWalletById(rule.walletId),
                    builder: (context, snapshot) {
                      final walletName =
                          snapshot.data?.name ?? 'Unknown Wallet';
                      return _DetailRow(
                        icon: Icons.account_balance_wallet,
                        label: 'Wallet',
                        value: walletName,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.category,
                    label: 'Category',
                    value: rule.templateCategoryId ?? 'Unknown',
                  ),
                  if (rule.templateNote != null && rule.templateNote!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.note,
                      label: 'Note',
                      value: rule.templateNote!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      rule.isActive ? Icons.pause : Icons.play_arrow,
                      color: rule.isActive ? AppColors.warning : AppColors.success,
                    ),
                    label: Text(
                      rule.isActive ? 'Pause' : 'Resume',
                      style: TextStyle(
                        color: rule.isActive ? AppColors.warning : AppColors.success,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: rule.isActive ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(Frequency frequency) {
    switch (frequency) {
      case Frequency.daily:
        return 'Daily';
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.monthly:
        return 'Monthly';
      case Frequency.yearly:
        return 'Yearly';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No recurring transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a recurring transaction when adding a transaction and selecting a frequency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Providers
final _recurringRuleRepositoryProvider =
    Provider<RecurringRuleRepository>((ref) {
  return RecurringRuleRepository();
});

final _recurringRulesStreamProvider =
    StreamProvider.family.autoDispose<List<RecurringRuleModel>, String>(
  (ref, userId) {
    final repository = ref.watch(_recurringRuleRepositoryProvider);
    return repository.streamRecurringRulesForUser(userId);
  },
);
