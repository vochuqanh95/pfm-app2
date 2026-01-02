import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberRole { owner, member }

class MemberStatus {
  static const active = 'active';
  static const invited = 'invited';
  static const removed = 'removed';
}

class HouseholdMemberModel {
  final String id;
  final String householdId;
  final String userId;
  final MemberRole role;
  final String status;
  final DateTime joinedAt;

  const HouseholdMemberModel({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    this.status = MemberStatus.active,
    required this.joinedAt,
  });

  factory HouseholdMemberModel.fromDocument(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return HouseholdMemberModel(
      id: doc.id,
      householdId: data['household_id'] ?? '',
      userId: data['user_id'] ?? '',
      role: MemberRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => MemberRole.member,
      ),
      status: (data['status'] ?? MemberStatus.active) as String,
      joinedAt: (data['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'household_id': householdId,
      'user_id': userId,
      'role': role.name,
      'status': status,
      'joined_at': Timestamp.fromDate(joinedAt),
    };
  }

  HouseholdMemberModel copyWith({
    String? id,
    String? householdId,
    String? userId,
    MemberRole? role,
    String? status,
    DateTime? joinedAt,
  }) {
    return HouseholdMemberModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  static String docId(String householdId, String userId) => '${householdId}_$userId';
}
