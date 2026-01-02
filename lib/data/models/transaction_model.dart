import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense, transfer }

enum TransactionStatus {
  approved,
  pending,
  rejected;

  String get displayName {
    switch (this) {
      case TransactionStatus.approved:
        return 'Approved';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.rejected:
        return 'Rejected';
    }
  }
}

class TransactionModel {
  final String transactionId;
  final String userId;
  final String? householdId;
  final String categoryId;
  final String? categoryName; // Snapshot name at creation
  final String? categoryType;
  final String walletId;
  final String? fromWalletId;
  final String? toWalletId;
  final double amount;
  final String currency;
  final double? fxRate;
  final TransactionType type;
  final String note;
  final DateTime date;
  final String? imageUrl;
  final String? ocrRawText;
  final String? recurringRuleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields for transaction attribution
  final String? actorUserId; // Who created/performed this transaction
  final String? actorDisplayName; // Display name of the actor (denormalized)
  final String? actorRole; // Role of the actor: 'head' or 'member' (denormalized)
  final String? goalId; // If this transaction is a goal contribution

  // Approval-related fields (for future approval workflow)
  final TransactionStatus status; // approved, pending, rejected
  final bool requiresApproval; // Whether this transaction needs approval
  final String? approvedByUserId; // User ID who approved this transaction
  final DateTime? approvedAt; // When the transaction was approved
  final String? rejectionReason; // Reason for rejection (if status is rejected)

  TransactionModel({
    required this.transactionId,
    required this.userId,
    this.householdId,
    required this.categoryId,
    this.categoryName,
    this.categoryType,
    required this.walletId,
    this.fromWalletId,
    this.toWalletId,
    required this.amount,
    this.currency = 'USD',
    this.fxRate,
    required this.type,
    this.note = '',
    required this.date,
    this.imageUrl,
    this.ocrRawText,
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.actorUserId,
    this.actorDisplayName,
    this.actorRole,
    this.goalId,
    this.status = TransactionStatus.approved,
    this.requiresApproval = false,
    this.approvedByUserId,
    this.approvedAt,
    this.rejectionReason,
  });

  // Helper properties for screens
  String get category => categoryId;
  String? get description => note.isNotEmpty ? note : null;
  String get resolvedCategoryName =>
      (categoryName != null && categoryName!.isNotEmpty) ? categoryName! : categoryId;
  String get createdBy => actorDisplayName ?? actorUserId ?? userId;

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      transactionId: doc.id,
      userId: data['user_id'] ?? '',
      householdId: data['household_id'],
      categoryId: data['category_id'] ?? '',
      categoryName: data['category_name'],
      categoryType: data['category_type'],
      walletId: data['wallet_id'] ?? '',
      fromWalletId: data['from_wallet_id'],
      toWalletId: data['to_wallet_id'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'USD',
      fxRate: data['fx_rate']?.toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
      note: data['note'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['image_url'],
      ocrRawText: data['ocr_raw_text'],
      recurringRuleId: data['recurring_rule_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actorUserId: data['actor_user_id'],
      actorDisplayName: data['actor_display_name'],
      actorRole: data['actor_role'],
      goalId: data['goal_id'],
      // Approval fields - backwards compatible (null status = approved)
      status: data['status'] != null
          ? TransactionStatus.values.firstWhere(
              (e) => e.name == data['status'],
              orElse: () => TransactionStatus.approved,
            )
          : TransactionStatus.approved,
      requiresApproval: data['requires_approval'] ?? false,
      approvedByUserId: data['approved_by_user_id'],
      approvedAt: (data['approved_at'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejection_reason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'household_id': householdId,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_type': categoryType,
      'wallet_id': walletId,
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'currency': currency,
      'fx_rate': fxRate,
      'type': type.name,
      'note': note,
      'date': Timestamp.fromDate(date),
      'image_url': imageUrl,
      'ocr_raw_text': ocrRawText,
      'recurring_rule_id': recurringRuleId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'actor_user_id': actorUserId,
      'actor_display_name': actorDisplayName,
      'actor_role': actorRole,
      'goal_id': goalId,
      'status': status.name,
      'requires_approval': requiresApproval,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejection_reason': rejectionReason,
    };
  }

  TransactionModel copyWith({
    String? transactionId,
    String? userId,
    String? householdId,
    String? categoryId,
    String? categoryName,
    String? categoryType,
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    double? amount,
    String? currency,
    double? fxRate,
    TransactionType? type,
    String? note,
    DateTime? date,
    String? imageUrl,
    String? ocrRawText,
    String? recurringRuleId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? actorUserId,
    String? actorDisplayName,
    String? actorRole,
    String? goalId,
    TransactionStatus? status,
    bool? requiresApproval,
    String? approvedByUserId,
    DateTime? approvedAt,
    String? rejectionReason,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryType: categoryType ?? this.categoryType,
      walletId: walletId ?? this.walletId,
      fromWalletId: fromWalletId ?? this.fromWalletId,
      toWalletId: toWalletId ?? this.toWalletId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      fxRate: fxRate ?? this.fxRate,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actorUserId: actorUserId ?? this.actorUserId,
      actorDisplayName: actorDisplayName ?? this.actorDisplayName,
      actorRole: actorRole ?? this.actorRole,
      goalId: goalId ?? this.goalId,
      status: status ?? this.status,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
