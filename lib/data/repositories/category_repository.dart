// MANUAL TEST CHECKLIST – CATEGORIES
// 1. Head: create personal expense; appears only for that account. Create household expense; visible to members. Long-press personal/household to delete -> disappears.
// 2. Member: create personal income works. Attempt household category -> denied or disabled; friendly error. Cannot delete head’s household category (permission error shown).
// 3. Relogin/switch accounts -> category lists refresh automatically.
// 4. Archived categories disappear from picker; existing transactions retain old labels.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category_model.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'categories';

  CategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Built-in categories stay local to avoid extra reads and security issues.
  List<CategoryModel> get _builtInCategories => [
        CategoryModel(
          categoryId: 'food',
          name: 'Food',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'food',
          colorIndex: 0,
        ),
        CategoryModel(
          categoryId: 'transport',
          name: 'Transport',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'transport',
          colorIndex: 1,
        ),
        CategoryModel(
          categoryId: 'shopping',
          name: 'Shopping',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'shopping',
          colorIndex: 2,
        ),
        CategoryModel(
          categoryId: 'bills',
          name: 'Bills',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'bills',
          colorIndex: 3,
        ),
        CategoryModel(
          categoryId: 'health',
          name: 'Health',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'health',
          colorIndex: 4,
        ),
        CategoryModel(
          categoryId: 'entertainment',
          name: 'Entertainment',
          type: CategoryType.expense,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'entertainment',
          colorIndex: 5,
        ),
        CategoryModel(
          categoryId: 'salary',
          name: 'Salary',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'salary',
          colorIndex: 0,
        ),
        CategoryModel(
          categoryId: 'bonus',
          name: 'Bonus',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'bonus',
          colorIndex: 1,
        ),
        CategoryModel(
          categoryId: 'investments',
          name: 'Investments',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'investments',
          colorIndex: 2,
        ),
        CategoryModel(
          categoryId: 'freelance',
          name: 'Freelance',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'freelance',
          colorIndex: 3,
        ),
        CategoryModel(
          categoryId: 'gifts',
          name: 'Gifts',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'gifts',
          colorIndex: 4,
        ),
        CategoryModel(
          categoryId: 'other_income',
          name: 'Other Income',
          type: CategoryType.income,
          scope: CategoryScope.builtIn,
          isSystem: true,
          iconName: 'other_income',
          colorIndex: 5,
        ),
      ];

  CategoryModel? _findBuiltIn(String id) {
    try {
      return _builtInCategories.firstWhere((c) => c.categoryId == id);
    } catch (_) {
      return null;
    }
  }

  List<CategoryModel> builtInsByType(CategoryType type) =>
      _builtInCategories.where((c) => c.type == type).toList();

  Stream<List<CategoryModel>> streamCategoriesByType({
    required CategoryType type,
    required String userId,
    required String? householdId,
  }) {
    // CRITICAL GUARD: Prevent querying with empty userId to avoid cross-user leaks
    if (userId.isEmpty) {
      debugPrint('[CATEGORY_REPO] Guard: userId is empty, returning empty stream');
      return Stream.value(<CategoryModel>[]);
    }

    final builtIns = builtInsByType(type);

    // Personal stream with error handling to prevent crashes
    final personalStream = _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.name)
        .where('scope', isEqualTo: 'personal')
        .where('user_id', isEqualTo: userId)
        .where('archived', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map(CategoryModel.fromFirestore).toList())
        .handleError((error) {
          debugPrint('[CATEGORY_REPO] Personal stream error (type=${type.name}, user=$userId): $error');
          // Return empty list on permission-denied to prevent crash
          return <CategoryModel>[];
        });

    // Household stream with error handling
    final householdStream =
        householdId == null || householdId.isEmpty
            ? Stream.value(<CategoryModel>[])
            : _firestore
                .collection(_collection)
                .where('type', isEqualTo: type.name)
                .where('scope', isEqualTo: 'household')
                .where('household_id', isEqualTo: householdId)
                .where('archived', isEqualTo: false)
                .snapshots()
                .map((snap) =>
                    snap.docs.map(CategoryModel.fromFirestore).toList())
                .handleError((error) {
                  debugPrint('[CATEGORY_REPO] Household stream error (type=${type.name}, household=$householdId): $error');
                  // Return empty list on permission-denied to prevent crash
                  return <CategoryModel>[];
                });

    debugPrint(
        '[CATEGORY_REPO] Stream categories type=${type.name} user=$userId household=$householdId');

    return _combineCategoryStreams(
      builtIns: builtIns,
      personalStream: personalStream,
      householdStream: householdStream,
      logLabel:
          'type=${type.name}, user=$userId, household=${householdId ?? '-'}',
    );
  }

  Future<String> createCustomCategory(CategoryModel category) async {
    if (category.scope == CategoryScope.builtIn ||
        category.isSystem == true) {
      throw ArgumentError('Cannot create built-in categories at runtime');
    }

    final isHousehold = category.scope == CategoryScope.household;
    final isPersonal = category.scope == CategoryScope.personal;
    if (isPersonal && (category.userId == null || category.userId!.isEmpty)) {
      throw ArgumentError('Personal category requires userId');
    }
    if (isHousehold &&
        (category.householdId == null || category.householdId!.isEmpty)) {
      throw ArgumentError('Household category requires householdId');
    }

    final data = category
        .copyWith(
          archived: false,
          isSystem: false,
          householdId: isPersonal ? null : category.householdId,
        )
        .toFirestore();

    debugPrint(
        '[CATEGORY_REPO] Creating custom category ${category.name} scope=${category.scope.name} user=${category.userId} household=${category.householdId}');

    try {
      final docRef = await _firestore
          .collection(_collection)
          .add({...data, 'archived': false});
      return docRef.id;
    } catch (e) {
      debugPrint('[CATEGORY_REPO] ERROR creating category: $e');
      rethrow;
    }
  }

  Future<void> updateCustomCategory(CategoryModel category) async {
    debugPrint(
        '[CATEGORY_REPO] Updating category ${category.categoryId} name=${category.name}');
    await _firestore
        .collection(_collection)
        .doc(category.categoryId)
        .update(category.toFirestore());
  }

  Future<void> archiveCategory(String categoryId) async {
    debugPrint('[CATEGORY_REPO] Archiving category $categoryId');
    await _firestore.collection(_collection).doc(categoryId).update({
      'archived': true,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<CategoryModel?> getCategoryByIdScoped({
    required String categoryId,
    required String userId,
    required String? householdId,
  }) async {
    final builtIn = _findBuiltIn(categoryId);
    if (builtIn != null) return builtIn;

    final doc =
        await _firestore.collection(_collection).doc(categoryId).get();
    if (!doc.exists) return null;
    final category = CategoryModel.fromFirestore(doc);

    final matchesUser = category.userId == userId;
    final matchesHousehold =
        householdId != null && householdId.isNotEmpty && category.householdId == householdId;
    if (category.scope == CategoryScope.personal && !matchesUser) {
      return null;
    }
    if (category.scope == CategoryScope.household && !matchesHousehold) {
      return null;
    }
    return category;
  }

  Stream<List<CategoryModel>> _combineCategoryStreams({
    required List<CategoryModel> builtIns,
    required Stream<List<CategoryModel>> personalStream,
    required Stream<List<CategoryModel>> householdStream,
    required String logLabel,
  }) {
    final controller = StreamController<List<CategoryModel>>();
    List<CategoryModel> personal = const [];
    List<CategoryModel> household = const [];

    void emit() {
      final combined = <CategoryModel>[
        ...builtIns,
        ...personal,
        ...household,
      ];
      controller.add(combined);
      debugPrint(
          '[CATEGORY_REPO] Emitting categories ($logLabel): builtIn=${builtIns.length}, personal=${personal.length}, household=${household.length}');
    }

    late final StreamSubscription<List<CategoryModel>> personalSub;
    late final StreamSubscription<List<CategoryModel>> householdSub;

    controller.onListen = () {
      personalSub = personalStream.listen((value) {
        personal = value;
        emit();
      });
      householdSub = householdStream.listen((value) {
        household = value;
        emit();
      });
    };

    controller.onCancel = () async {
      await personalSub.cancel();
      await householdSub.cancel();
    };

    return controller.stream;
  }
}
