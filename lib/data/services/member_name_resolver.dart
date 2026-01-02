import 'package:flutter/foundation.dart';
import '../models/household_member_model.dart';
import '../models/user_model.dart';
import '../repositories/household_repository.dart';
import '../repositories/user_repository.dart';

/// Helper to resolve a member's display name using the same data source
/// as household member pickers (users + household_members).
class MemberNameResolver {
  final HouseholdRepository _householdRepository;
  final UserRepository _userRepository;

  MemberNameResolver({
    HouseholdRepository? householdRepository,
    UserRepository? userRepository,
  })  : _householdRepository = householdRepository ?? HouseholdRepository(),
        _userRepository = userRepository ?? UserRepository();

  Future<String?> resolveMemberName({
    required String householdId,
    required String memberUserId,
  }) async {
    try {
      final members = await _householdRepository.getHouseholdMembers(householdId);
      HouseholdMemberModel? membership;
      for (final member in members) {
        if (member.userId == memberUserId) {
          membership = member;
          break;
        }
      }

      final user = await _userRepository.getUserById(memberUserId);
      final name = _buildDisplayName(
        user: user,
        membership: membership,
        fallbackUserId: memberUserId,
      );
      debugPrint(
          '[BUDGET_NAME] resolveMemberName household=$householdId member_user_id=$memberUserId resolved=$name');
      return name;
    } catch (e) {
      debugPrint(
          '[BUDGET_NAME] resolveMemberName FAILED household=$householdId member_user_id=$memberUserId error=$e');
      return null;
    }
  }

  String? _buildDisplayName({
    required UserModel? user,
    required HouseholdMemberModel? membership,
    required String fallbackUserId,
  }) {
    final rawName = (user?.name ?? '').trim();
    final invalidNames = {
      '',
      'Member',
      'Household Member',
      'Household Owner',
      'User',
      'Unknown member',
    };
    if (!invalidNames.contains(rawName) && !rawName.contains('@')) {
      return rawName;
    }

    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) {
      if (email.contains('@')) {
        final localPart = email.split('@').first;
        if (localPart.isNotEmpty && !localPart.contains('.')) {
          return localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
        }
        if (localPart.contains('.')) {
          final parts = localPart.split('.');
          return parts
              .where((p) => p.isNotEmpty)
              .map((p) => p.substring(0, 1).toUpperCase() + p.substring(1))
              .join(' ');
        }
      }
      return email;
    }

    if (fallbackUserId.isNotEmpty) {
      if (fallbackUserId.length > 8) {
        return '${fallbackUserId.substring(0, 8)}...';
      }
      return fallbackUserId;
    }

    if (membership != null && membership.role == MemberRole.owner) {
      return 'Household Owner';
    }

    return null;
  }
}
