import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/report_service.dart';
import 'auth_provider.dart';
import 'household_provider.dart';
import 'debt_provider.dart';
import 'wallet_provider.dart';

/// Report date range options
enum ReportRange {
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

/// Extension to get display labels for report ranges
extension ReportRangeExtension on ReportRange {
  String get label {
    switch (this) {
      case ReportRange.thisMonth:
        return 'This Month';
      case ReportRange.lastMonth:
        return 'Last Month';
      case ReportRange.last3Months:
        return 'Last 3 Months';
      case ReportRange.thisYear:
        return 'This Year';
      case ReportRange.custom:
        return 'Custom';
    }
  }
}

/// Report filter state - single source of truth for all report filters
class ReportFilterState {
  final ReportRange range;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? walletId; // null = all wallets
  final String? categoryId; // null = all categories
  final String?
      memberUserId; // null = all members (for heads); ignored for members

  const ReportFilterState({
    required this.range,
    this.customStartDate,
    this.customEndDate,
    this.walletId,
    this.categoryId,
    this.memberUserId,
  });

  ReportFilterState copyWith({
    ReportRange? range,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? walletId,
    String? categoryId,
    String? memberUserId,
    bool clearWallet = false,
    bool clearCategory = false,
    bool clearMember = false,
    bool clearCustomDates = false,
  }) {
    return ReportFilterState(
      range: range ?? this.range,
      customStartDate:
          clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate:
          clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      walletId: clearWallet ? null : (walletId ?? this.walletId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      memberUserId: clearMember ? null : (memberUserId ?? this.memberUserId),
    );
  }

  /// Compute actual start and end dates based on current range and custom dates
  (DateTime start, DateTime end) getDateRange() {
    final now = DateTime.now();

    (DateTime, DateTime) result;

    switch (range) {
      case ReportRange.thisMonth:
        result = (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;

      case ReportRange.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        result = (
          lastMonth,
          DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
        );
        break;

      case ReportRange.last3Months:
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
        result = (
          threeMonthsAgo,
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;

      case ReportRange.thisYear:
        result = (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;

      case ReportRange.custom:
        // Use custom dates if provided, otherwise default to this month
        if (customStartDate != null && customEndDate != null) {
          result = (customStartDate!, customEndDate!);
          break;
        }
        // Fallback to this month if custom dates not set
        result = (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
    }

    debugPrint('[REPORTS][RANGE] $range -> ${result.$1}..${result.$2}');
    return result;
  }
}

/// Notifier for managing report filter state
class ReportFilterNotifier extends StateNotifier<ReportFilterState> {
  ReportFilterNotifier()
      : super(const ReportFilterState(range: ReportRange.thisMonth));

  void setRange(ReportRange range) {
    state = state.copyWith(
      range: range,
      clearCustomDates: range != ReportRange.custom,
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      range: ReportRange.custom,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setWallet(String? walletId) {
    state = state.copyWith(
      walletId: walletId,
      clearWallet: walletId == null,
    );
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
  }

  void setMemberUser(String? memberUserId) {
    state = state.copyWith(
      memberUserId: memberUserId,
      clearMember: memberUserId == null,
    );
  }

  void clearFilters() {
    state = const ReportFilterState(range: ReportRange.thisMonth);
  }
}

/// Provider for report filter state
final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilterState>((ref) {
  return ReportFilterNotifier();
});

// ============================================================================
// REPORT DATA PROVIDERS
// ============================================================================

/// Report Service Provider
final reportServiceProvider = Provider<ReportService>((ref) {
  final walletRepository = ref.read(walletRepositoryProvider);
  final debtRepository = ref.read(debtRepositoryProvider);
  return ReportService(
    walletRepository: walletRepository,
    debtRepository: debtRepository,
  );
});

/// Report Summary Provider - reacts to filter changes
final reportSummaryProvider =
    FutureProvider.autoDispose<ReportSummary>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  // Return safe default if not authenticated (instead of throwing)
  if (user == null) {
    return const ReportSummary(totalIncome: 0, totalExpense: 0);
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  // Get current filters
  final filters = ref.watch(reportFilterProvider);
  final (start, end) = filters.getDateRange();

  // Get report service
  final service = ref.read(reportServiceProvider);

  // Fetch summary data
  return service.getTransactionSummary(
    currentUser: user,
    householdId: householdId,
    startDate: start,
    endDate: end,
    walletId: filters.walletId,
    categoryId: filters.categoryId,
    memberUserId: filters.memberUserId,
  );
});

/// Category Breakdown Provider - reacts to filter changes
final categoryBreakdownProvider =
    FutureProvider.autoDispose<List<CategorySpend>>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  // Return empty list if not authenticated (instead of throwing)
  if (user == null) {
    return [];
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  // Get current filters
  final filters = ref.watch(reportFilterProvider);
  final (start, end) = filters.getDateRange();

  // Get report service
  final service = ref.read(reportServiceProvider);

  // Fetch category breakdown
  return service.getCategorySpendBreakdown(
    currentUser: user,
    householdId: householdId,
    startDate: start,
    endDate: end,
    walletId: filters.walletId,
    categoryId: filters.categoryId,
    memberUserId: filters.memberUserId,
  );
});

/// Debt Summary Provider
final debtSummaryProvider =
    FutureProvider.autoDispose<DebtReportSummary>((ref) async {
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  if (user == null) {
    return const DebtReportSummary(
      totalIOwe: 0,
      totalOwedToMe: 0,
      overdueCount: 0,
    );
  }

  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  final service = ref.read(reportServiceProvider);

  return service.getDebtSummary(
    currentUser: user,
    householdId: householdId,
  );
});

/// Time Series Provider - reacts to filter changes
final timeSeriesProvider =
    FutureProvider.autoDispose<List<TimeSeriesPoint>>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  // Return empty list if not authenticated (instead of throwing)
  if (user == null) {
    return [];
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  // Get current filters
  final filters = ref.watch(reportFilterProvider);
  final (start, end) = filters.getDateRange();

  // Determine grouping based on range
  TimeGrouping grouping;
  switch (filters.range) {
    case ReportRange.thisMonth:
    case ReportRange.lastMonth:
      grouping = TimeGrouping.daily;
      break;
    case ReportRange.last3Months:
    case ReportRange.thisYear:
    case ReportRange.custom:
      grouping = TimeGrouping.monthly;
      break;
  }

  // Get report service
  final service = ref.read(reportServiceProvider);

  // Fetch time series data
  return service.getTimeSeriesSpend(
    currentUser: user,
    householdId: householdId,
    startDate: start,
    endDate: end,
    walletId: filters.walletId,
    categoryId: filters.categoryId,
    memberUserId: filters.memberUserId,
    grouping: grouping,
  );
});

/// Home Month Summary Provider - Fixed to "This Month" for home screen dashboard
final homeMonthSummaryProvider =
    FutureProvider.autoDispose<ReportSummary>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  // Return safe default if not authenticated (instead of throwing)
  if (user == null) {
    return const ReportSummary(totalIncome: 0, totalExpense: 0);
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  // Fixed to this month
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Get report service
  final service = ref.read(reportServiceProvider);

  // Fetch summary data for this month only (no filters)
  return service.getTransactionSummary(
    currentUser: user,
    householdId: householdId,
    startDate: start,
    endDate: end,
    walletId: null, // All wallets
    categoryId: null, // All categories
    memberUserId: null, // All members
  );
});

/// Member Spending Breakdown Provider (for household heads)
final memberSpendBreakdownProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  if (user == null || !user.isHead) {
    return []; // Only for heads
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  if (householdId == null || householdId.isEmpty) {
    return []; // No household
  }

  // Get current filters
  final filters = ref.watch(reportFilterProvider);
  final (start, end) = filters.getDateRange();

  // Get report service
  final service = ref.read(reportServiceProvider);

  // Fetch member breakdown
  return service.getMemberSpendBreakdown(
    currentUser: user,
    householdId: householdId,
    startDate: start,
    endDate: end,
    walletId: filters.walletId,
    categoryId: filters.categoryId,
    memberUserId: filters.memberUserId,
  );
});
