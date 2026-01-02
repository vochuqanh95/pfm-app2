import 'package:cloud_firestore/cloud_firestore.dart';

enum CategoryType { income, expense }

enum CategoryScope { builtIn, household, personal }

class CategoryModel {
  final String categoryId;
  final String? userId;
  final String? householdId;
  final String name;
  final CategoryType type;
  final CategoryScope scope;
  final String? parentId;
  final bool isSystem;
  final String? iconName;
  final int? colorIndex;
  final bool archived;

  CategoryModel({
    required this.categoryId,
    this.userId,
    this.householdId,
    required this.name,
    required this.type,
    this.scope = CategoryScope.personal,
    this.parentId,
    this.isSystem = false,
    this.iconName,
    this.colorIndex,
    this.archived = false,
  });

  bool get isShared => householdId != null || scope == CategoryScope.household;
  bool get isPersonal =>
      (userId != null && householdId == null) || scope == CategoryScope.personal;
  bool get isBuiltIn => scope == CategoryScope.builtIn || isSystem;

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawScope = data['scope'] ?? data['scope_type'];
    final resolvedScope = _parseScope(
      rawScope,
      isSystem: data['is_system'] ?? data['isSystem'] ?? false,
      hasHousehold: (data['household_id'] ?? data['householdId']) != null,
    );
    final rawColor = data['color_index'] ?? data['colorIndex'];
    return CategoryModel(
      categoryId: doc.id,
      userId: data['user_id'] ?? data['userId'],
      householdId: data['household_id'] ?? data['householdId'],
      name: data['name'] ?? '',
      type: CategoryType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CategoryType.expense,
      ),
      scope: resolvedScope,
      parentId: data['parent_id'] ?? data['parentId'],
      isSystem: data['is_system'] ?? data['isSystem'] ?? false,
      iconName: data['icon_name'] ?? data['iconName'],
      colorIndex: rawColor is num
          ? rawColor.toInt()
          : int.tryParse(rawColor?.toString() ?? ''),
      archived: data['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'userId': userId,
      'household_id': householdId,
      'householdId': householdId,
      'name': name,
      'type': type.name,
      'scope': _scopeToString(scope),
      'parent_id': parentId,
      'parentId': parentId,
      'is_system': isSystem || scope == CategoryScope.builtIn,
      'isSystem': isSystem || scope == CategoryScope.builtIn,
      'icon_name': iconName,
      'iconName': iconName,
      'color_index': colorIndex,
      'colorIndex': colorIndex,
      'archived': archived,
    };
  }

  CategoryModel copyWith({
    String? categoryId,
    String? userId,
    String? householdId,
    String? name,
    CategoryType? type,
    CategoryScope? scope,
    String? parentId,
    bool? isSystem,
    String? iconName,
    int? colorIndex,
    bool? archived,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      parentId: parentId ?? this.parentId,
      isSystem: isSystem ?? this.isSystem,
      iconName: iconName ?? this.iconName,
      colorIndex: colorIndex ?? this.colorIndex,
      archived: archived ?? this.archived,
    );
  }
}

CategoryScope _parseScope(
  dynamic rawScope, {
  required bool isSystem,
  required bool hasHousehold,
}) {
  final scopeString = rawScope?.toString();
  switch (scopeString) {
    case 'built_in':
    case 'builtIn':
    case 'built-in':
      return CategoryScope.builtIn;
    case 'household':
      return CategoryScope.household;
    case 'personal':
      return CategoryScope.personal;
  }

  if (isSystem) return CategoryScope.builtIn;
  if (hasHousehold) return CategoryScope.household;
  return CategoryScope.personal;
}

String _scopeToString(CategoryScope scope) {
  switch (scope) {
    case CategoryScope.builtIn:
      return 'built_in';
    case CategoryScope.household:
      return 'household';
    case CategoryScope.personal:
      return 'personal';
  }
}
