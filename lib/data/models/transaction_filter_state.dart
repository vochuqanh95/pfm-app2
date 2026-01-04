// Import foundation library để sử dụng @immutable annotation
import 'package:flutter/foundation.dart';
// Import DateTimeRange từ Material library
import 'package:flutter/material.dart' show DateTimeRange;
// Import TransactionModel để sử dụng TransactionType
import 'transaction_model.dart';

// Enum định nghĩa các bộ lọc khoảng thời gian có sẵn
enum DateRangeFilter {
  thisMonth, // Tháng này
  lastMonth, // Tháng trước
  last3Months, // 3 tháng qua
  thisYear, // Năm nay
  custom; // Tùy chỉnh khoảng thời gian

  // Getter trả về tên hiển thị của bộ lọc thời gian
  String get displayName {
    switch (this) {
      case DateRangeFilter.thisMonth:
        return 'This Month'; // Tháng này
      case DateRangeFilter.lastMonth:
        return 'Last Month'; // Tháng trước
      case DateRangeFilter.last3Months:
        return 'Last 3 Months'; // 3 tháng qua
      case DateRangeFilter.thisYear:
        return 'This Year'; // Năm nay
      case DateRangeFilter.custom:
        return 'Custom'; // Tùy chỉnh
    }
  }

  // Method trả về DateTimeRange tương ứng với bộ lọc
  DateTimeRange getDateRange() {
    final now = DateTime.now(); // Lấy thời gian hiện tại
    switch (this) {
      case DateRangeFilter.thisMonth:
        // Trả về khoảng từ ngày 1 tháng này đến cuối tháng này
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1), // Ngày đầu tháng
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59), // Ngày cuối tháng
        );
      case DateRangeFilter.lastMonth:
        // Trả về khoảng từ ngày 1 tháng trước đến cuối tháng trước
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1), // Ngày đầu tháng trước
          end: DateTime(now.year, now.month, 0, 23, 59, 59), // Ngày cuối tháng trước
        );
      case DateRangeFilter.last3Months:
        // Trả về khoảng từ 3 tháng trước đến cuối tháng này
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, 1), // Ngày đầu của 3 tháng trước
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59), // Ngày cuối tháng này
        );
      case DateRangeFilter.thisYear:
        // Trả về khoảng từ ngày 1/1 năm nay đến 31/12 năm nay
        return DateTimeRange(
          start: DateTime(now.year, 1, 1), // Ngày đầu năm
          end: DateTime(now.year, 12, 31, 23, 59, 59), // Ngày cuối năm
        );
      case DateRangeFilter.custom:
        // Cho custom, trả về khoảng mặc định (sẽ được ghi đè bởi customDateRange)
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1), // Ngày đầu tháng này
          end: now, // Thời gian hiện tại
        );
    }
  }
}

// Class immutable đại diện cho trạng thái bộ lọc giao dịch
@immutable
class TransactionFilterState {
  final DateRangeFilter dateRangeFilter; // Bộ lọc khoảng thời gian
  final DateTimeRange? customDateRange; // Khoảng thời gian tùy chỉnh (có thể null)
  final TransactionType? typeFilter; // Lọc theo loại giao dịch (null = tất cả)
  final String? walletIdFilter; // Lọc theo ví (null = tất cả)
  final String? categoryIdFilter; // Lọc theo danh mục (null = tất cả)
  final String? memberIdFilter; // Lọc theo thành viên (null = tất cả, chỉ dành cho chủ hộ)
  final String searchQuery; // Từ khóa tìm kiếm

  // Constructor khởi tạo TransactionFilterState
  const TransactionFilterState({
    this.dateRangeFilter = DateRangeFilter.thisMonth, // Mặc định tháng này
    this.customDateRange,
    this.typeFilter,
    this.walletIdFilter,
    this.categoryIdFilter,
    this.memberIdFilter,
    this.searchQuery = '', // Mặc định không có từ khóa tìm kiếm
  });

  // Getter lấy khoảng thời gian hiệu lực dựa trên loại bộ lọc
  DateTimeRange get effectiveDateRange {
    if (dateRangeFilter == DateRangeFilter.custom && customDateRange != null) {
      return customDateRange!; // Dùng khoảng tùy chỉnh nếu có
    }
    return dateRangeFilter.getDateRange(); // Dùng khoảng thời gian mặc định của bộ lọc
  }

  // Getter kiểm tra có bộ lọc nào đang hoạt động không (ngoài khoảng thời gian mặc định)
  bool get hasActiveFilters {
    return typeFilter != null || // Có lọc loại giao dịch
        walletIdFilter != null || // Có lọc ví
        categoryIdFilter != null || // Có lọc danh mục
        memberIdFilter != null || // Có lọc thành viên
        searchQuery.isNotEmpty || // Có từ khóa tìm kiếm
        dateRangeFilter != DateRangeFilter.thisMonth; // Không phải khoảng thời gian mặc định
  }

  // Getter đếm số lượng bộ lọc đang hoạt động
  int get activeFilterCount {
    int count = 0; // Khởi tạo bộ đếm
    if (typeFilter != null) count++; // Đếm bộ lọc loại giao dịch
    if (walletIdFilter != null) count++; // Đếm bộ lọc ví
    if (categoryIdFilter != null) count++; // Đếm bộ lọc danh mục
    if (memberIdFilter != null) count++; // Đếm bộ lọc thành viên
    if (searchQuery.isNotEmpty) count++; // Đếm từ khóa tìm kiếm
    if (dateRangeFilter != DateRangeFilter.thisMonth) count++; // Đếm bộ lọc thời gian
    return count; // Trả về tổng số bộ lọc
  }

  // Method tạo bản copy của TransactionFilterState với các giá trị được cập nhật
  TransactionFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTimeRange? customDateRange,
    TransactionType? typeFilter,
    String? walletIdFilter,
    String? categoryIdFilter,
    String? memberIdFilter,
    String? searchQuery,
    bool clearTypeFilter = false, // Flag xóa bộ lọc loại giao dịch
    bool clearWalletFilter = false, // Flag xóa bộ lọc ví
    bool clearCategoryFilter = false, // Flag xóa bộ lọc danh mục
    bool clearMemberFilter = false, // Flag xóa bộ lọc thành viên
    bool clearCustomDateRange = false, // Flag xóa khoảng thời gian tùy chỉnh
  }) {
    // Trả về TransactionFilterState mới với giá trị mới hoặc giữ nguyên/xóa giá trị cũ
    return TransactionFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter, // Dùng dateRangeFilter mới hoặc giữ nguyên
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange), // Xóa hoặc cập nhật
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter), // Xóa hoặc cập nhật
      walletIdFilter: clearWalletFilter ? null : (walletIdFilter ?? this.walletIdFilter), // Xóa hoặc cập nhật
      categoryIdFilter: clearCategoryFilter ? null : (categoryIdFilter ?? this.categoryIdFilter), // Xóa hoặc cập nhật
      memberIdFilter: clearMemberFilter ? null : (memberIdFilter ?? this.memberIdFilter), // Xóa hoặc cập nhật
      searchQuery: searchQuery ?? this.searchQuery, // Dùng searchQuery mới hoặc giữ nguyên
    );
  }

  // Method reset tất cả bộ lọc về mặc định
  TransactionFilterState reset() {
    return const TransactionFilterState(); // Trả về trạng thái mặc định
  }

  // Override toán tử == để so sánh 2 TransactionFilterState
  @override
  bool operator ==(Object other) =>
      identical(this, other) || // Kiểm tra cùng instance
      other is TransactionFilterState && // Kiểm tra cùng kiểu
          runtimeType == other.runtimeType && // Kiểm tra cùng runtimeType
          dateRangeFilter == other.dateRangeFilter && // So sánh dateRangeFilter
          customDateRange == other.customDateRange && // So sánh customDateRange
          typeFilter == other.typeFilter && // So sánh typeFilter
          walletIdFilter == other.walletIdFilter && // So sánh walletIdFilter
          categoryIdFilter == other.categoryIdFilter && // So sánh categoryIdFilter
          memberIdFilter == other.memberIdFilter && // So sánh memberIdFilter
          searchQuery == other.searchQuery; // So sánh searchQuery

  // Override hashCode để tính hash code cho TransactionFilterState
  @override
  int get hashCode =>
      dateRangeFilter.hashCode ^ // XOR hash của dateRangeFilter
      customDateRange.hashCode ^ // XOR hash của customDateRange
      typeFilter.hashCode ^ // XOR hash của typeFilter
      walletIdFilter.hashCode ^ // XOR hash của walletIdFilter
      categoryIdFilter.hashCode ^ // XOR hash của categoryIdFilter
      memberIdFilter.hashCode ^ // XOR hash của memberIdFilter
      searchQuery.hashCode; // XOR hash của searchQuery
}
