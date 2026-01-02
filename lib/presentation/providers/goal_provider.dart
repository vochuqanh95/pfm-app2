import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/user_model.dart';
import 'auth_provider.dart';
import 'household_provider.dart';
import 'wallet_provider.dart';

// Goal Repository Provider
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final balanceService = ref.watch(walletBalanceServiceProvider);
  return GoalRepository(balanceService: balanceService);
});

// Get personal goals
final personalGoalsProvider = FutureProvider.family<List<GoalModel>, String>((ref, userId) async {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.getPersonalGoals(userId);
});

// Get household goals
final householdGoalsProvider = FutureProvider.family<List<GoalModel>, String>((ref, householdId) async {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.getHouseholdGoals(householdId);
});

// Get all goals for user
final allGoalsProvider = FutureProvider.family<List<GoalModel>, WalletParams>((ref, params) async {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.getAllGoalsForUser(params.userId, params.householdIds);
});

// Stream goals
final goalsStreamProvider = StreamProvider.family<List<GoalModel>, GoalStreamParams>((ref, params) {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.streamGoals(
    userId: params.userId,
    householdId: params.householdId,
  );
});

final familyGoalsProvider = StreamProvider.autoDispose<List<GoalModel>>((ref) {
  final userAsync = ref.watch(authUserProvider);
  final householdAsync = ref.watch(currentUserHouseholdProvider);

  // FIXED: Return empty list immediately instead of Stream.empty() which never emits
  if (userAsync.isLoading) {
    debugPrint('[GOALS] User loading, returning empty family goals');
    return Stream.value(const <GoalModel>[]);
  }
  if (userAsync.hasError) {
    debugPrint('[GOALS] User error: ${userAsync.error}');
    return Stream.error(userAsync.error!);
  }

  final user = userAsync.value;
  if (user == null) {
    debugPrint('[GOALS] No user, returning empty family goals');
    return Stream.value(const <GoalModel>[]);
  }

  final householdId = householdAsync.maybeWhen(
    data: (h) => h?.householdId ?? user.householdId ?? '',
    orElse: () => user.householdId ?? '',
  );

  debugPrint('[GOALS] Loading family goals for household=$householdId');

  if (householdId.isEmpty) {
    debugPrint('[GOALS] No household, returning empty family goals');
    return Stream.value(const <GoalModel>[]);
  }

  final repository = ref.watch(goalRepositoryProvider);
  return repository.streamFamilyGoals(householdId).map((goals) {
    debugPrint('[GOALS] Family goals loaded: ${goals.length} goals');
    return goals;
  });
});

final myGoalsProvider = StreamProvider.autoDispose<List<GoalModel>>((ref) {
  final userAsync = ref.watch(authUserProvider);

  // FIXED: Return empty list immediately instead of Stream.empty() which never emits
  if (userAsync.isLoading) {
    debugPrint('[GOALS] User loading, returning empty personal goals');
    return Stream.value(const <GoalModel>[]);
  }
  if (userAsync.hasError) {
    debugPrint('[GOALS] User error: ${userAsync.error}');
    return Stream.error(userAsync.error!);
  }

  final user = userAsync.value;
  if (user == null) {
    debugPrint('[GOALS] No user, returning empty personal goals');
    return Stream.value(const <GoalModel>[]);
  }

  debugPrint('[GOALS] Loading personal goals for user=${user.userId}');

  final repository = ref.watch(goalRepositoryProvider);
  return repository.streamUserGoals(user.userId).map((goals) {
    debugPrint('[GOALS] Personal goals loaded: ${goals.length} goals');
    return goals;
  });
});

// Goal Notifier for CRUD operations
class GoalNotifier extends StateNotifier<AsyncValue<void>> {
  final GoalRepository _repository;

  GoalNotifier(this._repository) : super(const AsyncValue.data(null));

  // Create goal
  Future<String?> createGoal(GoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      final goalId = await _repository.createGoal(goal);
      state = const AsyncValue.data(null);
      debugPrint('[GOALS] Goal created successfully: $goalId');
      return goalId;
    } catch (e, stack) {
      debugPrint('[GOALS] Error creating goal: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // Update goal
  Future<void> updateGoal(GoalModel goal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateGoal(goal);
      debugPrint('[GOALS] Goal updated successfully: ${goal.goalId}');
    });
  }

  // Update goal progress
  Future<void> updateProgress(String goalId, double savedAmount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateGoalProgress(goalId, savedAmount);
      debugPrint('[GOALS] Goal progress updated: $goalId, amount: $savedAmount');
    });
  }

  // Delete goal
  Future<void> deleteGoal(String goalId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteGoal(goalId);
      debugPrint('[GOALS] Goal deleted: $goalId');
    });
  }

  // Add contribution to goal (ENHANCED VERSION)
  Future<void> addContribution({
    required String goalId,
    required double amount,
    required WalletModel wallet,
    required UserModel user,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addContribution(
        goalId: goalId,
        amount: amount,
        wallet: wallet,
        user: user,
      );
      debugPrint('[GOALS] Contribution added: $goalId, amount: $amount, wallet: ${wallet.walletId}');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('[GOALS] Error adding contribution: $e');
      state = AsyncValue.error(e, stack);
      rethrow; // Re-throw so UI can catch it
    }
  }
}

// Goal Notifier Provider
final goalNotifierProvider = StateNotifierProvider<GoalNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  return GoalNotifier(repository);
});

// Helper class for stream parameters
class GoalStreamParams {
  final String? userId;
  final String? householdId;

  GoalStreamParams({this.userId, this.householdId});
}
