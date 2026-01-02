import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/household_model.dart';
import '../models/household_member_model.dart';
import 'wallet_repository.dart';

class HouseholdJoinFailure implements Exception {
  final String code;
  final String message;

  HouseholdJoinFailure(this.code, this.message);

  @override
  String toString() => message;
}

class HouseholdRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletRepository _walletRepository = WalletRepository();
  static const String _householdsCollection = 'households';
  static const String _membersCollection = 'household_members';
  static final RegExp _invitePattern = RegExp(r'^[A-Z0-9]{6,8}$');

  DocumentReference<Map<String, dynamic>> _householdDoc(String householdId) {
    return _firestore.collection(_householdsCollection).doc(householdId);
  }

  DocumentReference<Map<String, dynamic>> _memberDoc(
      String householdId, String userId) {
    final docId = '${householdId}_$userId';
    return _firestore.collection(_membersCollection).doc(docId);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  bool _isValidInviteCode(String code) => _invitePattern.hasMatch(code);

  Future<String> _createUniqueInviteCode() async {
    while (true) {
      final code = _generateInviteCode();
      final exists = await _firestore
          .collection(_householdsCollection)
          .where('invite_code', isEqualTo: code)
          .limit(1)
          .get();
      if (exists.docs.isEmpty) {
        return code;
      }
    }
  }

  Future<String> _ensureInviteCode(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final currentCode = (doc.data()?['invite_code'] ?? '').toString().trim();
    if (_isValidInviteCode(currentCode)) {
      return currentCode;
    }

    final newCode = await _createUniqueInviteCode();
    await doc.reference.update({
      'invite_code': newCode,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return newCode;
  }

  Future<HouseholdModel> _buildHouseholdModel(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final base = HouseholdModel.fromFirestore(doc);
    final inviteCode = await _ensureInviteCode(doc);
    if (inviteCode == base.inviteCode) {
      return base;
    }
    return base.copyWith(inviteCode: inviteCode);
  }

  Future<HouseholdModel> createHouseholdWithOwner({
    required String ownerUserId,
    required String name,
  }) async {
    final inviteCode = await _createUniqueInviteCode();
    final now = DateTime.now();
    final docRef = _firestore.collection(_householdsCollection).doc();
    final household = HouseholdModel(
      householdId: docRef.id,
      ownerUserId: ownerUserId,
      name: name,
      inviteCode: inviteCode,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(household.toFirestore());
    final ownerMember = HouseholdMemberModel(
      id: HouseholdMemberModel.docId(household.householdId, ownerUserId),
      householdId: household.householdId,
      userId: ownerUserId,
      role: MemberRole.owner,
      joinedAt: now,
    );
    await _memberDoc(household.householdId, ownerUserId)
        .set(ownerMember.toFirestore());
    await _createDefaultHouseholdWallet(
      householdId: household.householdId,
      ownerUserId: ownerUserId,
      createdAt: now,
    );

    return household;
  }

  Future<HouseholdModel?> findHouseholdByInviteCode(String inviteCode) async {
    debugPrint(
        '[HOUSEHOLD][JOIN] Looking up household with invite_code=$inviteCode');
    try {
      final query = await _firestore
          .collection(_householdsCollection)
          .where('invite_code', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        debugPrint(
            '[HOUSEHOLD][JOIN] No household found with invite_code=$inviteCode');
        return null;
      }
      final household = await _buildHouseholdModel(query.docs.first);
      debugPrint(
          '[HOUSEHOLD][JOIN] Found household: id=${household.householdId}, name=${household.name}');
      return household;
    } catch (e) {
      debugPrint(
          '[HOUSEHOLD][JOIN] ERROR finding household by invite_code: $e');
      rethrow;
    }
  }

  Future<HouseholdModel?> getHouseholdById(String householdId) async {
    final doc = await _householdDoc(householdId).get();
    if (!doc.exists) return null;
    return _buildHouseholdModel(doc);
  }

  Stream<HouseholdModel?> watchHousehold(String householdId) {
    return _householdDoc(householdId).snapshots().asyncMap(
          (doc) => doc.exists ? _buildHouseholdModel(doc) : Future.value(null),
        );
  }

  Future<List<HouseholdModel>> getHouseholdsForUser(String userId) async {
    final query = await _firestore
        .collection(_householdsCollection)
        .where('owner_user_id', isEqualTo: userId)
        .get();
    return Future.wait(query.docs.map(_buildHouseholdModel));
  }

  Future<void> updateHousehold(HouseholdModel household) async {
    await _householdDoc(household.householdId).update(household.toFirestore());
  }

  Future<void> deleteHousehold(String householdId) async {
    await _householdDoc(householdId).delete();
  }

  Future<void> upsertMember(HouseholdMemberModel member) async {
    await _memberDoc(member.householdId, member.userId)
        .set(member.toFirestore());
  }

  Future<void> removeMember(String householdId, String userId) async {
    // Delete the member document
    await _memberDoc(householdId, userId).delete();
  }

  Future<void> approveMember({
    required String householdId,
    required String userId,
  }) async {
    await _memberDoc(householdId, userId).update({
      'status': MemberStatus.active,
      'joined_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectMember({
    required String householdId,
    required String userId,
  }) async {
    // Delete the member document to reject the invite
    await _memberDoc(householdId, userId).delete();
  }

  Future<List<HouseholdMemberModel>> getHouseholdMembers(
      String householdId) async {
    final query = await _firestore
        .collection(_membersCollection)
        .where('household_id', isEqualTo: householdId)
        .get();
    return query.docs
        .map(HouseholdMemberModel.fromDocument)
        .where((member) => member.status == MemberStatus.active)
        .toList();
  }

  Future<List<HouseholdMemberModel>> getAllHouseholdMembers(
      String householdId) async {
    final query = await _firestore
        .collection(_membersCollection)
        .where('household_id', isEqualTo: householdId)
        .get();
    return query.docs
        .map(HouseholdMemberModel.fromDocument)
        .where((member) => member.status != MemberStatus.removed)
        .toList();
  }

  Future<MemberRole?> getMemberRole(String householdId, String userId) async {
    final doc = await _memberDoc(householdId, userId).get();
    if (!doc.exists) return null;
    return HouseholdMemberModel.fromDocument(doc).role;
  }

  Future<bool> isHouseholdOwner(String householdId, String userId) async {
    final role = await getMemberRole(householdId, userId);
    return role == MemberRole.owner;
  }

  Future<List<HouseholdModel>> getAllUserHouseholds(String userId) async {
    final memberQuery = await _firestore
        .collection(_membersCollection)
        .where('user_id', isEqualTo: userId)
        .get();
    final householdIds = memberQuery.docs
        .map(HouseholdMemberModel.fromDocument)
        .where((member) => member.status == MemberStatus.active)
        .map((member) => member.householdId)
        .toSet();
    if (householdIds.isEmpty) return [];

    final result = <HouseholdModel>[];
    for (final id in householdIds) {
      final household = await getHouseholdById(id);
      if (household != null) {
        result.add(household);
      }
    }
    return result;
  }

  Stream<List<HouseholdMemberModel>> streamHouseholdMembers(
      String householdId) {
    debugPrint(
        '[HOUSEHOLD][MEMBERS] Streaming active members for household=$householdId');
    return _firestore
        .collection(_membersCollection)
        .where('household_id', isEqualTo: householdId)
        .snapshots()
        .map(
      (query) {
        final members = query.docs
            .map(HouseholdMemberModel.fromDocument)
            .where((member) => member.status == MemberStatus.active)
            .toList();
        debugPrint(
            '[HOUSEHOLD][MEMBERS] Loaded ${members.length} active members for household=$householdId');
        return members;
      },
    );
  }

  Stream<List<HouseholdMemberModel>> streamAllHouseholdMembers(
      String householdId) {
    debugPrint(
        '[HOUSEHOLD][MEMBERS] Streaming ALL members (including pending) for household=$householdId');
    return _firestore
        .collection(_membersCollection)
        .where('household_id', isEqualTo: householdId)
        .snapshots()
        .map(
      (query) {
        final members = query.docs
            .map(HouseholdMemberModel.fromDocument)
            .where((member) => member.status != MemberStatus.removed)
            .toList();
        debugPrint(
            '[HOUSEHOLD][MEMBERS] Loaded ${members.length} total members (excluding removed) for household=$householdId');
        return members;
      },
    );
  }

  Future<void> _createDefaultHouseholdWallet({
    required String householdId,
    required String ownerUserId,
    required DateTime createdAt,
  }) async {
    await _walletRepository.createHouseholdSharedWallet(
      householdId: householdId,
      ownerUserId: ownerUserId,
      name: 'Family Main Wallet',
      currency: 'USD',
    );
  }

  Future<HouseholdModel> joinHousehold({
    required String inviteCode,
    required String userId,
  }) async {
    debugPrint(
        '[HOUSEHOLD_REPO] joinHousehold - userId: $userId, inviteCode: $inviteCode');

    // 1. Look up household by invite code
    final household = await findHouseholdByInviteCode(inviteCode);
    if (household == null) {
      debugPrint('[HOUSEHOLD_REPO] joinHousehold - Invalid invite code');
      throw HouseholdJoinFailure(
        'invalid_invite',
        'Invalid invite code. Please check and try again.',
      );
    }
    debugPrint(
        '[HOUSEHOLD_REPO] joinHousehold - Found household: ${household.householdId}');

    // 2. Check if user is already a member (direct doc get - rules allow self-read)
    final memberDocId =
        HouseholdMemberModel.docId(household.householdId, userId);
    debugPrint(
        '[HOUSEHOLD][JOIN] Checking existing membership docId=$memberDocId');
    final existingMemberDoc =
        await _memberDoc(household.householdId, userId).get();
    if (existingMemberDoc.exists) {
      final existingMember =
          HouseholdMemberModel.fromDocument(existingMemberDoc);
      if (existingMember.status == MemberStatus.active) {
        debugPrint('[HOUSEHOLD_REPO] joinHousehold - User already a member');
        throw HouseholdJoinFailure(
          'already_member',
          'You are already a member of this household.',
        );
      }
    }

    // 3. SKIP member count check for join flow
    // Note: New users can't query members list (not authorized yet).
    // The 7-member limit will be enforced by household heads when they manage members.
    // If we need strict enforcement, this should be done via a Cloud Function or
    // by allowing the create to happen and letting rules validate on server side.
    debugPrint(
        '[HOUSEHOLD][JOIN] Skipping member count check (new user not authorized to list members)');

    // Alternative: Try to count but handle permission denial gracefully
    // This is commented out because rules don't allow non-members to list members
    /*
    try {
      final membersQuery = await _firestore
          .collection(_membersCollection)
          .where('household_id', isEqualTo: household.householdId)
          .where('status', isEqualTo: MemberStatus.active)
          .get();
      final activeMemberCount = membersQuery.docs.length;
      debugPrint('[HOUSEHOLD_REPO] joinHousehold - Active members: $activeMemberCount');
      if (activeMemberCount >= 7) {
        throw HouseholdJoinFailure(
          'household_full',
          'This household already has the maximum number of members (7).',
        );
      }
    } catch (e) {
      debugPrint('[HOUSEHOLD][JOIN] Could not verify member count (expected for new users): $e');
      // Continue with join - validation will happen at create time if rules enforce it
    }
    */

    // 4. Create/update household member document
    final now = DateTime.now();
    final newMember = HouseholdMemberModel(
      id: HouseholdMemberModel.docId(household.householdId, userId),
      householdId: household.householdId,
      userId: userId,
      role: MemberRole.member,
      status: MemberStatus.active,
      joinedAt: now,
    );

    debugPrint(
        '[HOUSEHOLD_REPO] joinHousehold - Creating member document: ${newMember.id}');
    try {
      await _memberDoc(household.householdId, userId)
          .set(newMember.toFirestore());
      debugPrint(
          '[HOUSEHOLD_REPO] joinHousehold - Successfully joined household');
    } catch (e) {
      debugPrint(
          '[HOUSEHOLD_REPO] joinHousehold - Failed to create member: $e');
      rethrow;
    }

    return household;
  }
}
