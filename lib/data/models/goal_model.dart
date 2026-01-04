// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Model đại diện cho mục tiêu tài chính trong ứng dụng
class GoalModel {
  final String goalId; // ID duy nhất của mục tiêu
  final String? userId; // ID của user sở hữu mục tiêu (có thể null)
  final String? householdId; // ID của gia đình (nếu là mục tiêu gia đình)
  final String name; // Tên mục tiêu
  final double targetAmount; // Số tiền mục tiêu cần đạt được
  final double savedAmount; // Số tiền đã tiết kiệm được
  final DateTime? deadline; // Hạn chót để đạt mục tiêu (có thể null)
  final DateTime createdAt; // Thời gian tạo mục tiêu
  final DateTime updatedAt; // Thời gian cập nhật gần nhất
  final String scope; // Phạm vi: 'personal' (cá nhân) hoặc 'family' (gia đình)
  final String? assignedUserDisplayName; // Tên hiển thị của người được gán (có thể null)

  // Constructor khởi tạo GoalModel với các tham số bắt buộc và tùy chọn
  GoalModel({
    required this.goalId,
    this.userId,
    this.householdId,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0.0, // Mặc định số tiền đã tiết kiệm là 0
    this.deadline,
    this.scope = 'personal', // Mặc định là mục tiêu cá nhân
    required this.createdAt,
    required this.updatedAt,
    this.assignedUserDisplayName,
  });

  // Getter kiểm tra mục tiêu có phải là mục tiêu chia sẻ không
  bool get isShared => householdId != null;
  // Getter tính phần trăm tiến độ đã hoàn thành
  double get progress => targetAmount > 0 ? (savedAmount / targetAmount) * 100 : 0;
  // Getter kiểm tra mục tiêu đã hoàn thành chưa
  bool get isCompleted => savedAmount >= targetAmount;

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành GoalModel
  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return GoalModel(
      goalId: doc.id, // Lấy ID từ document
      userId: data['user_id'], // Lấy userId
      householdId: data['household_id'], // Lấy householdId
      name: data['name'] ?? '', // Lấy tên mục tiêu, mặc định rỗng
      targetAmount: (data['target_amount'] ?? 0.0).toDouble(), // Lấy số tiền mục tiêu
      savedAmount: (data['saved_amount'] ?? 0.0).toDouble(), // Lấy số tiền đã tiết kiệm
      deadline: (data['deadline'] as Timestamp?)?.toDate(), // Chuyển Timestamp thành DateTime
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      scope: data['scope'] ?? (data['household_id'] != null ? 'family' : 'personal'), // Xác định scope
      assignedUserDisplayName: data['assigned_user_display_name'], // Lấy tên người được gán
    );
  }

  // Method chuyển đổi GoalModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, // ID user
      'household_id': householdId, // ID gia đình
      'name': name, // Tên mục tiêu
      'target_amount': targetAmount, // Số tiền mục tiêu
      'saved_amount': savedAmount, // Số tiền đã tiết kiệm
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null, // Chuyển DateTime thành Timestamp
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
      'updated_at': Timestamp.fromDate(updatedAt), // Chuyển DateTime thành Timestamp
      'scope': scope, // Phạm vi mục tiêu
      'assigned_user_display_name': assignedUserDisplayName, // Tên người được gán
    };
  }

  // Method tạo bản copy của GoalModel với các giá trị được cập nhật
  GoalModel copyWith({
    String? goalId,
    String? userId,
    String? householdId,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? scope,
    String? assignedUserDisplayName,
  }) {
    // Trả về GoalModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return GoalModel(
      goalId: goalId ?? this.goalId, // Dùng goalId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      targetAmount: targetAmount ?? this.targetAmount, // Dùng targetAmount mới hoặc giữ nguyên
      savedAmount: savedAmount ?? this.savedAmount, // Dùng savedAmount mới hoặc giữ nguyên
      deadline: deadline ?? this.deadline, // Dùng deadline mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
      scope: scope ?? this.scope, // Dùng scope mới hoặc giữ nguyên
      assignedUserDisplayName: assignedUserDisplayName ?? this.assignedUserDisplayName, // Dùng assignedUserDisplayName mới hoặc giữ nguyên
    );
  }
}
