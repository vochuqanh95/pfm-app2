import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../models/budget_with_usage_model.dart';
import '../repositories/budget_repository.dart';

/// Service for computing budget usage from denormalized counters
class BudgetService {
  final BudgetRepository _budgetRepository;

  BudgetService({BudgetRepository? budgetRepository})
      : _budgetRepository = budgetRepository ?? BudgetRepository();

  String _resolvePeriodKey(BudgetModel budget) {
    if (budget.periodKey != null && budget.periodKey!.isNotEmpty) {
      return budget.periodKey!;
    }
    final dt = budget.startDate;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
  }

  Future<BudgetWithUsage> buildBudgetWithUsage(
    BudgetModel budget, {
    String? viewerRole,
    String? viewerUserId,
  }) async {
    final periodKey = _resolvePeriodKey(budget);
    BudgetUsage usage;
    try {
      usage = await _budgetRepository.getBudgetUsage(
            budgetId: budget.budgetId,
            periodKey: periodKey,
            householdId: budget.householdId,
            viewerRole: viewerRole,
            viewerUserId: viewerUserId,
          ) ??
          BudgetUsage(periodKey: periodKey, spentAmount: 0);
    } catch (e) {
      debugPrint(
          '[BUDGET_USAGE] fallback zero budgetId=${budget.budgetId} household=${budget.householdId} period=$periodKey viewer=$viewerUserId role=$viewerRole error=$e');
      usage = BudgetUsage(periodKey: periodKey, spentAmount: 0);
    }
    return BudgetWithUsage(budget: budget, usage: usage);
  }

  Future<List<BudgetWithUsage>> buildBudgetsWithUsage(
    List<BudgetModel> budgets, {
    String? viewerRole,
    String? viewerUserId,
  }) async {
    final List<BudgetWithUsage> results = [];
    for (final budget in budgets) {
      results.add(
        await buildBudgetWithUsage(
          budget,
          viewerRole: viewerRole,
          viewerUserId: viewerUserId,
        ),
      );
    }
    return results;
  }
}
