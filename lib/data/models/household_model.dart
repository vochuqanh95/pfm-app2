// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Model đại diện cho hộ gia đình trong ứng dụng
class HouseholdModel {
  final String householdId; // ID duy nhất của hộ gia đình
  final String ownerUserId; // ID của chủ hộ (người tạo gia đình)
  final String name; // Tên hộ gia đình
  final String inviteCode; // Mã mời để thêm thành viên vào gia đình
  final DateTime createdAt; // Thời gian tạo hộ gia đình
  final DateTime updatedAt; // Thời gian cập nhật gần nhất

  // Constructor khởi tạo HouseholdModel
  HouseholdModel({
    required this.householdId,
    required this.ownerUserId,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành HouseholdModel
  factory HouseholdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return HouseholdModel(
      householdId: doc.id, // Lấy ID từ document
      ownerUserId: data['owner_user_id'] ?? '', // Lấy ID chủ hộ
      name: data['name'] ?? '', // Lấy tên gia đình
      inviteCode: data['invite_code'] ?? '', // Lấy mã mời
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
    );
  }

  // Method chuyển đổi HouseholdModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'owner_user_id': ownerUserId, // ID chủ hộ
      'name': name, // Tên gia đình
      'invite_code': inviteCode, // Mã mời
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
      'updated_at': Timestamp.fromDate(updatedAt), // Chuyển DateTime thành Timestamp
    };
  }

  // Method tạo bản copy của HouseholdModel với các giá trị được cập nhật
  HouseholdModel copyWith({
    String? householdId,
    String? ownerUserId,
    String? name,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // Trả về HouseholdModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return HouseholdModel(
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      ownerUserId: ownerUserId ?? this.ownerUserId, // Dùng ownerUserId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      inviteCode: inviteCode ?? this.inviteCode, // Dùng inviteCode mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
    );
  }
}
