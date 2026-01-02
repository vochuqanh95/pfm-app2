import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/actor_utils.dart';
import '../../../data/models/debt_model.dart';
import '../../../data/models/debt_payment_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

// MANUAL TEST CHECKLIST (Debt module)
// 1. Create a new household debt (type = I Owe) from Debts screen.
// 2. Open Debt Detail -> verify Remaining, Due Date, Status.
// 3. Tap "Record Payment":
//    - Choose an amount and a wallet.
//    - Confirm: payment appears in Payment History,
//      wallet balance decreases, and a matching transaction is created.
// 4. Tap "Mark as Fully Paid":
//    - Remaining becomes 0, status becomes Paid,
//      a final payment entry is created.
// 5. Net worth:
//    - Home "Total Debts" decreases correctly.
//    - Reports "Debt Summary" updates.
// 6. Permissions:
//    - Member cannot see debts from other households.
//    - Household members can see payment history for shared household debts.
// 7. Navigation:
//    - Home Debts action card -> Debts list.
//    - No more "Debug: Open Debts" or "View all debts" entries.
// 8. Edit debt: change interest or description -> detail and reports update; type/amount edits clamp paid amount.

class DebtDetailScreen extends ConsumerWidget {
  final String debtId;

  const DebtDetailScreen({
    super.key,
    required this.debtId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtStreamProvider(debtId));

    return debtAsync.when(
      data: (debt) {
        if (debt == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Debt Detail')),
            body: const Center(child: Text('Debt not found')),
          );
        }

        final isOwedToMe = debt.type == DebtType.owedToMe;
        final color = isOwedToMe ? AppColors.success : AppColors.error;
        final progress = debt.paidProgress;
        final estimatedInterest = debt.simpleInterestEstimate;
        final totalDue = debt.totalDueEstimate;
        final status = debt.status;
        final statusColor = status == DebtStatus.overdue
            ? AppColors.error
            : status == DebtStatus.paid
                ? AppColors.success
                : AppColors.secondary;
        final dueLabel = debt.dueDate != null
            ? DateFormat('MMM d, yyyy').format(debt.dueDate!)
            : 'No due date';

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Debt Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/debt-edit/${debt.debtId}'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteDialog(context, ref, debt),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Debt Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isOwedToMe ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.name.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        debt.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        debt.creditorDebtor ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '\$${debt.remainingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'of \$${debt.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% paid',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Debt Information
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debt Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Type',
                                value: isOwedToMe ? 'Owed to Me' : 'I Owe',
                                icon: Icons.swap_horiz,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Status',
                                value: status.name.toUpperCase(),
                                icon: Icons.flag,
                                valueColor: statusColor,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: isOwedToMe ? 'Debtor' : 'Creditor',
                                value: debt.creditorDebtor ?? '',
                                icon: Icons.person,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Total Amount',
                                value: '\$${debt.amount.toStringAsFixed(2)}',
                                icon: Icons.attach_money,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Remaining',
                                value:
                                    '\$${debt.remainingAmount.toStringAsFixed(2)}',
                                icon: Icons.account_balance,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Interest Rate',
                                value:
                                    '${debt.interestRate.toStringAsFixed(2)}%',
                                icon: Icons.percent,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Est. Interest (simple)',
                                value:
                                    '\$${estimatedInterest.toStringAsFixed(2)}',
                                icon: Icons.trending_up,
                              ),
                              const Divider(height: 24),
                              _InfoRow(
                                label: 'Total Due (est.)',
                                value: '\$${totalDue.toStringAsFixed(2)}',
                                icon: Icons.summarize,
                              ),
                              if (debt.dueDate != null) ...[
                                const Divider(height: 24),
                                _InfoRow(
                                  label: 'Due Date',
                                  value: dueLabel,
                                  icon: Icons.calendar_today,
                                  valueColor: debt.isOverdue
                                      ? AppColors.error
                                      : (debt.isDueSoon
                                          ? AppColors.secondary
                                          : null),
                                ),
                              ],
                              if (debt.description != null &&
                                  debt.description!.isNotEmpty) ...[
                                const Divider(height: 24),
                                _InfoRow(
                                  label: 'Description',
                                  value: debt.description!,
                                  icon: Icons.notes,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Payment History
                      const Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PaymentHistoryCard(debtId: debtId),

                      const SizedBox(height: 24),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showRecordPaymentDialog(context, ref, debt),
                          icon: const Icon(Icons.payment),
                          label: const Text('Record Payment'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (debt.remainingAmount > 0)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _markAsFullyPaid(context, ref, debt),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark as Fully Paid'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Debt Detail')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Debt'),
        content: Text('Are you sure you want to delete "${debt.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(debtNotifierProvider.notifier)
                    .deleteDebt(debt.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debt deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(
      BuildContext context, WidgetRef ref, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => _RecordPaymentDialog(debt: debt),
    );
  }

  void _markAsFullyPaid(
      BuildContext context, WidgetRef ref, DebtModel debt) async {
    if (debt.remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt is already fully paid')),
      );
      return;
    }

    // Show dialog to select wallet or manual payment
    showDialog(
      context: context,
      builder: (context) => _MarkAsFullyPaidDialog(debt: debt),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ).copyWith(
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  final DebtPaymentModel payment;

  const _PaymentHistoryItem({
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.check,
            color: AppColors.success,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.note ?? 'Payment',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${payment.date.day}/${payment.date.month}/${payment.date.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          '\$${payment.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _PaymentHistoryCard extends ConsumerWidget {
  final String debtId;

  const _PaymentHistoryCard({required this.debtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(debtPaymentsStreamProvider(debtId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: paymentsAsync.when(
          data: (payments) {
            if (payments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: AppColors.textSecondary.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No payment history yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (int i = 0; i < payments.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  _PaymentHistoryItem(payment: payments[i]),
                ],
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Unable to load payment history',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(debtPaymentsStreamProvider(debtId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final DebtModel debt;

  const _RecordPaymentDialog({required this.debt});

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedWalletId;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('User not logged in'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    // Watch user wallets
    final walletsAsync = ref.watch(personalWalletsStreamProvider(user.userId));

    return AlertDialog(
      title: const Text('Record Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                helperText:
                    'Remaining: \$${widget.debt.remainingAmount.toStringAsFixed(2)}',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pay from wallet (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            walletsAsync.when(
              data: (wallets) {
                if (wallets.isEmpty) {
                  return Text(
                    'No wallets available',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  );
                }

                return DropdownButtonFormField<String?>(
                  value: _selectedWalletId,
                  decoration: const InputDecoration(
                    hintText: 'None (manual payment)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (manual payment)'),
                    ),
                    ...wallets.map((wallet) {
                      return DropdownMenuItem<String?>(
                        value: wallet.walletId,
                        child: Text(
                            '${wallet.name} (\$${wallet.balance.toStringAsFixed(2)})'),
                      );
                    }),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _selectedWalletId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                'Unable to load wallets',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _handleRecordPayment,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Record'),
        ),
      ],
    );
  }

  Future<void> _handleRecordPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > widget.debt.remainingAmount) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overpayment'),
          content: Text(
            'Payment amount (\$${amount.toStringAsFixed(2)}) exceeds remaining debt (\$${widget.debt.remainingAmount.toStringAsFixed(2)}). Continue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final userAsync = ref.read(authUserProvider);
    final user = userAsync.valueOrNull;
    if (user == null) return;

    final actor = buildActorInfo(user);

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(debtNotifierProvider.notifier).recordPayment(
            debtId: widget.debt.id,
            amount: amount,
            userId: user.userId,
            actorUserId: actor.userId,
            actorDisplayName: actor.displayName,
            actorRole: actor.role,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            walletId: _selectedWalletId,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _MarkAsFullyPaidDialog extends ConsumerStatefulWidget {
  final DebtModel debt;

  const _MarkAsFullyPaidDialog({required this.debt});

  @override
  ConsumerState<_MarkAsFullyPaidDialog> createState() =>
      _MarkAsFullyPaidDialogState();
}

class _MarkAsFullyPaidDialogState
    extends ConsumerState<_MarkAsFullyPaidDialog> {
  String? _selectedWalletId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('User not logged in'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final walletsAsync = ref.watch(personalWalletsStreamProvider(user.userId));

    return AlertDialog(
      title: const Text('Mark as Fully Paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining amount: \$${widget.debt.remainingAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How would you like to pay?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            walletsAsync.when(
              data: (wallets) {
                return Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('Manual (no wallet)'),
                      subtitle: const Text(
                          'Update debt status only, no wallet change'),
                      value: null,
                      groupValue: _selectedWalletId,
                      onChanged: (value) {
                        setState(() {
                          _selectedWalletId = value;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (wallets.isNotEmpty)
                      ...wallets.map((wallet) {
                        final canAfford =
                            wallet.balance >= widget.debt.remainingAmount;
                        return RadioListTile<String?>(
                          title: Text(wallet.name),
                          subtitle: Text(
                            '\$${wallet.balance.toStringAsFixed(2)}${!canAfford ? ' (insufficient balance)' : ''}',
                            style: TextStyle(
                              color: canAfford
                                  ? AppColors.textSecondary
                                  : AppColors.error,
                            ),
                          ),
                          value: wallet.walletId,
                          groupValue: _selectedWalletId,
                          onChanged: (value) {
                            setState(() {
                              _selectedWalletId = value;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    if (wallets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No wallets available. Payment will be manual.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(
                'Unable to load wallets',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _handleMarkAsPaid,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark Paid'),
        ),
      ],
    );
  }

  Future<void> _handleMarkAsPaid() async {
    final userAsync = ref.read(authUserProvider);
    final user = userAsync.valueOrNull;
    if (user == null) return;

    // If wallet is selected, verify sufficient balance
    if (_selectedWalletId != null) {
      final walletsAsync =
          ref.read(personalWalletsStreamProvider(user.userId));
      final wallets = walletsAsync.valueOrNull ?? [];
      final selectedWallet =
          wallets.firstWhere((w) => w.walletId == _selectedWalletId);

      if (selectedWallet.balance < widget.debt.remainingAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient balance in ${selectedWallet.name}. Available: \$${selectedWallet.balance.toStringAsFixed(2)}, Required: \$${widget.debt.remainingAmount.toStringAsFixed(2)}',
            ),
          ),
        );
        return;
      }
    }

    final actor = buildActorInfo(user);

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(debtNotifierProvider.notifier).markAsFullyPaid(
            debtId: widget.debt.id,
            userId: user.userId,
            actorUserId: actor.userId,
            actorDisplayName: actor.displayName,
            actorRole: actor.role,
            walletId: _selectedWalletId,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedWalletId != null
                  ? 'Debt fully paid via wallet'
                  : 'Debt marked as fully paid',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
