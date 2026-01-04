// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum định nghĩa vai trò của thành viên trong gia đình
enum MemberRole { 
  owner, // Chủ hộ (người sở hữu gia đình)
  member // Thành viên
}

// Class định nghĩa các trạng thái của thành viên
class MemberStatus {
  static const active = 'active'; // Đang hoạt động
  static const invited = 'invited'; // Đã mời nhưng chưa tham gia
  static const removed = 'removed'; // Đã bị xóa khỏi gia đình
}

// Model đại diện cho một thành viên trong hộ gia đình
class HouseholdMemberModel {
  final String id; // ID duy nhất của member record
  final String householdId; // ID của hộ gia đình
  final String userId; // ID của user
  final MemberRole role; // Vai trò của thành viên (owner/member)
  final String status; // Trạng thái của thành viên (active/invited/removed)
  final DateTime joinedAt; // Thời gian tham gia gia đình

  // Constructor khởi tạo HouseholdMemberModel
  const HouseholdMemberModel({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    this.status = MemberStatus.active, // Mặc định đang hoạt động
    required this.joinedAt,
  });

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành HouseholdMemberModel
  factory HouseholdMemberModel.fromDocument(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {}; // Lấy dữ liệu từ document
    return HouseholdMemberModel(
      id: doc.id, // Lấy ID từ document
      householdId: data['household_id'] ?? '', // Lấy householdId
      userId: data['user_id'] ?? '', // Lấy userId
      role: MemberRole.values.firstWhere( // Tìm vai trò phù hợp
        (e) => e.name == data['role'],
        orElse: () => MemberRole.member, // Mặc định là member
      ),
      status: (data['status'] ?? MemberStatus.active) as String, // Lấy trạng thái, mặc định active
      joinedAt: (data['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
    );
  }

  // Method chuyển đổi HouseholdMemberModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'household_id': householdId, // ID gia đình
      'user_id': userId, // ID user
      'role': role.name, // Vai trò (chuyển enum thành string)
      'status': status, // Trạng thái
      'joined_at': Timestamp.fromDate(joinedAt), // Chuyển DateTime thành Timestamp
    };
  }

  // Method tạo bản copy của HouseholdMemberModel với các giá trị được cập nhật
  HouseholdMemberModel copyWith({
    String? id,
    String? householdId,
    String? userId,
    MemberRole? role,
    String? status,
    DateTime? joinedAt,
  }) {
    // Trả về HouseholdMemberModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return HouseholdMemberModel(
      id: id ?? this.id, // Dùng id mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      role: role ?? this.role, // Dùng role mới hoặc giữ nguyên
      status: status ?? this.status, // Dùng status mới hoặc giữ nguyên
      joinedAt: joinedAt ?? this.joinedAt, // Dùng joinedAt mới hoặc giữ nguyên
    );
  }

  // Method static tạo document ID từ householdId và userId (format: householdId_userId)
  static String docId(String householdId, String userId) => '${householdId}_$userId';
}
