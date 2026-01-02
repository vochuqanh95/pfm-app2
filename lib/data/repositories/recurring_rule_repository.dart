import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_rule_model.dart';

class RecurringRuleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'recurring_rules';

  // Create recurring rule
  Future<String> createRecurringRule(RecurringRuleModel rule) async {
    final docRef = await _firestore.collection(_collection).add(rule.toFirestore());
    return docRef.id;
  }

  // Get recurring rule by ID
  Future<RecurringRuleModel?> getRecurringRuleById(String ruleId) async {
    final doc = await _firestore.collection(_collection).doc(ruleId).get();
    if (!doc.exists) return null;
    return RecurringRuleModel.fromFirestore(doc);
  }

  // Get all recurring rules for wallet
  Future<List<RecurringRuleModel>> getRecurringRulesForWallet(String walletId) async {
    final query = await _firestore
        .collection(_collection)
        .where('wallet_id', isEqualTo: walletId)
        .orderBy('next_date')
        .get();

    return query.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList();
  }

  // Get active recurring rules (not disabled)
  Future<List<RecurringRuleModel>> getActiveRecurringRules(String walletId) async {
    final query = await _firestore
        .collection(_collection)
        .where('wallet_id', isEqualTo: walletId)
        .where('is_active', isEqualTo: true)
        .orderBy('next_date')
        .get();

    return query.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList();
  }

  // Get rules due today or before for a specific user/household
  Future<List<RecurringRuleModel>> getRulesDueToday({
    required String userId,
    String? householdId,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final List<RecurringRuleModel> allRules = [];

    // CRITICAL: Firestore security rules require EITHER user_id OR household_id filter
    // We fetch both household and personal rules separately, then merge

    // 1. Fetch household rules (if user belongs to a household)
    if (householdId != null && householdId.isNotEmpty) {
      try {
        final householdQuery = await _firestore
            .collection(_collection)
            .where('household_id', isEqualTo: householdId)
            .where('is_active', isEqualTo: true)
            .where('next_date', isLessThanOrEqualTo: Timestamp.fromDate(today))
            .get();

        allRules.addAll(
          householdQuery.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList(),
        );
      } catch (e) {
        print('[RecurringRuleRepository] Failed to fetch household rules: $e');
      }
    }

    // 2. Fetch personal rules (user_id = current user)
    try {
      final personalQuery = await _firestore
          .collection(_collection)
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .where('next_date', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      allRules.addAll(
        personalQuery.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList(),
      );
    } catch (e) {
      print('[RecurringRuleRepository] Failed to fetch personal rules: $e');
    }

    // 3. Remove duplicates by rule ID (in case a rule appears in both queries)
    final uniqueRules = <String, RecurringRuleModel>{};
    for (final rule in allRules) {
      if (rule.ruleId != null && rule.ruleId!.isNotEmpty) {
        uniqueRules[rule.ruleId!] = rule;
      }
    }

    return uniqueRules.values.toList();
  }

  // Update recurring rule
  Future<void> updateRecurringRule(RecurringRuleModel rule) async {
    await _firestore
        .collection(_collection)
        .doc(rule.ruleId)
        .update(rule.toFirestore());
  }

  // Update next date
  Future<void> updateNextDate(String ruleId, DateTime nextDate) async {
    await _firestore.collection(_collection).doc(ruleId).update({
      'next_date': Timestamp.fromDate(nextDate),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Toggle active status
  Future<void> toggleActive(String ruleId, bool isActive) async {
    await _firestore.collection(_collection).doc(ruleId).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete recurring rule
  Future<void> deleteRecurringRule(String ruleId) async {
    await _firestore.collection(_collection).doc(ruleId).delete();
  }

  // Stream recurring rules for wallet
  Stream<List<RecurringRuleModel>> streamRecurringRules(String walletId) {
    return _firestore
        .collection(_collection)
        .where('wallet_id', isEqualTo: walletId)
        .orderBy('next_date')
        .snapshots()
        .map((query) => query.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList());
  }

  // Stream recurring rules for user (template_user_id matches userId)
  Stream<List<RecurringRuleModel>> streamRecurringRulesForUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('template_user_id', isEqualTo: userId)
        .orderBy('next_date')
        .snapshots()
        .map((query) => query.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList());
  }

  // Stream recurring rules for household
  Stream<List<RecurringRuleModel>> streamRecurringRulesForHousehold(String householdId) {
    return _firestore
        .collection(_collection)
        .where('template_household_id', isEqualTo: householdId)
        .orderBy('next_date')
        .snapshots()
        .map((query) => query.docs.map((doc) => RecurringRuleModel.fromFirestore(doc)).toList());
  }
}
