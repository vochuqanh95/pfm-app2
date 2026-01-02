import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/bill_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/auth_provider.dart';

class BillListScreen extends ConsumerWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login')),
          );
        }

        final upcomingBillsAsync = ref.watch(upcomingBillsProvider(
          UpcomingBillParams(userId: user.uid, daysAhead: 30),
        ));

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Bills'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // TODO: Navigate to add bill screen
                  context.push('/add-bill');
                },
              ),
            ],
          ),
          body: upcomingBillsAsync.when(
            data: (bills) {
              if (bills.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bills yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add bills to track your payments',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/add-bill');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Bill'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return _BillCard(bill: bill);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final BillModel bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final daysUntilDue = bill.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = daysUntilDue >= 0 && daysUntilDue <= 3;

    Color statusColor = AppColors.textSecondary;
    if (bill.isPaid) {
      statusColor = AppColors.success;
    } else if (isOverdue) {
      statusColor = AppColors.error;
    } else if (isDueSoon) {
      statusColor = AppColors.warning;
    }

    String dueDateText;
    if (bill.isPaid) {
      dueDateText = 'Paid';
    } else if (isOverdue) {
      dueDateText = 'Overdue by ${daysUntilDue.abs()} days';
    } else if (isDueSoon) {
      dueDateText = 'Due in $daysUntilDue days';
    } else {
      dueDateText = 'Due ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/bill-detail/${bill.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  bill.isPaid ? Icons.check_circle : Icons.receipt,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueDateText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: bill.isPaid ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${bill.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: bill.isPaid ? AppColors.textSecondary : AppColors.textPrimary,
                      decoration: bill.isPaid ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (bill.isRecurring) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Recurring',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
