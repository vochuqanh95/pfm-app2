// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Model cho bản ghi thanh toán khoản nợ
// Được lưu trong subcollection: debts/{debtId}/payments/{paymentId}
class DebtPaymentModel {
  final String paymentId; // ID duy nhất của khoản thanh toán
  final String debtId; // ID của khoản nợ
  final String userId; // ID của user thực hiện thanh toán
  final String? walletId; // ID của ví sử dụng (có thể null - thanh toán không qua ví)
  final double amount; // Số tiền thanh toán
  final DateTime date; // Ngày thực hiện thanh toán
  final String? note; // Ghi chú về khoản thanh toán (có thể null)
  final DateTime createdAt; // Thời gian tạo bản ghi

  // Constructor khởi tạo DebtPaymentModel
  DebtPaymentModel({
    required this.paymentId,
    required this.debtId,
    required this.userId,
    this.walletId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  // Tạo DebtPaymentModel từ Firestore document
  factory DebtPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    return DebtPaymentModel(
      paymentId: doc.id, // Lấy ID từ document
      debtId: data['debt_id'] ?? '', // Lấy ID khoản nợ
      userId: data['user_id'] ?? '', // Lấy userId
      walletId: data['wallet_id'], // Lấy walletId (có thể null)
      amount: (data['amount'] ?? 0.0).toDouble(), // Lấy số tiền thanh toán
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      note: data['note'], // Lấy ghi chú (có thể null)
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
    );
  }

  // Chuyển đổi DebtPaymentModel thành Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'debt_id': debtId, // ID khoản nợ
      'user_id': userId, // ID user
      'wallet_id': walletId, // ID ví
      'amount': amount, // Số tiền thanh toán
      'date': Timestamp.fromDate(date), // Chuyển DateTime thành Timestamp
      'note': note, // Ghi chú
      'created_at': Timestamp.fromDate(createdAt), // Chuyển DateTime thành Timestamp
    };
  }

  // Method tạo bản copy với các giá trị được cập nhật
  DebtPaymentModel copyWith({
    String? paymentId,
    String? debtId,
    String? userId,
    String? walletId,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    // Trả về DebtPaymentModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return DebtPaymentModel(
      paymentId: paymentId ?? this.paymentId, // Dùng paymentId mới hoặc giữ nguyên
      debtId: debtId ?? this.debtId, // Dùng debtId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      walletId: walletId ?? this.walletId, // Dùng walletId mới hoặc giữ nguyên
      amount: amount ?? this.amount, // Dùng amount mới hoặc giữ nguyên
      date: date ?? this.date, // Dùng date mới hoặc giữ nguyên
      note: note ?? this.note, // Dùng note mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
    );
  }
}
