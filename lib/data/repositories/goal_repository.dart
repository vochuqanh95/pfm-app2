import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/actor_utils.dart';
import '../models/goal_model.dart';
import '../models/goal_contribution_model.dart';
import '../models/wallet_model.dart';
import '../models/user_model.dart';
import '../services/wallet_balance_service.dart';

class GoalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletBalanceService _balanceService;
  static const String _collection = 'goals';

  GoalRepository({WalletBalanceService? balanceService})
      : _balanceService = balanceService ?? WalletBalanceService();

  // Create goal
  Future<String> createGoal(GoalModel goal) async {
    final docRef = await _firestore.collection(_collection).add(goal.toFirestore());
    return docRef.id;
  }

  // Get goal by ID
  Future<GoalModel?> getGoalById(String goalId) async {
    final doc = await _firestore.collection(_collection).doc(goalId).get();
    if (!doc.exists) return null;
    return GoalModel.fromFirestore(doc);
  }

  // Get personal goals for user
  Future<List<GoalModel>> getPersonalGoals(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('scope', isEqualTo: 'personal')
        .orderBy('deadline')
        .get();

    return query.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
  }

  // Get household goals
  Future<List<GoalModel>> getHouseholdGoals(String householdId) async {
    final query = await _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('scope', isEqualTo: 'family')
        .orderBy('deadline')
        .get();

    return query.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
  }

  // Get all goals for user
  Future<List<GoalModel>> getAllGoalsForUser(String userId, List<String> householdIds) async {
    final List<GoalModel> allGoals = [];

    // Get personal goals
    final personalGoals = await getPersonalGoals(userId);
    allGoals.addAll(personalGoals);

    // Get household goals
    for (var householdId in householdIds) {
      final householdGoals = await getHouseholdGoals(householdId);
      allGoals.addAll(householdGoals);
    }

    // Sort by deadline (null dates go to end)
    allGoals.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });
    return allGoals;
  }

  // Get active goals (not completed)
  Future<List<GoalModel>> getActiveGoals({
    String? userId,
    String? householdId,
  }) async {
    Query query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.orderBy('deadline').get();
    final goals = result.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();

    // Filter out completed goals
    return goals.where((goal) => !goal.isCompleted).toList();
  }

  // Get completed goals
  Future<List<GoalModel>> getCompletedGoals({
    String? userId,
    String? householdId,
  }) async {
    Query query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    final result = await query.get();
    final goals = result.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();

    // Filter completed goals
    return goals.where((goal) => goal.isCompleted).toList();
  }

  // Update goal
  Future<void> updateGoal(GoalModel goal) async {
    await _firestore.collection(_collection).doc(goal.goalId).update(goal.toFirestore());
  }

  // Update goal progress
  Future<void> updateGoalProgress(String goalId, double savedAmount) async {
    await _firestore.collection(_collection).doc(goalId).update({
      'saved_amount': savedAmount,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete goal
  Future<void> deleteGoal(String goalId) async {
    await _firestore.collection(_collection).doc(goalId).delete();
  }

  // Stream goals
  Stream<List<GoalModel>> streamGoals({
    String? userId,
    String? householdId,
  }) {
    Query query = _firestore.collection(_collection);

    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }
    if (householdId != null) {
      query = query.where('household_id', isEqualTo: householdId);
    }

    return query.orderBy('deadline').snapshots().map(
          (query) => query.docs.map((doc) => GoalModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<GoalModel>> streamFamilyGoals(String householdId) {
    // FIXED: Return Stream.value([]) instead of Stream.empty()
    if (householdId.isEmpty) return Stream.value(const <GoalModel>[]);
    return _firestore
        .collection(_collection)
        .where('household_id', isEqualTo: householdId)
        .where('scope', isEqualTo: 'family')
        .orderBy('deadline')
        .snapshots()
        .map((query) => query.docs.map(GoalModel.fromFirestore).toList());
  }

  Stream<List<GoalModel>> streamUserGoals(String userId) {
    // FIXED: Return Stream.value([]) instead of Stream.empty()
    if (userId.isEmpty) return Stream.value(const <GoalModel>[]);
    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('scope', isEqualTo: 'personal')
        .orderBy('deadline')
        .snapshots()
        .map((query) => query.docs.map(GoalModel.fromFirestore).toList());
  }

  // Add contribution to a goal (ENHANCED VERSION)
  // Creates: contribution record, transaction, updates wallet balance, updates goal savedAmount
  Future<void> addContribution({
    required String goalId,
    required double amount,
    required WalletModel wallet,
    required UserModel user,
  }) async {
    print('[GOAL_CONTRIB] ========== START ==========');
    print('[GOAL_CONTRIB] goalId: $goalId');
    print('[GOAL_CONTRIB] amount: \$${amount.toStringAsFixed(2)}');
    print('[GOAL_CONTRIB] walletId: ${wallet.walletId}, walletName: ${wallet.name}, balance: \$${wallet.balance.toStringAsFixed(2)}');
    print('[GOAL_CONTRIB] userId: ${user.userId}, name: ${user.name}, role: ${user.role}');

    // Validate amount
    if (amount <= 0) {
      print('[GOAL_CONTRIB] ❌ ERROR: Invalid amount: $amount');
      throw Exception('Contribution amount must be greater than 0');
    }
    print('[GOAL_CONTRIB] ✓ Amount valid: \$${amount.toStringAsFixed(2)}');

    final now = DateTime.now();

    // Determine wallet scope
    final walletScope = wallet.scope == WalletScope.householdShared ? 'household' : 'personal';
    print('[GOAL_CONTRIB] Wallet scope: $walletScope');

    // First, fetch goal to get its name and householdId
    print('[GOAL_CONTRIB] Fetching goal details...');
    final goalRef = _firestore.collection(_collection).doc(goalId);
    final goalSnap = await goalRef.get();

    if (!goalSnap.exists) {
      print('[GOAL_CONTRIB] ❌ ERROR: Goal not found');
      throw Exception('Goal not found');
    }

    final goalData = goalSnap.data() as Map<String, dynamic>;
    final goalName = goalData['name'] ?? 'Unknown';
    final goalHouseholdId = goalData['household_id'] ?? '';
    print('[GOAL_CONTRIB] ✓ Goal found: $goalName, householdId: $goalHouseholdId');

    // Use WalletBalanceService to handle the transaction with additional operations
    print('[GOAL_CONTRIB] Starting transaction via WalletBalanceService...');

    // Build actor info with smart display name
    final actor = buildActorInfo(user);

    try {
      await _balanceService.applyExpenseTransaction(
        walletId: wallet.walletId,
        amount: amount,
        currency: wallet.currency,
        userId: user.userId,
        householdId: goalHouseholdId,
        categoryId: 'goal_contribution',
        note: 'Goal contribution: $goalName',
        date: now,
        actorUserId: actor.userId,
        actorDisplayName: actor.displayName,
        actorRole: actor.role,
        goalId: goalId,
        additionalOperations: (txn, transactionId) async {
          print('[GOAL_CONTRIB] ➤ Executing additional operations in transaction...');

          // Create contribution record in subcollection
          print('[GOAL_CONTRIB] ➤ Creating contribution record...');
          final contribution = GoalContributionModel(
            id: '', // Will be auto-generated
            amount: amount,
            walletId: wallet.walletId,
            walletScope: walletScope,
            userId: user.userId,
            userDisplayName: actor.displayName,
            userRole: actor.role,
            createdAt: now,
          );

          final contributionRef = goalRef.collection('contributions').doc();
          print('[GOAL_CONTRIB]    Path: goals/$goalId/contributions/${contributionRef.id}');
          txn.set(contributionRef, contribution.toFirestore());
          print('[GOAL_CONTRIB]    ✓ Contribution record queued');

          // Update goal savedAmount (increment)
          print('[GOAL_CONTRIB] ➤ Updating goal saved_amount...');
          print('[GOAL_CONTRIB]    Increment saved_amount by: \$${amount.toStringAsFixed(2)}');
          txn.update(goalRef, {
            'saved_amount': FieldValue.increment(amount),
            'updated_at': FieldValue.serverTimestamp(),
          });
          print('[GOAL_CONTRIB]    ✓ Goal update queued');
        },
      );

      print('[GOAL_CONTRIB] ========== ✅ SUCCESS ==========');
      print('[GOAL_CONTRIB] All updates committed to Firestore');
    } catch (e, stackTrace) {
      print('[GOAL_CONTRIB] ========== ❌ TRANSACTION FAILED ==========');
      print('[GOAL_CONTRIB] Error: $e');
      print('[GOAL_CONTRIB] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
