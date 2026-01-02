import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/report_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/net_worth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('Unable to load reports'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please sign in.')));
        }

        return _ReportsContent(user: user);
      },
    );
  }
}

class _ReportsContent extends ConsumerWidget {
  final dynamic user;

  const _ReportsContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHead = user.isHead as bool;
    final summaryAsync = ref.watch(reportSummaryProvider);
    final debtSummaryAsync = ref.watch(debtSummaryProvider);
    final categoryAsync = ref.watch(categoryBreakdownProvider);
    final memberAsync = ref.watch(memberSpendBreakdownProvider);
    final timeSeriesAsync = ref.watch(timeSeriesProvider);
    final netWorthAsync = isHead ? ref.watch(homeFinancesProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_off),
            tooltip: 'Clear Filters',
            onPressed: () {
              ref.read(reportFilterProvider.notifier).clearFilters();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Controls
              const _FilterSection(),
              const SizedBox(height: 16),

              // Family Net Worth (Head Only)
              if (isHead && netWorthAsync != null) ...[
                netWorthAsync.when(
                  data: (summary) => _FamilyNetWorthCard(
                    assets: summary.totalAssets,
                    debts: summary.totalDebts,
                  ),
                  loading: () => const _LoadingCard(height: 120),
                  error: (e, st) => _ErrorCard(
                    message: 'Unable to load net worth',
                    onRetry: () => ref.refresh(homeFinancesProvider),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Summary Cards
              summaryAsync.when(
                loading: () => const _LoadingCard(height: 100),
                error: (e, st) {
                  debugPrint('[REPORTS][UI][ERROR] summary: $e\n$st');
                  return _ErrorCard(
                    message: 'Unable to load summary',
                    onRetry: () => ref.refresh(reportSummaryProvider),
                  );
                },
                data: (summary) => _SummaryRow(
                  income: summary.totalIncome,
                  expense: summary.totalExpense,
                  net: summary.net,
                ),
              ),
              const SizedBox(height: 16),

              // Debt Summary
              debtSummaryAsync.when(
                loading: () => const _LoadingCard(height: 90),
                error: (e, st) {
                  debugPrint('[REPORTS][UI][ERROR] debt summary: $e\n$st');
                  return _ErrorCard(
                    message: 'Unable to load debt summary',
                    onRetry: () => ref.refresh(debtSummaryProvider),
                  );
                },
                data: (debtSummary) => _DebtSummaryCard(
                  totalIOwe: debtSummary.totalIOwe,
                  totalOwedToMe: debtSummary.totalOwedToMe,
                  overdueCount: debtSummary.overdueCount,
                ),
              ),
              const SizedBox(height: 16),

              // Category Breakdown
              const Text('Spending Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              categoryAsync.when(
                loading: () => const _LoadingCard(height: 200),
                error: (e, st) {
                  debugPrint('[REPORTS][UI][ERROR] categories: $e\n$st');
                  return _ErrorCard(
                    message: 'Unable to load categories',
                    onRetry: () => ref.refresh(categoryBreakdownProvider),
                  );
                },
                data: (categories) {
                  if (categories.isEmpty) {
                    return const _EmptyState(message: 'No spending data');
                  }
                  return Column(
                    children: [
                      _PieSection(data: categories),
                      const SizedBox(height: 8),
                      _CategoryList(data: categories),
                    ],
                  );
                },
              ),

              // Time Series - Income vs Expense Over Time
              const SizedBox(height: 24),
              const Text('Income vs Expense Over Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              timeSeriesAsync.when(
                loading: () => const _LoadingCard(height: 200),
                error: (e, st) {
                  debugPrint('[REPORTS][UI][ERROR] time series: $e\n$st');
                  return _ErrorCard(
                    message: 'Unable to load time series data',
                    onRetry: () => ref.refresh(timeSeriesProvider),
                  );
                },
                data: (series) {
                  if (series.isEmpty) {
                    return const _EmptyState(message: 'No data available');
                  }
                  return _TimeSeriesCard(data: series);
                },
              ),

              // Top Spenders (for heads only)
              if (isHead) ...[
                const SizedBox(height: 24),
                const Text('Top Spenders',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                memberAsync.when(
                  loading: () => const _LoadingCard(height: 150),
                  error: (e, st) {
                    debugPrint('[REPORTS][UI][ERROR] member data: $e\n$st');
                    return _ErrorCard(
                      message: 'Unable to load member data',
                      onRetry: () => ref.refresh(memberSpendBreakdownProvider),
                    );
                  },
                  data: (members) {
                    if (members.isEmpty) {
                      return const _EmptyState(
                          message: 'No member spending data');
                    }
                    return _TopSpendersList(spenders: members);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

// ============================================================================
// FILTER SECTION
// ============================================================================

class _FilterSection extends ConsumerWidget {
  const _FilterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            const _RangePicker(),
            const SizedBox(height: 12),
            const _WalletFilter(),
            const SizedBox(height: 12),
            const _CategoryFilter(),
            const SizedBox(height: 12),
            const _MemberFilter(),
          ],
        ),
      ),
    );
  }
}

class _RangePicker extends ConsumerWidget {
  const _RangePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date Range',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReportRange.values.map((range) {
            return ChoiceChip(
              label: Text(range.label),
              selected: filters.range == range,
              onSelected: (_) {
                ref.read(reportFilterProvider.notifier).setRange(range);
              },
            );
          }).toList(),
        ),
        if (filters.range == ReportRange.custom) ...[
          const SizedBox(height: 8),
          _CustomDatePicker(),
        ],
      ],
    );
  }
}

class _CustomDatePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFilterProvider);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              filters.customStartDate != null
                  ? dateFormat.format(filters.customStartDate!)
                  : 'Start Date',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: filters.customStartDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                final end = filters.customEndDate ?? DateTime.now();
                ref
                    .read(reportFilterProvider.notifier)
                    .setCustomRange(date, end);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              filters.customEndDate != null
                  ? dateFormat.format(filters.customEndDate!)
                  : 'End Date',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: filters.customEndDate ?? DateTime.now(),
                firstDate: filters.customStartDate ?? DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                final start = filters.customStartDate ??
                    DateTime.now().subtract(const Duration(days: 30));
                ref
                    .read(reportFilterProvider.notifier)
                    .setCustomRange(start, date);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _WalletFilter extends ConsumerWidget {
  const _WalletFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFilterProvider);
    final userAsync = ref.watch(authUserProvider);
    final householdAsync = ref.watch(currentUserHouseholdProvider);

    final user = userAsync.valueOrNull;
    final household = householdAsync.valueOrNull;

    if (user == null) return const SizedBox.shrink();

    final householdId = household?.householdId ?? user.householdId ?? '';
    final walletsProvider = householdId.isNotEmpty
        ? householdWalletsStreamProvider(householdId)
        : personalWalletsStreamProvider(user.userId);

    final walletsAsync = ref.watch(walletsProvider);

    return walletsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (wallets) {
        if (wallets.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wallet',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              value: filters.walletId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Wallets')),
                ...wallets.map((wallet) => DropdownMenuItem(
                      value: wallet.walletId,
                      child: Text(wallet.name),
                    )),
              ],
              onChanged: (value) {
                ref.read(reportFilterProvider.notifier).setWallet(value);
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  // Common expense categories
  static const categories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Bills & Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String?>(
          value: filters.categoryId,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Categories')),
            ...categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                )),
          ],
          onChanged: (value) {
            ref.read(reportFilterProvider.notifier).setCategory(value);
          },
        ),
      ],
    );
  }
}

class _MemberFilter extends ConsumerWidget {
  const _MemberFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final user = userAsync.valueOrNull;

    // Only show for household heads
    if (user == null || !user.isHead) {
      return const SizedBox.shrink();
    }

    final householdAsync = ref.watch(currentUserHouseholdProvider);
    final household = householdAsync.valueOrNull;

    if (household == null) return const SizedBox.shrink();

    final membersAsync =
        ref.watch(householdMemberDetailsProvider(household.householdId));

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (members) {
        if (members.length <= 1) return const SizedBox.shrink();

        final filters = ref.watch(reportFilterProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Member',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              value: filters.memberUserId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Members')),
                ...members.map((member) => DropdownMenuItem(
                      value: member.membership.userId,
                      child: Text(member.displayName),
                    )),
              ],
              onChanged: (value) {
                ref.read(reportFilterProvider.notifier).setMemberUser(value);
              },
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// SUMMARY & DISPLAY WIDGETS
// ============================================================================

class _SummaryRow extends StatelessWidget {
  final double income;
  final double expense;
  final double net;

  const _SummaryRow({
    required this.income,
    required this.expense,
    required this.net,
  });

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryItem(
              label: 'Income', value: income, color: AppColors.success),
          _SummaryItem(
              label: 'Expense', value: expense, color: AppColors.error),
          _SummaryItem(
              label: 'Net',
              value: net,
              color: net >= 0 ? AppColors.success : AppColors.error),
        ],
      ),
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  final double totalIOwe;
  final double totalOwedToMe;
  final int overdueCount;

  const _DebtSummaryCard({
    required this.totalIOwe,
    required this.totalOwedToMe,
    required this.overdueCount,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debt Summary',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'I Owe',
                  value: totalIOwe,
                  color: AppColors.error,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Owed to Me',
                  value: totalOwedToMe,
                  color: AppColors.success,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: overdueCount > 0
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overdue',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$overdueCount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: overdueCount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _PieSection extends StatelessWidget {
  final List<CategorySpend> data;

  const _PieSection({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold(0.0, (sum, item) => sum + item.totalAmount);

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
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            sections: data.take(8).map((item) {
              final percentage = (item.totalAmount / total * 100);
              return PieChartSectionData(
                value: item.totalAmount,
                title: '${percentage.toStringAsFixed(0)}%',
                color: _getCategoryColor(item.categoryId),
                radius: 80,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String categoryId) {
    final hash = categoryId.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategorySpend> data;

  const _CategoryList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold(0.0, (sum, item) => sum + item.totalAmount);

    return Column(
      children: data.map((item) {
        final percentage = (item.totalAmount / total * 100);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getCategoryColor(item.categoryId),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(item.categoryId, style: const TextStyle(fontSize: 14)),
          subtitle: Text('${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12)),
          trailing: Text('\$${item.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String categoryId) {
    final hash = categoryId.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }
}

class _TopSpendersList extends StatelessWidget {
  final List<Map<String, dynamic>> spenders;

  const _TopSpendersList({required this.spenders});

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
        children: spenders.take(5).map((spender) {
          final name = spender['name'] as String;
          final role = spender['role'] as String;
          final total = spender['total'] as double;
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
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
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// UTILITY WIDGETS
// ============================================================================

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.insights_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyNetWorthCard extends StatelessWidget {
  final double assets;
  final double debts;

  const _FamilyNetWorthCard({
    required this.assets,
    required this.debts,
  });

  @override
  Widget build(BuildContext context) {
    final netWorth = assets - debts;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family Net Worth',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${netWorth.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assets',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${assets.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${debts.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeSeriesCard extends StatelessWidget {
  final List<TimeSeriesPoint> data;

  const _TimeSeriesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendItem(
                color: AppColors.success,
                label: 'Income',
              ),
              _LegendItem(
                color: AppColors.error,
                label: 'Expense',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          final point = data[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('M/d').format(point.period),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income line
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.income);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.success.withValues(alpha: 0.1),
                    ),
                  ),
                  // Expense line
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.expense);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.error,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.error.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
