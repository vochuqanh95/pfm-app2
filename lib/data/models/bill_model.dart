import 'package:cloud_firestore/cloud_firestore.dart';

enum BillStatus { unpaid, paid, overdue }

enum BillRecurrence { none, monthly, yearly, custom }

class BillModel {
  final String billId;
  final String? userId;
  final String? householdId;
  final String name;
  final double amount;
  final String currency;
  final DateTime dueDate;
  final BillStatus status;
  final String? recurringRuleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields for extended functionality
  final String scope; // 'family' or 'personal'
  final String? createdByUserId; // Who created this bill
  final String? responsibleUserId; // Who should pay/be notified
  final BillRecurrence recurrence; // How often this bill recurs
  final int remindDaysBefore; // Days before due date to send reminder

  // Payment tracking fields
  final String? paidByUserId; // Who paid this bill
  final String? paidFromWalletId; // Which wallet was used to pay
  final String? linkedTransactionId; // Transaction created when bill was paid
  final DateTime? paidAt; // When the bill was paid

  BillModel({
    required this.billId,
    this.userId,
    this.householdId,
    required this.name,
    required this.amount,
    this.currency = 'USD',
    required this.dueDate,
    this.status = BillStatus.unpaid,
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.scope = 'personal',
    this.createdByUserId,
    this.responsibleUserId,
    this.recurrence = BillRecurrence.none,
    this.remindDaysBefore = 3,
    this.paidByUserId,
    this.paidFromWalletId,
    this.linkedTransactionId,
    this.paidAt,
  });

  bool get isShared => householdId != null && scope == 'family';
  bool get isOverdue => status == BillStatus.unpaid && dueDate.isBefore(DateTime.now());
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
  bool get shouldRemind {
    if (status == BillStatus.paid) return false;
    final reminderDate = dueDate.subtract(Duration(days: remindDaysBefore));
    final now = DateTime.now();
    return now.isAfter(reminderDate) && now.isBefore(dueDate);
  }

  // Helper properties for screens
  bool get isPaid => status == BillStatus.paid;
  String get id => billId;
  bool get isRecurring => recurrence != BillRecurrence.none || recurringRuleId != null;

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse status
    final statusStr = data['status'] as String?;
    BillStatus billStatus = BillStatus.unpaid;
    if (statusStr != null) {
      billStatus = BillStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => BillStatus.unpaid,
      );
    }

    // Parse recurrence
    final recurrenceStr = data['recurrence'] as String?;
    BillRecurrence billRecurrence = BillRecurrence.none;
    if (recurrenceStr != null) {
      billRecurrence = BillRecurrence.values.firstWhere(
        (e) => e.name == recurrenceStr,
        orElse: () => BillRecurrence.none,
      );
    }

    return BillModel(
      billId: doc.id,
      userId: data['user_id'],
      householdId: data['household_id'],
      name: data['name'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'USD',
      dueDate: (data['due_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: billStatus,
      recurringRuleId: data['recurring_rule_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scope: data['scope'] ?? 'personal',
      createdByUserId: data['created_by_user_id'],
      responsibleUserId: data['responsible_user_id'],
      recurrence: billRecurrence,
      remindDaysBefore: data['remind_days_before'] ?? 3,
      paidByUserId: data['paid_by_user_id'],
      paidFromWalletId: data['paid_from_wallet_id'],
      linkedTransactionId: data['linked_transaction_id'],
      paidAt: (data['paid_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'household_id': householdId,
      'name': name,
      'amount': amount,
      'currency': currency,
      'due_date': Timestamp.fromDate(dueDate),
      'status': status.name,
      'recurring_rule_id': recurringRuleId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'scope': scope,
      'created_by_user_id': createdByUserId,
      'responsible_user_id': responsibleUserId,
      'recurrence': recurrence.name,
      'remind_days_before': remindDaysBefore,
      'paid_by_user_id': paidByUserId,
      'paid_from_wallet_id': paidFromWalletId,
      'linked_transaction_id': linkedTransactionId,
      'paid_at': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }

  BillModel copyWith({
    String? billId,
    String? userId,
    String? householdId,
    String? name,
    double? amount,
    String? currency,
    DateTime? dueDate,
    BillStatus? status,
    String? recurringRuleId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? scope,
    String? createdByUserId,
    String? responsibleUserId,
    BillRecurrence? recurrence,
    int? remindDaysBefore,
    String? paidByUserId,
    String? paidFromWalletId,
    String? linkedTransactionId,
    DateTime? paidAt,
  }) {
    return BillModel(
      billId: billId ?? this.billId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scope: scope ?? this.scope,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      responsibleUserId: responsibleUserId ?? this.responsibleUserId,
      recurrence: recurrence ?? this.recurrence,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidFromWalletId: paidFromWalletId ?? this.paidFromWalletId,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
