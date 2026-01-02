import 'package:cloud_firestore/cloud_firestore.dart';

enum Frequency { daily, weekly, monthly, yearly }

class RecurringRuleModel {
  final String? ruleId;
  final String walletId;
  final Frequency frequency;
  final DateTime? nextDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Template transaction fields
  final double? templateAmount;
  final String? templateCategoryId;
  final String? templateType; // 'expense' or 'income'
  final String? templateUserId;
  final String? templateHouseholdId;
  final String? templateNote;
  final String? templateCurrency;
  final String? templateActorUserId;
  final String? templateActorDisplayName;
  final String? templateActorRole;

  RecurringRuleModel({
    this.ruleId,
    required this.walletId,
    required this.frequency,
    this.nextDate,
    this.endDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.templateAmount,
    this.templateCategoryId,
    this.templateType,
    this.templateUserId,
    this.templateHouseholdId,
    this.templateNote,
    this.templateCurrency,
    this.templateActorUserId,
    this.templateActorDisplayName,
    this.templateActorRole,
  });

  // Convert from Firestore
  factory RecurringRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringRuleModel(
      ruleId: doc.id,
      walletId: data['wallet_id'] ?? '',
      frequency: Frequency.values.firstWhere(
        (e) => e.toString().split('.').last == data['frequency'],
        orElse: () => Frequency.monthly,
      ),
      nextDate: (data['next_date'] as Timestamp?)?.toDate(),
      endDate: (data['end_date'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      templateAmount: (data['template_amount'] as num?)?.toDouble(),
      templateCategoryId: data['template_category_id'],
      templateType: data['template_type'],
      templateUserId: data['template_user_id'],
      templateHouseholdId: data['template_household_id'],
      templateNote: data['template_note'],
      templateCurrency: data['template_currency'],
      templateActorUserId: data['template_actor_user_id'],
      templateActorDisplayName: data['template_actor_display_name'],
      templateActorRole: data['template_actor_role'],
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'wallet_id': walletId,
      'frequency': frequency.toString().split('.').last,
      'next_date': nextDate != null ? Timestamp.fromDate(nextDate!) : null,
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'is_active': isActive,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'template_amount': templateAmount,
      'template_category_id': templateCategoryId,
      'template_type': templateType,
      'template_user_id': templateUserId,
      'template_household_id': templateHouseholdId,
      'template_note': templateNote,
      'template_currency': templateCurrency,
      'template_actor_user_id': templateActorUserId,
      'template_actor_display_name': templateActorDisplayName,
      'template_actor_role': templateActorRole,
    };
  }

  // Copy with
  RecurringRuleModel copyWith({
    String? ruleId,
    String? walletId,
    Frequency? frequency,
    DateTime? nextDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? templateAmount,
    String? templateCategoryId,
    String? templateType,
    String? templateUserId,
    String? templateHouseholdId,
    String? templateNote,
    String? templateCurrency,
    String? templateActorUserId,
    String? templateActorDisplayName,
    String? templateActorRole,
  }) {
    return RecurringRuleModel(
      ruleId: ruleId ?? this.ruleId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      nextDate: nextDate ?? this.nextDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      templateAmount: templateAmount ?? this.templateAmount,
      templateCategoryId: templateCategoryId ?? this.templateCategoryId,
      templateType: templateType ?? this.templateType,
      templateUserId: templateUserId ?? this.templateUserId,
      templateHouseholdId: templateHouseholdId ?? this.templateHouseholdId,
      templateNote: templateNote ?? this.templateNote,
      templateCurrency: templateCurrency ?? this.templateCurrency,
      templateActorUserId: templateActorUserId ?? this.templateActorUserId,
      templateActorDisplayName: templateActorDisplayName ?? this.templateActorDisplayName,
      templateActorRole: templateActorRole ?? this.templateActorRole,
    );
  }

  // Calculate next occurrence based on frequency
  DateTime calculateNextOccurrence() {
    if (nextDate == null) return DateTime.now();

    switch (frequency) {
      case Frequency.daily:
        return nextDate!.add(const Duration(days: 1));
      case Frequency.weekly:
        return nextDate!.add(const Duration(days: 7));
      case Frequency.monthly:
        return DateTime(
          nextDate!.year,
          nextDate!.month + 1,
          nextDate!.day,
        );
      case Frequency.yearly:
        return DateTime(
          nextDate!.year + 1,
          nextDate!.month,
          nextDate!.day,
        );
    }
  }

  // Check if rule is still valid (not past end date)
  bool get isValid {
    if (!isActive) return false;
    if (endDate == null) return true;
    return DateTime.now().isBefore(endDate!);
  }
}
