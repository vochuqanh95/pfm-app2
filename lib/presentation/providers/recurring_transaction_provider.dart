import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/recurring_transaction_service.dart';
import 'auth_provider.dart';
import 'household_provider.dart';

/// Provider for RecurringTransactionService instance
final recurringTransactionServiceProvider = Provider<RecurringTransactionService>((ref) {
  return RecurringTransactionService();
});

/// Provider that processes due recurring rules
/// Call this provider when the app starts or when user opens home screen
final processRecurringTransactionsProvider = FutureProvider.autoDispose<int>((ref) async {
  // Get current user and household context
  final userAsync = ref.watch(authUserProvider);
  final user = userAsync.value;

  if (user == null) {
    print('[RecurringTxnProvider] No authenticated user, skipping');
    return 0;
  }

  final householdAsync = ref.watch(currentUserHouseholdProvider);
  final household = householdAsync.value;
  final householdId = household?.householdId;

  final service = ref.read(recurringTransactionServiceProvider);
  final count = await service.processDueRules(
    now: DateTime.now(),
    userId: user.userId,
    householdId: householdId,
  );
  print('[RecurringTxnProvider] Processed $count recurring transactions');
  return count;
});
