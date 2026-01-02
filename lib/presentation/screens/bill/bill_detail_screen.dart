import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/actor_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/enums/app_currency.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/settings_provider.dart';

class BillDetailScreen extends ConsumerWidget {
  final String billId;

  const BillDetailScreen({
    super.key,
    required this.billId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billByIdProvider(billId));
    final settingsAsync = ref.watch(appSettingsProvider);

    return billAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Bill Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Unable to load bill'),
              const SizedBox(height: 8),
              Text('$error', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(billByIdProvider(billId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (bill) {
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bill Details')),
            body: const Center(child: Text('Bill not found')),
          );
        }
        final selectedCurrency = settingsAsync.valueOrNull?.currency ?? AppCurrency.usd;

        return _BillDetailContent(
          bill: bill,
          selectedCurrency: selectedCurrency,
        );
      },
    );
  }
}

class _BillDetailContent extends ConsumerWidget {
  final BillModel bill;
  final AppCurrency selectedCurrency;

  const _BillDetailContent({required this.bill, required this.selectedCurrency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysUntilDue = bill.daysUntilDue;
    final isOverdue = bill.isOverdue;
    final isDueSoon = daysUntilDue >= 0 && daysUntilDue <= 3;

    Color statusColor = AppColors.textSecondary;
    String statusText = 'Upcoming';

    if (bill.isPaid) {
      statusColor = AppColors.success;
      statusText = 'Paid';
    } else if (isOverdue) {
      statusColor = AppColors.error;
      statusText = 'Overdue by ${daysUntilDue.abs()} day${daysUntilDue.abs() == 1 ? '' : 's'}';
    } else if (isDueSoon) {
      statusColor = AppColors.warning;
      statusText = 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          if (!bill.isPaid)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/bill/edit/${bill.billId}'),
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bill Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      bill.isPaid ? Icons.check_circle : Icons.receipt_long,
                      size: 60,
                      color: statusColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      bill.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      MoneyFormatter.format(bill.amount, currency: selectedCurrency),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: bill.isPaid ? AppColors.textSecondary : statusColor,
                        decoration: bill.isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bill Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Due Date',
                      value: DateFormat('MMM dd, yyyy').format(bill.dueDate),
                    ),
                    _InfoRow(
                      icon: Icons.repeat,
                      label: 'Recurring',
                      value: _getRecurrenceLabel(bill.recurrence),
                    ),
                    _InfoRow(
                      icon: Icons.group,
                      label: 'Type',
                      value: bill.scope == 'family' ? 'Family Bill' : 'Personal Bill',
                    ),
                    _InfoRow(
                      icon: Icons.notifications,
                      label: 'Reminder',
                      value: '${bill.remindDaysBefore} day${bill.remindDaysBefore == 1 ? '' : 's'} before',
                    ),
                    if (bill.isRecurring)
                      _InfoRow(
                        icon: Icons.info_outline,
                        label: 'Next Occurrence',
                        value: 'Auto-generated when paid',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mark as Paid Button (only if unpaid)
            if (!bill.isPaid)
              ElevatedButton.icon(
                onPressed: () => _markAsPaid(context, ref),
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark as Paid'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.success,
                ),
              ),

            // Mark as Unpaid Button (if paid and needs correction)
            if (bill.isPaid) ...[
              OutlinedButton.icon(
                onPressed: () => _markAsUnpaid(context, ref),
                icon: const Icon(Icons.undo),
                label: const Text('Mark as Unpaid'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRecurrenceLabel(BillRecurrence recurrence) {
    switch (recurrence) {
      case BillRecurrence.none:
        return 'One-time';
      case BillRecurrence.monthly:
        return 'Monthly';
      case BillRecurrence.yearly:
        return 'Yearly';
      case BillRecurrence.custom:
        return 'Custom';
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text(
          'Are you sure you want to delete this bill? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(billNotifierProvider.notifier).deleteBill(bill.billId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill deleted')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting bill: $e')),
          );
        }
      }
    }
  }

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    // Get current user and household
    final user = ref.read(authUserProvider).value;
    final household = ref.read(currentUserHouseholdProvider).value;

    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to pay bills')),
        );
      }
      return;
    }

    if (household == null || bill.householdId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill must belong to a household')),
        );
      }
      return;
    }

    // Show wallet selection dialog
    final selectedWallet = await _showWalletSelectionDialog(context, ref, household.householdId);

    if (selectedWallet == null) {
      // User cancelled
      return;
    }

    // Pay the bill with the selected wallet
    final actor = buildActorInfo(user);

    try {
      await ref.read(billNotifierProvider.notifier).payBillWithWallet(
        billId: bill.billId,
        householdId: household.householdId,
        walletId: selectedWallet.walletId,
        actorUserId: actor.userId,
        actorDisplayName: actor.displayName,
        actorRole: actor.role,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill paid from wallet "${selectedWallet.name}"')),
        );
        // Refresh the bill data
        ref.invalidate(billByIdProvider(bill.billId));
        ref.invalidate(householdWalletsStreamProvider);
        ref.invalidate(upcomingHouseholdBillsStreamProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<WalletModel?> _showWalletSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    String householdId,
  ) async {
    // Get household wallets
    final walletsAsync = ref.read(householdWalletsStreamProvider(householdId));

    return walletsAsync.when(
      loading: () => null,
      error: (_, __) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load wallets')),
        );
        return null;
      },
      data: (wallets) async {
        // Filter to only family/household shared wallets and non-archived
        final familyWallets = wallets
            .where((w) => w.scope == WalletScope.householdShared && !w.archived)
            .toList();

        if (familyWallets.isEmpty) {
          if (context.mounted) {
            final createWallet = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No Family Wallet Available'),
                content: const Text(
                  'You need a family wallet to pay household bills. Would you like to create one?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Create Wallet'),
                  ),
                ],
              ),
            );

            if (createWallet == true && context.mounted) {
              context.push('/wallet/add');
            }
          }
          return null;
        }

        // Show wallet selection dialog
        if (context.mounted) {
          return await showDialog<WalletModel>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Select Wallet to Pay From'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: familyWallets.length,
                  itemBuilder: (context, index) {
                    final wallet = familyWallets[index];
                    return ListTile(
                      leading: Icon(
                        _getWalletIcon(wallet.type),
                        color: AppColors.primary,
                      ),
                      title: Text(wallet.name),
                      subtitle: Text(
                        MoneyFormatter.format(wallet.balance, currency: selectedCurrency),
                        style: TextStyle(
                          color: wallet.balance >= bill.amount
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: wallet.balance < bill.amount
                          ? const Icon(Icons.warning, color: AppColors.warning, size: 20)
                          : null,
                      onTap: () => Navigator.pop(dialogContext, wallet),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        }
        return null;
      },
    );
  }

  IconData _getWalletIcon(WalletType type) {
    switch (type) {
      case WalletType.cash:
        return Icons.money;
      case WalletType.bank:
        return Icons.account_balance;
      case WalletType.card:
        return Icons.credit_card;
      case WalletType.ewallet:
        return Icons.account_balance_wallet;
    }
  }

  Future<void> _markAsUnpaid(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(billNotifierProvider.notifier).markAsUnpaid(bill.billId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill marked as unpaid')),
        );
        ref.invalidate(billByIdProvider(bill.billId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
