import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';
import '../services/wallet_balance_service.dart';

class BillRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletBalanceService _balanceService;
  static const String _collection = 'bills';
  static const String _walletsCollection = 'wallets';

  BillRepository({WalletBalanceService? balanceService})
      : _balanceService = balanceService ?? WalletBalanceService();

  // Create bill
  Future<String> createBill(BillModel bill) async {
    final docRef = await _firestore.collection(_collection).add(bill.toFirestore());
    return docRef.id;
  }

  // Get bill by ID
  Future<BillModel?> getBillById(String billId) async {
    final doc = await _firestore.collection(_collection).doc(billId).get();
    if (!doc.exists) return null;
    return BillModel.fromFirestore(doc);
  }

  // Get personal bills for user
  Future<List<BillModel>> getPersonalBills(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('household_id', isNull: true)
        .orderBy('due_date')
        .get();

    return query.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
  }

  // Get household bills
  Future<List<BillModel>> getHouseholdBills(String householdId) async {
    final query = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .orderBy('due_date')
        .get();

    return query.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
  }

  // Get all bills for user
  Future<List<BillModel>> getAllBillsForUser(String userId, List<String> householdIds) async {
    final List<BillModel> allBills = [];

    // Get personal bills
    final personalBills = await getPersonalBills(userId);
    allBills.addAll(personalBills);

    // Get household bills
    for (var householdId in householdIds) {
      final householdBills = await getHouseholdBills(householdId);
      allBills.addAll(householdBills);
    }

    // Sort by due date
    allBills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return allBills;
  }

  // Get unpaid bills
  Future<List<BillModel>> getUnpaidBills({
    String? userId,
    String? householdId,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: BillStatus.unpaid.name);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.orderBy('due_date').get();
    return result.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
  }

  // Get overdue bills
  Future<List<BillModel>> getOverdueBills({
    String? userId,
    String? householdId,
  }) async {
    final unpaidBills = await getUnpaidBills(
      userId: userId,
      householdId: householdId,
    );

    return unpaidBills.where((bill) => bill.isOverdue).toList();
  }

  // Get upcoming bills (due within next N days)
  Future<List<BillModel>> getUpcomingBills({
    String? userId,
    String? householdId,
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    Query query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: BillStatus.unpaid.name)
        .where('due_date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('due_date', isLessThanOrEqualTo: Timestamp.fromDate(futureDate));

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.orderBy('due_date').get();
    return result.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
  }

  // Update bill
  Future<void> updateBill(BillModel bill) async {
    await _firestore
        .collection(_collection)
        .doc(bill.billId)
        .update(bill.toFirestore());
  }

  // Mark bill as paid
  // If recurring, generate the next bill instance
  Future<void> markBillAsPaid(String billId) async {
    final bill = await getBillById(billId);
    if (bill == null) return;

    await _firestore.collection(_collection).doc(billId).update({
      'status': BillStatus.paid.name,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // If recurring, create next bill instance
    if (bill.recurrence != BillRecurrence.none) {
      final nextDueDate = _calculateNextDueDate(bill.dueDate, bill.recurrence);
      if (nextDueDate != null) {
        final nextBill = bill.copyWith(
          billId: '', // Will be auto-generated
          dueDate: nextDueDate,
          status: BillStatus.unpaid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await createBill(nextBill);
      }
    }
  }

  DateTime? _calculateNextDueDate(DateTime currentDueDate, BillRecurrence recurrence) {
    switch (recurrence) {
      case BillRecurrence.monthly:
        return DateTime(
          currentDueDate.year,
          currentDueDate.month + 1,
          currentDueDate.day,
        );
      case BillRecurrence.yearly:
        return DateTime(
          currentDueDate.year + 1,
          currentDueDate.month,
          currentDueDate.day,
        );
      case BillRecurrence.none:
      case BillRecurrence.custom:
        return null; // Custom recurrence needs external handling
    }
  }

  // Legacy method for backward compatibility
  Future<void> markAsPaid(String billId) async {
    await markBillAsPaid(billId);
  }

  // Mark bill as unpaid
  Future<void> markAsUnpaid(String billId) async {
    await _firestore.collection(_collection).doc(billId).update({
      'status': BillStatus.unpaid.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete bill
  Future<void> deleteBill(String billId) async {
    await _firestore.collection(_collection).doc(billId).delete();
  }

  // Stream upcoming bills for household (for head)
  Stream<List<BillModel>> streamUpcomingBillsForHousehold({
    required String householdId,
    int daysAhead = 30,
  }) {
    if (householdId.isEmpty) {
      return Stream.value(const <BillModel>[]);
    }

    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('status', isEqualTo: BillStatus.unpaid.name)
        .where('due_date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('due_date', isLessThanOrEqualTo: Timestamp.fromDate(futureDate))
        .orderBy('due_date')
        .snapshots()
        .map((query) => query.docs.map((doc) => BillModel.fromFirestore(doc)).toList());
  }

  // Stream bills for responsible user (for members and head)
  Stream<List<BillModel>> streamBillsForResponsibleUser({
    required String userId,
    String? householdId,
  }) {
    if (userId.isEmpty) {
      return Stream.value(const <BillModel>[]);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('responsible_user_id', isEqualTo: userId);

    if (householdId != null && householdId.isNotEmpty) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    return query
        .orderBy('due_date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList());
  }

  // Stream bills
  Stream<List<BillModel>> streamBills({
    String? userId,
    String? householdId,
  }) {
    Query query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    return query.orderBy('due_date').snapshots().map(
          (query) => query.docs.map((doc) => BillModel.fromFirestore(doc)).toList(),
        );
  }

  // Stream all household bills (for head view)
  Stream<List<BillModel>> streamAllHouseholdBills(String householdId) {
    if (householdId.isEmpty) {
      return Stream.value(const <BillModel>[]);
    }

    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .orderBy('due_date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList());
  }

  // Get total unpaid amount
  Future<double> getTotalUnpaidAmount({
    String? userId,
    String? householdId,
  }) async {
    final unpaidBills = await getUnpaidBills(
      userId: userId,
      householdId: householdId,
    );

    return unpaidBills.fold<double>(0.0, (sum, bill) => sum + bill.amount);
  }

  // Get bills that should trigger reminders
  Future<List<BillModel>> getBillsNeedingReminders({
    String? userId,
    String? householdId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: BillStatus.unpaid.name);

    if (userId != null) {
      query = query.where('responsible_user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.orderBy('due_date').get();
    final bills = result.docs.map((doc) => BillModel.fromFirestore(doc)).toList();

    // Filter to only bills that should remind
    return bills.where((bill) => bill.shouldRemind).toList();
  }

  // Mark bill as paid manually (no wallet transaction)
  Future<void> markBillAsPaidManually({
    required String billId,
    required String userId,
  }) async {
    final bill = await getBillById(billId);
    if (bill == null) {
      throw Exception('Bill not found');
    }

    if (bill.status == BillStatus.paid) {
      throw Exception('Bill is already paid');
    }

    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final billRef = _firestore.collection(_collection).doc(billId);

      // Update bill status
      transaction.update(billRef, {
        'status': BillStatus.paid.name,
        'paid_by_user_id': userId,
        'paid_at': Timestamp.fromDate(now),
        'updated_at': FieldValue.serverTimestamp(),
        // Note: no wallet or transaction linkage for manual payment
      });

      // If recurring, create next occurrence
      if (bill.recurrence != BillRecurrence.none) {
        final nextDueDate = _calculateNextDueDate(bill.dueDate, bill.recurrence);
        if (nextDueDate != null) {
          final nextBillData = bill.copyWith(
            billId: '', // Will be auto-generated
            dueDate: nextDueDate,
            status: BillStatus.unpaid,
            createdAt: now,
            updatedAt: now,
            paidByUserId: null,
            paidFromWalletId: null,
            linkedTransactionId: null,
            paidAt: null,
          ).toFirestore();

          final nextBillRef = _firestore.collection(_collection).doc();
          transaction.set(nextBillRef, nextBillData);
        }
      }
    });
  }

  // Pay bill with wallet - creates transaction and updates wallet balance
  Future<void> payBillWithWallet({
    required String billId,
    required String householdId,
    required String walletId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
    String? categoryId,
  }) async {
    // First, fetch bill and wallet to validate
    final billDoc = await _firestore.collection(_collection).doc(billId).get();
    if (!billDoc.exists) {
      throw Exception('Bill not found');
    }
    final bill = BillModel.fromFirestore(billDoc);

    // Validate bill is not already paid
    if (bill.status == BillStatus.paid) {
      throw Exception('Bill is already paid');
    }

    // Validate bill belongs to same household
    if (bill.householdId != householdId) {
      throw Exception('Bill does not belong to this household');
    }

    // Fetch wallet to validate household
    final walletDoc = await _firestore.collection(_walletsCollection).doc(walletId).get();
    if (!walletDoc.exists) {
      throw Exception('Wallet not found');
    }
    final walletData = walletDoc.data()!;
    final walletHouseholdId = walletData['household_id'] as String?;
    if (walletHouseholdId != householdId) {
      throw Exception('Wallet does not belong to this household');
    }

    final now = DateTime.now();
    final billRef = _firestore.collection(_collection).doc(billId);

    // Use WalletBalanceService to handle the transaction with additional operations
    await _balanceService.applyExpenseTransaction(
      walletId: walletId,
      amount: bill.amount,
      currency: bill.currency,
      userId: actorUserId,
      householdId: householdId,
      categoryId: categoryId ?? 'bills',
      note: 'Bill payment: ${bill.name}',
      date: now,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      actorRole: actorRole,
      additionalOperations: (txn, transactionId) async {
        // Update bill status and payment info
        txn.update(billRef, {
          'status': BillStatus.paid.name,
          'paid_by_user_id': actorUserId,
          'paid_from_wallet_id': walletId,
          'linked_transaction_id': transactionId,
          'paid_at': Timestamp.fromDate(now),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // If bill is recurring, create next occurrence
        if (bill.recurrence != BillRecurrence.none) {
          final nextDueDate = _calculateNextDueDate(bill.dueDate, bill.recurrence);
          if (nextDueDate != null) {
            final nextBillData = bill.copyWith(
              billId: '', // Will be auto-generated
              dueDate: nextDueDate,
              status: BillStatus.unpaid,
              createdAt: now,
              updatedAt: now,
              paidByUserId: null,
              paidFromWalletId: null,
              linkedTransactionId: null,
              paidAt: null,
            ).toFirestore();

            final nextBillRef = _firestore.collection(_collection).doc();
            txn.set(nextBillRef, nextBillData);
          }
        }
      },
    );
  }
}
