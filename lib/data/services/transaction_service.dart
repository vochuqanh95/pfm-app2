import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../services/wallet_balance_service.dart';

class TransactionService {
  final TransactionRepository _transactionRepository;
  final WalletBalanceService _walletBalanceService;
  final FirebaseFirestore _firestore;

  TransactionService({
    TransactionRepository? transactionRepository,
    WalletBalanceService? walletBalanceService,
    FirebaseFirestore? firestore,
  })  : _transactionRepository = transactionRepository ?? TransactionRepository(),
        _walletBalanceService = walletBalanceService ?? WalletBalanceService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a transaction and apply its effect to the wallet(s) in a single flow.
  /// Returns the created transactionId.
  Future<String> createTransaction(TransactionModel transaction) async {
    debugPrint(
        '[TX_SERVICE] Creating transaction: type=${transaction.type.name}, amount=${transaction.amount}, wallet=${transaction.walletId}, category=${transaction.categoryId}, actor=${transaction.actorUserId}');
    debugPrint(
        '[TXN_CREATE] Creating transaction: amount=${transaction.amount}, wallet=${transaction.walletId}, type=${transaction.type.name}, actor=${transaction.actorUserId}');
    debugPrint(
        '[TXN_FIX] Saving txn with category_id=${transaction.categoryId}, category_name=${transaction.categoryName ?? '-'}');

    String transactionId;
    if (transaction.type == TransactionType.transfer) {
      if (transaction.fromWalletId == null || transaction.toWalletId == null) {
        throw ArgumentError('Transfer requires both fromWalletId and toWalletId');
      }
      transactionId = await _walletBalanceService.applyTransferTransaction(
        fromWalletId: transaction.fromWalletId!,
        toWalletId: transaction.toWalletId!,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        householdId: transaction.householdId,
        categoryId: transaction.categoryId,
        categoryName: transaction.categoryName,
        categoryType: transaction.categoryType,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    } else if (transaction.type == TransactionType.expense) {
      transactionId = await _walletBalanceService.applyExpenseTransaction(
        walletId: transaction.walletId,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        categoryId: transaction.categoryId,
        categoryName: transaction.categoryName,
        categoryType: transaction.categoryType,
        householdId: transaction.householdId,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        goalId: transaction.goalId,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    } else {
      transactionId = await _walletBalanceService.applyIncomeTransaction(
        walletId: transaction.walletId,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        categoryId: transaction.categoryId,
        categoryName: transaction.categoryName,
        categoryType: transaction.categoryType,
        householdId: transaction.householdId,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    }

    debugPrint('[TXN_CREATE] Firestore write completed: docId=$transactionId');
    return transactionId;
  }

  /// Update an existing transaction and adjust wallet balances for the delta.
  /// Currently supports income and expense edits on the same wallet.
  Future<void> updateTransaction(TransactionModel updated) async {
    final existing =
        await _transactionRepository.getTransactionById(updated.transactionId);
    if (existing == null) {
      throw Exception('Transaction not found');
    }

    if (existing.type == TransactionType.transfer ||
        updated.type == TransactionType.transfer) {
      throw Exception('Editing transfers is not supported yet');
    }

    if (existing.walletId != updated.walletId || existing.type != updated.type) {
      throw Exception('Changing wallet or type during edit is not supported');
    }

    final delta = updated.amount - existing.amount;
    debugPrint(
        '[TXN_UPDATE] Updating transaction=${updated.transactionId}, delta=$delta, type=${updated.type.name}');
    debugPrint(
        '[TX_SERVICE] Updating transaction: id=${updated.transactionId}, delta=$delta, walletChanged=${existing.walletId != updated.walletId}');
    debugPrint(
        '[TXN_FIX] Updating txn id=${updated.transactionId} category_name=${updated.categoryName ?? existing.categoryName ?? '-'}');

    await _firestore.runTransaction((txn) async {
      final walletRef = _firestore.collection('wallets').doc(updated.walletId);
      final walletSnap = await txn.get(walletRef);
      if (!walletSnap.exists) {
        throw Exception('Wallet not found');
      }

      final currentBalance =
          (walletSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      double newBalance = currentBalance;

      if (updated.type == TransactionType.expense) {
        newBalance = currentBalance - delta;
      } else if (updated.type == TransactionType.income) {
        newBalance = currentBalance + delta;
      }

      txn.update(walletRef, {
        'balance': newBalance,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final data = updated
          .copyWith(
            updatedAt: DateTime.now(),
            // Preserve createdAt if it existed
            createdAt: existing.createdAt,
          )
          .toFirestore();
      txn.update(
          _firestore.collection('transactions').doc(updated.transactionId), data);
    });

    debugPrint('[TXN_UPDATE] Transaction updated: ${updated.transactionId}');
  }

  /// Delete a transaction and revert its wallet impact atomically.
  Future<void> deleteTransaction(String transactionId) async {
    final txRef = _firestore.collection('transactions').doc(transactionId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(txRef);
      if (!snap.exists) {
        throw Exception('Transaction not found');
      }
      final tx = TransactionModel.fromFirestore(snap);

      // Validate required wallet info
      if (tx.type == TransactionType.transfer &&
          (tx.fromWalletId == null || tx.toWalletId == null)) {
        throw Exception('Transfer transaction missing wallet information');
      }
      if (tx.type != TransactionType.transfer && tx.walletId.isEmpty) {
        throw Exception('Transaction missing wallet information');
      }

      final walletCollection = _firestore.collection('wallets');
      final updates = <DocumentReference<Map<String, dynamic>>, double>{};

      switch (tx.type) {
        case TransactionType.expense:
          final walletRef = walletCollection.doc(tx.walletId);
          final walletSnap = await txn.get(walletRef);
          final current = (walletSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          final newBalance = current + tx.amount;
          updates[walletRef] = newBalance;
          debugPrint(
              '[TXN_FIX] Deleting txn id=$transactionId type=expense amount=${tx.amount} wallet=${tx.walletId} reversing delta=+${tx.amount}');
          break;
        case TransactionType.income:
          final walletRef = walletCollection.doc(tx.walletId);
          final walletSnap = await txn.get(walletRef);
          final current = (walletSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          final newBalance = current - tx.amount;
          updates[walletRef] = newBalance;
          debugPrint(
              '[TXN_FIX] Deleting txn id=$transactionId type=income amount=${tx.amount} wallet=${tx.walletId} reversing delta=-${tx.amount}');
          break;
        case TransactionType.transfer:
          final fromRef = walletCollection.doc(tx.fromWalletId);
          final toRef = walletCollection.doc(tx.toWalletId);
          final fromSnap = await txn.get(fromRef);
          final toSnap = await txn.get(toRef);
          if (!fromSnap.exists || !toSnap.exists) {
            throw Exception('Wallet not found for transfer reversal');
          }
          final fromBalance = (fromSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          final toBalance = (toSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          updates[fromRef] = fromBalance + tx.amount;
          updates[toRef] = toBalance - tx.amount;
          debugPrint(
              '[TXN_FIX] Deleting transfer txn id=$transactionId amount=${tx.amount} from=${tx.fromWalletId} to=${tx.toWalletId} reversing delta=+${tx.amount}/-${tx.amount}');
          break;
      }

      for (final entry in updates.entries) {
        txn.update(entry.key, {
          'balance': entry.value,
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      txn.delete(txRef);
    });

    debugPrint('[TXN_FIX] Delete complete id=$transactionId');
  }
}
