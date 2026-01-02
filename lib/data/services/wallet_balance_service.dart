import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class WalletBalanceService {
  final FirebaseFirestore _firestore;

  WalletBalanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _walletsCollection = 'wallets';
  static const String _transactionsCollection = 'transactions';

  /// Apply an expense transaction: decreases wallet balance and creates transaction record
  /// Returns the transaction ID
  Future<String> applyExpenseTransaction({
    required String walletId,
    required double amount,
    required String currency,
    required String userId,
    required String categoryId,
    String? categoryName,
    String? categoryType,
    String? householdId,
    String? note,
    DateTime? date,
    String? actorUserId,
    String? actorDisplayName,
    String? actorRole,
    String? goalId,
    String? imageUrl,
    String? recurringRuleId,
    Future<void> Function(Transaction txn, String transactionId)? additionalOperations,
  }) async {
    if (amount <= 0) {
      throw Exception('Transaction amount must be greater than 0');
    }

    final now = DateTime.now();
    final transactionDate = date ?? now;
    String? createdTransactionId;

    await _firestore.runTransaction((txn) async {
      // READ PHASE
      final walletRef = _firestore.collection(_walletsCollection).doc(walletId);
      final walletSnap = await txn.get(walletRef);

      if (!walletSnap.exists) {
        throw Exception('Wallet not found');
      }

      final walletData = walletSnap.data()!;
      final currentBalance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;

      // Validate sufficient balance for expense
      if (currentBalance < amount) {
        throw Exception(
            'Insufficient wallet balance. You have \$${currentBalance.toStringAsFixed(2)} but need \$${amount.toStringAsFixed(2)}');
      }

      // WRITE PHASE
      // 1. Create transaction record
      final transactionModel = TransactionModel(
        transactionId: '',
        userId: userId,
        householdId: householdId,
        categoryId: categoryId,
        categoryName: categoryName,
        categoryType: categoryType,
        walletId: walletId,
        amount: amount,
        currency: currency,
        type: TransactionType.expense,
        note: note ?? '',
        date: transactionDate,
        imageUrl: imageUrl,
        recurringRuleId: recurringRuleId,
        createdAt: now,
        updatedAt: now,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
        goalId: goalId,
      );

      final transactionRef = _firestore.collection(_transactionsCollection).doc();
      createdTransactionId = transactionRef.id;
      txn.set(transactionRef, transactionModel.toFirestore());

      // 2. Update wallet balance
      final newBalance = currentBalance - amount;
      txn.update(walletRef, {
        'balance': newBalance,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Execute additional operations if provided
      if (additionalOperations != null) {
        await additionalOperations(txn, createdTransactionId!);
      }
    });

    return createdTransactionId!;
  }

  /// Apply an income transaction: increases wallet balance and creates transaction record
  /// Returns the transaction ID
  Future<String> applyIncomeTransaction({
    required String walletId,
    required double amount,
    required String currency,
    required String userId,
    required String categoryId,
    String? categoryName,
    String? categoryType,
    String? householdId,
    String? note,
    DateTime? date,
    String? actorUserId,
    String? actorDisplayName,
    String? actorRole,
    String? imageUrl,
    String? recurringRuleId,
    Future<void> Function(Transaction txn, String transactionId)? additionalOperations,
  }) async {
    if (amount <= 0) {
      throw Exception('Transaction amount must be greater than 0');
    }

    final now = DateTime.now();
    final transactionDate = date ?? now;
    String? createdTransactionId;

    await _firestore.runTransaction((txn) async {
      // READ PHASE
      final walletRef = _firestore.collection(_walletsCollection).doc(walletId);
      final walletSnap = await txn.get(walletRef);

      if (!walletSnap.exists) {
        throw Exception('Wallet not found');
      }

      final walletData = walletSnap.data()!;
      final currentBalance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;

      // WRITE PHASE
      // 1. Create transaction record
      final transactionModel = TransactionModel(
        transactionId: '',
        userId: userId,
        householdId: householdId,
        categoryId: categoryId,
        categoryName: categoryName,
        categoryType: categoryType,
        walletId: walletId,
        amount: amount,
        currency: currency,
        type: TransactionType.income,
        note: note ?? '',
        date: transactionDate,
        imageUrl: imageUrl,
        recurringRuleId: recurringRuleId,
        createdAt: now,
        updatedAt: now,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
      );

      final transactionRef = _firestore.collection(_transactionsCollection).doc();
      createdTransactionId = transactionRef.id;
      txn.set(transactionRef, transactionModel.toFirestore());

      // 2. Update wallet balance
      final newBalance = currentBalance + amount;
      txn.update(walletRef, {
        'balance': newBalance,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Execute additional operations if provided
      if (additionalOperations != null) {
        await additionalOperations(txn, createdTransactionId!);
      }
    });

    return createdTransactionId!;
  }

  /// Apply a transfer transaction: decreases from wallet, increases to wallet, creates transaction record
  /// Returns the transaction ID
  Future<String> applyTransferTransaction({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required String currency,
    required String userId,
    String? householdId,
    String? categoryId,
    String? categoryName,
    String? categoryType,
    String? note,
    DateTime? date,
    String? actorUserId,
    String? actorDisplayName,
    String? actorRole,
    String? imageUrl,
    String? recurringRuleId,
    Future<void> Function(Transaction txn, String transactionId)? additionalOperations,
  }) async {
    if (amount <= 0) {
      throw Exception('Transfer amount must be greater than 0');
    }

    final now = DateTime.now();
    final transactionDate = date ?? now;
    String? createdTransactionId;

    await _firestore.runTransaction((txn) async {
      // READ PHASE
      final fromWalletRef = _firestore.collection(_walletsCollection).doc(fromWalletId);
      final toWalletRef = _firestore.collection(_walletsCollection).doc(toWalletId);

      final fromWalletSnap = await txn.get(fromWalletRef);
      final toWalletSnap = await txn.get(toWalletRef);

      if (!fromWalletSnap.exists) {
        throw Exception('Source wallet not found');
      }
      if (!toWalletSnap.exists) {
        throw Exception('Destination wallet not found');
      }

      final fromWalletData = fromWalletSnap.data()!;
      final toWalletData = toWalletSnap.data()!;

      final fromBalance = (fromWalletData['balance'] as num?)?.toDouble() ?? 0.0;
      final toBalance = (toWalletData['balance'] as num?)?.toDouble() ?? 0.0;

      // Validate sufficient balance in source wallet
      if (fromBalance < amount) {
        throw Exception(
            'Insufficient balance in source wallet. You have \$${fromBalance.toStringAsFixed(2)} but need \$${amount.toStringAsFixed(2)}');
      }

      // WRITE PHASE
      // 1. Create transaction record
      final transactionModel = TransactionModel(
        transactionId: '',
        userId: userId,
        householdId: householdId,
        categoryId: categoryId ?? 'transfer',
        categoryName: categoryName,
        categoryType: categoryType,
        walletId: fromWalletId,
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        amount: amount,
        currency: currency,
        type: TransactionType.transfer,
        note: note ?? '',
        date: transactionDate,
        imageUrl: imageUrl,
        recurringRuleId: recurringRuleId,
        createdAt: now,
        updatedAt: now,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
      );

      final transactionRef = _firestore.collection(_transactionsCollection).doc();
      createdTransactionId = transactionRef.id;
      txn.set(transactionRef, transactionModel.toFirestore());

      // 2. Update source wallet balance (decrease)
      final newFromBalance = fromBalance - amount;
      txn.update(fromWalletRef, {
        'balance': newFromBalance,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update destination wallet balance (increase)
      final newToBalance = toBalance + amount;
      txn.update(toWalletRef, {
        'balance': newToBalance,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Execute additional operations if provided
      if (additionalOperations != null) {
        await additionalOperations(txn, createdTransactionId!);
      }
    });

    return createdTransactionId!;
  }

  /// Update wallet balance directly (use with caution - prefer using transaction-based methods)
  /// This is mainly for backward compatibility or corrections
  Future<void> updateWalletBalance({
    required String walletId,
    required double newBalance,
  }) async {
    await _firestore.collection(_walletsCollection).doc(walletId).update({
      'balance': newBalance,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
