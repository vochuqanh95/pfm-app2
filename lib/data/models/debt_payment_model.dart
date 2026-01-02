import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for debt payment records
/// Stored in subcollection: debts/{debtId}/payments/{paymentId}
class DebtPaymentModel {
  final String paymentId;
  final String debtId;
  final String userId;
  final String? walletId; // Nullable - payment may not be from a wallet
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  DebtPaymentModel({
    required this.paymentId,
    required this.debtId,
    required this.userId,
    this.walletId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory DebtPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebtPaymentModel(
      paymentId: doc.id,
      debtId: data['debt_id'] ?? '',
      userId: data['user_id'] ?? '',
      walletId: data['wallet_id'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'debt_id': debtId,
      'user_id': userId,
      'wallet_id': walletId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Copy with method
  DebtPaymentModel copyWith({
    String? paymentId,
    String? debtId,
    String? userId,
    String? walletId,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return DebtPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      debtId: debtId ?? this.debtId,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
