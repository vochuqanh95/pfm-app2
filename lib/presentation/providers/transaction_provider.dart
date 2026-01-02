import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/transaction_export_service.dart';
import '../../data/services/transaction_import_service.dart';
import 'auth_provider.dart';
import 'household_provider.dart';
import 'wallet_provider.dart';

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => TransactionRepository());
final transactionServiceProvider = Provider<TransactionService>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionService(transactionRepository: repo);
});
final transactionExportServiceProvider =
    Provider<TransactionExportService>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  return TransactionExportService(
    transactionRepository: repo,
    walletRepository: walletRepo,
  );
});
final transactionImportServiceProvider =
    Provider<TransactionImportService>((ref) {
  final transactionService = ref.watch(transactionServiceProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  return TransactionImportService(
    transactionService: transactionService,
    transactionRepository: transactionRepository,
    walletRepository: walletRepo,
  );
});

final walletTransactionsProvider = FutureProvider.family
    .autoDispose<List<TransactionModel>, String>((ref, walletId) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactionsForWallet(walletId: walletId);
});

final walletTransactionsStreamProvider = StreamProvider.family
    .autoDispose<List<TransactionModel>, String>((ref, walletId) {
  final repository = ref.watch(transactionRepositoryProvider);
  debugPrint('[TRANSACTIONS] Wallet stream created wallet=$walletId');
  ref.onDispose(() {
    debugPrint('[TRANSACTIONS] Wallet stream disposed wallet=$walletId');
  });
  return repository.streamTransactionsForWallet(walletId: walletId);
});

final householdRecentTransactionsProvider = StreamProvider.family
    .autoDispose<List<TransactionModel>, String>((ref, householdId) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (householdId.isEmpty) {
    debugPrint('[TRANSACTIONS] Household recent empty id -> []');
    return Stream.value(const <TransactionModel>[]);
  }
  debugPrint('[TRANSACTIONS] Provider created for household recent: $householdId');
  ref.onDispose(() {
    debugPrint('[TRANSACTIONS] Provider disposed for household recent: $householdId');
  });
  return repository.watchTransactionsForHousehold(
    householdId: householdId,
    limit: 20,
  ).map((txns) {
    debugPrint(
        '[TRANSACTIONS] Household recent loaded: ${txns.length} transactions');
    return txns;
  });
});

class HouseholdTxParams {
  final String householdId;
  final int limit;

  const HouseholdTxParams({required this.householdId, this.limit = 200});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HouseholdTxParams &&
        other.householdId == householdId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(householdId, limit);
}

final householdTransactionsProvider = StreamProvider.family
    .autoDispose<List<TransactionModel>, HouseholdTxParams>((ref, params) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (params.householdId.isEmpty) {
    debugPrint('[TRANSACTIONS] Empty household ID, returning empty list');
    return Stream.value(const <TransactionModel>[]);
  }
  debugPrint(
      '[TRANSACTIONS] Watching household: household=${params.householdId} limit=${params.limit}');
  ref.onDispose(() {
    debugPrint(
        '[TRANSACTIONS] Disposed household stream: household=${params.householdId} limit=${params.limit}');
  });
  return repository.watchTransactionsForHousehold(
    householdId: params.householdId,
    limit: params.limit,
  ).map((txns) {
    debugPrint(
        '[TRANSACTIONS] Household transactions loaded: ${txns.length} transactions');
    return txns;
  });
});

final userRecentTransactionsProvider = StreamProvider.family
    .autoDispose<List<TransactionModel>, UserTransactionParams>((ref, params) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (params.userId.isEmpty) {
    debugPrint('[TRANSACTIONS] Empty user ID, returning empty list');
    return Stream.value(const <TransactionModel>[]);
  }
  debugPrint(
      '[TRANSACTIONS] Watching user: user=${params.userId} household=${params.householdId} limit=${params.limit}');
  ref.onDispose(() {
    debugPrint(
        '[TRANSACTIONS] Disposed user stream: user=${params.userId} household=${params.householdId}');
  });
  return repository.watchTransactionsForUser(
    userId: params.userId,
    householdId: params.householdId,
    limit: params.limit,
  ).map((txns) {
    debugPrint(
        '[TRANSACTIONS] User transactions loaded: ${txns.length} transactions');
    return txns;
  });
});

final transactionsByDateRangeProvider =
    FutureProvider.family.autoDispose<List<TransactionModel>, DateRangeParams>(
        (ref, params) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactionsByDateRange(
    walletId: params.walletId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

final totalIncomeProvider = FutureProvider.family<double, DateRangeParams>((ref, params) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.calculateTotalIncome(
    walletId: params.walletId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

final totalExpensesProvider = FutureProvider.family<double, DateRangeParams>((ref, params) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.calculateTotalExpenses(
    walletId: params.walletId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Auto-refreshing recent transactions for Home that follows auth/household changes.
final homeRecentTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionModel>>((ref) {
  final userAsync = ref.watch(authUserProvider);
  final householdAsync = ref.watch(currentUserHouseholdProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) {
        debugPrint('[TRANSACTIONS] No user for home stream, returning []');
        return Stream.value(const <TransactionModel>[]);
      }
      final householdId =
          householdAsync.valueOrNull?.householdId ?? user.householdId ?? '';
      final repository = ref.watch(transactionRepositoryProvider);
      final label =
          'user=${user.userId}, household=${householdId.isEmpty ? '-' : householdId}';
      debugPrint('[TRANSACTIONS] Provider created for $label');
      ref.onDispose(() {
        debugPrint('[TRANSACTIONS] Provider disposed for $label');
      });

      if (householdId.isNotEmpty) {
        return repository
            .watchTransactionsForHousehold(
              householdId: householdId,
              limit: 20,
            )
            .map((txns) {
          debugPrint(
              '[TRANSACTIONS] Recent household transactions: ${txns.length}');
          return txns;
        });
      }

      return repository
          .watchTransactionsForUser(
            userId: user.userId,
            householdId: null,
            limit: 20,
          )
          .map((txns) {
        debugPrint(
            '[TRANSACTIONS] Recent personal transactions: ${txns.length}');
        return txns;
      });
    },
    loading: () => const Stream.empty(),
    error: (error, _) => Stream.error(error),
  );
});

class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final TransactionService _service;

  TransactionNotifier(this._repository, this._service)
      : super(const AsyncValue.data(null));

  Future<String?> createTransaction(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    try {
      final transactionId = await _repository.createTransaction(transaction);
      state = const AsyncValue.data(null);
      debugPrint('[TRANSACTIONS] Transaction created: $transactionId');
      return transactionId;
    } catch (e, stack) {
      debugPrint('[TRANSACTIONS] Error creating transaction: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateTransaction(transaction);
      debugPrint('[TRANSACTIONS] Transaction updated: ${transaction.transactionId}');
    });
  }

  Future<void> deleteTransaction(String transactionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.deleteTransaction(transactionId);
      debugPrint('[TRANSACTIONS] Transaction deleted: $transactionId');
    });
  }

  Future<void> updateApprovalStatus(String transactionId, bool isApproved) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[TRANSACTIONS] Approval status updated: $transactionId, approved: $isApproved');
    });
  }
}

final transactionNotifierProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final service = ref.watch(transactionServiceProvider);
  return TransactionNotifier(repository, service);
});

class DateRangeParams {
  final String walletId;
  final DateTime startDate;
  final DateTime endDate;

  DateRangeParams({
    required this.walletId,
    required this.startDate,
    required this.endDate,
  });
}

class UserTransactionParams {
  final String userId;
  final String? householdId;
  final int limit;

  const UserTransactionParams({
    required this.userId,
    this.householdId,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserTransactionParams &&
        other.userId == userId &&
        other.householdId == householdId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(userId, householdId, limit);
}
