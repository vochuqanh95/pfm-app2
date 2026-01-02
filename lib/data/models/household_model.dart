import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdModel {
  final String householdId;
  final String ownerUserId;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  HouseholdModel({
    required this.householdId,
    required this.ownerUserId,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HouseholdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseholdModel(
      householdId: doc.id,
      ownerUserId: data['owner_user_id'] ?? '',
      name: data['name'] ?? '',
      inviteCode: data['invite_code'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'owner_user_id': ownerUserId,
      'name': name,
      'invite_code': inviteCode,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  HouseholdModel copyWith({
    String? householdId,
    String? ownerUserId,
    String? name,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HouseholdModel(
      householdId: householdId ?? this.householdId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
