import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/notification_model.dart';
import '../repositories/debt_repository.dart';
import '../repositories/notification_repository.dart';

class DebtReminderService {
  final DebtRepository _debtRepository;
  final NotificationRepository _notificationRepository;
  final FirebaseFirestore _firestore;

  DebtReminderService({
    DebtRepository? debtRepository,
    NotificationRepository? notificationRepository,
    FirebaseFirestore? firestore,
  })  : _debtRepository = debtRepository ?? DebtRepository(),
        _notificationRepository =
            notificationRepository ?? NotificationRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<int> checkDebtsAndNotify({
    required String userId,
    String? householdId,
  }) async {
    try {
      debugPrint(
          '[DebtReminder] Checking debts for reminders user=$userId household=$householdId');

      final dueSoonDebts = await _debtRepository.getDebtsNeedingReminders(
        userId: userId,
        householdId: householdId,
      );
      final overdueDebts = await _debtRepository.getOverdueDebts(
        userId: userId,
        householdId: householdId,
      );

      debugPrint(
          '[DebtReminder] Found ${dueSoonDebts.length} due soon, ${overdueDebts.length} overdue');

      int notificationsCreated = 0;

      for (final debt in dueSoonDebts) {
        final alreadySent = await _hasRecentNotification(
          userId: userId,
          debtId: debt.debtId,
          type: 'debt_reminder',
          withinHours: 24,
        );

        if (alreadySent) {
          debugPrint(
              '[DebtReminder] Skipping reminder for ${debt.name} (already sent)');
          continue;
        }

        final notification = NotificationModel(
          notificationId: '',
          userId: userId,
          type: 'debt_reminder',
          title: _buildReminderTitle(debt),
          message: _buildReminderMessage(debt),
          readStatus: false,
          sentAt: DateTime.now(),
          relatedEntityId: debt.debtId,
          relatedEntityType: 'debt',
        );

        await _notificationRepository.createNotification(notification);
        notificationsCreated++;
        debugPrint('[DebtReminder] ✓ Reminder created for debt ${debt.name}');
      }

      for (final debt in overdueDebts) {
        final alreadySent = await _hasRecentNotification(
          userId: userId,
          debtId: debt.debtId,
          type: 'debt_overdue',
          withinHours: 24,
        );

        if (alreadySent) {
          debugPrint(
              '[DebtReminder] Skipping overdue alert for ${debt.name} (already sent)');
          continue;
        }

        final notification = NotificationModel(
          notificationId: '',
          userId: userId,
          type: 'debt_overdue',
          title: _buildOverdueTitle(debt),
          message: _buildOverdueMessage(debt),
          readStatus: false,
          sentAt: DateTime.now(),
          relatedEntityId: debt.debtId,
          relatedEntityType: 'debt',
        );

        await _notificationRepository.createNotification(notification);
        notificationsCreated++;
        debugPrint('[DebtReminder] ✓ Overdue alert created for ${debt.name}');
      }

      debugPrint(
          '[DebtReminder] ✓ Total notifications created: $notificationsCreated');
      return notificationsCreated;
    } catch (e, st) {
      debugPrint('[DebtReminder] ERROR running reminders: $e\n$st');
      return 0;
    }
  }

  String _buildReminderTitle(DebtModel debt) {
    return 'Debt due soon: ${debt.name}';
  }

  String _buildReminderMessage(DebtModel debt) {
    if (debt.dueDate == null) return 'Upcoming debt: ${debt.name}';
    final days = debt.dueDate!.difference(DateTime.now()).inDays.clamp(0, 365);
    if (days == 0) {
      return 'Due today: \$${debt.totalDueEstimate.toStringAsFixed(2)}';
    }
    if (days == 1) {
      return 'Due tomorrow: \$${debt.totalDueEstimate.toStringAsFixed(2)}';
    }
    return 'Due in $days days: \$${debt.totalDueEstimate.toStringAsFixed(2)}';
  }

  String _buildOverdueTitle(DebtModel debt) {
    return 'Overdue debt: ${debt.name}';
  }

  String _buildOverdueMessage(DebtModel debt) {
    if (debt.dueDate == null) {
      return 'Debt overdue: \$${debt.totalDueEstimate.toStringAsFixed(2)} outstanding';
    }
    final days = DateTime.now().difference(debt.dueDate!).inDays;
    final daysOverdue = days < 1 ? 0 : days;
    if (daysOverdue == 0) {
      return 'Due today: \$${debt.totalDueEstimate.toStringAsFixed(2)} outstanding';
    }
    if (daysOverdue == 1) {
      return 'Overdue by 1 day: \$${debt.totalDueEstimate.toStringAsFixed(2)} outstanding';
    }
    return 'Overdue by $daysOverdue days: \$${debt.totalDueEstimate.toStringAsFixed(2)} outstanding';
  }

  Future<bool> _hasRecentNotification({
    required String userId,
    required String debtId,
    required String type,
    int withinHours = 24,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: withinHours));

      final query = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .where('related_entity_id', isEqualTo: debtId)
          .where('related_entity_type', isEqualTo: 'debt')
          .where('sent_at', isGreaterThan: Timestamp.fromDate(cutoff))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[DebtReminder] Error checking recent notifications: $e');
      return false;
    }
  }
}
