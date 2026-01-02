// MANUAL TEST CHECKLIST – CATEGORY PROVIDER LIFECYCLE
// T1 Launch with Head user:
//    - Open Add Transaction -> categories load (no permission denied).
// T2 Logout -> Login as Member:
//    - Immediately open Add Transaction -> categories load without pressing "Reload".
//    - Logcat must NOT show queries for the previous user_id.
// T3 Repeat logout/login 3 times:
//    - No growing number of category listeners.
//    - Check logcat for "[CATEGORY_PROVIDER] Disposed" messages.
// T4 Create personal expense category:
//    - Saved successfully (no permission denied).
//    - Appears immediately in picker list.
// T5 Household custom category (if supported by product):
//    - Head can create.
//    - Member can read but cannot create/edit/delete (verify denied).
// T6 Verify no crash:
//    - If app still closes, provide the captured FATAL EXCEPTION stacktrace.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import 'auth_provider.dart';

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository());

// CRITICAL: Auth gate provider to invalidate category streams on auth changes
// This prevents stale streams from querying with old user_ids after logout/login
final _categoryAuthGateProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.valueOrNull?.uid;

  debugPrint('[CATEGORY_AUTH_GATE] Current auth user: ${userId ?? "null"}');

  // When auth changes, this provider rebuilds and all dependent providers refresh
  return userId;
});

class CategoryQueryParams {
  final CategoryType type;
  final String userId;
  final String? householdId;

  const CategoryQueryParams({
    required this.type,
    required this.userId,
    required this.householdId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryQueryParams &&
        other.type == type &&
        other.userId == userId &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(type, userId, householdId);
}

class CategoryLookupParams {
  final String categoryId;
  final String userId;
  final String? householdId;

  const CategoryLookupParams({
    required this.categoryId,
    required this.userId,
    required this.householdId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryLookupParams &&
        other.categoryId == categoryId &&
        other.userId == userId &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(categoryId, userId, householdId);
}

final categoriesStreamProvider = StreamProvider.family
    .autoDispose<List<CategoryModel>, CategoryQueryParams>((ref, params) {
  // CRITICAL: Watch auth gate to auto-invalidate when auth changes (logout/login)
  // This ensures stale streams for old users are disposed
  final currentAuthUserId = ref.watch(_categoryAuthGateProvider);

  // Defensive check: if params.userId doesn't match current auth, return empty
  // This handles race conditions during logout/login transitions
  if (currentAuthUserId != null && params.userId != currentAuthUserId) {
    debugPrint(
        '[CATEGORY_PROVIDER] Auth mismatch: params.userId=${params.userId} != currentAuth=$currentAuthUserId, returning empty');
    return Stream.value(<CategoryModel>[]);
  }

  final repository = ref.watch(categoryRepositoryProvider);
  debugPrint(
      '[CATEGORY_PROVIDER] Created stream for type=${params.type.name} user=${params.userId} household=${params.householdId}');
  ref.onDispose(() {
    debugPrint(
        '[CATEGORY_PROVIDER] Disposed stream for type=${params.type.name} user=${params.userId} household=${params.householdId}');
  });
  return Stream.multi((controller) {
    final sub = repository
        .streamCategoriesByType(
          type: params.type,
          userId: params.userId,
          householdId: params.householdId,
        )
        .listen(
      controller.add,
      onError: (error, stackTrace) {
        debugPrint(
            '[CATEGORY_PROVIDER] stream error type=${params.type.name} user=${params.userId} household=${params.householdId} error=$error');
        controller.add(const <CategoryModel>[]);
      },
    );
    controller.onCancel = () async {
      await sub.cancel();
    };
  });
});

final categoryByIdProvider = FutureProvider.family
    .autoDispose<CategoryModel?, CategoryLookupParams>((ref, params) async {
  // Watch auth gate for consistency
  ref.watch(_categoryAuthGateProvider);

  final repository = ref.watch(categoryRepositoryProvider);
  debugPrint(
      '[CATEGORY_PROVIDER] Lookup category=${params.categoryId} user=${params.userId} household=${params.householdId}');
  return repository.getCategoryByIdScoped(
    categoryId: params.categoryId,
    userId: params.userId,
    householdId: params.householdId,
  );
});

class CategoryNameMapParams {
  final String userId;
  final String? householdId;

  const CategoryNameMapParams({
    required this.userId,
    required this.householdId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryNameMapParams &&
        other.userId == userId &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(userId, householdId);
}

/// Lightweight map of categoryId -> categoryName to avoid per-row lookups.
final categoryNameMapProvider =
    Provider.family.autoDispose<Map<String, String>, CategoryNameMapParams>((ref, params) {
  // Watch auth gate to ensure map refreshes on auth changes
  ref.watch(_categoryAuthGateProvider);

  final repository = ref.watch(categoryRepositoryProvider);
  final builtInExpense = repository.builtInsByType(CategoryType.expense);
  final builtInIncome = repository.builtInsByType(CategoryType.income);

  final expenseCats = ref
          .watch(
            categoriesStreamProvider(
              CategoryQueryParams(
                type: CategoryType.expense,
                userId: params.userId,
                householdId: params.householdId,
              ),
            ),
          )
          .value ??
      const <CategoryModel>[];
  final incomeCats = ref
          .watch(
            categoriesStreamProvider(
              CategoryQueryParams(
                type: CategoryType.income,
                userId: params.userId,
                householdId: params.householdId,
              ),
            ),
          )
          .value ??
      const <CategoryModel>[];

  final map = <String, String>{
    for (final cat in [...builtInExpense, ...builtInIncome, ...expenseCats, ...incomeCats])
      cat.categoryId: cat.name,
  };
  return map;
});
