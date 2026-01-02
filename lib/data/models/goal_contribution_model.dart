import 'package:cloud_firestore/cloud_firestore.dart';

class GoalContributionModel {
  final String id;
  final double amount;
  final String walletId;
  final String walletScope; // "household" or "personal"
  final String userId;
  final String userDisplayName;
  final String userRole; // "head" or "member"
  final DateTime createdAt;

  const GoalContributionModel({
    required this.id,
    required this.amount,
    required this.walletId,
    required this.walletScope,
    required this.userId,
    required this.userDisplayName,
    required this.userRole,
    required this.createdAt,
  });

  factory GoalContributionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalContributionModel(
      id: doc.id,
      amount: (data['amount'] ?? 0.0).toDouble(),
      walletId: data['wallet_id'] ?? '',
      walletScope: data['wallet_scope'] ?? 'personal',
      userId: data['user_id'] ?? '',
      userDisplayName: data['user_display_name'] ?? '',
      userRole: data['user_role'] ?? 'member',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'wallet_id': walletId,
      'wallet_scope': walletScope,
      'user_id': userId,
      'user_display_name': userDisplayName,
      'user_role': userRole,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  GoalContributionModel copyWith({
    String? id,
    double? amount,
    String? walletId,
    String? walletScope,
    String? userId,
    String? userDisplayName,
    String? userRole,
    DateTime? createdAt,
  }) {
    return GoalContributionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      walletId: walletId ?? this.walletId,
      walletScope: walletScope ?? this.walletScope,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userRole: userRole ?? this.userRole,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
