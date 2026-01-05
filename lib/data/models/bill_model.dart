// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum định nghĩa trạng thái của hóa đơn
enum BillStatus { 
  unpaid, // Chưa thanh toán
  paid, // Đã thanh toán
  overdue // Quá hạn
}

// Enum định nghĩa chu kỳ lặp lại của hóa đơn
enum BillRecurrence { 
  none, // Không lặp lại
  monthly, // Lặp lại hàng tháng
  yearly, // Lặp lại hàng năm
  custom // Tùy chỉnh chu kỳ lặp lại
}

// Model đại diện cho hóa đơn cần thanh toán trong ứng dụng
class BillModel {
  final String billId; // ID duy nhất của hóa đơn
  final String? userId; // ID của user sở hữu hóa đơn (có thể null)
  final String? householdId; // ID của gia đình (nếu là hóa đơn gia đình)
  final String name; // Tên hóa đơn
  final double amount; // Số tiền cần thanh toán
  final String currency; // Đơn vị tiền tệ (VD: USD, VND)
  final DateTime dueDate; // Ngày đến hạn thanh toán
  final BillStatus status; // Trạng thái thanh toán (chưa/đã/quá hạn)
  final String? recurringRuleId; // ID của quy tắc lặp lại (nếu là hóa đơn định kỳ)
  final DateTime createdAt; // Thời gian tạo hóa đơn
  final DateTime updatedAt; // Thời gian cập nhật gần nhất

  // Các trường mở rộng cho chức năng nâng cao
  final String scope; // Phạm vi: 'family' (gia đình) hoặc 'personal' (cá nhân)
  final String? createdByUserId; // ID của người tạo hóa đơn
  final String? responsibleUserId; // ID của người chịu trách nhiệm thanh toán/nhận thông báo
  final BillRecurrence recurrence; // Chu kỳ lặp lại của hóa đơn
  final int remindDaysBefore; // Số ngày trước hạn để gửi thông báo nhắc nhở

  // Các trường theo dõi thanh toán
  final String? paidByUserId; // ID của người đã thanh toán hóa đơn
  final String? paidFromWalletId; // ID của ví được sử dụng để thanh toán
  final String? linkedTransactionId; // ID của giao dịch được tạo khi thanh toán hóa đơn
  final DateTime? paidAt; // Thời gian thanh toán hóa đơn

  // Constructor khởi tạo BillModel với các tham số bắt buộc và tùy chọn
  BillModel({
    required this.billId,
    this.userId,
    this.householdId,
    required this.name,
    required this.amount,
    this.currency = 'USD', // Mặc định là USD
    required this.dueDate,
    this.status = BillStatus.unpaid, // Mặc định chưa thanh toán
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.scope = 'personal', // Mặc định là hóa đơn cá nhân
    this.createdByUserId,
    this.responsibleUserId,
    this.recurrence = BillRecurrence.none, // Mặc định không lặp lại
    this.remindDaysBefore = 3, // Mặc định nhắc nhở trước 3 ngày
    this.paidByUserId,
    this.paidFromWalletId,
    this.linkedTransactionId,
    this.paidAt,
  });

  // Getter kiểm tra hóa đơn có phải là hóa đơn chia sẻ không
  bool get isShared => householdId != null && scope == 'family';
  // Getter kiểm tra hóa đơn có quá hạn không (chưa thanh toán và đã qua ngày đáo hạn)
  bool get isOverdue => status == BillStatus.unpaid && dueDate.isBefore(DateTime.now());
  // Getter tính số ngày còn lại đến hạn
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
  // Getter kiểm tra có nên nhắc nhở không
  bool get shouldRemind {
    if (status == BillStatus.paid) return false; // Đã thanh toán thì không nhắc
    final reminderDate = dueDate.subtract(Duration(days: remindDaysBefore)); // Tính ngày bắt đầu nhắc
    final now = DateTime.now();
    return now.isAfter(reminderDate) && now.isBefore(dueDate); // Kiểm tra có trong khoảng thời gian nhắc không
  }

  // Các getter hỗ trợ cho màn hình
  bool get isPaid => status == BillStatus.paid; // Kiểm tra đã thanh toán
  String get id => billId; // Lấy ID hóa đơn
  bool get isRecurring => recurrence != BillRecurrence.none || recurringRuleId != null; // Kiểm tra có lặp lại không

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành BillModel
  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document

    // Parse (phân tích) trạng thái hóa đơn từ string
    final statusStr = data['status'] as String?;
    BillStatus billStatus = BillStatus.unpaid; // Mặc định chưa thanh toán
    if (statusStr != null) {
      billStatus = BillStatus.values.firstWhere( // Tìm enum phù hợp
        (e) => e.name == statusStr,
        orElse: () => BillStatus.unpaid, // Mặc định unpaid nếu không tìm thấy
      );
    }

    // Parse (phân tích) chu kỳ lặp lại từ string
    final recurrenceStr = data['recurrence'] as String?;
    BillRecurrence billRecurrence = BillRecurrence.none; // Mặc định không lặp lại
    if (recurrenceStr != null) {
      billRecurrence = BillRecurrence.values.firstWhere( // Tìm enum phù hợp
        (e) => e.name == recurrenceStr,
        orElse: () => BillRecurrence.none, // Mặc định none nếu không tìm thấy
      );
    }

    // Tạo và trả về BillModel từ dữ liệu Firestore
    return BillModel(
      billId: doc.id, // Lấy ID từ document
      userId: data['user_id'], // Lấy userId
      householdId: data['household_id'], // Lấy householdId
      name: data['name'] ?? '', // Lấy tên hóa đơn, mặc định rỗng
      amount: (data['amount'] ?? 0.0).toDouble(), // Lấy số tiền
      currency: data['currency'] ?? 'USD', // Lấy currency, mặc định USD
      dueDate: (data['due_date'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      status: billStatus, // Gán trạng thái đã parse
      recurringRuleId: data['recurring_rule_id'], // Lấy ID quy tắc lặp lại
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      scope: data['scope'] ?? 'personal', // Lấy scope, mặc định personal
      createdByUserId: data['created_by_user_id'], // Lấy ID người tạo
      responsibleUserId: data['responsible_user_id'], // Lấy ID người chịu trách nhiệm
      recurrence: billRecurrence, // Gán chu kỳ đã parse
      remindDaysBefore: data['remind_days_before'] ?? 3, // Lấy số ngày nhắc trước, mặc định 3
      paidByUserId: data['paid_by_user_id'], // Lấy ID người thanh toán
      paidFromWalletId: data['paid_from_wallet_id'], // Lấy ID ví thanh toán
      linkedTransactionId: data['linked_transaction_id'], // Lấy ID giao dịch liên kết
      paidAt: (data['paid_at'] as Timestamp?)?.toDate(), // Chuyển Timestamp thành DateTime
    );
  }

  // Method chuyển đổi BillModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId, // ID user
      'household_id': householdId, // ID gia đình
      'name': name, // Tên hóa đơn
      'amount': amount, // Số tiền
      'currency': currency, // Đơn vị tiền tệ
      'due_date': Timestamp.fromDate(dueDate), // Chuyển DateTime thành Timestamp
      'status': status.name, // Trạng thái (chuyển enum thành string)
      'recurring_rule_id': recurringRuleId, // ID quy tắc lặp lại
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
      'updated_at': Timestamp.fromDate(updatedAt), // Chuyển DateTime thành Timestamp
      'scope': scope, // Phạm vi hóa đơn
      'created_by_user_id': createdByUserId, // ID người tạo
      'responsible_user_id': responsibleUserId, // ID người chịu trách nhiệm
      'recurrence': recurrence.name, // Chu kỳ lặp lại (chuyển enum thành string)
      'remind_days_before': remindDaysBefore, // Số ngày nhắc trước
      'paid_by_user_id': paidByUserId, // ID người thanh toán
      'paid_from_wallet_id': paidFromWalletId, // ID ví thanh toán
      'linked_transaction_id': linkedTransactionId, // ID giao dịch liên kết
      'paid_at': paidAt != null ? Timestamp.fromDate(paidAt!) : null, // Chuyển DateTime thành Timestamp
    };
  }

  // Method tạo bản copy của BillModel với các giá trị được cập nhật
  BillModel copyWith({
    String? billId,
    String? userId,
    String? householdId,
    String? name,
    double? amount,
    String? currency,
    DateTime? dueDate,
    BillStatus? status,
    String? recurringRuleId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? scope,
    String? createdByUserId,
    String? responsibleUserId,
    BillRecurrence? recurrence,
    int? remindDaysBefore,
    String? paidByUserId,
    String? paidFromWalletId,
    String? linkedTransactionId,
    DateTime? paidAt,
  }) {
    // Trả về BillModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return BillModel(
      billId: billId ?? this.billId, // Dùng billId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      amount: amount ?? this.amount, // Dùng amount mới hoặc giữ nguyên
      currency: currency ?? this.currency, // Dùng currency mới hoặc giữ nguyên
      dueDate: dueDate ?? this.dueDate, // Dùng dueDate mới hoặc giữ nguyên
      status: status ?? this.status, // Dùng status mới hoặc giữ nguyên
      recurringRuleId: recurringRuleId ?? this.recurringRuleId, // Dùng recurringRuleId mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
      scope: scope ?? this.scope, // Dùng scope mới hoặc giữ nguyên
      createdByUserId: createdByUserId ?? this.createdByUserId, // Dùng createdByUserId mới hoặc giữ nguyên
      responsibleUserId: responsibleUserId ?? this.responsibleUserId, // Dùng responsibleUserId mới hoặc giữ nguyên
      recurrence: recurrence ?? this.recurrence, // Dùng recurrence mới hoặc giữ nguyên
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore, // Dùng remindDaysBefore mới hoặc giữ nguyên
      paidByUserId: paidByUserId ?? this.paidByUserId, // Dùng paidByUserId mới hoặc giữ nguyên
      paidFromWalletId: paidFromWalletId ?? this.paidFromWalletId, // Dùng paidFromWalletId mới hoặc giữ nguyên
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId, // Dùng linkedTransactionId mới hoặc giữ nguyên
      paidAt: paidAt ?? this.paidAt, // Dùng paidAt mới hoặc giữ nguyên
    );
  }
}
