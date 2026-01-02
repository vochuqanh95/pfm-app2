import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletType { cash, bank, card, ewallet }

enum WalletScope { personal, householdShared, memberPrivate }

extension WalletScopeX on WalletScope {
  String get rawValue {
    switch (this) {
      case WalletScope.householdShared:
        return 'household_shared';
      case WalletScope.memberPrivate:
        return 'member_private';
      case WalletScope.personal:
      default:
        return 'personal';
    }
  }

  static WalletScope fromRaw(String? raw, {String? householdId}) {
    switch (raw) {
      case 'household_shared':
        return WalletScope.householdShared;
      case 'member_private':
        return WalletScope.memberPrivate;
      case 'personal':
        return WalletScope.personal;
      default:
        return (householdId?.isNotEmpty ?? false)
            ? WalletScope.householdShared
            : WalletScope.personal;
    }
  }
}

class WalletModel {
  final String walletId;
  final String? userId;
  final String? householdId;
  final String name;
  final WalletType type;
  final WalletScope scope;
  final String currency;
  final double openingBalance;
  final double balance;
  final bool archived;
  final bool isDebt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WalletModel({
    required this.walletId,
    this.userId,
    this.householdId,
    required this.name,
    required this.type,
    this.scope = WalletScope.personal,
    this.currency = 'USD',
    this.openingBalance = 0.0,
    this.balance = 0.0,
    this.archived = false,
    this.isDebt = false,
    required this.createdAt,
    this.updatedAt,
  });

  String? get ownerUserId => userId;
  bool get isShared => scope == WalletScope.householdShared;
  bool get isMemberPrivate => scope == WalletScope.memberPrivate;
  bool get isPersonal => scope == WalletScope.personal;

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final householdId = (data['householdId'] ?? data['household_id']) as String?;
    final userId = (data['userId'] ?? data['user_id']) as String?;
    final createdAtRaw = data['createdAt'] ?? data['created_at'];
    final updatedAtRaw = data['updatedAt'] ?? data['updated_at'];

    return WalletModel(
      walletId: doc.id,
      userId: userId,
      householdId: householdId,
      name: data['name'] ?? '',
      type: WalletType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => WalletType.cash,
      ),
      scope: WalletScopeX.fromRaw(
        data['scope'],
        householdId: householdId,
      ),
      currency: data['currency'] ?? 'USD',
      openingBalance: (data['openingBalance'] ?? data['opening_balance'] ?? 0.0).toDouble(),
      balance: (data['balance'] ?? 0.0).toDouble(),
      archived: data['archived'] ?? false,
      isDebt: data['isDebt'] ?? data['is_debt'] ?? false,
      createdAt: (createdAtRaw as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (updatedAtRaw as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final createdTimestamp = Timestamp.fromDate(createdAt);
    final updatedTimestamp = updatedAt != null ? Timestamp.fromDate(updatedAt!) : null;
    return {
      'walletId': walletId,
      // Write both snake and camel for compatibility
      'user_id': userId,
      'userId': userId,
      'household_id': householdId,
      'householdId': householdId,
      'name': name,
      'type': type.name,
      'scope': scope.rawValue,
      'currency': currency,
      'openingBalance': openingBalance,
      'opening_balance': openingBalance,
      'balance': balance,
      'archived': archived,
      'isDebt': isDebt,
      'is_debt': isDebt,
      'createdAt': createdTimestamp,
      'created_at': createdTimestamp,
      'updatedAt': updatedTimestamp,
      'updated_at': updatedTimestamp,
    };
  }

  WalletModel copyWith({
    String? walletId,
    String? userId,
    String? householdId,
    String? name,
    WalletType? type,
    WalletScope? scope,
    String? currency,
    double? openingBalance,
    double? balance,
    bool? archived,
    bool? isDebt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      currency: currency ?? this.currency,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
      archived: archived ?? this.archived,
      isDebt: isDebt ?? this.isDebt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
