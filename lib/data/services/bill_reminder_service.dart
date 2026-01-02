import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/bill_repository.dart';
import '../repositories/notification_repository.dart';
import '../models/bill_model.dart';
import '../models/notification_model.dart';

/// Service to check bills and create reminder notifications
/// Should be called periodically (e.g., when user opens Home screen)
class BillReminderService {
  final BillRepository _billRepository;
  final NotificationRepository _notificationRepository;
  final FirebaseFirestore _firestore;

  BillReminderService({
    BillRepository? billRepository,
    NotificationRepository? notificationRepository,
    FirebaseFirestore? firestore,
  })  : _billRepository = billRepository ?? BillRepository(),
        _notificationRepository = notificationRepository ?? NotificationRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check bills and create reminders for a user
  /// Returns the number of notifications created
  Future<int> checkAndCreateRemindersForUser({
    required String userId,
    String? householdId,
  }) async {
    try {
      print('[BillReminder] Checking reminders for user: $userId, household: $householdId');

      // Get bills needing reminders
      final billsNeedingReminders = await _billRepository.getBillsNeedingReminders(
        userId: userId,
        householdId: householdId,
      );

      print('[BillReminder] Found ${billsNeedingReminders.length} bills needing reminders');

      int notificationsCreated = 0;

      for (final bill in billsNeedingReminders) {
        try {
          // Check if we already sent a reminder for this bill today
          final alreadySent = await _hasRecentNotification(
            userId: userId,
            billId: bill.billId,
            type: 'bill_reminder',
            withinHours: 24,
          );

          if (alreadySent) {
            print('[BillReminder] ⏭ Skipping reminder for bill: ${bill.name} (already sent today)');
            continue;
          }

          // Create reminder notification
          final notificationMessage = _buildReminderMessage(bill);
          final notificationTitle = _buildReminderTitle(bill);

          final notification = NotificationModel(
            notificationId: '', // Will be auto-generated
            userId: userId,
            type: 'bill_reminder',
            title: notificationTitle,
            message: notificationMessage,
            readStatus: false,
            sentAt: DateTime.now(),
            relatedEntityId: bill.billId,
            relatedEntityType: 'bill',
          );

          await _notificationRepository.createNotification(notification);
          notificationsCreated++;

          print('[BillReminder] ✓ Created reminder for bill: ${bill.name}');
        } catch (e) {
          print('[BillReminder] ❌ Error creating reminder for bill ${bill.billId}: $e');
          // Continue with other bills
        }
      }

      // Also check for overdue bills
      final overdueBills = await _billRepository.getOverdueBills(
        userId: userId,
        householdId: householdId,
      );

      print('[BillReminder] Found ${overdueBills.length} overdue bills');

      for (final bill in overdueBills) {
        try {
          // Check if we already sent an overdue notification for this bill today
          final alreadySent = await _hasRecentNotification(
            userId: userId,
            billId: bill.billId,
            type: 'bill_overdue',
            withinHours: 24,
          );

          if (alreadySent) {
            print('[BillReminder] ⏭ Skipping overdue notification for bill: ${bill.name} (already sent today)');
            continue;
          }

          // Create overdue notification
          final overdueMessage = _buildOverdueMessage(bill);
          final overdueTitle = _buildOverdueTitle(bill);

          final notification = NotificationModel(
            notificationId: '',
            userId: userId,
            type: 'bill_overdue',
            title: overdueTitle,
            message: overdueMessage,
            readStatus: false,
            sentAt: DateTime.now(),
            relatedEntityId: bill.billId,
            relatedEntityType: 'bill',
          );

          await _notificationRepository.createNotification(notification);
          notificationsCreated++;

          print('[BillReminder] ✓ Created overdue notification for bill: ${bill.name}');
        } catch (e) {
          print('[BillReminder] ❌ Error creating overdue notification for bill ${bill.billId}: $e');
          // Continue with other bills
        }
      }

      print('[BillReminder] ✓ Created $notificationsCreated notifications total');
      return notificationsCreated;
    } catch (e, stackTrace) {
      print('[BillReminder] ❌ ERROR in checkAndCreateRemindersForUser: $e');
      print('[BillReminder] StackTrace: $stackTrace');
      return 0;
    }
  }

  String _buildReminderTitle(BillModel bill) {
    return 'Upcoming Bill: ${bill.name}';
  }

  String _buildReminderMessage(BillModel bill) {
    final daysUntilDue = bill.daysUntilDue;

    if (daysUntilDue == 0) {
      return 'Due today: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    } else if (daysUntilDue == 1) {
      return 'Due tomorrow: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    } else {
      return 'Due in $daysUntilDue days: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    }
  }

  String _buildOverdueTitle(BillModel bill) {
    return 'Overdue Bill: ${bill.name}';
  }

  String _buildOverdueMessage(BillModel bill) {
    final daysOverdue = bill.daysUntilDue.abs();

    if (daysOverdue == 0) {
      return 'Overdue today: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    } else if (daysOverdue == 1) {
      return 'Overdue by 1 day: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    } else {
      return 'Overdue by $daysOverdue days: ${bill.currency} ${bill.amount.toStringAsFixed(2)}';
    }
  }

  /// Check if we've already sent a notification of this type for this bill recently
  Future<bool> _hasRecentNotification({
    required String userId,
    required String billId,
    required String type,
    int withinHours = 24,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: withinHours));

      final query = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .where('related_entity_id', isEqualTo: billId)
          .where('related_entity_type', isEqualTo: 'bill')
          .where('sent_at', isGreaterThan: Timestamp.fromDate(cutoff))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('[BillReminder] Error checking recent notifications: $e');
      return false; // If error, assume not sent (safe to send)
    }
  }
}
