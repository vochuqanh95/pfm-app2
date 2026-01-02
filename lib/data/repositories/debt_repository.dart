import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';
import '../services/wallet_balance_service.dart';

class DebtRepository {
  final FirebaseFirestore _firestore;
  final WalletBalanceService _walletBalanceService;
  static const String _collection = 'debts';
  static const String _paymentsSubcollection = 'payments';

  DebtRepository({
    FirebaseFirestore? firestore,
    WalletBalanceService? walletBalanceService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _walletBalanceService = walletBalanceService ?? WalletBalanceService();

  Future<String> createDebt(DebtModel debt) async {
    final docRef =
        await _firestore.collection(_collection).add(debt.toFirestore());
    return docRef.id;
  }

  Future<DebtModel?> getDebtById(String debtId) async {
    final doc = await _firestore.collection(_collection).doc(debtId).get();
    if (!doc.exists) return null;
    return DebtModel.fromFirestore(doc);
  }

  Future<List<DebtModel>> getPersonalDebts(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('household_id', isNull: true)
        .orderBy('due_date')
        .get();

    final debts =
        query.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
    debugPrint(
        '[DEBT_REPO] Personal debts fetched: ${debts.length} for user=$userId');
    return debts;
  }

  Future<List<DebtModel>> getHouseholdDebts(String householdId) async {
    final query = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .orderBy('due_date')
        .get();

    final debts =
        query.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
    debugPrint(
        '[DEBT_REPO] Household debts fetched: ${debts.length} for household=$householdId');
    return debts;
  }

  Future<List<DebtModel>> getAllDebtsForUser(
      String userId, List<String> householdIds) async {
    final List<DebtModel> allDebts = [];

    final personalDebts = await getPersonalDebts(userId);
    allDebts.addAll(personalDebts);

    for (var householdId in householdIds) {
      final householdDebts = await getHouseholdDebts(householdId);
      allDebts.addAll(householdDebts);
    }

    allDebts.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    debugPrint(
        '[DEBT_REPO] Combined debts fetched: ${allDebts.length} for user=$userId');
    return allDebts;
  }

  Future<void> updateDebt(DebtModel debt) async {
    debugPrint(
        '[DEBT_REPO] updateDebt id=${debt.debtId}, interestRate=${debt.interestRate}');
    try {
      await _firestore
          .collection(_collection)
          .doc(debt.debtId)
          .update(debt.toFirestore());
    } catch (e) {
      debugPrint('[DEBT_REPO] ERROR updateDebt id=${debt.debtId}: $e');
      rethrow;
    }
  }

  Stream<DebtModel?> watchDebtById(String debtId) {
    if (debtId.isEmpty) {
      debugPrint('[DEBT_REPO] watchDebtById empty id');
      return Stream.value(null);
    }
    debugPrint('[DEBT_REPO] watchDebtById id=$debtId');
    return _firestore
        .collection(_collection)
        .doc(debtId)
        .snapshots()
        .map((doc) => doc.exists ? DebtModel.fromFirestore(doc) : null);
  }

  Future<void> deleteDebt(String debtId) async {
    await _firestore.collection(_collection).doc(debtId).delete();
  }

  Stream<List<DebtModel>> streamDebts({
    String? userId,
    String? householdId,
  }) {
    try {
      debugPrint(
          '[DEBT] Streaming debts: userId=$userId, householdId=$householdId');

      if (userId == null && householdId == null) {
        debugPrint(
            '[DEBT] WARNING: No filters provided, returning empty stream');
        return Stream.value(const <DebtModel>[]);
      }

      Query<Map<String, dynamic>> query = _firestore.collection(_collection);

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
        debugPrint('[DEBT] Filter: user_id == $userId');
      }
      if (householdId != null) {
        query = query.where('household_id', isEqualTo: householdId);
        debugPrint('[DEBT] Filter: household_id == $householdId');
      }

      debugPrint('[DEBT] Adding orderBy: due_date');
      return query.orderBy('due_date').snapshots().map((snapshot) {
        final debts =
            snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
        debugPrint('[DEBT] Loaded ${debts.length} debts');
        return debts;
      }).handleError((error) {
        debugPrint('[DEBT] ERROR Stream error: $error');
      });
    } catch (e, stackTrace) {
      debugPrint('[DEBT] ERROR in streamDebts: $e');
      debugPrint('[DEBT] StackTrace: $stackTrace');
      return Stream.value(const <DebtModel>[]);
    }
  }

  Stream<List<DebtModel>> watchHouseholdDebts(String householdId) {
    if (householdId.isEmpty) {
      debugPrint('[DEBT_REPO] Empty householdId, returning []');
      return Stream.value(const <DebtModel>[]);
    }

    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .orderBy('due_date')
        .snapshots()
        .map((snapshot) {
      final debts =
          snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
      debugPrint(
          '[DEBT_REPO] Household debts fetched: ${debts.length} for household=$householdId');
      return debts;
    }).handleError((error) {
      debugPrint('[DEBT_REPO] Stream error (household): $error');
    });
  }

  Stream<List<DebtModel>> watchUserDebts(
    String userId, {
    bool includeHousehold = false,
  }) {
    if (userId.isEmpty) {
      debugPrint('[DEBT_REPO] Empty userId, returning []');
      return Stream.value(const <DebtModel>[]);
    }

    Query<Map<String, dynamic>> query =
        _firestore.collection(_collection).where('user_id', isEqualTo: userId);

    if (!includeHousehold) {
      query = query.where('household_id', isNull: true);
    }

    return query.orderBy('due_date').snapshots().map((snapshot) {
      final debts =
          snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
      debugPrint(
          '[DEBT_REPO] User debts fetched: ${debts.length} for user=$userId');
      return debts;
    }).handleError((error) {
      debugPrint('[DEBT_REPO] Stream error (user): $error');
    });
  }

  Future<double> getTotalDebtAmount({
    String? userId,
    String? householdId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.get();
    final debts =
        result.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();

    return debts.fold<double>(
        0.0, (total, debt) => total + debt.remainingAmount);
  }

  Future<double> getTotalInterestAmount({
    String? userId,
    String? householdId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.get();
    final debts =
        result.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();

    return debts.fold<double>(
        0.0,
        (runningTotal, debt) =>
            runningTotal + (debt.amount * debt.interestRate / 100));
  }

  Future<void> addPayment({
    required String debtId,
    required double amount,
    required DateTime date,
    String? note,
    String? walletId,
    required String userId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than 0');
    }

    final now = DateTime.now();
    DebtModel? parentDebt;

    try {
      debugPrint(
          '[DebtRepo] Recording payment for debt=$debtId, amount=$amount, walletId=$walletId');

      await _firestore.runTransaction((transaction) async {
        final debtRef = _firestore.collection(_collection).doc(debtId);
        final debtSnapshot = await transaction.get(debtRef);

        if (!debtSnapshot.exists) {
          throw Exception('Debt not found');
        }

        final debt = DebtModel.fromFirestore(debtSnapshot);
        parentDebt = debt;
        final currentPaidAmount = debt.paidAmount ?? 0.0;
        final newPaidAmount = currentPaidAmount + amount;

        debugPrint(
            '[DebtRepo] Current paid: $currentPaidAmount, New paid: $newPaidAmount, Total: ${debt.amount}');

        final paymentRef = debtRef.collection(_paymentsSubcollection).doc();
        final payment = DebtPaymentModel(
          paymentId: paymentRef.id,
          debtId: debtId,
          userId: userId,
          walletId: walletId,
          amount: amount,
          date: date,
          note: note,
          createdAt: now,
        );

        transaction.set(paymentRef, payment.toFirestore());

        transaction.update(debtRef, {
          'paid_amount': newPaidAmount,
        });

        debugPrint(
            '[DebtRepo] Payment document created and debt updated in transaction');
      });

      if (walletId != null) {
        final debt = parentDebt;
        if (debt == null) {
          debugPrint(
              '[DebtRepo] WARN payment saved but parent debt not cached for wallet adjustment');
          return;
        }

        String walletCurrency = 'USD';
        String? walletHouseholdId;

        try {
          final walletSnap =
              await _firestore.collection('wallets').doc(walletId).get();
          if (walletSnap.exists) {
            final data = walletSnap.data()!;
            walletCurrency = (data['currency'] ?? 'USD') as String;
            final dynamic householdValue =
                data['household_id'] ?? data['householdId'];
            if (householdValue is String) {
              walletHouseholdId = householdValue;
            }
          }
        } catch (e) {
          debugPrint(
              '[DebtRepo] WARN unable to load wallet $walletId for currency/household: $e');
        }

        final isIncomingPayment = debt.type == DebtType.owedToMe;
        final detailParts = <String>[
          if (debt.name.isNotEmpty) debt.name,
          if (note != null && note.isNotEmpty) note,
        ];
        final baseLabel =
            isIncomingPayment ? 'Debt payment received' : 'Debt payment';
        final transactionNote = detailParts.isEmpty
            ? baseLabel
            : '$baseLabel: ${detailParts.join(' - ')}';
        final transactionHouseholdId =
            debt.householdId ?? walletHouseholdId;

        debugPrint(
            '[DebtRepo] Creating ${isIncomingPayment ? 'income' : 'expense'} transaction: amount=$amount, householdId=$transactionHouseholdId');

        if (isIncomingPayment) {
          await _walletBalanceService.applyIncomeTransaction(
            walletId: walletId,
            amount: amount,
            currency: walletCurrency,
            userId: userId,
            categoryId: 'debt_payment',
            householdId: transactionHouseholdId,
            note: transactionNote,
            date: date,
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorRole: actorRole,
          );
        } else {
          await _walletBalanceService.applyExpenseTransaction(
            walletId: walletId,
            amount: amount,
            currency: walletCurrency,
            userId: userId,
            categoryId: 'debt_payment',
            householdId: transactionHouseholdId,
            note: transactionNote,
            date: date,
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorRole: actorRole,
          );
        }

        debugPrint(
            '[DebtRepo] Wallet adjustment complete (${isIncomingPayment ? 'income' : 'expense'}) and transaction created');
      }

      debugPrint('[DebtRepo] Payment recorded successfully');
    } catch (e, stackTrace) {
      debugPrint('[DebtRepo] ERROR adding payment: $e');
      debugPrint('[DebtRepo] StackTrace: $stackTrace');
      rethrow;
    }
  }

  Stream<List<DebtPaymentModel>> streamPayments(String debtId) {
    try {
      debugPrint('[DebtRepo] Streaming payments for debt: $debtId');

      return _firestore
          .collection(_collection)
          .doc(debtId)
          .collection(_paymentsSubcollection)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        final payments = snapshot.docs
            .map((doc) => DebtPaymentModel.fromFirestore(doc))
            .toList();
        debugPrint('[DebtRepo] Loaded ${payments.length} payments');
        return payments;
      }).handleError((error) {
        debugPrint('[DebtRepo] ERROR Payment stream error: $error');
        // Let the error propagate so UI can show error state
        throw error;
      });
    } catch (e, stackTrace) {
      debugPrint('[DebtRepo] ERROR in streamPayments: $e');
      debugPrint('[DebtRepo] StackTrace: $stackTrace');
      // Return error stream instead of empty list so UI shows error
      return Stream.error(e, stackTrace);
    }
  }

  Future<List<DebtModel>> getDebtsNeedingReminders({
    required String userId,
    String? householdId,
    int daysAhead = 3,
  }) async {
    final now = DateTime.now();
    final upcomingCutoff = now.add(Duration(days: daysAhead));
    final List<DebtModel> debts = [];

    try {
      final personalQuery = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .where('household_id', isNull: true)
          .where('due_date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('due_date',
              isLessThanOrEqualTo: Timestamp.fromDate(upcomingCutoff))
          .orderBy('due_date')
          .get();

      debts.addAll(
        personalQuery.docs.map((doc) => DebtModel.fromFirestore(doc)),
      );
    } catch (e) {
      debugPrint('[DEBT_REPO] WARN loading personal reminder debts: $e');
    }

    if (householdId != null && householdId.isNotEmpty) {
      try {
        final householdQuery = await _firestore
            .collection(_collection)
            .where('household_id', isEqualTo: householdId)
            .where('due_date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .where('due_date',
                isLessThanOrEqualTo: Timestamp.fromDate(upcomingCutoff))
            .orderBy('due_date')
            .get();

        debts.addAll(
          householdQuery.docs.map((doc) => DebtModel.fromFirestore(doc)),
        );
      } catch (e) {
        debugPrint('[DEBT_REPO] WARN loading household reminder debts: $e');
      }
    }

    final actionable = debts.where((debt) => debt.remainingAmount > 0).toList();
    debugPrint(
        '[DEBT_REPO] Reminder debts fetched: ${actionable.length} (user=$userId, household=$householdId)');
    return actionable;
  }

  Future<List<DebtModel>> getOverdueDebts({
    required String userId,
    String? householdId,
  }) async {
    final now = DateTime.now();
    final List<DebtModel> debts = [];

    try {
      final personalQuery = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .where('household_id', isNull: true)
          .where('due_date', isLessThan: Timestamp.fromDate(now))
          .orderBy('due_date')
          .get();

      debts.addAll(
        personalQuery.docs.map((doc) => DebtModel.fromFirestore(doc)),
      );
    } catch (e) {
      debugPrint('[DEBT_REPO] WARN loading personal overdue debts: $e');
    }

    if (householdId != null && householdId.isNotEmpty) {
      try {
        final householdQuery = await _firestore
            .collection(_collection)
            .where('household_id', isEqualTo: householdId)
            .where('due_date', isLessThan: Timestamp.fromDate(now))
            .orderBy('due_date')
            .get();

        debts.addAll(
          householdQuery.docs.map((doc) => DebtModel.fromFirestore(doc)),
        );
      } catch (e) {
        debugPrint('[DEBT_REPO] WARN loading household overdue debts: $e');
      }
    }

    final overdue = debts
        .where((debt) => debt.remainingAmount > 0 && debt.isOverdue)
        .toList();
    debugPrint(
        '[DEBT_REPO] Overdue debts fetched: ${overdue.length} (user=$userId, household=$householdId)');
    return overdue;
  }
}
