import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String goalId;
  final String? userId;
  final String? householdId;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String scope;
  final String? assignedUserDisplayName;

  GoalModel({
    required this.goalId,
    this.userId,
    this.householdId,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.deadline,
    this.scope = 'personal',
    required this.createdAt,
    required this.updatedAt,
    this.assignedUserDisplayName,
  });

  bool get isShared => householdId != null;
  double get progress => targetAmount > 0 ? (savedAmount / targetAmount) * 100 : 0;
  bool get isCompleted => savedAmount >= targetAmount;

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalModel(
      goalId: doc.id,
      userId: data['user_id'],
      householdId: data['household_id'],
      name: data['name'] ?? '',
      targetAmount: (data['target_amount'] ?? 0.0).toDouble(),
      savedAmount: (data['saved_amount'] ?? 0.0).toDouble(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scope: data['scope'] ?? (data['household_id'] != null ? 'family' : 'personal'),
      assignedUserDisplayName: data['assigned_user_display_name'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'household_id': householdId,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'scope': scope,
      'assigned_user_display_name': assignedUserDisplayName,
    };
  }

  GoalModel copyWith({
    String? goalId,
    String? userId,
    String? householdId,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? scope,
    String? assignedUserDisplayName,
  }) {
    return GoalModel(
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scope: scope ?? this.scope,
      assignedUserDisplayName: assignedUserDisplayName ?? this.assignedUserDisplayName,
    );
  }
}
