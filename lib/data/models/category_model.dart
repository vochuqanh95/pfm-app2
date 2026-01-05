// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum định nghĩa loại danh mục
enum CategoryType { 
  income, // Thu nhập
  expense // Chi tiêu
}

// Enum định nghĩa phạm vi sử dụng của danh mục
enum CategoryScope { 
  builtIn, // Danh mục có sẵn trong hệ thống (không thể chỉnh sửa)
  household, // Danh mục của gia đình
  personal // Danh mục cá nhân
}

// Model đại diện cho danh mục giao dịch trong ứng dụng
class CategoryModel {
  final String categoryId; // ID duy nhất của danh mục
  final String? userId; // ID của user sở hữu (có thể null)
  final String? householdId; // ID của gia đình (nếu là danh mục gia đình)
  final String name; // Tên danh mục
  final CategoryType type; // Loại danh mục (thu nhập/chi tiêu)
  final CategoryScope scope; // Phạm vi sử dụng (built-in/household/personal)
  final String? parentId; // ID của danh mục cha (nếu là danh mục con)
  final bool isSystem; // Đánh dấu danh mục là danh mục hệ thống
  final String? iconName; // Tên icon hiển thị (có thể null)
  final int? colorIndex; // Index màu sắc hiển thị (có thể null)
  final bool archived; // Trạng thái lưu trữ (đã lưu trữ hay chưa)

  // Constructor khởi tạo CategoryModel
  CategoryModel({
    required this.categoryId,
    this.userId,
    this.householdId,
    required this.name,
    required this.type,
    this.scope = CategoryScope.personal, // Mặc định là danh mục cá nhân
    this.parentId,
    this.isSystem = false, // Mặc định không phải danh mục hệ thống
    this.iconName,
    this.colorIndex,
    this.archived = false, // Mặc định chưa lưu trữ
  });

  // Getter kiểm tra danh mục có phải là danh mục chia sẻ không
  bool get isShared => householdId != null || scope == CategoryScope.household;
  // Getter kiểm tra danh mục có phải là danh mục cá nhân không
  bool get isPersonal =>
      (userId != null && householdId == null) || scope == CategoryScope.personal;
  // Getter kiểm tra danh mục có phải là danh mục có sẵn không
  bool get isBuiltIn => scope == CategoryScope.builtIn || isSystem;

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành CategoryModel
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    final rawScope = data['scope'] ?? data['scope_type']; // Lấy scope (hỗ trợ cả 2 field name)
    final resolvedScope = _parseScope( // Parse scope từ dữ liệu
      rawScope,
      isSystem: data['is_system'] ?? data['isSystem'] ?? false, // Kiểm tra isSystem
      hasHousehold: (data['household_id'] ?? data['householdId']) != null, // Kiểm tra có household không
    );
    final rawColor = data['color_index'] ?? data['colorIndex']; // Lấy color index (hỗ trợ cả 2 field name)
    return CategoryModel(
      categoryId: doc.id, // Lấy ID từ document
      userId: data['user_id'] ?? data['userId'], // Lấy userId (hỗ trợ cả 2 format)
      householdId: data['household_id'] ?? data['householdId'], // Lấy householdId (hỗ trợ cả 2 format)
      name: data['name'] ?? '', // Lấy tên danh mục
      type: CategoryType.values.firstWhere( // Tìm loại danh mục phù hợp
        (e) => e.name == data['type'],
        orElse: () => CategoryType.expense, // Mặc định là expense
      ),
      scope: resolvedScope, // Gán scope đã parse
      parentId: data['parent_id'] ?? data['parentId'], // Lấy parentId (hỗ trợ cả 2 format)
      isSystem: data['is_system'] ?? data['isSystem'] ?? false, // Lấy isSystem
      iconName: data['icon_name'] ?? data['iconName'], // Lấy iconName (hỗ trợ cả 2 format)
      colorIndex: rawColor is num // Parse colorIndex
          ? rawColor.toInt()
          : int.tryParse(rawColor?.toString() ?? ''),
      archived: data['archived'] ?? false, // Lấy trạng thái lưu trữ
    );
  }

  // Method chuyển đổi CategoryModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, // ID user (snake_case)
      'userId': userId, // ID user (camelCase - tương thích)
      'household_id': householdId, // ID gia đình (snake_case)
      'householdId': householdId, // ID gia đình (camelCase - tương thích)
      'name': name, // Tên danh mục
      'type': type.name, // Loại danh mục (chuyển enum thành string)
      'scope': _scopeToString(scope), // Phạm vi (chuyển enum thành string)
      'parent_id': parentId, // ID danh mục cha (snake_case)
      'parentId': parentId, // ID danh mục cha (camelCase - tương thích)
      'is_system': isSystem || scope == CategoryScope.builtIn, // Trạng thái hệ thống (snake_case)
      'isSystem': isSystem || scope == CategoryScope.builtIn, // Trạng thái hệ thống (camelCase - tương thích)
      'icon_name': iconName, // Tên icon (snake_case)
      'iconName': iconName, // Tên icon (camelCase - tương thích)
      'color_index': colorIndex, // Index màu (snake_case)
      'colorIndex': colorIndex, // Index màu (camelCase - tương thích)
      'archived': archived, // Trạng thái lưu trữ
    };
  }

  // Method tạo bản copy của CategoryModel với các giá trị được cập nhật
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
    // Trả về CategoryModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId, // Dùng categoryId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      type: type ?? this.type, // Dùng type mới hoặc giữ nguyên
      scope: scope ?? this.scope, // Dùng scope mới hoặc giữ nguyên
      parentId: parentId ?? this.parentId, // Dùng parentId mới hoặc giữ nguyên
      isSystem: isSystem ?? this.isSystem, // Dùng isSystem mới hoặc giữ nguyên
      iconName: iconName ?? this.iconName, // Dùng iconName mới hoặc giữ nguyên
      colorIndex: colorIndex ?? this.colorIndex, // Dùng colorIndex mới hoặc giữ nguyên
      archived: archived ?? this.archived, // Dùng archived mới hoặc giữ nguyên
    );
  }
}

// Hàm helper parse scope từ dữ liệu thô
CategoryScope _parseScope(
  dynamic rawScope, {
  required bool isSystem, // Có phải là danh mục hệ thống không
  required bool hasHousehold, // Có liên kết với household không
}) {
  final scopeString = rawScope?.toString(); // Chuyển thành string
  switch (scopeString) {
    case 'built_in':
    case 'builtIn':
    case 'built-in':
      return CategoryScope.builtIn; // Trả về scope built-in
    case 'household':
      return CategoryScope.household; // Trả về scope household
    case 'personal':
      return CategoryScope.personal; // Trả về scope personal
  }

  // Xác định scope dựa trên các điều kiện
  if (isSystem) return CategoryScope.builtIn; // Là hệ thống thì built-in
  if (hasHousehold) return CategoryScope.household; // Có household thì household
  return CategoryScope.personal; // Mặc định là personal
}

// Hàm helper chuyển đổi CategoryScope thành string
String _scopeToString(CategoryScope scope) {
  switch (scope) {
    case CategoryScope.builtIn:
      return 'built_in'; // Trả về string cho built-in
    case CategoryScope.household:
      return 'household'; // Trả về string cho household
    case CategoryScope.personal:
      return 'personal'; // Trả về string cho personal
  }
}
