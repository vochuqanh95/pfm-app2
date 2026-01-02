import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'transactions';

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection(_collection);

  Future<String> createTransaction(TransactionModel transaction) async {
    final now = DateTime.now();
    final data = transaction.toFirestore()
      ..['created_at'] = Timestamp.fromDate(now)
      ..['updated_at'] = Timestamp.fromDate(now);

    final docRef = await _transactions.add(data);
    return docRef.id;
  }

  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final doc = await _transactions.doc(transactionId).get();
    if (!doc.exists) return null;
    return TransactionModel.fromFirestore(doc);
  }

  Future<List<TransactionModel>> getTransactionsForWallet({
    required String walletId,
    int limit = 50,
  }) async {
    final query = await _transactions
        .where('wallet_id', isEqualTo: walletId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    return query.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDateRange({
    required String walletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = await _transactions
        .where('wallet_id', isEqualTo: walletId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .get();
    return query.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<List<TransactionModel>> getTransactionsByCategory({
    required String walletId,
    required String categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _transactions
        .where('wallet_id', isEqualTo: walletId)
        .where('category_id', isEqualTo: categoryId);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final result = await query.orderBy('date', descending: true).get();
    return result.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<List<TransactionModel>> getIncomeTransactions({
    required String walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _getTransactionsByType(
      walletId: walletId,
      type: TransactionType.income,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<TransactionModel>> getExpenseTransactions({
    required String walletId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _getTransactionsByType(
      walletId: walletId,
      type: TransactionType.expense,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<TransactionModel>> _getTransactionsByType({
    required String walletId,
    required TransactionType type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _transactions
        .where('wallet_id', isEqualTo: walletId)
        .where('type', isEqualTo: type.name);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final result = await query.orderBy('date', descending: true).get();
    return result.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final data = transaction.toFirestore()
      ..['updated_at'] = Timestamp.fromDate(DateTime.now());
    await _transactions.doc(transaction.transactionId).update(data);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactions.doc(transactionId).delete();
  }

  Stream<List<TransactionModel>> streamTransactionsForWallet({
    required String walletId,
    int limit = 50,
  }) {
    return _transactions
        .where('wallet_id', isEqualTo: walletId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) => query.docs.map(TransactionModel.fromFirestore).toList());
  }

  Stream<List<TransactionModel>> watchTransactionsForHousehold({
    required String householdId,
    int? limit,
  }) {
    if (householdId.isEmpty) {
      return const Stream.empty();
    }
    Query<Map<String, dynamic>> query = _transactions
        .where('household_id', isEqualTo: householdId)
        .orderBy('created_at', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snap) => snap.docs.map(TransactionModel.fromFirestore).toList());
  }

  Stream<List<TransactionModel>> watchTransactionsForUser({
    required String userId,
    String? householdId,
    int? limit,
  }) {
    if (userId.isEmpty) {
      return const Stream.empty();
    }
    Query<Map<String, dynamic>> query = _transactions.where('user_id', isEqualTo: userId);

    if (householdId != null && householdId.isNotEmpty) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    query = query.orderBy('created_at', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(TransactionModel.fromFirestore).toList());
  }

  Future<List<TransactionModel>> getTransactionsForHousehold({
    required String householdId,
    int? limit,
  }) async {
    if (householdId.isEmpty) return [];

    Query<Map<String, dynamic>> query = _transactions
        .where('household_id', isEqualTo: householdId)
        .orderBy('created_at', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    final result = await query.get();
    return result.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<List<TransactionModel>> getTransactionsForUser({
    required String userId,
    String? householdId,
    int? limit,
  }) async {
    if (userId.isEmpty) return [];

    Query<Map<String, dynamic>> query = _transactions.where('user_id', isEqualTo: userId);

    if (householdId != null && householdId.isNotEmpty) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    query = query.orderBy('created_at', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }

    final result = await query.get();
    return result.docs.map(TransactionModel.fromFirestore).toList();
  }

  Future<double> calculateTotalIncome({
    required String walletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await getIncomeTransactions(
      walletId: walletId,
      startDate: startDate,
      endDate: endDate,
    );
    return transactions.fold<double>(0.0, (sum, txn) => sum + txn.amount);
  }

  Future<double> calculateTotalExpenses({
    required String walletId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await getExpenseTransactions(
      walletId: walletId,
      startDate: startDate,
      endDate: endDate,
    );
    return transactions.fold<double>(0.0, (sum, txn) => sum + txn.amount);
  }

  /// Get transactions for reports with date range filtering
  /// Uses the same query patterns as Home (created_at) to ensure index compatibility
  Future<List<TransactionModel>> getTransactionsForReports({
    required String userId,
    String? householdId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final List<TransactionModel> allTransactions = [];

      // Use created_at for querying (matches existing indexes)
      // We'll fetch transactions created around the date range, then filter by actual date field
      final createdAtStart = Timestamp.fromDate(startDate.subtract(const Duration(days: 7)));
      final createdAtEnd = Timestamp.fromDate(endDate.add(const Duration(days: 7)));

      // 1. Fetch household transactions (if user belongs to a household)
      if (householdId != null && householdId.isNotEmpty) {
        try {
          // Use the same query pattern as watchTransactionsForHousehold
          // This matches existing index: household_id + created_at DESC
          final householdQuery = await _transactions
              .where('household_id', isEqualTo: householdId)
              .where('created_at', isGreaterThanOrEqualTo: createdAtStart)
              .where('created_at', isLessThanOrEqualTo: createdAtEnd)
              .orderBy('created_at', descending: true)
              .get();

          allTransactions.addAll(
            householdQuery.docs.map(TransactionModel.fromFirestore).toList(),
          );
        } catch (e) {
          print('[TransactionRepository] Failed to fetch household transactions: $e');
        }
      }

      // 2. Fetch personal transactions (user_id = current user)
      try {
        // Use the same query pattern as watchTransactionsForUser
        // This matches existing index: user_id + created_at DESC
        final personalQuery = await _transactions
            .where('user_id', isEqualTo: userId)
            .where('created_at', isGreaterThanOrEqualTo: createdAtStart)
            .where('created_at', isLessThanOrEqualTo: createdAtEnd)
            .orderBy('created_at', descending: true)
            .get();

        allTransactions.addAll(
          personalQuery.docs.map(TransactionModel.fromFirestore).toList(),
        );
      } catch (e) {
        print('[TransactionRepository] Failed to fetch personal transactions: $e');
      }

      // 3. Remove duplicates by transaction ID
      final uniqueTransactions = <String, TransactionModel>{};
      for (final tx in allTransactions) {
        if (tx.transactionId.isNotEmpty) {
          uniqueTransactions[tx.transactionId] = tx;
        }
      }

      // 4. Filter by actual transaction date (not created_at)
      final filtered = uniqueTransactions.values.where((tx) {
        return tx.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
               tx.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      // 5. Sort by transaction date
      filtered.sort((a, b) => b.date.compareTo(a.date));

      print('[TransactionRepository][REPORTS] householdId=$householdId userId=$userId '
          'range=$startDate..$endDate fetched ${filtered.length} tx AFTER merge and date filter');

      return filtered;
    } catch (e, st) {
      print('[TransactionRepository][REPORTS][ERROR] Failed to fetch transactions: $e\n$st');
      return [];
    }
  }
}
