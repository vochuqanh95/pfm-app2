// Manual Testing Checklist:
// [ ] Transaction detail opens when tapping a transaction in Recent Transactions
// [ ] Amount displays correctly (red for expense, green for income)
// [ ] All transaction details are visible (wallet, category, date, actor, note, receipt)
// [ ] Receipt thumbnail opens full screen when tapped
// [ ] "From recurring rule" chip shows when transaction has recurring_rule_id
// [ ] Edit button opens Add Transaction screen pre-filled (Head can edit all, Member only their own)
// [ ] Delete button shows confirmation dialog and deletes transaction (Head can delete all, Member only their own)
// [ ] Duplicate button opens Add Transaction pre-filled with today's date
// [ ] Status badge displays correctly (Approved/Pending/Rejected)
// [ ] Read-only mode shows when Member tries to view other's transactions (no edit/delete buttons)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/actor_utils.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/recurring_rule_model.dart';
import '../../data/repositories/recurring_rule_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';

class TransactionDetailSheet extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const Center(child: Text('Unable to load user information.')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('You must be signed in.'));
        }

        // Check permissions: Head can edit all, Member can only edit their own
        final canEdit = user.isHead || transaction.actorUserId == user.userId;

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
              // Header with amount and type
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      transaction.type == TransactionType.expense
                          ? '-\$${transaction.amount.toStringAsFixed(2)}'
                          : transaction.type == TransactionType.income
                              ? '+\$${transaction.amount.toStringAsFixed(2)}'
                              : '\$${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: transaction.type == TransactionType.expense
                            ? AppColors.error
                            : transaction.type == TransactionType.income
                                ? AppColors.success
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTypeDisplayName(transaction.type),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(status: transaction.status),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Transaction details
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today,
                        label: 'Date & Time',
                        value: DateFormat('MMM dd, yyyy · hh:mm a').format(transaction.date),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<WalletModel?>(
                        future: ref.read(walletRepositoryProvider).getWalletById(transaction.walletId),
                        builder: (context, snapshot) {
                          final walletName = snapshot.data?.name ?? 'Unknown Wallet';
                          final walletIcon = _getWalletIcon(snapshot.data?.type);
                          return _DetailRow(
                            icon: walletIcon,
                            label: 'Wallet',
                            value: walletName,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _CategoryRow(transaction: transaction),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.person,
                        label: 'Created By',
                        value: formatActorLabel(
                          transaction.actorDisplayName ?? 'Unknown',
                          transaction.actorRole ?? 'member',
                        ),
                      ),
                      if (transaction.note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.note,
                          label: 'Note',
                          value: transaction.note,
                        ),
                      ],
                      if (transaction.imageUrl != null) ...[
                        const SizedBox(height: 16),
                        _ReceiptRow(imageUrl: transaction.imageUrl!),
                      ],
                      if (transaction.recurringRuleId != null) ...[
                        const SizedBox(height: 16),
                        _RecurringRuleChip(ruleId: transaction.recurringRuleId!),
                      ],
                    ],
                  ),
                ),
              ),
              // Action buttons
              if (canEdit)
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
                          onPressed: () => _handleDelete(context, ref),
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleEdit(context),
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
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'You can only edit or delete your own transactions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getTypeDisplayName(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData _getWalletIcon(WalletType? type) {
    if (type == null) return Icons.account_balance_wallet;
    switch (type) {
      case WalletType.cash:
        return Icons.money;
      case WalletType.bank:
        return Icons.account_balance;
      case WalletType.card:
        return Icons.credit_card;
      case WalletType.ewallet:
        return Icons.phone_android;
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.pop(context);
    context.push('/transaction/${transaction.transactionId}/edit');
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
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
        debugPrint(
            '[TXN_FIX] Deleting txn id=${transaction.transactionId} type=${transaction.type.name} amount=${transaction.amount} wallet=${transaction.walletId}');
        await ref.read(transactionServiceProvider).deleteTransaction(transaction.transactionId);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted and wallet updated')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete transaction: $e')),
          );
        }
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final TransactionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;

    switch (status) {
      case TransactionStatus.approved:
        badgeColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case TransactionStatus.pending:
        badgeColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        break;
      case TransactionStatus.rejected:
        badgeColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

class _CategoryRow extends ConsumerWidget {
  final TransactionModel transaction;

  const _CategoryRow({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameMap = ref.watch(
      categoryNameMapProvider(
        CategoryNameMapParams(
          userId: transaction.userId,
          householdId: transaction.householdId,
        ),
      ),
    );
    final resolvedName = (transaction.categoryName != null &&
            transaction.categoryName!.isNotEmpty)
        ? transaction.categoryName!
        : nameMap[transaction.categoryId] ?? 'Unknown category';

    return _DetailRow(
      icon: Icons.category,
      label: 'Category',
      value: resolvedName,
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String imageUrl;

  const _ReceiptRow({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text(
              'Receipt',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // TODO: Open full-screen image viewer
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(imageUrl),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              height: 120,
              width: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: 120,
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, color: AppColors.error),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RecurringRuleChip extends ConsumerWidget {
  final String ruleId;

  const _RecurringRuleChip({required this.ruleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<RecurringRuleModel?>(
      future: ref.read(recurringRuleRepositoryProvider).getRecurringRuleById(ruleId),
      builder: (context, snapshot) {
        final ruleName = snapshot.data != null
            ? '${snapshot.data!.frequency.name.toUpperCase()} recurring'
            : 'Recurring rule';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.repeat, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              Text(
                ruleName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.info,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Provider for recurring rule repository
final recurringRuleRepositoryProvider = Provider<RecurringRuleRepository>((ref) {
  return RecurringRuleRepository();
});
