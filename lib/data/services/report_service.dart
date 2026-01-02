import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/wallet_repository.dart';

/// Summary metrics for a report period
class ReportSummary {
  final double totalIncome;
  final double totalExpense;

  const ReportSummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  double get net => totalIncome - totalExpense;
}

class DebtReportSummary {
  final double totalIOwe;
  final double totalOwedToMe;
  final int overdueCount;

  const DebtReportSummary({
    required this.totalIOwe,
    required this.totalOwedToMe,
    required this.overdueCount,
  });
}

/// Category spending breakdown
class CategorySpend {
  final String categoryId;
  final double totalAmount;

  const CategorySpend({
    required this.categoryId,
    required this.totalAmount,
  });
}

/// Time grouping options for time series data
enum TimeGrouping {
  daily,
  weekly,
  monthly,
}

/// Data point for time series chart
class TimeSeriesPoint {
  final DateTime period;
  final double income;
  final double expense;

  const TimeSeriesPoint({
    required this.period,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

/// Service for generating reports and aggregating transaction data
class ReportService {
  final FirebaseFirestore _firestore;
  final TransactionRepository _transactionRepository;
  final DebtRepository _debtRepository;
  final WalletRepository _walletRepository;
  static const String _transactionsCollection = 'transactions';

  ReportService({
    FirebaseFirestore? firestore,
    TransactionRepository? transactionRepository,
    DebtRepository? debtRepository,
    WalletRepository? walletRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _transactionRepository =
            transactionRepository ?? TransactionRepository(),
        _debtRepository = debtRepository ?? DebtRepository(),
        _walletRepository = walletRepository ?? WalletRepository();

  Future<DebtReportSummary> getDebtSummary({
    required UserModel currentUser,
    String? householdId,
  }) async {
    try {
      debugPrint(
          '[REPORTS][SERVICE] getDebtSummary called user=${currentUser.userId} household=$householdId');

      final debts = <DebtModel>[];

      try {
        final personal =
            await _debtRepository.getPersonalDebts(currentUser.userId);
        debts.addAll(personal);
      } catch (e) {
        debugPrint('[REPORTS][SERVICE] WARN loading personal debts: $e');
      }

      if (currentUser.isHead && householdId != null && householdId.isNotEmpty) {
        try {
          final householdDebts =
              await _debtRepository.getHouseholdDebts(householdId);
          debts.addAll(householdDebts);
        } catch (e) {
          debugPrint('[REPORTS][SERVICE] WARN loading household debts: $e');
        }
      }

      final totalIOwe = debts
          .where((debt) => debt.type == DebtType.iOwe)
          .fold<double>(0, (sum, debt) => sum + debt.remainingAmount);

      final totalOwedToMe = debts
          .where((debt) => debt.type == DebtType.owedToMe)
          .fold<double>(0, (sum, debt) => sum + debt.remainingAmount);

      final overdueCount =
          debts.where((debt) => debt.status == DebtStatus.overdue).length;

      debugPrint(
          '[REPORTS][SERVICE] Debt summary totals: owe=$totalIOwe owedToMe=$totalOwedToMe overdue=$overdueCount from ${debts.length} debts');

      return DebtReportSummary(
        totalIOwe: totalIOwe,
        totalOwedToMe: totalOwedToMe,
        overdueCount: overdueCount,
      );
    } catch (e, st) {
      debugPrint('[REPORTS][SERVICE][ERROR] getDebtSummary: $e\n$st');
      return const DebtReportSummary(
        totalIOwe: 0,
        totalOwedToMe: 0,
        overdueCount: 0,
      );
    }
  }

  /// Get transaction summary (total income, expense, net) for a given filter set
  Future<ReportSummary> getTransactionSummary({
    required UserModel currentUser,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String? categoryId,
    String? memberUserId,
  }) async {
    try {
      debugPrint('[REPORTS][SERVICE] getTransactionSummary called with '
          'userId=${currentUser.userId}, householdId=$householdId, range=$startDate..$endDate, '
          'walletId=$walletId, categoryId=$categoryId, memberUserId=$memberUserId');

      final baseTransactions = await _fetchBaseTransactionsForReports(
        currentUser: currentUser,
        householdId: householdId,
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = _applyInMemoryFilters(
        transactions: baseTransactions,
        currentUser: currentUser,
        walletId: walletId,
        categoryId: categoryId,
        memberUserId: memberUserId,
      );

      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (final tx in transactions) {
        if (tx.type == TransactionType.income) {
          totalIncome += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          totalExpense += tx.amount;
        }
      }

      debugPrint('[REPORTS][SERVICE] getTransactionSummary completed: '
          'income=$totalIncome, expense=$totalExpense (${transactions.length} transactions)');

      return ReportSummary(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    } catch (e, st) {
      debugPrint('[REPORTS][SERVICE][ERROR] getTransactionSummary: $e\n$st');
      // Return safe default instead of throwing - allows UI to show empty state
      return const ReportSummary(
        totalIncome: 0,
        totalExpense: 0,
      );
    }
  }

  /// Get spending breakdown by category
  Future<List<CategorySpend>> getCategorySpendBreakdown({
    required UserModel currentUser,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String? categoryId,
    String? memberUserId,
  }) async {
    try {
      debugPrint('[REPORTS][SERVICE] getCategorySpendBreakdown called');

      final baseTransactions = await _fetchBaseTransactionsForReports(
        currentUser: currentUser,
        householdId: householdId,
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = _applyInMemoryFilters(
        transactions: baseTransactions,
        currentUser: currentUser,
        walletId: walletId,
        categoryId: categoryId,
        memberUserId: memberUserId,
      );

      // Group expenses by category
      final Map<String, double> categoryTotals = {};

      for (final tx in transactions) {
        if (tx.type == TransactionType.expense) {
          final catId = tx.categoryId;
          if (catId.isNotEmpty) {
            categoryTotals[catId] = (categoryTotals[catId] ?? 0.0) + tx.amount;
          }
        }
      }

      // Convert to list and sort by amount descending
      final result = categoryTotals.entries
          .map((e) => CategorySpend(categoryId: e.key, totalAmount: e.value))
          .toList()
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      debugPrint(
          '[REPORTS][SERVICE] getCategorySpendBreakdown completed: ${result.length} categories');

      return result;
    } catch (e, st) {
      debugPrint(
          '[REPORTS][SERVICE][ERROR] getCategorySpendBreakdown: $e\n$st');
      // Return empty list instead of throwing - allows UI to show empty state
      return [];
    }
  }

  /// Get time series data (income/expense over time)
  Future<List<TimeSeriesPoint>> getTimeSeriesSpend({
    required UserModel currentUser,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String? categoryId,
    String? memberUserId,
    TimeGrouping grouping = TimeGrouping.daily,
  }) async {
    try {
      debugPrint(
          '[REPORTS][SERVICE] getTimeSeriesSpend called with grouping=$grouping');

      final baseTransactions = await _fetchBaseTransactionsForReports(
        currentUser: currentUser,
        householdId: householdId,
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = _applyInMemoryFilters(
        transactions: baseTransactions,
        currentUser: currentUser,
        walletId: walletId,
        categoryId: categoryId,
        memberUserId: memberUserId,
      );

      // Group by time period
      final Map<String, TimeSeriesPoint> periodMap = {};

      for (final tx in transactions) {
        final periodKey = _getPeriodKey(tx.date, grouping);
        final period = _getPeriodStart(tx.date, grouping);

        if (!periodMap.containsKey(periodKey)) {
          periodMap[periodKey] = TimeSeriesPoint(
            period: period,
            income: 0.0,
            expense: 0.0,
          );
        }

        final currentPoint = periodMap[periodKey]!;
        if (tx.type == TransactionType.income) {
          periodMap[periodKey] = TimeSeriesPoint(
            period: period,
            income: currentPoint.income + tx.amount,
            expense: currentPoint.expense,
          );
        } else if (tx.type == TransactionType.expense) {
          periodMap[periodKey] = TimeSeriesPoint(
            period: period,
            income: currentPoint.income,
            expense: currentPoint.expense + tx.amount,
          );
        }
      }

      // Convert to list and sort by period
      final result = periodMap.values.toList()
        ..sort((a, b) => a.period.compareTo(b.period));

      debugPrint(
          '[REPORTS][SERVICE] getTimeSeriesSpend completed: ${result.length} periods');

      return result;
    } catch (e, st) {
      debugPrint('[REPORTS][SERVICE][ERROR] getTimeSeriesSpend: $e\n$st');
      // Return empty list instead of throwing - allows UI to show empty state
      return [];
    }
  }

  /// Get member spending breakdown (for household heads)
  Future<List<Map<String, dynamic>>> getMemberSpendBreakdown({
    required UserModel currentUser,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String? categoryId,
    String? memberUserId,
  }) async {
    try {
      debugPrint('[REPORTS][SERVICE] getMemberSpendBreakdown called');

      final baseTransactions = await _fetchBaseTransactionsForReports(
        currentUser: currentUser,
        householdId: householdId,
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = _applyInMemoryFilters(
        transactions: baseTransactions,
        currentUser: currentUser,
        walletId: walletId,
        categoryId: categoryId,
        memberUserId: memberUserId,
      );

      // Group expenses by member
      final Map<String, Map<String, dynamic>> memberTotals = {};

      for (final tx in transactions) {
        if (tx.type == TransactionType.expense) {
          final actorId = tx.actorUserId ?? tx.userId;
          if (!memberTotals.containsKey(actorId)) {
            memberTotals[actorId] = {
              'userId': actorId,
              'name': tx.actorDisplayName ?? 'Unknown',
              'role': tx.actorRole ?? 'member',
              'total': 0.0,
            };
          }
          memberTotals[actorId]!['total'] =
              (memberTotals[actorId]!['total'] as double) + tx.amount;
        }
      }

      // Convert to list and sort by total descending
      final result = memberTotals.values.toList()
        ..sort(
            (a, b) => (b['total'] as double).compareTo(a['total'] as double));

      debugPrint(
          '[REPORTS][SERVICE] getMemberSpendBreakdown completed: ${result.length} members');

      return result;
    } catch (e, st) {
      debugPrint('[REPORTS][SERVICE][ERROR] getMemberSpendBreakdown: $e\n$st');
      // Return empty list instead of throwing - allows UI to show empty state
      return [];
    }
  }

  Future<List<TransactionModel>> _fetchBaseTransactionsForReports({
    required UserModel currentUser,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('[REPORTS][BASE] Fetching transactions via repository: '
          'householdId=$householdId, userId=${currentUser.userId}, range=$startDate..$endDate');

      // Use the repository method that reuses Home's working query patterns
      final transactions =
          await _transactionRepository.getTransactionsForReports(
        userId: currentUser.userId,
        householdId: householdId,
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint('[REPORTS][BASE] AFTER FETCH count=${transactions.length}');

      return transactions;
    } catch (e, st) {
      debugPrint(
          '[REPORTS][BASE][ERROR] Failed to fetch base transactions: $e\n$st');
      return [];
    }
  }

  Future<List<String>> _resolveVisibleWalletIds({
    required String userId,
    String? householdId,
    required bool isHead,
  }) async {
    final wallets = <WalletModel>[];

    try {
      final personalWallets =
          await _walletRepository.getPersonalWallets(userId);
      wallets.addAll(personalWallets);
    } catch (e) {
      debugPrint('[REPORTS][BASE][WARN] Failed to load personal wallets: $e');
    }

    if (householdId != null && householdId.isNotEmpty) {
      try {
        final householdWallets = await _walletRepository
            .getHouseholdWallets(householdId, userId: userId);
        wallets.addAll(
          householdWallets.where((wallet) {
            // Head: see all household_shared wallets + their own member_private
            // Member: see household_shared + only their own member_private
            if (wallet.scope == WalletScope.householdShared) return true;
            if (wallet.scope == WalletScope.memberPrivate)
              return wallet.userId == userId;
            return false;
          }),
        );
      } catch (e) {
        debugPrint(
            '[REPORTS][BASE][WARN] Failed to load household wallets: $e');
      }
    }

    final ids = <String>{};
    for (final wallet in wallets) {
      if (wallet.walletId.isNotEmpty) {
        ids.add(wallet.walletId);
      }
    }
    return ids.toList();
  }

  List<TransactionModel> _applyInMemoryFilters({
    required List<TransactionModel> transactions,
    required UserModel currentUser,
    String? walletId,
    String? categoryId,
    String? memberUserId,
  }) {
    var filtered = transactions;

    // Head vs Member actor filtering
    if (currentUser.isHead) {
      // Head: can see all transactions from visible wallets
      // If memberUserId filter is set, apply it
      if (memberUserId != null && memberUserId.isNotEmpty) {
        filtered = filtered.where((tx) {
          final actorId = tx.actorUserId ?? tx.userId;
          return actorId == memberUserId;
        }).toList();
      }
      // Otherwise show all household transactions
    } else {
      // Member: only see their own spending regardless of filters
      filtered = filtered.where((tx) {
        final actorId = tx.actorUserId ?? tx.userId;
        return actorId == currentUser.userId || tx.userId == currentUser.userId;
      }).toList();
      debugPrint(
          '[REPORTS][FILTER] Member filter: showing only transactions by ${currentUser.userId}');
    }

    if (walletId != null && walletId.isNotEmpty) {
      filtered = filtered.where((tx) => tx.walletId == walletId).toList();
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      filtered = filtered.where((tx) => tx.categoryId == categoryId).toList();
    }

    debugPrint('[REPORTS][BASE] AFTER FILTERS count=${filtered.length}');

    return filtered;
  }

  /// Get period key for grouping
  String _getPeriodKey(DateTime date, TimeGrouping grouping) {
    switch (grouping) {
      case TimeGrouping.daily:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case TimeGrouping.weekly:
        final weekNumber = _getWeekNumber(date);
        return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
      case TimeGrouping.monthly:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  /// Get period start date for grouping
  DateTime _getPeriodStart(DateTime date, TimeGrouping grouping) {
    switch (grouping) {
      case TimeGrouping.daily:
        return DateTime(date.year, date.month, date.day);
      case TimeGrouping.weekly:
        // Start of week (Monday)
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - (weekday - 1));
      case TimeGrouping.monthly:
        return DateTime(date.year, date.month, 1);
    }
  }

  /// Get week number in year
  int _getWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}
