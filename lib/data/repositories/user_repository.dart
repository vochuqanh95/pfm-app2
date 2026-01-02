import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../core/models/app_settings.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'users';

  // Create user
  Future<void> createUser(UserModel user) async {
    await _firestore.collection(_collection).doc(user.userId).set(user.toFirestore());
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection(_collection).doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // Alias for getUserById
  Future<UserModel?> getUser(String userId) => getUserById(userId);

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    final query = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return UserModel.fromFirestore(query.docs.first);
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    await _firestore.collection(_collection).doc(user.userId).update(user.toFirestore());
  }

  // Ensure user document exists or create it
  Future<UserModel> ensureUserDocument({
    required String userId,
    required String name,
    required String email,
    String role = UserRoles.member,
  }) async {
    final normalizedName = name.trim().isEmpty ? 'Member' : name.trim();
    final normalizedEmail = email.trim();

    final doc = await _firestore.collection(_collection).doc(userId).get();
    if (doc.exists) {
      final existingUser = UserModel.fromFirestore(doc);
      final existingName = existingUser.name.trim();

      // Update if existing name is generic/fallback and we have a proper name
      final isGenericName = existingName.isEmpty ||
                           existingName == 'Member' ||
                           existingName == 'Household Member' ||
                           existingName == 'Household Owner' ||
                           existingName == 'User' ||
                           existingName.contains('@'); // Email addresses are also generic

      if (isGenericName && normalizedName != 'Member' && !normalizedName.contains('@')) {
        // Update the document with the proper name
        final updatedUser = existingUser.copyWith(
          name: normalizedName,
          email: normalizedEmail.isNotEmpty ? normalizedEmail : existingUser.email,
          updatedAt: DateTime.now(),
        );
        await updateUser(updatedUser);
        return updatedUser;
      }

      return existingUser;
    }

    final now = DateTime.now();
    final newUser = UserModel(
      userId: userId,
      name: normalizedName,
      email: normalizedEmail,
      role: role,
      createdAt: now,
      updatedAt: now,
    );

    await createUser(newUser);
    return newUser;
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection(_collection).doc(userId).delete();
  }

  // Get user stream (real-time updates)
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection(_collection).doc(userId).snapshots().map(
      (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
    );
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    required String userId,
    String? currency,
    String? language,
  }) async {
    final Map<String, dynamic> updates = {};
    if (currency != null) updates['currency'] = currency;
    if (language != null) updates['language'] = language;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    updates['updated_at'] = FieldValue.serverTimestamp();

    await _firestore.collection(_collection).doc(userId).update(updates);
  }

  Future<void> updateUserHousehold({
    required String userId,
    String? householdId,
  }) async {
    await _firestore.collection(_collection).doc(userId).update({
      'householdId': householdId,
      'household_id': householdId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserRoleAndHousehold({
    required String userId,
    String? role,
    String? householdId,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (role != null) {
      updates['role'] = role;
    }
    if (householdId != null) {
      updates['householdId'] = householdId;
      updates['household_id'] = householdId;
    }
    await _firestore.collection(_collection).doc(userId).update(updates);
  }

  // Update two-factor authentication status
  Future<void> updateTwoFactorEnabled({
    required String userId,
    required bool enabled,
  }) async {
    await _firestore.collection(_collection).doc(userId).update({
      'twoFactorEnabled': enabled,
      'two_factor_enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<AppSettings> loadAppSettings(String userId) async {
    final doc = await _firestore.collection(_collection).doc(userId).get();
    if (!doc.exists) {
      return const AppSettings();
    }
    final data = doc.data() ?? {};
    final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};
    final legacyLanguage = data['language'] as String?;
    final legacyCurrency = data['currency'] as String?;

    final merged = {
      'language': prefs['language'] ?? legacyLanguage,
      'currency': prefs['currency'] ?? legacyCurrency,
    };
    final settings = AppSettings.fromJson(merged);
    debugPrint('[SETTINGS_REPO] loadAppSettings for user=$userId => ${settings.toJson()}');
    return settings;
  }

  Future<void> updateAppSettings(String userId, AppSettings settings) async {
    debugPrint('[SETTINGS_REPO] updateAppSettings for user=$userId => ${settings.toJson()}');
    await _firestore.collection(_collection).doc(userId).set({
      'preferences': settings.toJson(),
      // Keep legacy fields in sync for backward compatibility
      'language': settings.language.code,
      'currency': settings.currency.code,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
