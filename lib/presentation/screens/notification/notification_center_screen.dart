// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import Riverpod để quản lý state
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import màu sắc ứng dụng
import '../../../core/theme/app_colors.dart';

// Màn hình trung tâm thông báo - hiển thị danh sách thông báo cho user
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  // Build UI của màn hình thông báo
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Triển khai notification provider và lấy dữ liệu thông báo từ backend
    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Màu nền sáng
      appBar: AppBar(
        title: const Text('Notifications'), // Tiêu đề "Thông báo"
        actions: [
          // Nút đánh dấu tất cả đã đọc
          IconButton(
            icon: const Icon(Icons.done_all), // Icon check tất cả
            onPressed: () {
              // TODO: Đánh dấu tất cả thông báo là đã đọc
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16), // Padding xung quanh danh sách
        children: [
          // Card thông báo cảnh báo ngân sách
          _NotificationCard(
            title: 'Budget Alert', // Tiêu đề: Cảnh báo ngân sách
            message: 'You have used 85% of your Food & Dining budget', // Đã dùng 85% ngân sách ăn uống
            time: '2 hours ago', // 2 giờ trước
            icon: Icons.warning, // Icon cảnh báo
            iconColor: AppColors.warning, // Màu cảnh báo
            isRead: false, // Chưa đọc
          ),
          // Card nhắc nhở hóa đơn
          _NotificationCard(
            title: 'Bill Reminder', // Tiêu đề: Nhắc hóa đơn
            message: 'Electricity bill is due in 3 days', // Hóa đơn điện đến hạn trong 3 ngày
            time: '5 hours ago', // 5 giờ trước
            icon: Icons.receipt, // Icon hóa đơn
            iconColor: AppColors.error, // Màu lỗi/khẩn cấp
            isRead: false, // Chưa đọc
          ),
          // Card giao dịch được phê duyệt
          _NotificationCard(
            title: 'Transaction Approved', // Tiêu đề: Giao dịch đã phê duyệt
            message: 'Your transaction of \$250 has been approved', // Giao dịch $250 đã được phê duyệt
            time: '1 day ago', // 1 ngày trước
            icon: Icons.check_circle, // Icon check
            iconColor: AppColors.success, // Màu thành công
            isRead: true, // Đã đọc
          ),
          // Card thành viên mới tham gia
          _NotificationCard(
            title: 'New Member Added', // Tiêu đề: Thêm thành viên mới
            message: 'John Doe has joined your household', // John Doe đã tham gia gia đình
            time: '2 days ago', // 2 ngày trước
            icon: Icons.person_add, // Icon thêm người
            iconColor: AppColors.info, // Màu thông tin
            isRead: true, // Đã đọc
          ),
        ],
      ),
    );
  }
}

// Widget private hiển thị một card thông báo
class _NotificationCard extends StatelessWidget {
  final String title; // Tiêu đề thông báo
  final String message; // Nội dung thông báo
  final String time; // Thời gian thông báo
  final IconData icon; // Icon hiển thị
  final Color iconColor; // Màu của icon
  final bool isRead; // Trạng thái đã đọc/chưa đọc

  // Constructor với các tham số bắt buộc
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isRead = false, // Mặc định chưa đọc
  });

  // Build UI cho card thông báo
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12), // Khoảng cách giữa các card
      color: isRead ? Colors.white : AppColors.primaryLight.withOpacity(0.1), // Màu khác nhau cho đã đọc/chưa đọc
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding bên trong card
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Căn trên cho các phần tử
          children: [
            // Container chứa icon thông báo
            Container(
              padding: const EdgeInsets.all(12), // Padding xung quanh icon
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1), // Màu nền nhạt của icon
                borderRadius: BorderRadius.circular(12), // Bo tròn góc
              ),
              child: Icon(
                icon, // Hiển thị icon
                color: iconColor, // Màu icon
                size: 24, // Kích thước icon
              ),
            ),
            const SizedBox(width: 12), // Khoảng cách giữa icon và nội dung
            // Phần nội dung thông báo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Căn trái
                children: [
                  // Tiêu đề thông báo
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, // Bold nếu chưa đọc
                    ),
                  ),
                  const SizedBox(height: 4), // Khoảng cách
                  // Nội dung thông báo
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary, // Màu chữ phụ
                    ),
                  ),
                  const SizedBox(height: 8), // Khoảng cách
                  // Thời gian thông báo
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary, // Màu chữ phụ
                    ),
                  ),
                ],
              ),
            ),
            // Chấm tròn màu xanh cho thông báo chưa đọc
            if (!isRead)
              Container(
                width: 8, // Chiều rộng chấm
                height: 8, // Chiều cao chấm
                decoration: const BoxDecoration(
                  color: AppColors.primary, // Màu primary
                  shape: BoxShape.circle, // Hình tròn
                ),
              ),
          ],
        ),
      ),
    );
  }
}
