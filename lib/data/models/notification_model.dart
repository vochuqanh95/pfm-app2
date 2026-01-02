import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId;
  final String type;
  final String title; // Short subject line
  final String message;
  final bool readStatus;
  final DateTime sentAt;
  final DateTime? updatedAt;

  // Optional fields for linking to related entities (e.g., bills, debts)
  final String? relatedEntityId;
  final String? relatedEntityType; // e.g., 'bill', 'debt', 'goal'

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.readStatus = false,
    required this.sentAt,
    this.updatedAt,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userId: data['user_id'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      readStatus: data['read_status'] ?? false,
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      relatedEntityId: data['related_entity_id'],
      relatedEntityType: data['related_entity_type'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'read_status': readStatus,
      'sent_at': Timestamp.fromDate(sentAt),
    };

    if (updatedAt != null) {
      map['updated_at'] = Timestamp.fromDate(updatedAt!);
    }

    if (relatedEntityId != null) {
      map['related_entity_id'] = relatedEntityId!;
    }

    if (relatedEntityType != null) {
      map['related_entity_type'] = relatedEntityType!;
    }

    return map;
  }

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
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      readStatus: readStatus ?? this.readStatus,
      sentAt: sentAt ?? this.sentAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
    );
  }
}
