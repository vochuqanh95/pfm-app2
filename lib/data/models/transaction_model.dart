// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum định nghĩa các loại giao dịch
enum TransactionType { 
  income, // Thu nhập
  expense, // Chi tiêu
  transfer // Chuyển khoản giữa các ví
}

// Enum định nghĩa trạng thái của giao dịch (cho workflow phê duyệt)
enum TransactionStatus {
  approved, // Đã phê duyệt
  pending, // Đang chờ phê duyệt
  rejected; // Đã từ chối

  // Getter trả về tên hiển thị của trạng thái
  String get displayName {
    switch (this) {
      case TransactionStatus.approved:
        return 'Approved'; // Hiển thị "Đã phê duyệt"
      case TransactionStatus.pending:
        return 'Pending'; // Hiển thị "Đang chờ"
      case TransactionStatus.rejected:
        return 'Rejected'; // Hiển thị "Đã từ chối"
    }
  }
}

// Model đại diện cho một giao dịch tài chính trong ứng dụng
class TransactionModel {
  final String transactionId; // ID duy nhất của giao dịch
  final String userId; // ID của user tạo giao dịch
  final String? householdId; // ID của gia đình (nếu là giao dịch gia đình)
  final String categoryId; // ID của danh mục giao dịch
  final String? categoryName; // Tên danh mục tại thời điểm tạo (snapshot)
  final String? categoryType; // Loại danh mục (thu nhập/chi tiêu)
  final String walletId; // ID của ví sử dụng
  final String? fromWalletId; // ID ví nguồn (cho giao dịch chuyển khoản)
  final String? toWalletId; // ID ví đích (cho giao dịch chuyển khoản)
  final double amount; // Số tiền giao dịch
  final String currency; // Đơn vị tiền tệ (VD: USD, VND)
  final double? fxRate; // Tỷ giá hối đoái (nếu có)
  final TransactionType type; // Loại giao dịch (thu nhập/chi tiêu/chuyển khoản)
  final String note; // Ghi chú về giao dịch
  final DateTime date; // Ngày thực hiện giao dịch
  final String? imageUrl; // URL ảnh hóa đơn (nếu có)
  final String? ocrRawText; // Text được OCR từ ảnh (nếu có)
  final String? recurringRuleId; // ID của quy tắc lặp lại (nếu là giao dịch định kỳ)
  final DateTime createdAt; // Thời gian tạo giao dịch
  final DateTime updatedAt; // Thời gian cập nhật gần nhất

  // Các trường cho việc phân quyền giao dịch
  final String? actorUserId; // ID của người tạo/thực hiện giao dịch
  final String? actorDisplayName; // Tên hiển thị của người tạo (denormalized)
  final String? actorRole; // Vai trò của người tạo: 'head' hoặc 'member' (denormalized)
  final String? goalId; // ID mục tiêu nếu giao dịch này là đóng góp cho mục tiêu

  // Các trường liên quan đến workflow phê duyệt
  final TransactionStatus status; // Trạng thái: approved, pending, rejected
  final bool requiresApproval; // Giao dịch này có cần phê duyệt không
  final String? approvedByUserId; // ID của user đã phê duyệt giao dịch
  final DateTime? approvedAt; // Thời gian giao dịch được phê duyệt
  final String? rejectionReason; // Lý do từ chối (nếu status là rejected)

  // Constructor khởi tạo TransactionModel với các tham số bắt buộc và tùy chọn
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
    this.currency = 'USD', // Mặc định là USD
    this.fxRate,
    required this.type,
    this.note = '', // Mặc định ghi chú rỗng
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
    this.status = TransactionStatus.approved, // Mặc định đã phê duyệt
    this.requiresApproval = false, // Mặc định không cần phê duyệt
    this.approvedByUserId,
    this.approvedAt,
    this.rejectionReason,
  });

  // Các getter hỗ trợ cho màn hình
  String get category => categoryId; // Lấy ID danh mục
  String? get description => note.isNotEmpty ? note : null; // Lấy mô tả (note nếu có)
  String get resolvedCategoryName => // Lấy tên danh mục hiển thị
      (categoryName != null && categoryName!.isNotEmpty) ? categoryName! : categoryId;
  String get createdBy => actorDisplayName ?? actorUserId ?? userId; // Lấy tên người tạo

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành TransactionModel
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return TransactionModel(
      transactionId: doc.id, // Lấy ID từ document
      userId: data['user_id'] ?? '', // Lấy userId
      householdId: data['household_id'], // Lấy householdId
      categoryId: data['category_id'] ?? '', // Lấy categoryId
      categoryName: data['category_name'], // Lấy tên danh mục
      categoryType: data['category_type'], // Lấy loại danh mục
      walletId: data['wallet_id'] ?? '', // Lấy walletId
      fromWalletId: data['from_wallet_id'], // Lấy ví nguồn (cho transfer)
      toWalletId: data['to_wallet_id'], // Lấy ví đích (cho transfer)
      amount: (data['amount'] ?? 0.0).toDouble(), // Lấy số tiền, mặc định 0
      currency: data['currency'] ?? 'USD', // Lấy currency, mặc định USD
      fxRate: data['fx_rate']?.toDouble(), // Lấy tỷ giá (nếu có)
      type: TransactionType.values.firstWhere( // Tìm loại giao dịch phù hợp
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense, // Mặc định là expense
      ),
      note: data['note'] ?? '', // Lấy ghi chú
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      imageUrl: data['image_url'], // Lấy URL ảnh
      ocrRawText: data['ocr_raw_text'], // Lấy text OCR
      recurringRuleId: data['recurring_rule_id'], // Lấy ID quy tắc lặp lại
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      actorUserId: data['actor_user_id'], // Lấy ID người tạo
      actorDisplayName: data['actor_display_name'], // Lấy tên người tạo
      actorRole: data['actor_role'], // Lấy vai trò người tạo
      goalId: data['goal_id'], // Lấy ID mục tiêu
      // Các trường phê duyệt - tương thích ngược (null status = approved)
      status: data['status'] != null
          ? TransactionStatus.values.firstWhere(
              (e) => e.name == data['status'],
              orElse: () => TransactionStatus.approved,
            )
          : TransactionStatus.approved, // Mặc định là approved nếu null
      requiresApproval: data['requires_approval'] ?? false, // Lấy trạng thái cần phê duyệt
      approvedByUserId: data['approved_by_user_id'], // Lấy ID người phê duyệt
      approvedAt: (data['approved_at'] as Timestamp?)?.toDate(), // Chuyển Timestamp thành DateTime
      rejectionReason: data['rejection_reason'], // Lấy lý do từ chối
    );
  }

  // Method chuyển đổi TransactionModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, // ID user
      'household_id': householdId, // ID gia đình
      'category_id': categoryId, // ID danh mục
      'category_name': categoryName, // Tên danh mục
      'category_type': categoryType, // Loại danh mục
      'wallet_id': walletId, // ID ví
      'from_wallet_id': fromWalletId, // ID ví nguồn
      'to_wallet_id': toWalletId, // ID ví đích
      'amount': amount, // Số tiền
      'currency': currency, // Đơn vị tiền tệ
      'fx_rate': fxRate, // Tỷ giá
      'type': type.name, // Loại giao dịch (chuyển enum thành string)
      'note': note, // Ghi chú
      'date': Timestamp.fromDate(date), // Chuyển DateTime thành Timestamp
      'image_url': imageUrl, // URL ảnh
      'ocr_raw_text': ocrRawText, // Text OCR
      'recurring_rule_id': recurringRuleId, // ID quy tắc lặp lại
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
      'updated_at': Timestamp.fromDate(updatedAt), // Chuyển DateTime thành Timestamp
      'actor_user_id': actorUserId, // ID người tạo
      'actor_display_name': actorDisplayName, // Tên người tạo
      'actor_role': actorRole, // Vai trò người tạo
      'goal_id': goalId, // ID mục tiêu
      'status': status.name, // Trạng thái (chuyển enum thành string)
      'requires_approval': requiresApproval, // Trạng thái cần phê duyệt
      'approved_by_user_id': approvedByUserId, // ID người phê duyệt
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null, // Chuyển DateTime thành Timestamp
      'rejection_reason': rejectionReason, // Lý do từ chối
    };
  }

  // Method tạo bản copy của TransactionModel với các giá trị được cập nhật
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
    // Trả về TransactionModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId, // Dùng transactionId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      categoryId: categoryId ?? this.categoryId, // Dùng categoryId mới hoặc giữ nguyên
      categoryName: categoryName ?? this.categoryName, // Dùng categoryName mới hoặc giữ nguyên
      categoryType: categoryType ?? this.categoryType, // Dùng categoryType mới hoặc giữ nguyên
      walletId: walletId ?? this.walletId, // Dùng walletId mới hoặc giữ nguyên
      fromWalletId: fromWalletId ?? this.fromWalletId, // Dùng fromWalletId mới hoặc giữ nguyên
      toWalletId: toWalletId ?? this.toWalletId, // Dùng toWalletId mới hoặc giữ nguyên
      amount: amount ?? this.amount, // Dùng amount mới hoặc giữ nguyên
      currency: currency ?? this.currency, // Dùng currency mới hoặc giữ nguyên
      fxRate: fxRate ?? this.fxRate, // Dùng fxRate mới hoặc giữ nguyên
      type: type ?? this.type, // Dùng type mới hoặc giữ nguyên
      note: note ?? this.note, // Dùng note mới hoặc giữ nguyên
      date: date ?? this.date, // Dùng date mới hoặc giữ nguyên
      imageUrl: imageUrl ?? this.imageUrl, // Dùng imageUrl mới hoặc giữ nguyên
      ocrRawText: ocrRawText ?? this.ocrRawText, // Dùng ocrRawText mới hoặc giữ nguyên
      recurringRuleId: recurringRuleId ?? this.recurringRuleId, // Dùng recurringRuleId mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
      actorUserId: actorUserId ?? this.actorUserId, // Dùng actorUserId mới hoặc giữ nguyên
      actorDisplayName: actorDisplayName ?? this.actorDisplayName, // Dùng actorDisplayName mới hoặc giữ nguyên
      actorRole: actorRole ?? this.actorRole, // Dùng actorRole mới hoặc giữ nguyên
      goalId: goalId ?? this.goalId, // Dùng goalId mới hoặc giữ nguyên
      status: status ?? this.status, // Dùng status mới hoặc giữ nguyên
      requiresApproval: requiresApproval ?? this.requiresApproval, // Dùng requiresApproval mới hoặc giữ nguyên
      approvedByUserId: approvedByUserId ?? this.approvedByUserId, // Dùng approvedByUserId mới hoặc giữ nguyên
      approvedAt: approvedAt ?? this.approvedAt, // Dùng approvedAt mới hoặc giữ nguyên
      rejectionReason: rejectionReason ?? this.rejectionReason, // Dùng rejectionReason mới hoặc giữ nguyên
    );
  }
}
