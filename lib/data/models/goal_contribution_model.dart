// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Model đại diện cho một khoản đóng góp vào mục tiêu
class GoalContributionModel {
  final String id; // ID duy nhất của khoản đóng góp
  final double amount; // Số tiền đóng góp
  final String walletId; // ID của ví dùng để đóng góp
  final String walletScope; // Phạm vi ví: "household" (gia đình) hoặc "personal" (cá nhân)
  final String userId; // ID của user thực hiện đóng góp
  final String userDisplayName; // Tên hiển thị của user
  final String userRole; // Vai trò của user: "head" (chủ hộ) hoặc "member" (thành viên)
  final DateTime createdAt; // Thời gian tạo khoản đóng góp

  // Constructor khởi tạo GoalContributionModel
  const GoalContributionModel({
    required this.id,
    required this.amount,
    required this.walletId,
    required this.walletScope,
    required this.userId,
    required this.userDisplayName,
    required this.userRole,
    required this.createdAt,
  });

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành GoalContributionModel
  factory GoalContributionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return GoalContributionModel(
      id: doc.id, // Lấy ID từ document
      amount: (data['amount'] ?? 0.0).toDouble(), // Lấy số tiền đóng góp
      walletId: data['wallet_id'] ?? '', // Lấy ID ví
      walletScope: data['wallet_scope'] ?? 'personal', // Lấy phạm vi ví, mặc định personal
      userId: data['user_id'] ?? '', // Lấy ID user
      userDisplayName: data['user_display_name'] ?? '', // Lấy tên hiển thị
      userRole: data['user_role'] ?? 'member', // Lấy vai trò, mặc định member
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
    );
  }

  // Method chuyển đổi GoalContributionModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount, // Số tiền đóng góp
      'wallet_id': walletId, // ID ví
      'wallet_scope': walletScope, // Phạm vi ví
      'user_id': userId, // ID user
      'user_display_name': userDisplayName, // Tên hiển thị
      'user_role': userRole, // Vai trò
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
    };
  }

  // Method tạo bản copy của GoalContributionModel với các giá trị được cập nhật
  GoalContributionModel copyWith({
    String? id,
    double? amount,
    String? walletId,
    String? walletScope,
    String? userId,
    String? userDisplayName,
    String? userRole,
    DateTime? createdAt,
  }) {
    // Trả về GoalContributionModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return GoalContributionModel(
      id: id ?? this.id, // Dùng id mới hoặc giữ nguyên
      amount: amount ?? this.amount, // Dùng amount mới hoặc giữ nguyên
      walletId: walletId ?? this.walletId, // Dùng walletId mới hoặc giữ nguyên
      walletScope: walletScope ?? this.walletScope, // Dùng walletScope mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      userDisplayName: userDisplayName ?? this.userDisplayName, // Dùng userDisplayName mới hoặc giữ nguyên
      userRole: userRole ?? this.userRole, // Dùng userRole mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
    );
  }
}
