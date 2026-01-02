import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/bill_reminder_service.dart';
import '../../data/models/bill_model.dart';
import 'auth_provider.dart';
import 'household_provider.dart';
import 'wallet_provider.dart';

// Bill Repository Provider
final billRepositoryProvider = Provider<BillRepository>((ref) {
  final balanceService = ref.watch(walletBalanceServiceProvider);
  return BillRepository(balanceService: balanceService);
});

// Get unpaid bills
final unpaidBillsProvider = FutureProvider.family<List<BillModel>, BillParams>((ref, params) async {
  final repository = ref.watch(billRepositoryProvider);
  return repository.getUnpaidBills(
    userId: params.userId,
    householdId: params.householdId,
  );
});

// Get overdue bills
final overdueBillsProvider = FutureProvider.family<List<BillModel>, BillParams>((ref, params) async {
  final repository = ref.watch(billRepositoryProvider);
  return repository.getOverdueBills(
    userId: params.userId,
    householdId: params.householdId,
  );
});

// Get upcoming bills
final upcomingBillsProvider = FutureProvider.family<List<BillModel>, UpcomingBillParams>((ref, params) async {
  final repository = ref.watch(billRepositoryProvider);
  return repository.getUpcomingBills(
    userId: params.userId,
    householdId: params.householdId,
    daysAhead: params.daysAhead,
  );
});

// Stream bills
final billsStreamProvider = StreamProvider.family<List<BillModel>, BillParams>((ref, params) {
  final repository = ref.watch(billRepositoryProvider);
  return repository.streamBills(
    userId: params.userId,
    householdId: params.householdId,
  );
});

// Stream upcoming bills for household (for head view on home screen)
final upcomingHouseholdBillsStreamProvider = StreamProvider.autoDispose<List<BillModel>>((ref) {
  final repository = ref.watch(billRepositoryProvider);
  final household = ref.watch(currentUserHouseholdProvider).value;

  if (household == null) {
    return Stream.value(const <BillModel>[]);
  }

  return repository.streamUpcomingBillsForHousehold(
    householdId: household.householdId,
    daysAhead: 30,
  );
});

// Stream bills assigned to current user (for member and head views)
final myResponsibleBillsStreamProvider = StreamProvider.autoDispose<List<BillModel>>((ref) {
  final repository = ref.watch(billRepositoryProvider);
  final user = ref.watch(authUserProvider).value;
  final household = ref.watch(currentUserHouseholdProvider).value;

  if (user == null) {
    return Stream.value(const <BillModel>[]);
  }

  return repository.streamBillsForResponsibleUser(
    userId: user.userId,
    householdId: household?.householdId,
  );
});

// Stream all household bills (for bills screen - head view)
final allHouseholdBillsStreamProvider = StreamProvider.autoDispose<List<BillModel>>((ref) {
  final repository = ref.watch(billRepositoryProvider);
  final household = ref.watch(currentUserHouseholdProvider).value;

  if (household == null) {
    return Stream.value(const <BillModel>[]);
  }

  return repository.streamAllHouseholdBills(household.householdId);
});

// Get total unpaid amount
final totalUnpaidBillsProvider = FutureProvider.family<double, BillParams>((ref, params) async {
  final repository = ref.watch(billRepositoryProvider);
  return repository.getTotalUnpaidAmount(
    userId: params.userId,
    householdId: params.householdId,
  );
});

// Get bills needing reminders for current user
final billsNeedingRemindersProvider = FutureProvider.autoDispose<List<BillModel>>((ref) async {
  final repository = ref.watch(billRepositoryProvider);
  final user = ref.watch(authUserProvider).value;
  final household = ref.watch(currentUserHouseholdProvider).value;

  if (user == null) {
    return const <BillModel>[];
  }

  return repository.getBillsNeedingReminders(
    userId: user.userId,
    householdId: household?.householdId,
  );
});

// Get a single bill by ID
final billByIdProvider = FutureProvider.autoDispose.family<BillModel?, String>((ref, billId) async {
  final repository = ref.watch(billRepositoryProvider);
  return repository.getBillById(billId);
});

// Bill Notifier for CRUD operations
class BillNotifier extends StateNotifier<AsyncValue<void>> {
  final BillRepository _repository;

  BillNotifier(this._repository) : super(const AsyncValue.data(null));

  // Create bill
  Future<String?> createBill(BillModel bill) async {
    state = const AsyncValue.loading();
    try {
      final billId = await _repository.createBill(bill);
      state = const AsyncValue.data(null);
      return billId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // Update bill
  Future<void> updateBill(BillModel bill) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateBill(bill);
    });
  }

  // Mark as paid (with recurring logic)
  Future<void> markAsPaid(String billId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.markBillAsPaid(billId);
    });
  }

  // Mark as unpaid
  Future<void> markAsUnpaid(String billId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.markAsUnpaid(billId);
    });
  }

  // Delete bill
  Future<void> deleteBill(String billId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteBill(billId);
    });
  }

  // Pay bill with wallet - creates transaction and updates wallet
  Future<void> payBillWithWallet({
    required String billId,
    required String householdId,
    required String walletId,
    required String actorUserId,
    required String actorDisplayName,
    required String actorRole,
    String? categoryId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.payBillWithWallet(
        billId: billId,
        householdId: householdId,
        walletId: walletId,
        actorUserId: actorUserId,
        actorDisplayName: actorDisplayName,
        actorRole: actorRole,
        categoryId: categoryId,
      );
    });
  }

  // Mark bill as paid manually (no wallet transaction)
  Future<void> markAsPaidManually({
    required String billId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.markBillAsPaidManually(
        billId: billId,
        userId: userId,
      );
    });
  }
}

// Bill Notifier Provider
final billNotifierProvider = StateNotifierProvider<BillNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(billRepositoryProvider);
  return BillNotifier(repository);
});

// Helper classes for parameters
class BillParams {
  final String? userId;
  final String? householdId;

  BillParams({this.userId, this.householdId});
}

class UpcomingBillParams {
  final String? userId;
  final String? householdId;
  final int daysAhead;

  UpcomingBillParams({
    this.userId,
    this.householdId,
    this.daysAhead = 7,
  });
}

// ============================================================================
// BILL REMINDER SERVICE & PROVIDERS
// ============================================================================

/// Notification Repository Provider (for bill reminders)
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Bill Reminder Service Provider
final billReminderServiceProvider = Provider<BillReminderService>((ref) {
  final billRepo = ref.watch(billRepositoryProvider);
  final notifRepo = ref.watch(notificationRepositoryProvider);
  return BillReminderService(
    billRepository: billRepo,
    notificationRepository: notifRepo,
  );
});

/// Bill Reminder Process Provider
/// This runs the bill reminder check when watched (e.g., from HomeScreen)
/// Returns the number of notifications created, or 0 if there was an error
final billReminderProcessProvider = FutureProvider.autoDispose<int>((ref) async {
  // Get current user
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.valueOrNull;

  if (user == null) {
    return 0; // No user, skip reminder check
  }

  // Get household context
  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.valueOrNull;
  final householdId = household?.householdId ?? user.householdId;

  // Run the reminder service
  final service = ref.read(billReminderServiceProvider);

  try {
    final notificationsCreated = await service.checkAndCreateRemindersForUser(
      userId: user.userId,
      householdId: householdId,
    );
    return notificationsCreated;
  } catch (e) {
    // Log error but don't throw - we don't want to block the app
    print('[BillReminderProvider] Error processing reminders: $e');
    return 0;
  }
});
