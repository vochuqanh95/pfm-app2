import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetPeriod { daily, weekly, monthly, yearly }

class BudgetModel {
  final String budgetId;
  final String? userId;
  final String? householdId;
  final String categoryId;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final double alertThreshold;
  final int lastNotifiedThreshold; // 0, 80, 90, or 100 - tracks which alert was last sent
  final String budgetType; // 'family' | 'member'
  final String? memberUserId;
  final String? memberDisplayName;
  final String? periodKey; // YYYY-MM
  final String walletScopeFilter; // e.g., household_shared
  final String? createdBy;
  final DateTime? createdAt;
  final bool archived;

  BudgetModel({
    required this.budgetId,
    this.userId,
    this.householdId,
    required this.categoryId,
    required this.amount,
    required this.startDate,
    required this.endDate,
    this.alertThreshold = 0.8,
    this.lastNotifiedThreshold = 0,
    this.budgetType = 'family',
    this.memberUserId,
    this.memberDisplayName,
    this.periodKey,
    this.walletScopeFilter = 'household_shared',
    this.createdBy,
    this.createdAt,
    this.archived = false,
  });

  bool get isShared => householdId != null;
  bool get isMemberBudget => budgetType == 'member';

  // Helper properties for screens
  String get id => budgetId; // Alias for budgetId
  String get name => 'Budget'; // Placeholder - ideally should be stored or computed from category
  String get category => categoryId; // Using categoryId as category for now
  BudgetPeriod get period {
    // Calculate period based on date range
    final days = endDate.difference(startDate).inDays;
    if (days <= 1) return BudgetPeriod.daily;
    if (days <= 7) return BudgetPeriod.weekly;
    if (days <= 31) return BudgetPeriod.monthly;
    return BudgetPeriod.yearly;
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawDisplayName = data['member_display_name'] ?? data['memberDisplayName'];
    return BudgetModel(
      budgetId: doc.id,
      userId: data['user_id'] ?? data['userId'],
      householdId: data['household_id'] ?? data['householdId'],
      categoryId: (data['category_id'] ?? data['categoryId'] ?? '') as String,
      amount: (data['amount'] ?? data['limit_amount'] ?? 0.0).toDouble(),
      startDate: (data['start_date'] as Timestamp?)?.toDate() ??
          (data['startDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ??
          (data['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      alertThreshold: (data['alert_threshold'] ?? 0.8).toDouble(),
      lastNotifiedThreshold: (data['last_notified_threshold'] ?? 0) as int,
      budgetType: (data['budget_type'] ?? 'family') as String,
      memberUserId: data['member_user_id'],
      memberDisplayName: (rawDisplayName is String ? rawDisplayName.trim() : rawDisplayName)
          as String?,
      periodKey: data['period_key'],
      walletScopeFilter:
          (data['wallet_scope_filter'] ?? 'household_shared') as String,
      createdBy: data['created_by'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      archived: data['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // snake_case writes for triggers/rules
      'user_id': userId,
      'household_id': householdId,
      'category_id': categoryId,
      'amount': amount,
      'limit_amount': amount,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'alert_threshold': alertThreshold,
      'last_notified_threshold': lastNotifiedThreshold,
      'budget_type': budgetType,
      'member_user_id': memberUserId,
      'member_display_name': memberDisplayName,
      'period_key': periodKey,
      'wallet_scope_filter': walletScopeFilter,
      'created_by': createdBy,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'archived': archived,
      // camelCase legacy writes
      'userId': userId,
      'householdId': householdId,
      'categoryId': categoryId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'limitAmount': amount,
      'memberDisplayName': memberDisplayName,
    };
  }

  BudgetModel copyWith({
    String? budgetId,
    String? userId,
    String? householdId,
    String? categoryId,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    double? alertThreshold,
    int? lastNotifiedThreshold,
    String? budgetType,
    String? memberUserId,
    String? memberDisplayName,
    String? periodKey,
    String? walletScopeFilter,
    String? createdBy,
    DateTime? createdAt,
    bool? archived,
  }) {
    return BudgetModel(
      budgetId: budgetId ?? this.budgetId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      lastNotifiedThreshold: lastNotifiedThreshold ?? this.lastNotifiedThreshold,
      budgetType: budgetType ?? this.budgetType,
      memberUserId: memberUserId ?? this.memberUserId,
      memberDisplayName: memberDisplayName ?? this.memberDisplayName,
      periodKey: periodKey ?? this.periodKey,
      walletScopeFilter: walletScopeFilter ?? this.walletScopeFilter,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }
}
