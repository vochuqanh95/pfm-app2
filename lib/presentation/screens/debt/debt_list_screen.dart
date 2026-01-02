import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/debt_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/household_provider.dart';

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

class DebtListScreen extends ConsumerWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Please login')),
          );
        }

        final householdId = user.householdId ?? '';
        final params = DebtVisibilityParams(
          userId: user.userId,
          householdId: householdId,
          includeHouseholdDebts: user.isHead && householdId.isNotEmpty,
          isHead: user.isHead,
        );

        final debtsAsync = ref.watch(filteredDebtsProvider(params));

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            title: const Text('Debts'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: 'Clear filters',
                onPressed: () =>
                    ref.read(debtFilterProvider.notifier).clearFilters(),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  debugPrint('[DEBT_UI] Navigating to AddDebtScreen');
                  context.pushNamed('add-debt');
                },
              ),
            ],
          ),
          body: debtsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $error'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(filteredDebtsProvider(params)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (debts) {
              final owedToMe =
                  debts.where((d) => d.type == DebtType.owedToMe).toList();
              final iOwe = debts.where((d) => d.type == DebtType.iOwe).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredDebtsProvider(params));
                  await Future<void>.delayed(const Duration(milliseconds: 200));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _DebtFilters(
                      isHead: user.isHead,
                      householdId: householdId,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Owed to Me',
                            amount: owedToMe.fold(
                              0.0,
                              (sum, debt) => sum + debt.remainingAmount,
                            ),
                            color: AppColors.success,
                            icon: Icons.arrow_downward,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'I Owe',
                            amount: iOwe.fold(
                              0.0,
                              (sum, debt) => sum + debt.remainingAmount,
                            ),
                            color: AppColors.error,
                            icon: Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (debts.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 64,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No debts match the filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => ref
                                    .read(debtFilterProvider.notifier)
                                    .clearFilters(),
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        'DEBTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...debts.map((debt) => _DebtCard(debt: debt)),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DebtFilters extends ConsumerWidget {
  final bool isHead;
  final String householdId;

  const _DebtFilters({
    required this.isHead,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(debtFilterProvider);

    final membersAsync = isHead && householdId.isNotEmpty
        ? ref.watch(householdMemberDetailsProvider(householdId))
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(debtFilterProvider.notifier).clearFilters(),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filters.type == null,
                  onSelected: (_) =>
                      ref.read(debtFilterProvider.notifier).setType(null),
                ),
                ChoiceChip(
                  label: const Text('Owed to Me'),
                  selected: filters.type == DebtType.owedToMe,
                  onSelected: (_) => ref
                      .read(debtFilterProvider.notifier)
                      .setType(DebtType.owedToMe),
                ),
                ChoiceChip(
                  label: const Text('I Owe'),
                  selected: filters.type == DebtType.iOwe,
                  onSelected: (_) => ref
                      .read(debtFilterProvider.notifier)
                      .setType(DebtType.iOwe),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Active'),
                  selected: filters.status == DebtStatus.active,
                  onSelected: (_) => ref
                      .read(debtFilterProvider.notifier)
                      .setStatus(DebtStatus.active),
                ),
                ChoiceChip(
                  label: const Text('Overdue'),
                  selected: filters.status == DebtStatus.overdue,
                  onSelected: (_) => ref
                      .read(debtFilterProvider.notifier)
                      .setStatus(DebtStatus.overdue),
                ),
                ChoiceChip(
                  label: const Text('Paid'),
                  selected: filters.status == DebtStatus.paid,
                  onSelected: (_) => ref
                      .read(debtFilterProvider.notifier)
                      .setStatus(DebtStatus.paid),
                ),
                ChoiceChip(
                  label: const Text('Any Status'),
                  selected: filters.status == null,
                  onSelected: (_) =>
                      ref.read(debtFilterProvider.notifier).setStatus(null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DebtDueFilter>(
                    value: filters.dueFilter,
                    decoration: const InputDecoration(
                      labelText: 'Due',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DebtDueFilter.any,
                        child: Text('Any'),
                      ),
                      DropdownMenuItem(
                        value: DebtDueFilter.dueSoon,
                        child: Text('Due Soon'),
                      ),
                      DropdownMenuItem(
                        value: DebtDueFilter.overdue,
                        child: Text('Overdue'),
                      ),
                      DropdownMenuItem(
                        value: DebtDueFilter.noDueDate,
                        child: Text('No Due Date'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(debtFilterProvider.notifier)
                            .setDueFilter(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (householdId.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<DebtScopeFilter>(
                      value: filters.scope,
                      decoration: const InputDecoration(
                        labelText: 'Scope',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DebtScopeFilter.all,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: DebtScopeFilter.personal,
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                          value: DebtScopeFilter.household,
                          child: Text('Household'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(debtFilterProvider.notifier).setScope(value);
                        }
                      },
                    ),
                  ),
              ],
            ),
            if (isHead && householdId.isNotEmpty) ...[
              const SizedBox(height: 12),
              membersAsync!.when(
                data: (members) {
                  if (members.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String?>(
                    value: filters.memberUserId,
                    decoration: const InputDecoration(
                      labelText: 'Member',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Members'),
                      ),
                      ...members.map(
                        (member) => DropdownMenuItem<String?>(
                          value: member.membership.userId,
                          child: Text(member.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) => ref
                        .read(debtFilterProvider.notifier)
                        .setMemberUser(value),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Filters help narrow to specific debts (due soon, overdue, by scope).',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;

  const _DebtCard({required this.debt});

  Color _statusColor(DebtStatus status) {
    switch (status) {
      case DebtStatus.overdue:
        return AppColors.error;
      case DebtStatus.paid:
        return AppColors.success;
      case DebtStatus.active:
        return AppColors.secondary;
    }
  }

  String _dueLabel(DateFormat formatter) {
    if (debt.dueDate == null) return 'No due date';
    return formatter.format(debt.dueDate!);
  }

  @override
  Widget build(BuildContext context) {
    final isOwedToMe = debt.type == DebtType.owedToMe;
    final color = isOwedToMe ? AppColors.success : AppColors.error;
    final progress = debt.totalAmount > 0 ? debt.paidProgress : 0.0;
    final formatter = DateFormat('MMM d');
    final scopeLabel = debt.householdId == null ? 'Personal' : 'Household';
    final statusColor = _statusColor(debt.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/debt-detail/${debt.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOwedToMe ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((debt.creditorDebtor ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            debt.creditorDebtor ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Badge(
                              label: isOwedToMe ? 'Owed to Me' : 'I Owe',
                              color: color,
                            ),
                            _Badge(
                              label: scopeLabel,
                              color: AppColors.primary,
                            ),
                            _Badge(
                              label: debt.status.name.toUpperCase(),
                              color: statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${debt.remainingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'of \$${debt.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _dueLabel(formatter),
                    style: TextStyle(
                      fontSize: 12,
                      color: debt.isOverdue
                          ? AppColors.error
                          : (debt.isDueSoon
                              ? AppColors.secondary
                              : AppColors.textSecondary),
                      fontWeight:
                          debt.isOverdue ? FontWeight.w700 : FontWeight.w500,
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
