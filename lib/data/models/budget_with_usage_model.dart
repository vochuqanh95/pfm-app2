import 'budget_model.dart';

class BudgetUsage {
  final String periodKey;
  final double spentAmount;
  final int lastAlertLevelSent;
  final DateTime? updatedAt;

  const BudgetUsage({
    required this.periodKey,
    required this.spentAmount,
    this.lastAlertLevelSent = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'period_key': periodKey,
        'spent_amount': spentAmount,
        'last_alert_level_sent': lastAlertLevelSent,
        'updated_at': updatedAt,
      };
}

/// Combines a budget with its calculated/denormalized usage data
class BudgetWithUsage {
  final BudgetModel budget;
  final BudgetUsage usage;

  const BudgetWithUsage({
    required this.budget,
    required this.usage,
  });

  // Computed properties
  double get remainingAmount => budget.amount - usage.spentAmount;

  double get usagePercent {
    if (budget.amount == 0) return 0.0;
    return (usage.spentAmount / budget.amount) * 100;
  }

  bool get isOverBudget => usage.spentAmount > budget.amount;

  bool get isNearLimit => usagePercent >= (budget.alertThreshold * 100);

  // Determine which threshold bracket we're in (0, 80, 90, 100)
  int get currentThreshold {
    if (usagePercent >= 100) return 100;
    if (usagePercent >= 90) return 90;
    if (usagePercent >= 80) return 80;
    return 0;
  }
}
