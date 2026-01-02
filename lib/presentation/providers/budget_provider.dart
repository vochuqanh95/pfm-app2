import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/budget_with_usage_model.dart';
import '../../data/services/budget_service.dart';
import '../../data/services/budget_alert_service.dart';
import '../../data/services/member_name_resolver.dart';
import 'auth_provider.dart';

// Budget Repository Provider
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository());

// Budget Service Provider
final budgetServiceProvider = Provider<BudgetService>(
    (ref) => BudgetService(budgetRepository: ref.watch(budgetRepositoryProvider)));

// Budget Alert Service Provider
final budgetAlertServiceProvider =
    Provider<BudgetAlertService>((ref) => BudgetAlertService(
          budgetService: ref.watch(budgetServiceProvider),
          budgetRepository: ref.watch(budgetRepositoryProvider),
        ));

final memberNameResolverProvider =
    Provider<MemberNameResolver>((ref) => MemberNameResolver());

// DISABLED: Personal budgets not supported (budgets are household-only)
final personalBudgetsProvider = FutureProvider.family<List<BudgetModel>, String>((ref, userId) async {
  debugPrint('[BUDGET_PROVIDER] personalBudgetsProvider DISABLED - budgets are household-only');
  return [];
});

// Get household budgets
final householdBudgetsProvider = FutureProvider.family<List<BudgetModel>, String>((ref, householdId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getHouseholdBudgets(householdId);
});

// Get active budgets
final activeBudgetsProvider = FutureProvider.family<List<BudgetModel>, BudgetParams>((ref, params) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getActiveBudgets(
    userId: params.userId,
    householdId: params.householdId,
  );
});

// DISABLED: Legacy stream provider (use activeBudgetsWithUsageStreamProvider instead)
final budgetsStreamProvider = StreamProvider.family<List<BudgetModel>, BudgetParams>((ref, params) {
  debugPrint('[BUDGET_PROVIDER] budgetsStreamProvider DISABLED - use activeBudgetsWithUsageStreamProvider');
  return Stream.value([]);
});

// Budget Notifier for CRUD operations
class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final BudgetRepository _repository;
  final BudgetAlertService _alertService;

  BudgetNotifier(this._repository, this._alertService)
      : super(const AsyncValue.data(null));

  // Create budget
  Future<String?> createBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    try {
      final budgetId = await _repository.createBudget(budget);
      state = const AsyncValue.data(null);
      return budgetId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // Update budget
  Future<void> updateBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateBudget(budget);
    });
  }

  // Delete budget
  Future<void> deleteBudget(String budgetId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteBudget(budgetId);
    });
  }

  // Check if budget exceeded
  Future<bool> isBudgetExceeded(String budgetId, double spent) async {
    return _repository.isBudgetExceeded(budgetId: budgetId, spent: spent);
  }

  // Check if alert threshold reached
  Future<bool> isAlertThresholdReached(String budgetId, double spent) async {
    return _repository.isAlertThresholdReached(budgetId: budgetId, spent: spent);
  }

  // Check budgets and send alerts if thresholds are crossed
  Future<int> checkAndSendAlerts({String? userId, String? householdId}) async {
    try {
      return await _alertService.checkBudgetsAndAlert(
        userId: userId,
        householdId: householdId,
      );
    } catch (e) {
      print('[BudgetNotifier] Error checking alerts: $e');
      return 0;
    }
  }

  // Check a specific budget for alerts
  Future<bool> checkBudgetAlert(String budgetId) async {
    try {
      return await _alertService.checkBudgetById(budgetId);
    } catch (e) {
      print('[BudgetNotifier] Error checking budget alert: $e');
      return false;
    }
  }
}

// Budget Notifier Provider
final budgetNotifierProvider = StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  final alertService = ref.watch(budgetAlertServiceProvider);
  return BudgetNotifier(repository, alertService);
});

// Get budget by ID
final budgetByIdProvider = FutureProvider.family<BudgetModel?, String>((ref, budgetId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.getBudgetById(budgetId);
});

// Get budget with usage (spent amount, transactions, etc.)
final budgetWithUsageProvider = FutureProvider.family<BudgetWithUsage?, String>((ref, budgetId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  final service = ref.watch(budgetServiceProvider);
  final viewer = ref.watch(authUserProvider).value;
  final viewerRole = (viewer?.isHead ?? false) ? 'head' : 'member';

  final budget = await repository.getBudgetById(budgetId);
  if (budget == null) return null;

  return await service.buildBudgetWithUsage(
    budget,
    viewerRole: viewerRole,
    viewerUserId: viewer?.userId,
  );
});

// Stream active budgets with usage (REAL-TIME)
final activeBudgetsWithUsageStreamProvider = StreamProvider.family.autoDispose<List<BudgetWithUsage>, BudgetParams>((ref, params) async* {
  final repository = ref.watch(budgetRepositoryProvider);
  final service = ref.watch(budgetServiceProvider);
  final viewerRole = params.isHead == true ? 'head' : 'member';

  // Stream budgets based on role
  Stream<List<BudgetModel>> budgetsStream;

  if (params.isHead == true && params.householdId != null && params.periodKey != null) {
    budgetsStream = repository.streamBudgetsForHead(
      householdId: params.householdId!,
      periodKey: params.periodKey!,
    );
  } else if (params.isHead == false &&
      params.householdId != null &&
      params.periodKey != null &&
      params.viewerUserId != null) {
    budgetsStream = repository.streamBudgetsForMember(
      householdId: params.householdId!,
      periodKey: params.periodKey!,
      memberUserId: params.viewerUserId!,
    );
  } else {
    // Invalid params - return empty stream (household-based budgets require householdId + periodKey)
    debugPrint('[BUDGET_STREAM] ERROR: Invalid params - householdId and periodKey required. Returning empty stream.');
    budgetsStream = Stream.value([]);
  }

  // For each budgets update, fetch usage and yield combined result
  await for (final budgets in budgetsStream) {
    debugPrint(
        '[BUDGET_LIST] stream update userId=${params.userId} householdId=${params.householdId} period=${params.periodKey} isHead=${params.isHead} viewer=${params.viewerUserId} docs=${budgets.length}');

    final budgetsWithUsage = await service.buildBudgetsWithUsage(
      budgets,
      viewerRole: viewerRole,
      viewerUserId: params.viewerUserId,
    );

    yield budgetsWithUsage;
  }
});

// Legacy: Get active budgets with usage (Future-based, kept for backwards compatibility)
final activeBudgetsWithUsageProvider = FutureProvider.family<List<BudgetWithUsage>, BudgetParams>((ref, params) async {
  final repository = ref.watch(budgetRepositoryProvider);
  final service = ref.watch(budgetServiceProvider);

  List<BudgetModel> budgets = [];
  if (params.isHead == true && params.householdId != null && params.periodKey != null) {
    budgets = await repository.getHeadBudgets(
      householdId: params.householdId!,
      periodKey: params.periodKey!,
    );
  } else if (params.isHead == false &&
      params.householdId != null &&
      params.periodKey != null &&
      params.viewerUserId != null) {
    budgets = await repository.getMemberBudgets(
      householdId: params.householdId!,
      periodKey: params.periodKey!,
      memberUserId: params.viewerUserId!,
    );
  } else {
    budgets = await repository.getActiveBudgets(
      userId: params.userId,
      householdId: params.householdId,
      periodKey: params.periodKey,
      isHead: params.isHead,
      viewerUserId: params.viewerUserId,
    );
  }

  debugPrint(
      '[BUDGET_LIST] fetch userId=${params.userId} householdId=${params.householdId} period=${params.periodKey} isHead=${params.isHead} viewer=${params.viewerUserId} docs=${budgets.length}');
  for (final budget in budgets.take(5)) {
    debugPrint(
        '[BUDGET_LIST] doc id=${budget.budgetId} household_id=${budget.householdId} period_key=${budget.periodKey} archived=${budget.archived} type=${budget.budgetType}');
  }

  final viewerRole = params.isHead == true ? 'head' : 'member';
  return await service.buildBudgetsWithUsage(
    budgets,
    viewerRole: viewerRole,
    viewerUserId: params.viewerUserId,
  );
});

// Get spent amount for a budget (lightweight - no transaction list)
final budgetSpentAmountProvider = FutureProvider.family<double, String>((ref, budgetId) async {
  final repository = ref.watch(budgetRepositoryProvider);
  final service = ref.watch(budgetServiceProvider);
  final viewer = ref.watch(authUserProvider).value;
  final viewerRole = (viewer?.isHead ?? false) ? 'head' : 'member';

  final budget = await repository.getBudgetById(budgetId);
  if (budget == null) return 0.0;

  final withUsage = await service.buildBudgetWithUsage(
    budget,
    viewerRole: viewerRole,
    viewerUserId: viewer?.userId,
  );
  return withUsage.usage.spentAmount;
});

// Helper class for parameters
class BudgetParams {
  final String? userId;
  final String? householdId;
  final String? periodKey;
  final bool? isHead;
  final String? viewerUserId;

  const BudgetParams({
    this.userId,
    this.householdId,
    this.periodKey,
    this.isHead,
    this.viewerUserId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetParams &&
        other.userId == userId &&
        other.householdId == householdId &&
        other.periodKey == periodKey &&
        other.isHead == isHead &&
        other.viewerUserId == viewerUserId;
  }

  @override
  int get hashCode => Object.hash(userId, householdId, periodKey, isHead, viewerUserId);

  @override
  String toString() =>
      'BudgetParams(userId: $userId, householdId: $householdId, periodKey: $periodKey, isHead: $isHead, viewer: $viewerUserId)';
}
