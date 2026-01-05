// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import Riverpod để quản lý state
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import TransactionModel để xử lý dữ liệu giao dịch
import '../../../data/models/transaction_model.dart';
// Import TransactionProvider để truy cập repository
import '../../providers/transaction_provider.dart';
// Import màn hình thêm giao dịch để tái sử dụng cho chỉnh sửa
import 'add_transaction_screen.dart';

// CHECKLIST KIỂM TRA THỦ CÔNG (Chỉnh sửa giao dịch)
// 1) Mở giao dịch từ Gần đây -> Chỉnh sửa -> đổi số tiền 50 -> 80: ví điều chỉnh +30/-30 một lần, cập nhật cùng document
// 2) Chỉ sửa ghi chú/danh mục: số dư ví không thay đổi, giao dịch hiển thị trường mới
// 3) Chỉnh sửa chuyển khoản bị chặn với thông báo thân thiện
// 4) Hủy chỉnh sửa (quay lại) giữ nguyên giao dịch

// Màn hình chỉnh sửa giao dịch - sử dụng ConsumerWidget để truy cập Riverpod
class EditTransactionScreen extends ConsumerWidget {
  final String transactionId; // ID của giao dịch cần chỉnh sửa

  // Constructor với transactionId bắt buộc
  const EditTransactionScreen({super.key, required this.transactionId});

  // Build UI của màn hình
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(transactionRepositoryProvider); // Lấy transaction repository từ provider
    // Sử dụng FutureBuilder để load dữ liệu giao dịch bất đồng bộ
    return FutureBuilder<TransactionModel?>(
      future: repository.getTransactionById(transactionId), // Gọi API lấy giao dịch theo ID
      builder: (context, snapshot) {
        // Hiển thị loading khi đang chờ dữ liệu
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()), // Hiển thị vòng xoay loading
          );
        }
        // Hiển thị lỗi khi không tìm thấy giao dịch
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Transaction not found')), // Thông báo không tìm thấy
          );
        }

        final transaction = snapshot.data!; // Lấy dữ liệu giao dịch
        // Tái sử dụng AddTransactionScreen với dữ liệu giao dịch hiện tại
        return AddTransactionScreen(
          initialType: transaction.type, // Truyền loại giao dịch
          existingTransaction: transaction, // Truyền giao dịch cần chỉnh sửa
        );
      },
    );
  }
}
