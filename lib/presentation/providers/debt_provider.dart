import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/debt_payment_model.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/debt_reminder_service.dart';
import './auth_provider.dart';
import './household_provider.dart';

class DebtVisibilityParams {
  final String userId;
  final String? householdId;
  final bool includeHouseholdDebts;
  final bool isHead;

  const DebtVisibilityParams({
    required this.userId,
    this.householdId,
    this.includeHouseholdDebts = false,
    this.isHead = false,
  });
}

enum DebtScopeFilter { all, personal, household }

enum DebtDueFilter { any, dueSoon, overdue, noDueDate }

class DebtFilterState {
  final DebtType? type;
  final DebtStatus? status;
  final DebtScopeFilter scope;
  final DebtDueFilter dueFilter;
  final String? memberUserId;

  const DebtFilterState({
    this.type,
    this.status,
    this.scope = DebtScopeFilter.all,
    this.dueFilter = DebtDueFilter.any,
    this.memberUserId,
  });

  DebtFilterState copyWith({
    DebtType? type,
    bool clearType = false,
    DebtStatus? status,
    bool clearStatus = false,
    DebtScopeFilter? scope,
    DebtDueFilter? dueFilter,
    String? memberUserId,
    bool clearMember = false,
  }) {
    return DebtFilterState(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      scope: scope ?? this.scope,
      dueFilter: dueFilter ?? this.dueFilter,
      memberUserId: clearMember ? null : (memberUserId ?? this.memberUserId),
    );
  }
}

class DebtFilterNotifier extends StateNotifier<DebtFilterState> {
  DebtFilterNotifier() : super(const DebtFilterState());

  void setType(DebtType? type) {
    state = state.copyWith(type: type, clearType: type == null);
  }

  void setStatus(DebtStatus? status) {
    state = state.copyWith(status: status, clearStatus: status == null);
  }

  void setScope(DebtScopeFilter scope) {
    state = state.copyWith(scope: scope);
  }

  void setDueFilter(DebtDueFilter dueFilter) {
    state = state.copyWith(dueFilter: dueFilter);
  }

  void setMemberUser(String? memberUserId) {
    state = state.copyWith(
      memberUserId: memberUserId,
      clearMember: memberUserId == null || memberUserId.isEmpty,
    );
  }

  void clearFilters() {
    state = const DebtFilterState();
  }
}

// Debt Repository Provider
final debtRepositoryProvider =
    Provider<DebtRepository>((ref) => DebtRepository());

final debtNotificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

final debtReminderServiceProvider = Provider<DebtReminderService>((ref) {
  final debtRepo = ref.watch(debtRepositoryProvider);
  final notificationRepo = ref.watch(debtNotificationRepositoryProvider);
  return DebtReminderService(
    debtRepository: debtRepo,
    notificationRepository: notificationRepo,
  );
});

final debtReminderProcessProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  if (user == null) {
    return 0;
  }

  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  final service = ref.read(debtReminderServiceProvider);

  try {
    final count = await service.checkDebtsAndNotify(
      userId: user.userId,
      householdId: householdId,
    );
    return count;
  } catch (e) {
    debugPrint('[DEBT_REMINDER] Error processing reminders: $e');
    return 0;
  }
});

// Debt filter provider
final debtFilterProvider =
    StateNotifierProvider.autoDispose<DebtFilterNotifier, DebtFilterState>(
        (ref) {
  return DebtFilterNotifier();
});

// Get debts for user
final userDebtsProvider =
    FutureProvider.family<List<DebtModel>, String>((ref, userId) async {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.getPersonalDebts(userId);
});

// CRITICAL FIX: Added .autoDispose to properly clean up streams on logout/login
final householdDebtsStreamProvider = StreamProvider.family
    .autoDispose<List<DebtModel>, String>((ref, householdId) {
  final repository = ref.watch(debtRepositoryProvider);
  if (householdId.isEmpty) {
    debugPrint('[DEBTS] Empty household ID, returning empty list');
    return Stream.value(const <DebtModel>[]);
  }
  debugPrint('[DEBTS] Streaming household debts: household=$householdId');
  return repository.watchHouseholdDebts(householdId).map((debts) {
    debugPrint('[DEBTS] Household debts loaded: ${debts.length} debts');
    return debts;
  });
});

// CRITICAL FIX: Added .autoDispose to properly clean up streams on logout/login
final userDebtsStreamProvider =
    StreamProvider.family.autoDispose<List<DebtModel>, String>((ref, userId) {
  final repository = ref.watch(debtRepositoryProvider);
  if (userId.isEmpty) {
    debugPrint('[DEBTS] Empty user ID, returning empty list');
    return Stream.value(const <DebtModel>[]);
  }
  debugPrint('[DEBTS] Streaming user debts: user=$userId');
  return repository.watchUserDebts(userId).map((debts) {
    debugPrint('[DEBTS] User debts loaded: ${debts.length} debts');
    return debts;
  });
});

final combinedDebtsProvider = Provider.autoDispose
    .family<AsyncValue<List<DebtModel>>, DebtVisibilityParams>((ref, params) {
  final personal = ref.watch(userDebtsStreamProvider(params.userId));
  final household = params.includeHouseholdDebts &&
          (params.householdId != null && params.householdId!.isNotEmpty)
      ? ref.watch(householdDebtsStreamProvider(params.householdId!))
      : const AsyncValue.data(<DebtModel>[]);

  return _mergeDebtStreams(
    personal: personal,
    household: household,
    logLabel: params.includeHouseholdDebts ? 'combined' : 'personal_only',
  );
});

final filteredDebtsProvider = Provider.autoDispose
    .family<AsyncValue<List<DebtModel>>, DebtVisibilityParams>((ref, params) {
  final base = ref.watch(combinedDebtsProvider(params));
  final filters = ref.watch(debtFilterProvider);

  return base.whenData(
    (debts) => applyDebtFilters(
      debts,
      filters: filters,
      isHead: params.isHead,
    ),
  );
});

// Get debt by ID
final debtProvider =
    FutureProvider.family<DebtModel?, String>((ref, debtId) async {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.getDebtById(debtId);
});

final debtStreamProvider =
    StreamProvider.family.autoDispose<DebtModel?, String>((ref, debtId) {
  final repository = ref.watch(debtRepositoryProvider);
  if (debtId.isEmpty) {
    debugPrint('[DEBT_DEBUG] Empty debtId for stream provider');
    return Stream.value(null);
  }
  debugPrint('[DEBT_DEBUG] Subscribing to debt stream id=$debtId');
  return repository.watchDebtById(debtId);
});

// CRITICAL FIX: Added .autoDispose to properly clean up streams on logout/login
final debtPaymentsStreamProvider = StreamProvider.family
    .autoDispose<List<DebtPaymentModel>, String>((ref, debtId) {
  final repository = ref.watch(debtRepositoryProvider);
  if (debtId.isEmpty) {
    debugPrint('[DEBT_PAYMENTS] Empty debt ID, returning empty list');
    return Stream.value(const <DebtPaymentModel>[]);
  }
  debugPrint('[DEBT_PAYMENTS] Streaming payments for debt: $debtId');
  return repository.streamPayments(debtId);
});

// Debt Notifier for CRUD operations
class DebtNotifier extends StateNotifier<AsyncValue<void>> {
  final DebtRepository _repository;

  DebtNotifier(this._repository) : super(const AsyncValue.data(null));

  // Create debt
  Future<String?> createDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    try {
      final debtId = await _repository.createDebt(debt);
      state = const AsyncValue.data(null);
      debugPrint('[DEBTS] Debt created: $debtId');
      return debtId;
    } catch (e, stack) {
      debugPrint('[DEBTS] Error creating debt: $e');
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // Update debt
  Future<void> updateDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateDebt(debt);
      debugPrint('[DEBTS] Debt updated: ${debt.debtId}');
    });
  }

  // Delete debt
  Future<void> deleteDebt(String debtId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteDebt(debtId);
      debugPrint('[DEBTS] Debt deleted: $debtId');
    });
  }

  // Add payment to debt
  Future<void> addPayment({
    required String debtId,
    required double amount,
    required String userId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
    DateTime? date,
    String? note,
    String? walletId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.addPayment(
        debtId: debtId,
        amount: amount,
        date: date ?? DateTime.now(),
        note: note,
        walletId: walletId,
        userId: userId,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
      );
      debugPrint('[DEBTS] Payment added: debt=$debtId amount=$amount');
    });
  }

  // Record payment (wrapper with cleaner signature for UI)
  Future<void> recordPayment({
    required String debtId,
    required double amount,
    required String userId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
    DateTime? date,
    String? note,
    String? walletId,
  }) async {
    await addPayment(
      debtId: debtId,
      amount: amount,
      userId: userId,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      actorRole: actorRole,
      date: date,
      note: note,
      walletId: walletId,
    );
  }

  // Mark debt as fully paid
  Future<void> markAsFullyPaid({
    required String debtId,
    required String userId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
    String? note,
    String? walletId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final debt = await _repository.getDebtById(debtId);
      if (debt == null) {
        throw Exception('Debt not found');
      }

      final remainingAmount = debt.remainingAmount;
      if (remainingAmount <= 0) {
        debugPrint('[DEBTS] Debt already fully paid');
        return;
      }

      debugPrint(
          '[DEBTS] markAsFullyPaid: debtId=$debtId, remaining=$remainingAmount, walletId=$walletId');

      await _repository.addPayment(
        debtId: debtId,
        amount: remainingAmount,
        date: DateTime.now(),
        note: note ?? 'Marked as fully paid',
        walletId: walletId,
        userId: userId,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
      );

      debugPrint(
          '[DEBTS] Marked as fully paid: $debtId (paid $remainingAmount)');
    });
  }
}

// Debt Notifier Provider
final debtNotifierProvider =
    StateNotifierProvider<DebtNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return DebtNotifier(repository);
});

AsyncValue<List<DebtModel>> _mergeDebtStreams({
  required AsyncValue<List<DebtModel>> personal,
  required AsyncValue<List<DebtModel>> household,
  required String logLabel,
}) {
  if (personal.hasError) {
    debugPrint(
        '[DEBTS][$logLabel] Personal debt stream error: ${personal.error}');
    return AsyncValue.error(
        personal.error!, personal.stackTrace ?? StackTrace.current);
  }
  if (household.hasError) {
    debugPrint(
        '[DEBTS][$logLabel] Household debt stream error: ${household.error}');
    return AsyncValue.error(
        household.error!, household.stackTrace ?? StackTrace.current);
  }

  final personalList = personal.value ?? const <DebtModel>[];
  final householdList = household.value ?? const <DebtModel>[];
  final combined = <DebtModel>[
    ...personalList,
    ...householdList,
  ];

  debugPrint(
      '[DEBTS][$logLabel] Combined debts: personal=${personalList.length}, household=${householdList.length}, total=${combined.length}');

  return AsyncValue.data(combined);
}

List<DebtModel> applyDebtFilters(
  List<DebtModel> debts, {
  required DebtFilterState filters,
  required bool isHead,
}) {
  final filtered = debts.where((debt) {
    if (filters.type != null && debt.type != filters.type) return false;
    if (filters.status != null && debt.status != filters.status) return false;

    switch (filters.scope) {
      case DebtScopeFilter.personal:
        if (debt.householdId != null) return false;
        break;
      case DebtScopeFilter.household:
        if (debt.householdId == null) return false;
        break;
      case DebtScopeFilter.all:
        break;
    }

    switch (filters.dueFilter) {
      case DebtDueFilter.dueSoon:
        if (!debt.isDueSoon) return false;
        break;
      case DebtDueFilter.overdue:
        if (!debt.isOverdue) return false;
        break;
      case DebtDueFilter.noDueDate:
        if (debt.dueDate != null) return false;
        break;
      case DebtDueFilter.any:
        break;
    }

    if (filters.memberUserId != null &&
        filters.memberUserId!.isNotEmpty &&
        isHead) {
      if (debt.userId != filters.memberUserId) return false;
    }

    return true;
  }).toList();

  filtered.sort((a, b) {
    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    return aDate.compareTo(bDate);
  });

  return filtered;
}
