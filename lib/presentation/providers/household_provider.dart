import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/household_model.dart';
import '../../data/models/household_member_model.dart';
import '../../data/models/user_model.dart';
import 'auth_provider.dart';

// Household Repository Provider
final householdRepositoryProvider =
    Provider<HouseholdRepository>((ref) => HouseholdRepository());

// Get households for user
final userHouseholdsProvider =
    FutureProvider.family<List<HouseholdModel>, String>((ref, userId) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.getAllUserHouseholds(userId);
});

// Get household by ID
final householdProvider =
    FutureProvider.family<HouseholdModel?, String>((ref, householdId) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.getHouseholdById(householdId);
});

// Get household members
final householdMembersProvider =
    FutureProvider.family<List<HouseholdMemberModel>, String>(
        (ref, householdId) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.getHouseholdMembers(householdId);
});

// Stream household members (active only)
// CRITICAL: .autoDispose ensures streams are recreated after logout/login
final householdMembersStreamProvider = StreamProvider.autoDispose
    .family<List<HouseholdMemberModel>, String>((ref, householdId) {
  final repository = ref.watch(householdRepositoryProvider);
  debugPrint(
      '[PROVIDER] Creating householdMembersStream for household=$householdId');
  return repository.streamHouseholdMembers(householdId);
});

// Stream all household members (including pending, excluding removed)
// CRITICAL: .autoDispose ensures streams are recreated after logout/login
final allHouseholdMembersStreamProvider = StreamProvider.autoDispose
    .family<List<HouseholdMemberModel>, String>((ref, householdId) {
  final repository = ref.watch(householdRepositoryProvider);
  debugPrint(
      '[PROVIDER] Creating allHouseholdMembersStream for household=$householdId');
  return repository.streamAllHouseholdMembers(householdId);
});

class HouseholdMemberDetail {
  final HouseholdMemberModel membership;
  final UserModel? user;

  const HouseholdMemberDetail({
    required this.membership,
    required this.user,
  });

  bool get isOwner => membership.role == MemberRole.owner;

  String get displayName {
    final userName = (user?.name ?? '').trim();

    // Check if name is valid and not a generic placeholder
    final isValidName = userName.isNotEmpty &&
        userName != 'Member' &&
        userName != 'Household Member' &&
        userName != 'Household Owner' &&
        userName != 'User';

    if (isValidName) {
      return userName;
    }

    // Try to extract name from email (before @)
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      final localPart = email.split('@').first;
      // Capitalize first letter and return if it looks like a name
      if (localPart.isNotEmpty && !localPart.contains('.')) {
        return localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
      }
      // If email has dots (like first.last@email.com), try to format nicely
      if (localPart.contains('.')) {
        final parts = localPart.split('.');
        return parts
            .where((p) => p.isNotEmpty)
            .map((p) => p.substring(0, 1).toUpperCase() + p.substring(1))
            .join(' ');
      }
      return localPart;
    }

    // Return full email if no @ found
    if (email.isNotEmpty) {
      return email;
    }

    // Fall back to short form of userId if both name and email are missing
    final userId = membership.userId;
    if (userId.length > 8) {
      return '${userId.substring(0, 8)}...';
    }
    return userId.isNotEmpty
        ? userId
        : (isOwner ? 'Household Owner' : 'Household Member');
  }

  String get email => user?.email ?? '';

  String get roleLabel => isOwner ? 'Owner' : 'Member';

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return 'M';
    final codeUnit =
        source.runes.isEmpty ? 'M'.codeUnitAt(0) : source.runes.first;
    return String.fromCharCode(codeUnit).toUpperCase();
  }
}

// CRITICAL: .autoDispose ensures streams are recreated after logout/login
final householdMemberDetailsProvider = StreamProvider.autoDispose
    .family<List<HouseholdMemberDetail>, String>((ref, householdId) {
  final repository = ref.watch(householdRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);

  debugPrint(
      '[PROVIDER] Creating householdMemberDetailsProvider for household=$householdId');
  return repository
      .streamHouseholdMembers(householdId)
      .asyncMap((members) async {
    if (members.isEmpty) return const <HouseholdMemberDetail>[];

    final details = await Future.wait(members.map((member) async {
      final user = await userRepository.getUserById(member.userId);
      return HouseholdMemberDetail(membership: member, user: user);
    }));

    details.sort((a, b) {
      if (a.isOwner && !b.isOwner) return -1;
      if (!a.isOwner && b.isOwner) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return details;
  });
});

// All household member details (including pending)
// CRITICAL: .autoDispose ensures streams are recreated after logout/login
final allHouseholdMemberDetailsProvider = StreamProvider.autoDispose
    .family<List<HouseholdMemberDetail>, String>((ref, householdId) {
  final repository = ref.watch(householdRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);

  debugPrint(
      '[PROVIDER] Creating allHouseholdMemberDetailsProvider for household=$householdId');
  return repository
      .streamAllHouseholdMembers(householdId)
      .asyncMap((members) async {
    if (members.isEmpty) return const <HouseholdMemberDetail>[];

    final details = await Future.wait(members.map((member) async {
      final user = await userRepository.getUserById(member.userId);
      return HouseholdMemberDetail(membership: member, user: user);
    }));

    details.sort((a, b) {
      // Sort by: owner first, then pending, then active, then by name
      if (a.isOwner && !b.isOwner) return -1;
      if (!a.isOwner && b.isOwner) return 1;

      final aIsPending = a.membership.status == MemberStatus.invited;
      final bIsPending = b.membership.status == MemberStatus.invited;
      if (aIsPending && !bIsPending) return -1;
      if (!aIsPending && bIsPending) return 1;

      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return details;
  });
});

final currentUserHouseholdProvider = StreamProvider<HouseholdModel?>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null || (user.householdId?.isNotEmpty != true)) {
        return const Stream<HouseholdModel?>.empty();
      }
      final repository = ref.watch(householdRepositoryProvider);
      return repository.watchHousehold(user.householdId!);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// Check if user is household owner
final isHouseholdOwnerProvider =
    FutureProvider.family<bool, HouseholdUserParams>((ref, params) async {
  final repository = ref.watch(householdRepositoryProvider);
  return repository.isHouseholdOwner(params.householdId, params.userId);
});

// Household Notifier for CRUD operations
class HouseholdNotifier extends StateNotifier<AsyncValue<void>> {
  final HouseholdRepository _repository;
  final UserRepository _userRepository;

  HouseholdNotifier(this._repository, this._userRepository)
      : super(const AsyncValue.data(null));

  Future<String> createHouseholdForUser({
    required String ownerUserId,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final household = await _repository.createHouseholdWithOwner(
        ownerUserId: ownerUserId,
        name: name,
      );
      state = const AsyncValue.data(null);
      return household.householdId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Update household
  Future<void> updateHousehold(HouseholdModel household) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateHousehold(household);
    });
  }

  // Delete household
  Future<void> deleteHousehold(String householdId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteHousehold(householdId);
    });
  }

  // Add member to household
  Future<void> addMember(HouseholdMemberModel member) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.upsertMember(member);
    });
  }

  // Remove member from household
  Future<void> removeMember({
    required String householdId,
    required String userId,
    required String currentUserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Verify current user is household owner
      final isOwner =
          await _repository.isHouseholdOwner(householdId, currentUserId);
      if (!isOwner) {
        throw Exception('Only the household owner can remove members.');
      }

      // Remove the member
      await _repository.removeMember(householdId, userId);

      // Clear household_id from user's document
      await _userRepository.updateUserRoleAndHousehold(
        userId: userId,
        role: UserRoles.member,
        householdId: null,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Approve pending member
  Future<void> approveMember({
    required String householdId,
    required String userId,
    required String currentUserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Verify current user is household owner
      final isOwner =
          await _repository.isHouseholdOwner(householdId, currentUserId);
      if (!isOwner) {
        throw Exception('Only the household owner can approve members.');
      }

      await _repository.approveMember(
        householdId: householdId,
        userId: userId,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Reject pending member
  Future<void> rejectMember({
    required String householdId,
    required String userId,
    required String currentUserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Verify current user is household owner
      final isOwner =
          await _repository.isHouseholdOwner(householdId, currentUserId);
      if (!isOwner) {
        throw Exception('Only the household owner can reject members.');
      }

      await _repository.rejectMember(
        householdId: householdId,
        userId: userId,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // Invite member to household (placeholder - implement with proper invitation system)
  Future<void> inviteMember(String householdId, String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // TODO: Implement invitation logic
      // This would typically send an email invitation or create a pending invite in Firestore
      await Future.delayed(const Duration(milliseconds: 500));
    });
  }

  // Cancel invitation (placeholder - implement with proper invitation system)
  Future<void> cancelInvite(String householdId, String inviteId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // TODO: Implement cancel invitation logic
      await Future.delayed(const Duration(milliseconds: 500));
    });
  }

  // Join household by invite code
  Future<HouseholdModel> joinCurrentUserToHousehold({
    required String inviteCode,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Join household (creates member document)
      final household = await _repository.joinHousehold(
        inviteCode: inviteCode,
        userId: userId,
      );

      // Update user document with household_id and role
      await _userRepository.updateUserRoleAndHousehold(
        userId: userId,
        role: UserRoles.member,
        householdId: household.householdId,
      );

      state = const AsyncValue.data(null);
      return household;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Household Notifier Provider
final householdNotifierProvider =
    StateNotifierProvider<HouseholdNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(householdRepositoryProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  return HouseholdNotifier(repository, userRepository);
});

// Helper class for parameters
class HouseholdUserParams {
  final String householdId;
  final String userId;

  HouseholdUserParams({required this.householdId, required this.userId});
}
