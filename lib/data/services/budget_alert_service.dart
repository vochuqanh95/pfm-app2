import '../models/budget_model.dart';
import '../repositories/budget_repository.dart';
import 'budget_service.dart';

/// Client-side helper kept for compatibility.
/// Real alerting now handled by Cloud Functions updating budget_usages.
class BudgetAlertService {
  final BudgetService _budgetService;
  final BudgetRepository _budgetRepository;

  BudgetAlertService({
    BudgetService? budgetService,
    BudgetRepository? budgetRepository,
  })  : _budgetService = budgetService ?? BudgetService(),
        _budgetRepository = budgetRepository ?? BudgetRepository();

  /// Client-side alert check DISABLED (Cloud Functions handle alerts)
  /// Returns 0 to avoid permission-denied errors from querying budgets by userId
  Future<int> checkBudgetsAndAlert({
    String? userId,
    String? householdId,
    String? periodKey,
  }) async {
    // NO-OP: Cloud Functions handle budget alerts automatically
    // Querying budgets here with userId causes permission-denied
    return 0;
  }

  Future<bool> checkBudgetById(String budgetId) async {
    final budget = await _budgetRepository.getBudgetById(budgetId);
    if (budget == null) return false;
    await _budgetService.buildBudgetWithUsage(budget);
    return true;
  }
}
