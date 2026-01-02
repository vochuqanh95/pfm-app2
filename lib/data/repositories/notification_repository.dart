import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  // Create notification
  Future<String> createNotification(NotificationModel notification) async {
    final docRef = await _firestore.collection(_collection).add(notification.toFirestore());
    return docRef.id;
  }

  // Get notification by ID
  Future<NotificationModel?> getNotificationById(String notificationId) async {
    final doc = await _firestore.collection(_collection).doc(notificationId).get();
    if (!doc.exists) return null;
    return NotificationModel.fromFirestore(doc);
  }

  // Get notifications for user
  Future<List<NotificationModel>> getNotificationsForUser({
    required String userId,
    int limit = 50,
  }) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .orderBy('sent_at', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
  }

  // Get unread notifications
  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('read_status', isEqualTo: false)
        .orderBy('sent_at', descending: true)
        .get();

    return query.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    final query = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('read_status', isEqualTo: false)
        .get();

    return query.docs.length;
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'read_status': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final unreadNotifications = await getUnreadNotifications(userId);

    final batch = _firestore.batch();
    for (var notification in unreadNotifications) {
      batch.update(
        _firestore.collection(_collection).doc(notification.notificationId),
        {
          'read_status': true,
          'updated_at': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).delete();
  }

  // Delete all notifications for user
  Future<void> deleteAllNotifications(String userId) async {
    final notifications = await getNotificationsForUser(userId: userId);

    final batch = _firestore.batch();
    for (var notification in notifications) {
      batch.delete(_firestore.collection(_collection).doc(notification.notificationId));
    }

    await batch.commit();
  }

  // Stream notifications
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .orderBy('sent_at', descending: true)
        .limit(50)
        .snapshots()
        .map((query) => query.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
  }

  // Stream unread count
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .where('read_status', isEqualTo: false)
        .snapshots()
        .map((query) => query.docs.length);
  }

  // Send notification to all household members
  Future<void> sendToHouseholdMembers({
    required List<String> memberUserIds,
    required String type,
    required String title,
    required String message,
    String? relatedEntityId,
    String? relatedEntityType,
  }) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (var userId in memberUserIds) {
      final notification = NotificationModel(
        notificationId: '',
        userId: userId,
        type: type,
        title: title,
        message: message,
        readStatus: false,
        sentAt: DateTime.now(),
        relatedEntityId: relatedEntityId,
        relatedEntityType: relatedEntityType,
      );

      final docRef = _firestore.collection(_collection).doc();
      batch.set(docRef, {
        ...notification.toFirestore(),
        'sent_at': now,
      });
    }

    await batch.commit();
  }
}
