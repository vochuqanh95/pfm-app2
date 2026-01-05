// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Class định nghĩa các role (vai trò) của user trong hệ thống
class UserRoles {
  static const head = 'head'; // Vai trò chủ hộ (người quản lý)
  static const member = 'member'; // Vai trò thành viên
}

// Model đại diện cho thông tin người dùng trong ứng dụng
class UserModel {
  final String userId; // ID duy nhất của user
  final String name; // Tên hiển thị của user
  final String email; // Địa chỉ email của user
  final String currency; // Đơn vị tiền tệ user sử dụng (VD: USD, VND)
  final String language; // Ngôn ngữ hiển thị (VD: en, vi)
  final String role; // Vai trò của user (head hoặc member)
  final String? householdId; // ID của gia đình mà user thuộc về (có thể null)
  final bool twoFactorEnabled; // Trạng thái bật/tắt xác thực 2 yếu tố
  final DateTime createdAt; // Thời gian tạo tài khoản
  final DateTime updatedAt; // Thời gian cập nhật thông tin gần nhất

  // Constructor khởi tạo UserModel với các tham số bắt buộc và tùy chọn
  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.currency = 'USD', // Mặc định là USD
    this.language = 'en', // Mặc định là tiếng Anh
    this.role = UserRoles.member, // Mặc định là member
    this.householdId,
    this.twoFactorEnabled = false, // Mặc định tắt xác thực 2 yếu tố
    required this.createdAt,
    required this.updatedAt,
  });

  // Getter kiểm tra user có phải là chủ hộ không
  bool get isHead => role == UserRoles.head;
  // Getter kiểm tra user có phải là thành viên không
  bool get isMember => role == UserRoles.member;

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document

    // Khởi tạo biến lưu timestamp
    Timestamp? createdTimestamp;
    Timestamp? updatedTimestamp;

    // Lấy giá trị createdAt hoặc created_at từ Firestore (hỗ trợ cả 2 format)
    final createdValue = data['createdAt'] ?? data['created_at'];
    // Lấy giá trị updatedAt hoặc updated_at từ Firestore (hỗ trợ cả 2 format)
    final updatedValue = data['updatedAt'] ?? data['updated_at'];

    // Kiểm tra và gán giá trị nếu là Timestamp
    if (createdValue is Timestamp) {
      createdTimestamp = createdValue;
    }
    if (updatedValue is Timestamp) {
      updatedTimestamp = updatedValue;
    }

    // Tạo và trả về UserModel từ dữ liệu Firestore
    return UserModel(
      userId: doc.id, // Lấy ID từ document
      name: data['name'] ?? '', // Lấy tên, mặc định rỗng nếu null
      email: data['email'] ?? '', // Lấy email, mặc định rỗng nếu null
      currency: data['currency'] ?? 'USD', // Lấy currency, mặc định USD
      language: data['language'] ?? 'en', // Lấy language, mặc định en
      role: data['role'] ?? UserRoles.member, // Lấy role, mặc định member
      householdId: (data['householdId'] ?? data['household_id']) as String?, // Lấy householdId (hỗ trợ cả 2 format)
      twoFactorEnabled: (data['twoFactorEnabled'] ?? data['two_factor_enabled']) as bool? ?? false, // Lấy trạng thái 2FA
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: updatedTimestamp?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
    );
  }

  // Method chuyển đổi UserModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    final createdTimestamp = Timestamp.fromDate(createdAt); // Chuyển DateTime thành Timestamp
    final updatedTimestamp = Timestamp.fromDate(updatedAt); // Chuyển DateTime thành Timestamp
    return {
      'name': name, // Tên user
      'email': email, // Email user
      'currency': currency, // Đơn vị tiền tệ
      'language': language, // Ngôn ngữ
      'role': role, // Vai trò
      'householdId': householdId, // ID gia đình (camelCase)
      'household_id': householdId, // ID gia đình (snake_case - tương thích)
      'twoFactorEnabled': twoFactorEnabled, // Trạng thái 2FA (camelCase)
      'two_factor_enabled': twoFactorEnabled, // Trạng thái 2FA (snake_case - tương thích)
      'createdAt': createdTimestamp, // Thời gian tạo (camelCase)
      'updatedAt': updatedTimestamp, // Thời gian cập nhật (camelCase)
      'created_at': createdTimestamp, // Thời gian tạo (snake_case - tương thích)
      'updated_at': updatedTimestamp, // Thời gian cập nhật (snake_case - tương thích)
    };
  }

  // Method tạo bản copy của UserModel với các giá trị được cập nhật
  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? currency,
    String? language,
    String? role,
    String? householdId,
    bool? twoFactorEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // Trả về UserModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return UserModel(
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      email: email ?? this.email, // Dùng email mới hoặc giữ nguyên
      currency: currency ?? this.currency, // Dùng currency mới hoặc giữ nguyên
      language: language ?? this.language, // Dùng language mới hoặc giữ nguyên
      role: role ?? this.role, // Dùng role mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled, // Dùng twoFactorEnabled mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
    );
  }
}
