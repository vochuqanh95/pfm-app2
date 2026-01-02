import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum DebtType {
  owedToMe,
  iOwe
} // owedToMe = someone owes me, iOwe = I owe someone

enum DebtStatus { active, paid, overdue }

class DebtModel {
  final String debtId;
  final String? userId;
  final String? householdId;
  final String name;
  final double amount;
  final double interestRate;
  final DateTime? dueDate;
  final String? creditorDebtor; // Name of person/entity
  final DebtType? type; // Type of debt
  final double? paidAmount; // Amount already paid
  final DateTime createdAt;

  DebtModel({
    required this.debtId,
    this.userId,
    this.householdId,
    required this.name,
    required this.amount,
    this.interestRate = 0.0,
    this.dueDate,
    this.creditorDebtor,
    this.type,
    this.paidAmount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isShared => householdId != null;

  // Helper properties for screens
  String get id => debtId; // Alias for debtId
  double get totalAmount => amount; // Total amount of debt
  double get paidAmountValue => paidAmount ?? 0;
  double get remainingAmount {
    final remaining = amount - paidAmountValue;
    return remaining < 0
        ? 0
        : remaining; // Clamp to zero to avoid negative net worth
  }

  double get paidProgress =>
      amount > 0 ? (paidAmountValue / amount).clamp(0, 1) : 0;

  bool get isPaid => remainingAmount <= 0.01;

  bool get isOverdue {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return remainingAmount > 0 &&
        !isPaid &&
        dueDate!.isBefore(DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1)));
  }

  bool get isDueSoon {
    if (dueDate == null || isPaid || isOverdue) return false;
    final now = DateTime.now();
    final days = dueDate!.difference(now).inDays;
    return days >= 0 && days <= 7;
  }

  DebtStatus get status {
    if (isPaid) return DebtStatus.paid;
    if (isOverdue) return DebtStatus.overdue;
    return DebtStatus.active;
  }

  double get simpleInterestEstimate {
    if (interestRate <= 0 || remainingAmount <= 0) return 0;
    final now = DateTime.now();
    final start = createdAt.isAfter(now) ? now : createdAt;
    final daysElapsed = now.difference(start).inDays;
    if (daysElapsed <= 0) return 0;
    final yearlyRate = interestRate / 100;
    return remainingAmount * yearlyRate * (daysElapsed / 365);
  }

  double get totalDueEstimate => remainingAmount + simpleInterestEstimate;

  String? get description =>
      name.isNotEmpty ? name : null; // Map name to description

  factory DebtModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawInterest = data['interest_rate'] ?? data['interestRate'] ?? 0.0;
    final parsedInterest = (rawInterest is num)
        ? rawInterest.toDouble()
        : double.tryParse(rawInterest.toString()) ?? 0.0;
    debugPrint(
        '[DEBT_DEBUG] fromFirestore interestRate=$parsedInterest raw=$rawInterest doc=${doc.id}');
    return DebtModel(
      debtId: doc.id,
      userId: data['user_id'],
      householdId: data['household_id'],
      name: data['name'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      interestRate: parsedInterest,
      dueDate: (data['due_date'] as Timestamp?)?.toDate(),
      creditorDebtor: data['creditor_debtor'],
      type: data['type'] != null
          ? DebtType.values.firstWhere(
              (e) => e.name == data['type'],
              orElse: () => DebtType.iOwe,
            )
          : null,
      paidAmount: (data['paid_amount'] ?? 0.0).toDouble(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'user_id': userId,
      'household_id': householdId,
      'name': name,
      'amount': amount,
      'interest_rate': interestRate,
      'interestRate': interestRate,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'creditor_debtor': creditorDebtor,
      'type': type?.name,
      'paid_amount': paidAmount,
      'created_at': Timestamp.fromDate(createdAt),
    };
    debugPrint('[DEBT_DEBUG] toFirestore interestRate=$interestRate');
    return map;
  }

  DebtModel copyWith({
    String? debtId,
    String? userId,
    String? householdId,
    String? name,
    double? amount,
    double? interestRate,
    DateTime? dueDate,
    String? creditorDebtor,
    DebtType? type,
    double? paidAmount,
    DateTime? createdAt,
  }) {
    return DebtModel(
      debtId: debtId ?? this.debtId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
      creditorDebtor: creditorDebtor ?? this.creditorDebtor,
      type: type ?? this.type,
      paidAmount: paidAmount ?? this.paidAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
