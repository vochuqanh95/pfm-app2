// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Model đại diện cho thông báo trong ứng dụng
class NotificationModel {
  final String notificationId; // ID duy nhất của thông báo
  final String userId; // ID của user nhận thông báo
  final String type; // Loại thông báo (VD: 'bill_reminder', 'debt_alert')
  final String title; // Tiêu đề ngắn gọn của thông báo
  final String message; // Nội dung chi tiết của thông báo
  final bool readStatus; // Trạng thái đã đọc (true) hoặc chưa đọc (false)
  final DateTime sentAt; // Thời gian gửi thông báo
  final DateTime? updatedAt; // Thời gian cập nhật gần nhất (có thể null)

  // Các trường tùy chọn để liên kết với các đối tượng liên quan (VD: hóa đơn, nợ)
  final String? relatedEntityId; // ID của đối tượng liên quan (có thể null)
  final String? relatedEntityType; // Loại đối tượng liên quan (VD: 'bill', 'debt', 'goal')

  // Constructor khởi tạo NotificationModel
  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.readStatus = false, // Mặc định chưa đọc
    required this.sentAt,
    this.updatedAt,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành NotificationModel
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return NotificationModel(
      notificationId: doc.id, // Lấy ID từ document
      userId: data['user_id'] ?? '', // Lấy userId
      type: data['type'] ?? '', // Lấy loại thông báo
      title: data['title'] ?? '', // Lấy tiêu đề
      message: data['message'] ?? '', // Lấy nội dung
      readStatus: data['read_status'] ?? false, // Lấy trạng thái đọc, mặc định false
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(), // Chuyển Timestamp thành DateTime
      relatedEntityId: data['related_entity_id'], // Lấy ID đối tượng liên quan
      relatedEntityType: data['related_entity_type'], // Lấy loại đối tượng liên quan
    );
  }

  // Method chuyển đổi NotificationModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    final map = {
      'user_id': userId, // ID user
      'type': type, // Loại thông báo
      'title': title, // Tiêu đề
      'message': message, // Nội dung
      'read_status': readStatus, // Trạng thái đọc
      'sent_at': Timestamp.fromDate(sentAt), // Chuyển DateTime thành Timestamp
    };

    // Chỉ thêm updatedAt nếu có giá trị
    if (updatedAt != null) {
      map['updated_at'] = Timestamp.fromDate(updatedAt!);
    }

    // Chỉ thêm relatedEntityId nếu có giá trị
    if (relatedEntityId != null) {
      map['related_entity_id'] = relatedEntityId!;
    }

    // Chỉ thêm relatedEntityType nếu có giá trị
    if (relatedEntityType != null) {
      map['related_entity_type'] = relatedEntityType!;
    }

    return map;
  }

  // Method tạo bản copy của NotificationModel với các giá trị được cập nhật
  NotificationModel copyWith({
    String? notificationId,
    String? userId,
    String? type,
    String? title,
    String? message,
    bool? readStatus,
    DateTime? sentAt,
    DateTime? updatedAt,
    String? relatedEntityId,
    String? relatedEntityType,
  }) {
    // Trả về NotificationModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId, // Dùng notificationId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      type: type ?? this.type, // Dùng type mới hoặc giữ nguyên
      title: title ?? this.title, // Dùng title mới hoặc giữ nguyên
      message: message ?? this.message, // Dùng message mới hoặc giữ nguyên
      readStatus: readStatus ?? this.readStatus, // Dùng readStatus mới hoặc giữ nguyên
      sentAt: sentAt ?? this.sentAt, // Dùng sentAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
      relatedEntityId: relatedEntityId ?? this.relatedEntityId, // Dùng relatedEntityId mới hoặc giữ nguyên
      relatedEntityType: relatedEntityType ?? this.relatedEntityType, // Dùng relatedEntityType mới hoặc giữ nguyên
    );
  }
}
