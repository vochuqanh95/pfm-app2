import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/enums/app_currency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/bill_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/settings_provider.dart';

class BillsOverviewScreen extends ConsumerStatefulWidget {
  const BillsOverviewScreen({super.key});

  @override
  ConsumerState<BillsOverviewScreen> createState() => _BillsOverviewScreenState();
}

class _BillsOverviewScreenState extends ConsumerState<BillsOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Unable to load user data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(authUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in')));
        }
        final preferredCurrency = settingsAsync.valueOrNull?.currency ?? AppCurrency.usd;

        final householdId = householdAsync.maybeWhen(
          data: (h) => h?.householdId ?? user.householdId ?? '',
          orElse: () => user.householdId ?? '',
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(user.isHead ? 'Family Bills' : 'My Bills'),
            actions: [
              if (user.isHead)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/bill/add'),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Overdue'),
                Tab(text: 'Paid'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _BillsTab(
                filter: BillFilter.upcoming,
                userId: user.userId,
                householdId: householdId,
                isHead: user.isHead,
                currency: preferredCurrency,
              ),
              _BillsTab(
                filter: BillFilter.overdue,
                userId: user.userId,
                householdId: householdId,
                isHead: user.isHead,
                currency: preferredCurrency,
              ),
              _BillsTab(
                filter: BillFilter.paid,
                userId: user.userId,
                householdId: householdId,
                isHead: user.isHead,
                currency: preferredCurrency,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum BillFilter { upcoming, overdue, paid }

class _BillsTab extends ConsumerWidget {
  final BillFilter filter;
  final String userId;
  final String householdId;
  final bool isHead;
  final AppCurrency currency;

  const _BillsTab({
    required this.filter,
    required this.userId,
    required this.householdId,
    required this.isHead,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use appropriate provider based on user role
    final billsAsync = isHead
        ? ref.watch(allHouseholdBillsStreamProvider)
        : ref.watch(myResponsibleBillsStreamProvider);

    return billsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Unable to load bills', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('$error', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (isHead) {
                  ref.invalidate(allHouseholdBillsStreamProvider);
                } else {
                  ref.invalidate(myResponsibleBillsStreamProvider);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allBills) {
        // Filter bills based on the selected tab
        final filteredBills = _filterBills(allBills);

        if (filteredBills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyIcon(),
                  size: 80,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isHead && filter == BillFilter.upcoming) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/bill/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bill'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBills.length,
          itemBuilder: (context, index) {
            final bill = filteredBills[index];
            return _BillCard(
              bill: bill,
              isHead: isHead,
              currency: currency,
            );
          },
        );
      },
    );
  }

  List<BillModel> _filterBills(List<BillModel> bills) {
    switch (filter) {
      case BillFilter.upcoming:
        return bills.where((b) => b.status == BillStatus.unpaid && !b.isOverdue).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case BillFilter.overdue:
        return bills.where((b) => b.status == BillStatus.unpaid && b.isOverdue).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case BillFilter.paid:
        return bills.where((b) => b.status == BillStatus.paid).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Most recent first
    }
  }

  IconData _getEmptyIcon() {
    switch (filter) {
      case BillFilter.upcoming:
        return Icons.event_available;
      case BillFilter.overdue:
        return Icons.warning_amber_rounded;
      case BillFilter.paid:
        return Icons.check_circle_outline;
    }
  }

  String _getEmptyMessage() {
    switch (filter) {
      case BillFilter.upcoming:
        return 'No upcoming bills';
      case BillFilter.overdue:
        return 'No overdue bills';
      case BillFilter.paid:
        return 'No paid bills yet';
    }
  }
}

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final bool isHead;
  final AppCurrency currency;

  const _BillCard({
    required this.bill,
    required this.isHead,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntilDue = bill.daysUntilDue;
    final isOverdue = bill.isOverdue;
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
      dueDateText = 'Overdue by ${daysUntilDue.abs()} day${daysUntilDue.abs() == 1 ? '' : 's'}';
    } else if (isDueSoon) {
      dueDateText = 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}';
    } else {
      dueDateText = 'Due ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/bill-detail/${bill.billId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
                    if (bill.scope == 'family' && bill.responsibleUserId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Assigned bill',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                            MoneyFormatter.format(bill.amount, currency: currency),
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
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bill.recurrence.name,
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
