import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/actor_utils.dart';
import '../../../data/models/household_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/net_worth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../../data/models/bill_model.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/transaction_detail_sheet.dart';

// HOME QUICK ACTIONS – MANUAL TEST
// - Head: tap Budgets -> budget list loads (no crash).
// - Member: tap Budgets -> budget list loads (read-only ok).
// - Tap Debts still works.
// - Logout/login: buttons still visible and work.
// - Regression: transactions/net worth still load; debt payments unaffected.

class HomeScreen extends ConsumerWidget {
  final bool isMemberView;

  const HomeScreen({super.key, this.isMemberView = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    // Process recurring transactions in the background
    ref.watch(processRecurringTransactionsProvider);

    // Process bill reminders in the background
    ref.watch(billReminderProcessProvider);
    ref.watch(debtReminderProcessProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        debugPrint('Unable to load home: $error');
        return const Scaffold(
          body: _CenteredMessage(message: 'Unable to load your home right now'),
        );
      },
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please sign in again.')),
          );
        }

        final household = householdAsync.maybeWhen(
            data: (value) => value, orElse: () => null);
        final memberView = isMemberView || user.isMember;
        final householdId = household?.householdId ?? user.householdId ?? '';

        final netWorthAsync = ref.watch(homeFinancesProvider);
        final netWorthTitle = householdId.isNotEmpty
            ? 'Total Family Net Worth'
            : (user.isHead ? 'Your Net Worth' : 'Your Net Worth');
        final transactionsAsync = ref.watch(homeRecentTransactionsProvider);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _HomeHeader(
                      user: user,
                      household: household,
                    ),
                  ),
                  if ((user.isMember) && (user.householdId?.isEmpty ?? true))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: AppColors.primary.withOpacity(0.08),
                        child: ListTile(
                          leading: const Icon(Icons.info_outline,
                              color: AppColors.primary),
                          title: const Text('Join your family household'),
                          subtitle: const Text(
                              'Enter the invite code shared by your household owner.'),
                          trailing: TextButton(
                            onPressed: () => context.push('/join-household'),
                            child: const Text('Join now'),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: netWorthAsync.when(
                      data: (summary) => _NetWorthCard(
                        title: netWorthTitle,
                        assets: summary.totalAssets,
                        debts: summary.totalDebts,
                      ),
                      loading: () => const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) {
                        debugPrint('Failed to load net worth: $error');
                        return Column(
                          children: [
                            _NetWorthCard(
                              title: netWorthTitle,
                              assets: 0,
                              debts: 0,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  ref.refresh(homeFinancesProvider),
                              child:
                                  const Text('Unable to load finances - Retry'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.receipt_long,
                            label: 'Debts',
                            color: AppColors.secondary,
                            onTap: () => context.pushNamed('debts'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.pie_chart,
                            label: 'Budgets',
                            color: AppColors.primary,
                            onTap: () => context.push('/budgets'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (memberView) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Member view: some management actions are hidden.',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Bills Section
                  _BillsSection(
                      userId: user.userId,
                      householdId: householdId,
                      isHead: user.isHead),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/transactions'),
                          child: const Text('See All'),
                        ),
                      ],
                    ),
                  ),
                  transactionsAsync.when(
                    data: (transactions) => _TransactionList(
                      transactions: transactions,
                      isMemberView: memberView,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) {
                      debugPrint('Failed to load transactions: $error');
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _AsyncErrorState(
                          message: 'Unable to load transactions',
                          onRetry: () => ref.refresh(homeRecentTransactionsProvider),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/add-transaction'),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: const BottomNavBar(currentIndex: 0),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final UserModel user;
  final HouseholdModel? household;

  const _HomeHeader({
    required this.user,
    required this.household,
  });

  @override
  Widget build(BuildContext context) {
    final householdName = household?.name ??
        (user.isHead ? 'No household yet' : 'Personal finances');
    final subtitle = household != null
        ? 'Family household'
        : (user.isHead ? 'Create your household' : 'Personal only');
    final roleLabel = user.isHead ? 'Head' : 'Member';
    final avatarLetter =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'F';
    final showCreateBtn = user.isHead && (user.householdId?.isEmpty ?? true);
    final showJoinBtn = user.isMember && (user.householdId?.isEmpty ?? true);

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary,
          child: Text(
            avatarLetter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      householdName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(roleLabel),
                    backgroundColor: user.isHead
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.secondary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color:
                          user.isHead ? AppColors.primary : AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (showCreateBtn)
                TextButton(
                  onPressed: () => context.push('/create-household'),
                  child: const Text('Create household'),
                ),
              if (showJoinBtn)
                TextButton(
                  onPressed: () => context.push('/join-household'),
                  child: const Text('Join household'),
                ),
            ],
          ),
        ),
        if (user.isHead && household != null)
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Manage Members',
            onPressed: () => context.push('/member-management'),
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AsyncErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _AsyncErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final String title;
  final double assets;
  final double debts;

  const _NetWorthCard({
    required this.title,
    required this.assets,
    required this.debts,
  });

  @override
  Widget build(BuildContext context) {
    final netWorth = assets - debts;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${netWorth.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NetWorthItem(
                label: 'Total Assets',
                value: '\$${assets.toStringAsFixed(2)}',
                color: AppColors.success,
              ),
              _NetWorthItem(
                label: 'Total Debts',
                value: '\$${debts.toStringAsFixed(2)}',
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetWorthItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NetWorthItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _TransactionList extends ConsumerWidget {
  final List<TransactionModel> transactions;
  final bool isMemberView;

  const _TransactionList({
    required this.transactions,
    required this.isMemberView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: AppColors.textSecondary.withOpacity(0.4),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isMemberView
                      ? 'Add your first personal transaction to get started.'
                      : 'Record a household transaction to see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isExpense = tx.type == TransactionType.expense;
        final color = isExpense ? AppColors.error : AppColors.success;
        final nameMap = ref.watch(
          categoryNameMapProvider(
            CategoryNameMapParams(
              userId: tx.userId,
              householdId: tx.householdId,
            ),
          ),
        );
        final displayCategory = (tx.categoryName != null && tx.categoryName!.isNotEmpty)
            ? tx.categoryName!
            : nameMap[tx.categoryId] ?? 'Unknown category';
        final amountLabel =
            '${isExpense ? '-' : '+'}\$${tx.amount.toStringAsFixed(2)}';

        return ListTile(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollController) => TransactionDetailSheet(
                  transaction: tx,
                ),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(
              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
            ),
          ),
          title: Text(tx.note.isNotEmpty ? tx.note : displayCategory),
          subtitle: Text(
            tx.actorDisplayName != null
                ? 'by ${formatActorLabel(tx.actorDisplayName, tx.actorRole)}'
                : '${tx.date.toLocal()}'.split('.').first,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: Text(
            amountLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        );
      },
    );
  }
}

class _BillsSection extends ConsumerWidget {
  final String userId;
  final String householdId;
  final bool isHead;

  const _BillsSection({
    required this.userId,
    required this.householdId,
    required this.isHead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use appropriate provider based on user role
    final billsAsync = isHead && householdId.isNotEmpty
        ? ref.watch(upcomingHouseholdBillsStreamProvider)
        : ref.watch(myResponsibleBillsStreamProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isHead ? 'Upcoming Bills' : 'My Bills',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/bills'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          billsAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Unable to load bills'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        if (isHead && householdId.isNotEmpty) {
                          ref.invalidate(upcomingHouseholdBillsStreamProvider);
                        } else {
                          ref.invalidate(myResponsibleBillsStreamProvider);
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (bills) {
              // Filter to only show unpaid bills
              final upcomingBills = bills
                  .where((b) => b.status == BillStatus.unpaid)
                  .take(3)
                  .toList();

              if (upcomingBills.isEmpty) {
                // Show empty state card
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isHead
                              ? 'No upcoming bills'
                              : 'No bills assigned to you yet',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isHead) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => context.push('/bill/add'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Bill'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children:
                    upcomingBills.map((bill) => _BillItem(bill: bill)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BillItem extends StatelessWidget {
  final BillModel bill;

  const _BillItem({required this.bill});

  @override
  Widget build(BuildContext context) {
    final daysUntilDue = bill.daysUntilDue;
    final isOverdue = bill.isOverdue;
    final isDueSoon = daysUntilDue >= 0 && daysUntilDue <= 3;

    Color statusColor = AppColors.info;
    if (isOverdue) {
      statusColor = AppColors.error;
    } else if (isDueSoon) {
      statusColor = AppColors.warning;
    }

    String dueDateText;
    if (isOverdue) {
      dueDateText = 'Overdue';
    } else if (isDueSoon) {
      dueDateText = 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}';
    } else {
      dueDateText = 'Due ${bill.dueDate.day}/${bill.dueDate.month}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/bill-detail/${bill.billId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.receipt, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dueDateText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${bill.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
