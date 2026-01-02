import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/models/wallet_model.dart';
import '../../data/services/wallet_balance_service.dart';

// Wallet Balance Service Provider
final walletBalanceServiceProvider = Provider<WalletBalanceService>((ref) => WalletBalanceService());

// Wallet Repository Provider
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final balanceService = ref.watch(walletBalanceServiceProvider);
  return WalletRepository(balanceService: balanceService);
});

// Get all wallets for user
final walletsProvider = FutureProvider.family<List<WalletModel>, WalletParams>((ref, params) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getAllWalletsForUser(params.userId, params.householdIds);
});

// Get personal wallets
final personalWalletsProvider = FutureProvider.family<List<WalletModel>, String>((ref, userId) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getPersonalWallets(userId);
});

// Get household wallets
final householdWalletsProvider = FutureProvider.family<List<WalletModel>, String>((ref, householdId) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getHouseholdWallets(householdId);
});

// Stream personal wallets
final personalWalletsStreamProvider = StreamProvider.family<List<WalletModel>, String>((ref, userId) {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.streamPersonalWallets(userId);
});

// Stream household wallets
final householdWalletsStreamProvider = StreamProvider.family<List<WalletModel>, String>((ref, householdId) {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.streamHouseholdWallets(householdId);
});

// CRITICAL FIX: Added .autoDispose to properly clean up streams on logout/login
final headWalletsProvider = StreamProvider.family.autoDispose<List<WalletModel>, HeadWalletParams>((ref, params) {
  final repository = ref.watch(walletRepositoryProvider);

  // Guard: Don't query if params are invalid
  // FIXED: Return Stream.value([]) instead of Stream.empty() to ensure at least one emission
  if (params.userId.isEmpty || params.householdId.isEmpty) {
    debugPrint('[WALLET_PROVIDER] Invalid head params: userId=${params.userId}, householdId=${params.householdId}');
    return Stream.value(const <WalletModel>[]);
  }

  debugPrint('[WALLET_PROVIDER] Creating head wallet stream: userId=${params.userId}, householdId=${params.householdId}');
  return repository.watchWalletsForHead(
    householdId: params.householdId,
    userId: params.userId,
  );
});

// CRITICAL FIX: Added .autoDispose to properly clean up streams on logout/login
final memberWalletsProvider =
    StreamProvider.family.autoDispose<List<WalletModel>, WalletVisibilityParams>((ref, params) {
  final repository = ref.watch(walletRepositoryProvider);

  // Guard: Don't query if params are invalid
  // FIXED: Return Stream.value([]) instead of Stream.empty() to ensure at least one emission
  if (params.userId.isEmpty || params.householdId.isEmpty) {
    debugPrint('[WALLET_PROVIDER] Invalid member params: userId=${params.userId}, householdId=${params.householdId}');
    return Stream.value(const <WalletModel>[]);
  }

  debugPrint('[WALLET_PROVIDER] Creating member wallet stream: userId=${params.userId}, householdId=${params.householdId}');
  return repository.watchWalletsForMember(
    householdId: params.householdId,
    userId: params.userId,
  );
});

// Get total balance
final totalBalanceProvider = FutureProvider.family<double, WalletParams>((ref, params) async {
  final repository = ref.watch(walletRepositoryProvider);
  return repository.getTotalBalance(params.userId, params.householdIds);
});

// Wallet Notifier for CRUD operations
class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  final WalletRepository _repository;

  WalletNotifier(this._repository) : super(const AsyncValue.data(null));

  // Create wallet
  Future<String?> createWallet(WalletModel wallet) async {
    state = const AsyncValue.loading();
    try {
      final walletId = await _repository.createWallet(wallet);
      state = const AsyncValue.data(null);
      return walletId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  // Update wallet
  Future<void> updateWallet(WalletModel wallet) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateWallet(wallet);
    });
  }

  // Update balance
  Future<void> updateBalance(String walletId, double newBalance) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateBalance(walletId, newBalance);
    });
  }

  // Archive wallet
  Future<void> archiveWallet(String walletId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.archiveWallet(walletId);
    });
  }

  // Delete wallet
  Future<void> deleteWallet(String walletId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteWallet(walletId);
    });
  }
}

// Wallet Notifier Provider
final walletNotifierProvider = StateNotifierProvider<WalletNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(repository);
});

// Helper class for parameters
class WalletParams {
  final String userId;
  final List<String> householdIds;

  WalletParams({required this.userId, required this.householdIds});
}

class WalletVisibilityParams {
  final String userId;
  final String householdId;

  const WalletVisibilityParams({
    required this.userId,
    required this.householdId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletVisibilityParams &&
        other.userId == userId &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(userId, householdId);
}

class HeadWalletParams {
  final String householdId;
  final String userId;

  const HeadWalletParams({
    required this.householdId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HeadWalletParams &&
        other.householdId == householdId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(householdId, userId);
}
