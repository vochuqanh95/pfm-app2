import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/wallet_balance_service.dart';

class WalletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletBalanceService _balanceService;
  static const String _collection = 'wallets';

  WalletRepository({WalletBalanceService? balanceService})
      : _balanceService = balanceService ?? WalletBalanceService();

  CollectionReference<Map<String, dynamic>> get _wallets => _firestore.collection(_collection);

  Query<Map<String, dynamic>> _walletBaseQuery() {
    return _wallets.where('archived', isEqualTo: false);
  }

  Future<String> createWallet(WalletModel wallet) async {
    final docRef = await _wallets.add(wallet.toFirestore());
    return docRef.id;
  }

  Future<WalletModel> createHouseholdWallet({
    required String householdId,
    required String name,
    required String type,
    required String currency,
    double openingBalance = 0,
    bool shared = true,
    String? ownerUserId,
    bool isDebt = false,
  }) async {
    final now = DateTime.now();
    final scope = shared ? WalletScope.householdShared : WalletScope.memberPrivate;
    final wallet = WalletModel(
      walletId: '',
      householdId: householdId,
      userId: shared ? null : ownerUserId,
      name: name,
      type: _parseWalletType(type),
      scope: scope,
      currency: currency,
      openingBalance: openingBalance,
      balance: openingBalance,
      archived: false,
      isDebt: isDebt,
      createdAt: now,
      updatedAt: now,
    );
    final docRef = await _wallets.add(wallet.toFirestore());
    return wallet.copyWith(walletId: docRef.id);
  }

  Future<WalletModel> createHouseholdSharedWallet({
    required String householdId,
    required String ownerUserId,
    required String name,
    String type = 'cash',
    String currency = 'USD',
  }) {
    return createHouseholdWallet(
      householdId: householdId,
      name: name,
      type: type,
      currency: currency,
      openingBalance: 0,
      shared: true,
      ownerUserId: ownerUserId,
    );
  }

  Future<WalletModel> createMemberPrivateWallet({
    required String householdId,
    required String ownerUserId,
    required String name,
    String type = 'cash',
    String currency = 'USD',
  }) {
    return createHouseholdWallet(
      householdId: householdId,
      name: name,
      type: type,
      currency: currency,
      openingBalance: 0,
      shared: false,
      ownerUserId: ownerUserId,
    );
  }

  Future<WalletModel> createPersonalWallet({
    required String ownerUserId,
    required String name,
    required String type,
    required String currency,
    double openingBalance = 0,
    bool isDebt = false,
  }) async {
    final now = DateTime.now();
    final wallet = WalletModel(
      walletId: '',
      householdId: null,
      userId: ownerUserId,
      name: name,
      type: _parseWalletType(type),
      scope: WalletScope.personal,
      currency: currency,
      openingBalance: openingBalance,
      balance: openingBalance,
      archived: false,
      isDebt: isDebt,
      createdAt: now,
      updatedAt: now,
    );
    final docRef = await _wallets.add(wallet.toFirestore());
    return wallet.copyWith(walletId: docRef.id);
  }

  Future<WalletModel?> getWalletById(String walletId) async {
    final doc = await _wallets.doc(walletId).get();
    if (!doc.exists) return null;
    return WalletModel.fromFirestore(doc);
  }

  Future<List<WalletModel>> getPersonalWallets(String userId) async {
    if (userId.isEmpty) return [];

    final snap = await _wallets
        .where('user_id', isEqualTo: userId)
        .where('scope', isEqualTo: 'personal')
        .where('archived', isEqualTo: false)
        .get();

    final wallets = snap.docs.map(WalletModel.fromFirestore).toList();
    debugPrint('[WALLET_REPO] getPersonalWallets: found ${wallets.length} wallets for user $userId');
    return wallets;
  }

  Future<List<WalletModel>> getHouseholdWallets(String householdId, {String? userId}) async {
    if (householdId.isEmpty) return [];

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    // Household shared wallets (snake_case only)
    futures.add(
      _wallets
          .where('household_id', isEqualTo: householdId)
          .where('scope', isEqualTo: 'household_shared')
          .where('archived', isEqualTo: false)
          .get(),
    );

    // Member private wallets if userId provided (snake_case only)
    if (userId != null && userId.isNotEmpty) {
      futures.add(
        _wallets
            .where('household_id', isEqualTo: householdId)
            .where('user_id', isEqualTo: userId)
            .where('scope', isEqualTo: 'member_private')
            .where('archived', isEqualTo: false)
            .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final allWallets = <WalletModel>[];
    for (final snap in snapshots) {
      allWallets.addAll(snap.docs.map(WalletModel.fromFirestore));
    }
    debugPrint('[WALLET_REPO] getHouseholdWallets: found ${allWallets.length} wallets for household $householdId');
    return allWallets;
  }

  Future<List<WalletModel>> getAllWalletsForUser(String userId, List<String> householdIds) async {
    final List<WalletModel> allWallets = [];
    final personalWallets = await getPersonalWallets(userId);
    allWallets.addAll(personalWallets);
    for (final householdId in householdIds) {
      final householdWallets = await getHouseholdWallets(householdId, userId: userId);
      allWallets.addAll(householdWallets);
    }
    return allWallets;
  }

  Future<void> updateWallet(WalletModel wallet) async {
    await _wallets.doc(wallet.walletId).update(wallet.toFirestore());
  }

  Future<void> updateBalance(String walletId, double newBalance) async {
    await _balanceService.updateWalletBalance(
      walletId: walletId,
      newBalance: newBalance,
    );
  }

  Future<void> archiveWallet(String walletId) async {
    await _wallets.doc(walletId).update({
      'archived': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWallet(String walletId) async {
    await _wallets.doc(walletId).delete();
  }

  Stream<List<WalletModel>> watchWalletsForHead({
    required String householdId,
    required String userId,
  }) {
    debugPrint('[WALLET_REPO] watchWalletsForHead: userId=$userId, householdId=$householdId');
    final personalStream = _personalWallets(userId);
    final sharedStream = _householdSharedWallets(householdId);
    final ownPrivateStream = _memberPrivateWallets(householdId: householdId, userId: userId);

    return _combineThreeWalletStreams(
      personalStream: personalStream,
      memberPrivateStream: ownPrivateStream,
      sharedStream: sharedStream,
    );
  }

  Stream<List<WalletModel>> watchWalletsForMember({
    required String householdId,
    required String userId,
  }) {
    debugPrint('[WALLET_REPO] watchWalletsForMember: userId=$userId, householdId=$householdId');
    final personalStream = _personalWallets(userId);
    final sharedStream = _householdSharedWallets(householdId);
    final privateStream = _memberPrivateWallets(householdId: householdId, userId: userId);

    return _combineThreeWalletStreams(
      personalStream: personalStream,
      memberPrivateStream: privateStream,
      sharedStream: sharedStream,
    );
  }

  Stream<List<WalletModel>> streamPersonalWallets(String userId) {
    return _personalWallets(userId);
  }

  Stream<List<WalletModel>> streamHouseholdWallets(String householdId, {String? userId}) {
    final sharedStream = _householdSharedWallets(householdId);
    final privateStream = (userId != null && userId.isNotEmpty)
        ? _memberPrivateWallets(householdId: householdId, userId: userId)
        : Stream.value(const <WalletModel>[]);

    return _combineWalletStreams(
      householdStream: sharedStream,
      personalStream: privateStream,
    );
  }

  Future<double> getTotalBalance(String userId, List<String> householdIds) async {
    final wallets = await getAllWalletsForUser(userId, householdIds);
    return wallets.fold<double>(0.0, (sum, wallet) => sum + wallet.balance);
  }

  Future<void> applyTransactionToWallet(TransactionModel transaction) async {
    // Delegate to WalletBalanceService based on transaction type
    if (transaction.type == TransactionType.transfer) {
      if (transaction.fromWalletId == null || transaction.toWalletId == null) return;
      await _balanceService.applyTransferTransaction(
        fromWalletId: transaction.fromWalletId!,
        toWalletId: transaction.toWalletId!,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        householdId: transaction.householdId,
        categoryId: transaction.categoryId,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    } else if (transaction.type == TransactionType.expense) {
      await _balanceService.applyExpenseTransaction(
        walletId: transaction.walletId,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        householdId: transaction.householdId,
        categoryId: transaction.categoryId,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        goalId: transaction.goalId,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    } else if (transaction.type == TransactionType.income) {
      await _balanceService.applyIncomeTransaction(
        walletId: transaction.walletId,
        amount: transaction.amount,
        currency: transaction.currency,
        userId: transaction.userId,
        householdId: transaction.householdId,
        categoryId: transaction.categoryId,
        note: transaction.note,
        date: transaction.date,
        actorUserId: transaction.actorUserId,
        actorDisplayName: transaction.actorDisplayName,
        actorRole: transaction.actorRole,
        imageUrl: transaction.imageUrl,
        recurringRuleId: transaction.recurringRuleId,
      );
    }
  }

  WalletType _parseWalletType(String value) {
    return WalletType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => WalletType.cash,
    );
  }

  // Personal wallets: query using snake_case only
  Stream<List<WalletModel>> _personalWallets(String userId) {
    if (userId.isEmpty) return Stream.value(const <WalletModel>[]);

    return _wallets
        .where('user_id', isEqualTo: userId)
        .where('scope', isEqualTo: 'personal')
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final wallets = snap.docs.map(WalletModel.fromFirestore).toList();
          debugPrint('[WALLET_REPO] Personal wallets: ${wallets.length}');
          return wallets;
        });
  }

  // Member-private wallets: query using snake_case only
  Stream<List<WalletModel>> _memberPrivateWallets({
    required String userId,
    required String householdId,
  }) {
    if (userId.isEmpty || householdId.isEmpty) {
      return Stream.value(const <WalletModel>[]);
    }

    return _wallets
        .where('household_id', isEqualTo: householdId)
        .where('user_id', isEqualTo: userId)
        .where('scope', isEqualTo: 'member_private')
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final wallets = snap.docs.map(WalletModel.fromFirestore).toList();
          debugPrint('[WALLET_REPO] Member-private wallets: ${wallets.length}');
          return wallets;
        });
  }

  // Household-shared wallets: query using snake_case only
  Stream<List<WalletModel>> _householdSharedWallets(String householdId) {
    if (householdId.isEmpty) return Stream.value(const <WalletModel>[]);

    return _wallets
        .where('household_id', isEqualTo: householdId)
        .where('scope', isEqualTo: 'household_shared')
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final wallets = snap.docs.map(WalletModel.fromFirestore).toList();
          debugPrint('[WALLET_REPO] Household-shared wallets: ${wallets.length}');
          return wallets;
        });
  }

  Stream<List<WalletModel>> _combineWalletStreams({
    required Stream<List<WalletModel>> householdStream,
    required Stream<List<WalletModel>> personalStream,
    List<WalletModel> Function(List<WalletModel>)? householdFilter,
    List<WalletModel> Function(List<WalletModel>)? personalFilter,
  }) {
    return Stream.multi((controller) {
      var latestHousehold = const <WalletModel>[];
      var latestPersonal = const <WalletModel>[];
      var hasHousehold = false;
      var hasPersonal = false;

      void emit() {
        if (controller.isClosed) return;
        // FIXED: Emit as soon as we have data from at least one stream
        if (!hasHousehold && !hasPersonal) return;
        final merged = <String, WalletModel>{};
        final householdList = householdFilter != null ? householdFilter(latestHousehold) : latestHousehold;
        final personalList = personalFilter != null ? personalFilter(latestPersonal) : latestPersonal;
        for (final wallet in householdList) {
          merged[wallet.walletId] = wallet;
        }
        for (final wallet in personalList) {
          merged[wallet.walletId] = wallet;
        }
        controller.add(merged.values.toList());
      }

      final subA = householdStream.listen(
        (value) {
          latestHousehold = value;
          hasHousehold = true;
          emit();
        },
        onError: controller.addError,
      );
      final subB = personalStream.listen(
        (value) {
          latestPersonal = value;
          hasPersonal = true;
          emit();
        },
        onError: controller.addError,
      );

      controller.onCancel = () async {
        await subA.cancel();
        await subB.cancel();
      };
    });
  }

  // Combine personal, member-private, and shared wallet streams for Head/Member
  Stream<List<WalletModel>> _combineThreeWalletStreams({
    required Stream<List<WalletModel>> personalStream,
    required Stream<List<WalletModel>> memberPrivateStream,
    required Stream<List<WalletModel>> sharedStream,
  }) {
    return Stream.multi((controller) {
      var latestPersonal = const <WalletModel>[];
      var latestMemberPrivate = const <WalletModel>[];
      var latestShared = const <WalletModel>[];
      var hasPersonal = false;
      var hasMemberPrivate = false;
      var hasShared = false;

      void emit() {
        if (controller.isClosed) return;
        if (!hasPersonal && !hasMemberPrivate && !hasShared) return;
        final merged = <String, WalletModel>{};
        for (final wallet in latestPersonal) {
          merged[wallet.walletId] = wallet;
        }
        for (final wallet in latestMemberPrivate) {
          merged[wallet.walletId] = wallet;
        }
        for (final wallet in latestShared) {
          merged[wallet.walletId] = wallet;
        }
        debugPrint('[WALLET_REPO] watchWallets combined: personal=${latestPersonal.length}, private=${latestMemberPrivate.length}, shared=${latestShared.length}, total=${merged.length}');
        controller.add(merged.values.toList());
      }

      final subPersonal = personalStream.listen(
        (value) {
          latestPersonal = value;
          hasPersonal = true;
          emit();
        },
        onError: (e) {
          debugPrint('[WALLET_REPO] ERROR: Personal stream failed: $e');
          latestPersonal = const [];
          hasPersonal = true;
          emit();
        },
      );

      final subMemberPrivate = memberPrivateStream.listen(
        (value) {
          latestMemberPrivate = value;
          hasMemberPrivate = true;
          emit();
        },
        onError: (e) {
          debugPrint('[WALLET_REPO] ERROR: Member private stream failed: $e');
          latestMemberPrivate = const [];
          hasMemberPrivate = true;
          emit();
        },
      );

      final subShared = sharedStream.listen(
        (value) {
          latestShared = value;
          hasShared = true;
          emit();
        },
        onError: (e) {
          debugPrint('[WALLET_REPO] ERROR: Shared stream failed: $e');
          latestShared = const [];
          hasShared = true;
          emit();
        },
      );

      controller.onCancel = () async {
        await subPersonal.cancel();
        await subMemberPrivate.cancel();
        await subShared.cancel();
      };
    });
  }
}
