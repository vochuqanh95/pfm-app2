import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoles {
  static const head = 'head';
  static const member = 'member';
}

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String currency;
  final String language;
  final String role;
  final String? householdId;
  final bool twoFactorEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.currency = 'USD',
    this.language = 'en',
    this.role = UserRoles.member,
    this.householdId,
    this.twoFactorEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isHead => role == UserRoles.head;
  bool get isMember => role == UserRoles.member;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Timestamp? createdTimestamp;
    Timestamp? updatedTimestamp;

    final createdValue = data['createdAt'] ?? data['created_at'];
    final updatedValue = data['updatedAt'] ?? data['updated_at'];

    if (createdValue is Timestamp) {
      createdTimestamp = createdValue;
    }
    if (updatedValue is Timestamp) {
      updatedTimestamp = updatedValue;
    }

    return UserModel(
      userId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      currency: data['currency'] ?? 'USD',
      language: data['language'] ?? 'en',
      role: data['role'] ?? UserRoles.member,
      householdId: (data['householdId'] ?? data['household_id']) as String?,
      twoFactorEnabled: (data['twoFactorEnabled'] ?? data['two_factor_enabled']) as bool? ?? false,
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      updatedAt: updatedTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final createdTimestamp = Timestamp.fromDate(createdAt);
    final updatedTimestamp = Timestamp.fromDate(updatedAt);
    return {
      'name': name,
      'email': email,
      'currency': currency,
      'language': language,
      'role': role,
      'householdId': householdId,
      'household_id': householdId,
      'twoFactorEnabled': twoFactorEnabled,
      'two_factor_enabled': twoFactorEnabled,
      'createdAt': createdTimestamp,
      'updatedAt': updatedTimestamp,
      'created_at': createdTimestamp,
      'updated_at': updatedTimestamp,
    };
  }

  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? currency,
    String? language,
    String? role,
    String? householdId,
    bool? twoFactorEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      role: role ?? this.role,
      householdId: householdId ?? this.householdId,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
