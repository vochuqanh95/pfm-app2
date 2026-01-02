import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_rule_model.dart';
import '../models/transaction_model.dart';
import '../repositories/recurring_rule_repository.dart';
import '../repositories/transaction_repository.dart';
import 'wallet_balance_service.dart';

/// Service to process recurring transactions
/// Call processDueRules() periodically to generate transactions from active rules
class RecurringTransactionService {
  final RecurringRuleRepository _ruleRepository;
  final TransactionRepository _transactionRepository;
  final WalletBalanceService _walletBalanceService;

  RecurringTransactionService({
    RecurringRuleRepository? ruleRepository,
    TransactionRepository? transactionRepository,
    WalletBalanceService? walletBalanceService,
  })  : _ruleRepository = ruleRepository ?? RecurringRuleRepository(),
        _transactionRepository = transactionRepository ?? TransactionRepository(),
        _walletBalanceService = walletBalanceService ?? WalletBalanceService();

  /// Process all due recurring rules and generate transactions
  /// Returns the number of transactions generated
  Future<int> processDueRules({
    required DateTime now,
    required String userId,
    String? householdId,
  }) async {
    try {
      print('[RecurringTxn] Processing due rules for date: $now, userId: $userId, householdId: $householdId');

      // Get all rules that are due for this user/household
      final dueRules = await _ruleRepository.getRulesDueToday(
        userId: userId,
        householdId: householdId,
      );
      print('[RecurringTxn] Found ${dueRules.length} due rules');

      int generatedCount = 0;

      for (final rule in dueRules) {
        try {
          // Check if rule is still valid
          if (!rule.isValid) {
            print('[RecurringTxn] Skipping invalid rule: ${rule.ruleId}');
            // Deactivate the rule
            if (rule.ruleId != null) {
              await _ruleRepository.toggleActive(rule.ruleId!, false);
            }
            continue;
          }

          // Validate that we have template data
          if (rule.templateAmount == null ||
              rule.templateCategoryId == null ||
              rule.templateType == null ||
              rule.templateUserId == null ||
              rule.templateCurrency == null) {
            print('[RecurringTxn] ⚠️ Skipping rule ${rule.ruleId}: Missing template data');
            continue;
          }

          print('[RecurringTxn] Generating transaction for rule: ${rule.ruleId}');

          // Generate a new transaction using the template data
          try {
            String? transactionId;

            if (rule.templateType == 'expense') {
              transactionId = await _walletBalanceService.applyExpenseTransaction(
                walletId: rule.walletId,
                amount: rule.templateAmount!,
                currency: rule.templateCurrency!,
                userId: rule.templateUserId!,
                categoryId: rule.templateCategoryId!,
                householdId: rule.templateHouseholdId,
                note: rule.templateNote != null && rule.templateNote!.isNotEmpty
                    ? 'Recurring: ${rule.templateNote}'
                    : 'Recurring transaction',
                date: now,
                recurringRuleId: rule.ruleId,
                actorUserId: rule.templateActorUserId,
                actorDisplayName: rule.templateActorDisplayName,
                actorRole: rule.templateActorRole,
              );
            } else if (rule.templateType == 'income') {
              transactionId = await _walletBalanceService.applyIncomeTransaction(
                walletId: rule.walletId,
                amount: rule.templateAmount!,
                currency: rule.templateCurrency!,
                userId: rule.templateUserId!,
                categoryId: rule.templateCategoryId!,
                householdId: rule.templateHouseholdId,
                note: rule.templateNote != null && rule.templateNote!.isNotEmpty
                    ? 'Recurring: ${rule.templateNote}'
                    : 'Recurring transaction',
                date: now,
                recurringRuleId: rule.ruleId,
                actorUserId: rule.templateActorUserId,
                actorDisplayName: rule.templateActorDisplayName,
                actorRole: rule.templateActorRole,
              );
            }

            if (transactionId != null && transactionId.isNotEmpty) {
              generatedCount++;
              print('[RecurringTxn] ✓ Generated transaction: $transactionId');
            }
          } catch (e) {
            print('[RecurringTxn] ❌ Error creating transaction for rule ${rule.ruleId}: $e');
            // Continue to update next date even if transaction fails
          }

          // Update the rule's next date
          final nextOccurrence = rule.calculateNextOccurrence();
          if (rule.ruleId != null) {
            await _ruleRepository.updateNextDate(rule.ruleId!, nextOccurrence);
            print('[RecurringTxn] ✓ Updated next date to: $nextOccurrence');
          }

        } catch (e) {
          print('[RecurringTxn] ❌ Error processing rule ${rule.ruleId}: $e');
          // Continue with next rule even if one fails
        }
      }

      print('[RecurringTxn] ✓ Completed. Generated $generatedCount transactions');
      return generatedCount;
    } catch (e, stackTrace) {
      print('[RecurringTxn] ❌ ERROR in processDueRules: $e');
      print('[RecurringTxn] StackTrace: $stackTrace');
      return 0;
    }
  }

  /// Get all active recurring rules for a wallet
  Future<List<RecurringRuleModel>> getActiveRulesForWallet(String walletId) async {
    return await _ruleRepository.getActiveRecurringRules(walletId);
  }

  /// Cancel a recurring rule
  Future<void> cancelRule(String ruleId) async {
    await _ruleRepository.toggleActive(ruleId, false);
  }

  /// Resume a recurring rule
  Future<void> resumeRule(String ruleId) async {
    await _ruleRepository.toggleActive(ruleId, true);
  }

  /// Delete a recurring rule permanently
  Future<void> deleteRule(String ruleId) async {
    await _ruleRepository.deleteRecurringRule(ruleId);
  }
}
