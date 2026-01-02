# Firestore Schema & Naming Convention Guide

## Overview

This document establishes the naming conventions and schema guidelines for the Family Wealth app's Firestore database.

## Naming Conventions

### Field Names in Firestore

**Rule:** All Firestore field names MUST use `snake_case`.

**Examples:**
- ✅ `user_id`
- ✅ `household_id`
- ✅ `created_at`
- ✅ `updated_at`
- ✅ `read_status`
- ❌ `userId` (incorrect - do not use camelCase)
- ❌ `createdAt` (incorrect - do not use camelCase)

### Dart Model Properties

**Rule:** All Dart class properties MUST use `camelCase`.

**Examples:**
- ✅ `userId`
- ✅ `householdId`
- ✅ `createdAt`
- ✅ `updatedAt`
- ✅ `readStatus`
- ❌ `user_id` (incorrect - do not use snake_case in Dart)

## Mapping Between Dart and Firestore

### fromFirestore() Method

When reading from Firestore, map snake_case fields to camelCase properties:

```dart
factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return NotificationModel(
    notificationId: doc.id,
    userId: data['user_id'] ?? '',              // snake_case → camelCase
    readStatus: data['read_status'] ?? false,   // snake_case → camelCase
    sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
  );
}
```

### toFirestore() Method

When writing to Firestore, map camelCase properties to snake_case fields:

```dart
Map<String, dynamic> toFirestore() {
  return {
    'user_id': userId,              // camelCase → snake_case
    'read_status': readStatus,      // camelCase → snake_case
    'sent_at': Timestamp.fromDate(sentAt),
    'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };
}
```

## Standard Fields

### Timestamps

All collections should include these timestamp fields:

- `created_at` (Timestamp): When the document was created
- `updated_at` (Timestamp): When the document was last updated

**Dart mapping:**
```dart
DateTime createdAt;
DateTime? updatedAt;
```

### IDs and References

- Document IDs: Use Firestore auto-generated IDs when possible
- User references: `user_id` (String)
- Household references: `household_id` (String)
- Wallet references: `wallet_id` (String)

## Example: Complete Model Implementation

```dart
class NotificationModel {
  final String notificationId;
  final String userId;
  final String type;
  final String message;
  final bool readStatus;
  final DateTime sentAt;
  final DateTime? updatedAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.message,
    this.readStatus = false,
    required this.sentAt,
    this.updatedAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userId: data['user_id'] ?? '',
      type: data['type'] ?? '',
      message: data['message'] ?? '',
      readStatus: data['read_status'] ?? false,
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'user_id': userId,
      'type': type,
      'message': message,
      'read_status': readStatus,
      'sent_at': Timestamp.fromDate(sentAt),
    };

    if (updatedAt != null) {
      map['updated_at'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
  }
}
```

## Repository Query Examples

### Correct (snake_case in queries)

```dart
// ✅ CORRECT
await _firestore
    .collection('notifications')
    .where('user_id', isEqualTo: userId)
    .where('read_status', isEqualTo: false)
    .orderBy('sent_at', descending: true)
    .get();
```

### Incorrect (camelCase in queries)

```dart
// ❌ INCORRECT - Will fail to match documents
await _firestore
    .collection('notifications')
    .where('userId', isEqualTo: userId)       // Wrong!
    .where('readStatus', isEqualTo: false)    // Wrong!
    .orderBy('sentAt', descending: true)      // Wrong!
    .get();
```

## Updates and Deletes

Always use snake_case for field names in updates:

```dart
// ✅ CORRECT
await _firestore.collection('notifications').doc(id).update({
  'read_status': true,
  'updated_at': FieldValue.serverTimestamp(),
});

// ❌ INCORRECT
await _firestore.collection('notifications').doc(id).update({
  'readStatus': true,      // Wrong!
  'updatedAt': FieldValue.serverTimestamp(),  // Wrong!
});
```

## Balance Update Guidelines

### Centralized Service

**Rule:** All wallet balance updates MUST go through `WalletBalanceService`.

**DO NOT:**
- Directly update wallet balance fields in repositories
- Scatter balance update logic across multiple files
- Skip Firestore transactions for balance updates

**DO:**
```dart
// ✅ CORRECT - Use the centralized service
await _balanceService.applyExpenseTransaction(
  walletId: walletId,
  amount: amount,
  currency: currency,
  userId: userId,
  categoryId: categoryId,
  // ... other parameters
);
```

**DO NOT:**
```dart
// ❌ INCORRECT - Direct balance update
await _wallets.doc(walletId).update({
  'balance': newBalance,  // Don't do this!
});
```

## Migration from Legacy Naming

If you encounter old documents with camelCase field names:

1. **Read:** Support both snake_case and camelCase as fallbacks in `fromFirestore()`
2. **Write:** Always write snake_case only in `toFirestore()`
3. **Queries:** Always query using snake_case field names

Example fallback reading:
```dart
userId: data['user_id'] ?? data['userId'] ?? '',  // Try snake_case first, fallback to camelCase
```

## Summary Checklist

- [ ] Firestore field names use `snake_case`
- [ ] Dart properties use `camelCase`
- [ ] `fromFirestore()` maps snake_case → camelCase
- [ ] `toFirestore()` maps camelCase → snake_case
- [ ] Queries use snake_case field names
- [ ] Updates use snake_case field names
- [ ] All timestamps use `created_at` and `updated_at`
- [ ] Balance updates use `WalletBalanceService`

## References

- NotificationModel: `lib/data/models/notification_model.dart`
- NotificationRepository: `lib/data/repositories/notification_repository.dart`
- WalletBalanceService: `lib/data/services/wallet_balance_service.dart`
- TransactionModel: `lib/data/models/transaction_model.dart`
- WalletModel: `lib/data/models/wallet_model.dart`
