import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_contribution_model.dart';

class GoalContributionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get contributions subcollection reference for a goal
  CollectionReference<Map<String, dynamic>> _contributionsCollection(String goalId) {
    return _firestore.collection('goals').doc(goalId).collection('contributions');
  }

  /// Add a contribution to a goal
  Future<String> addContribution({
    required String goalId,
    required GoalContributionModel contribution,
  }) async {
    final docRef = await _contributionsCollection(goalId).add(contribution.toFirestore());
    return docRef.id;
  }

  /// Get contributions for a goal
  Future<List<GoalContributionModel>> getContributions(String goalId) async {
    final query = await _contributionsCollection(goalId)
        .orderBy('created_at', descending: true)
        .get();
    return query.docs.map((doc) => GoalContributionModel.fromFirestore(doc)).toList();
  }

  /// Stream contributions for a goal
  Stream<List<GoalContributionModel>> streamContributions(String goalId) {
    return _contributionsCollection(goalId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((query) => query.docs.map((doc) => GoalContributionModel.fromFirestore(doc)).toList());
  }

  /// Get total contributed by a specific user
  Future<double> getTotalContributedByUser({
    required String goalId,
    required String userId,
  }) async {
    final query = await _contributionsCollection(goalId)
        .where('user_id', isEqualTo: userId)
        .get();

    return query.docs.fold<double>(
      0.0,
      (total, doc) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        return total + amount;
      },
    );
  }
}
