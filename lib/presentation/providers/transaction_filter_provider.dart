import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_filter_state.dart';
import '../../data/models/transaction_model.dart';

class TransactionFilterNotifier extends StateNotifier<TransactionFilterState> {
  TransactionFilterNotifier() : super(const TransactionFilterState());

  void setDateRangeFilter(DateRangeFilter filter) {
    state = state.copyWith(
      dateRangeFilter: filter,
      clearCustomDateRange: filter != DateRangeFilter.custom,
    );
  }

  void setCustomDateRange(DateTimeRange? range) {
    state = state.copyWith(
      dateRangeFilter: DateRangeFilter.custom,
      customDateRange: range,
    );
  }

  void setTypeFilter(TransactionType? type) {
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
    );
  }

  void setWalletFilter(String? walletId) {
    state = state.copyWith(
      walletIdFilter: walletId,
      clearWalletFilter: walletId == null,
    );
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(
      categoryIdFilter: categoryId,
      clearCategoryFilter: categoryId == null,
    );
  }

  void setMemberFilter(String? memberId) {
    state = state.copyWith(
      memberIdFilter: memberId,
      clearMemberFilter: memberId == null,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void resetFilters() {
    state = state.reset();
  }

  void clearFilter(String filterType) {
    switch (filterType) {
      case 'type':
        state = state.copyWith(clearTypeFilter: true);
        break;
      case 'wallet':
        state = state.copyWith(clearWalletFilter: true);
        break;
      case 'category':
        state = state.copyWith(clearCategoryFilter: true);
        break;
      case 'member':
        state = state.copyWith(clearMemberFilter: true);
        break;
      case 'search':
        state = state.copyWith(searchQuery: '');
        break;
      case 'date':
        state = state.copyWith(dateRangeFilter: DateRangeFilter.thisMonth);
        break;
    }
  }
}

final transactionFilterProvider =
    StateNotifierProvider.autoDispose<TransactionFilterNotifier, TransactionFilterState>((ref) {
  return TransactionFilterNotifier();
});

// Filtered transactions provider
final filteredTransactionsProvider = Provider.family.autoDispose<
    List<TransactionModel>,
    ({List<TransactionModel> transactions, TransactionFilterState filter})>(
  (ref, params) {
    final transactions = params.transactions;
    final filter = params.filter;

    var filtered = transactions.where((transaction) {
      // Date range filter
      final dateRange = filter.effectiveDateRange;
      if (transaction.date.isBefore(dateRange.start) ||
          transaction.date.isAfter(dateRange.end)) {
        return false;
      }

      // Type filter
      if (filter.typeFilter != null && transaction.type != filter.typeFilter) {
        return false;
      }

      // Wallet filter
      if (filter.walletIdFilter != null &&
          transaction.walletId != filter.walletIdFilter) {
        return false;
      }

      // Category filter
      if (filter.categoryIdFilter != null &&
          transaction.categoryId != filter.categoryIdFilter) {
        return false;
      }

      // Member filter
      if (filter.memberIdFilter != null &&
          transaction.actorUserId != filter.memberIdFilter) {
        return false;
      }

      // Search query filter
      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        final note = transaction.note.toLowerCase();
        final categoryId = transaction.categoryId.toLowerCase();
        if (!note.contains(query) && !categoryId.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  },
);
