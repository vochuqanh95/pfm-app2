import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'transaction_model.dart';

enum DateRangeFilter {
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom;

  String get displayName {
    switch (this) {
      case DateRangeFilter.thisMonth:
        return 'This Month';
      case DateRangeFilter.lastMonth:
        return 'Last Month';
      case DateRangeFilter.last3Months:
        return 'Last 3 Months';
      case DateRangeFilter.thisYear:
        return 'This Year';
      case DateRangeFilter.custom:
        return 'Custom';
    }
  }

  DateTimeRange getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case DateRangeFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case DateRangeFilter.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case DateRangeFilter.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case DateRangeFilter.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case DateRangeFilter.custom:
        // For custom, return a default range (will be overridden by customDateRange)
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }
}

@immutable
class TransactionFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTimeRange? customDateRange;
  final TransactionType? typeFilter; // null = all types
  final String? walletIdFilter; // null = all wallets
  final String? categoryIdFilter; // null = all categories
  final String? memberIdFilter; // null = all members (only for heads)
  final String searchQuery;

  const TransactionFilterState({
    this.dateRangeFilter = DateRangeFilter.thisMonth,
    this.customDateRange,
    this.typeFilter,
    this.walletIdFilter,
    this.categoryIdFilter,
    this.memberIdFilter,
    this.searchQuery = '',
  });

  // Get the effective date range based on the filter type
  DateTimeRange get effectiveDateRange {
    if (dateRangeFilter == DateRangeFilter.custom && customDateRange != null) {
      return customDateRange!;
    }
    return dateRangeFilter.getDateRange();
  }

  // Check if any filters are active (besides the default date range)
  bool get hasActiveFilters {
    return typeFilter != null ||
        walletIdFilter != null ||
        categoryIdFilter != null ||
        memberIdFilter != null ||
        searchQuery.isNotEmpty ||
        dateRangeFilter != DateRangeFilter.thisMonth;
  }

  // Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (typeFilter != null) count++;
    if (walletIdFilter != null) count++;
    if (categoryIdFilter != null) count++;
    if (memberIdFilter != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (dateRangeFilter != DateRangeFilter.thisMonth) count++;
    return count;
  }

  TransactionFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTimeRange? customDateRange,
    TransactionType? typeFilter,
    String? walletIdFilter,
    String? categoryIdFilter,
    String? memberIdFilter,
    String? searchQuery,
    bool clearTypeFilter = false,
    bool clearWalletFilter = false,
    bool clearCategoryFilter = false,
    bool clearMemberFilter = false,
    bool clearCustomDateRange = false,
  }) {
    return TransactionFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      walletIdFilter: clearWalletFilter ? null : (walletIdFilter ?? this.walletIdFilter),
      categoryIdFilter: clearCategoryFilter ? null : (categoryIdFilter ?? this.categoryIdFilter),
      memberIdFilter: clearMemberFilter ? null : (memberIdFilter ?? this.memberIdFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Reset all filters to default
  TransactionFilterState reset() {
    return const TransactionFilterState();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFilterState &&
          runtimeType == other.runtimeType &&
          dateRangeFilter == other.dateRangeFilter &&
          customDateRange == other.customDateRange &&
          typeFilter == other.typeFilter &&
          walletIdFilter == other.walletIdFilter &&
          categoryIdFilter == other.categoryIdFilter &&
          memberIdFilter == other.memberIdFilter &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode =>
      dateRangeFilter.hashCode ^
      customDateRange.hashCode ^
      typeFilter.hashCode ^
      walletIdFilter.hashCode ^
      categoryIdFilter.hashCode ^
      memberIdFilter.hashCode ^
      searchQuery.hashCode;
}
