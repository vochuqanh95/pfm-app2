import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/wallet_model.dart';
import 'auth_provider.dart';
import 'household_provider.dart';
import 'debt_provider.dart';
import 'wallet_provider.dart';

class NetWorthSummary {
  final double totalAssets;
  final double totalDebts;

  const NetWorthSummary({
    required this.totalAssets,
    required this.totalDebts,
  });

  double get netWorth => totalAssets - totalDebts;

  factory NetWorthSummary.zero() =>
      const NetWorthSummary(totalAssets: 0, totalDebts: 0);
}

class UserNetWorthParams {
  final String userId;
  final String householdId;

  const UserNetWorthParams({
    required this.userId,
    required this.householdId,
  });
}

final familyNetWorthProvider = Provider.autoDispose
    .family<AsyncValue<NetWorthSummary>, HeadWalletParams>((ref, params) {
  if (params.householdId.isEmpty) {
    debugPrint('[NET_WORTH] family: missing householdId, returning zero');
    return AsyncValue.data(NetWorthSummary.zero());
  }

  final wallets = ref.watch(headWalletsProvider(params));
  final debts = ref.watch(householdDebtsStreamProvider(params.householdId));

  return _combineNetWorthValues(
    wallets: wallets,
    debts: debts,
    householdFilterId: params.householdId,
    logLabel: 'family',
  );
});

final homeFinancesProvider =
    Provider.autoDispose<AsyncValue<NetWorthSummary>>((ref) {
  final userAsync = ref.watch(authUserProvider);

  ref.onDispose(() {
    final disposedUserId = userAsync.asData?.value?.userId ?? 'null';
    debugPrint('[NET_WORTH] Provider disposed (user=$disposedUserId)');
  });

  if (userAsync.isLoading) {
    debugPrint('[NET_WORTH] Auth loading, returning zero summary');
    return AsyncValue.data(NetWorthSummary.zero());
  }

  if (userAsync.hasError) {
    debugPrint('[NET_WORTH] Auth error: ${userAsync.error}');
    return AsyncValue.error(
        userAsync.error!, userAsync.stackTrace ?? StackTrace.current);
  }

  final user = userAsync.value;
  if (user == null) {
    debugPrint('[NET_WORTH] No user, returning zero summary');
    return AsyncValue.data(NetWorthSummary.zero());
  }

  final householdId = ref.watch(
    currentUserHouseholdProvider.select(
      (householdAsync) =>
          householdAsync.asData?.value?.householdId ?? user.householdId ?? '',
    ),
  );

  debugPrint(
      '[NET_WORTH] Loading net worth: user=${user.userId}, household=$householdId, role=${user.role}');

  final walletProvider = householdId.isEmpty
      ? personalWalletsStreamProvider(user.userId)
      : user.isHead
          ? headWalletsProvider(
              HeadWalletParams(
                householdId: householdId,
                userId: user.userId,
              ),
            )
          : memberWalletsProvider(
              WalletVisibilityParams(
                userId: user.userId,
                householdId: householdId,
              ),
            );

  final personalDebts = ref.watch(userDebtsStreamProvider(user.userId));
  final householdDebts = householdId.isNotEmpty && user.isHead
      ? ref.watch(householdDebtsStreamProvider(householdId))
      : const AsyncValue.data(<DebtModel>[]);

  final wallets = ref.watch(walletProvider);
  final debts = _mergeDebtValues(
    personal: personalDebts,
    household: householdDebts,
    logLabel: 'home',
  );

  return _combineNetWorthValues(
    wallets: wallets,
    debts: debts,
    householdFilterId: householdId.isEmpty ? null : householdId,
    logLabel: 'home',
  );
});

final userNetWorthProvider = Provider.autoDispose
    .family<AsyncValue<NetWorthSummary>, UserNetWorthParams>((ref, params) {
  if (params.userId.isEmpty) {
    debugPrint('[NET_WORTH] user: missing userId, returning zero');
    return AsyncValue.data(NetWorthSummary.zero());
  }

  if (params.householdId.isEmpty) {
    final debts = ref.watch(userDebtsStreamProvider(params.userId));
    return _combineNetWorthValues(
      wallets: const AsyncValue.data(<WalletModel>[]),
      debts: debts,
      logLabel: 'user',
    );
  }

  final walletParams = WalletVisibilityParams(
    userId: params.userId,
    householdId: params.householdId,
  );
  final wallets = ref.watch(memberWalletsProvider(walletParams));
  final debts = ref.watch(userDebtsStreamProvider(params.userId));

  return _combineNetWorthValues(
    wallets: wallets,
    debts: debts,
    householdFilterId: params.householdId,
    logLabel: 'user',
  );
});

AsyncValue<NetWorthSummary> _combineNetWorthValues({
  required AsyncValue<List<WalletModel>> wallets,
  required AsyncValue<List<DebtModel>> debts,
  required String logLabel,
  String? householdFilterId,
}) {
  if (wallets.hasError) {
    debugPrint('[NET_WORTH] Wallet stream error ($logLabel): ${wallets.error}');
    return AsyncValue.error(
        wallets.error!, wallets.stackTrace ?? StackTrace.current);
  }

  if (debts.hasError) {
    debugPrint('[NET_WORTH] Debt stream error ($logLabel): ${debts.error}');
    return AsyncValue.error(
        debts.error!, debts.stackTrace ?? StackTrace.current);
  }

  final walletList = wallets.value ?? const <WalletModel>[];
  final debtList = debts.value ?? const <DebtModel>[];

  if (wallets.isLoading && walletList.isEmpty) {
    debugPrint(
        '[NET_WORTH] Waiting for wallet data ($logLabel), returning zero for now');
  }

  final summary = _buildSummary(
    walletList,
    debtList,
    householdFilterId: householdFilterId,
  );

  debugPrint(
    '[NET_WORTH] Emitting summary ($logLabel): wallets=${walletList.length} debts=${debtList.length} assets=${summary.totalAssets} totalDebts=${summary.totalDebts} net=${summary.netWorth}',
  );

  return AsyncValue.data(summary);
}

NetWorthSummary _buildSummary(
  List<WalletModel> wallets,
  List<DebtModel> debts, {
  String? householdFilterId,
}) {
  final filteredWallets = householdFilterId == null
      ? wallets
      : wallets
          .where((wallet) => wallet.householdId == householdFilterId)
          .toList();

  double assets = 0;
  double debtWallets = 0;
  for (final wallet in filteredWallets) {
    final isDebtWallet = wallet.isDebt || wallet.type == WalletType.card;
    if (isDebtWallet) {
      debtWallets += wallet.balance.abs();
    } else {
      assets += wallet.balance;
    }
  }

  final debtTotal =
      debts.fold<double>(0, (sum, debt) => sum + debt.remainingAmount);
  return NetWorthSummary(
      totalAssets: assets, totalDebts: debtTotal + debtWallets);
}

AsyncValue<List<DebtModel>> _mergeDebtValues({
  required AsyncValue<List<DebtModel>> personal,
  required AsyncValue<List<DebtModel>> household,
  required String logLabel,
}) {
  if (personal.hasError) {
    return AsyncValue.error(
        personal.error!, personal.stackTrace ?? StackTrace.current);
  }
  if (household.hasError) {
    return AsyncValue.error(
        household.error!, household.stackTrace ?? StackTrace.current);
  }

  final personalList = personal.value ?? const <DebtModel>[];
  final householdList = household.value ?? const <DebtModel>[];
  final combined = <DebtModel>[...personalList, ...householdList];

  debugPrint(
      '[NET_WORTH] Debts merged ($logLabel): personal=${personalList.length} household=${householdList.length} total=${combined.length}');

  return AsyncValue.data(combined);
}
