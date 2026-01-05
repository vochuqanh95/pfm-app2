// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import Riverpod để quản lý state
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import go_router để điều hướng
import 'package:go_router/go_router.dart';
// Import Firebase để xử lý lỗi Firebase
import 'package:firebase_core/firebase_core.dart';
// Import màu sắc ứng dụng
import '../../../core/theme/app_colors.dart';
// Import UserModel để sử dụng UserRoles
import '../../../data/models/user_model.dart';
// Import các providers
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';

// Màn hình tạo gia đình mới - cho phép user tạo household và trở thành chủ hộ
class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

// State của CreateHouseholdScreen quản lý form và trạng thái tạo
class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>(); // Key cho form validation
  final _nameController = TextEditingController(); // Controller cho input tên gia đình
  bool _isLoading = false; // Trạng thái đang xử lý tạo gia đình

  // Giải phóng tài nguyên khi widget bị hủy
  @override
  void dispose() {
    _nameController.dispose(); // Hủy controller
    super.dispose();
  }

  // Hàm xử lý tạo gia đình mới
  Future<void> _createHousehold({String? overrideName}) async {
    if (overrideName == null && !_formKey.currentState!.validate()) return; // Validate form nếu không skip

    final authService = ref.read(authServiceProvider); // Lấy auth service
    final firebaseUser = authService.currentUser; // Lấy Firebase user hiện tại
    final messenger = ScaffoldMessenger.of(context); // Lưu messenger để dùng sau

    // Kiểm tra user đã đăng nhập chưa
    if (firebaseUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to continue.')),
      );
      return;
    }

    setState(() => _isLoading = true); // Bắt đầu loading

    try {
      final householdNotifier = ref.read(householdNotifierProvider.notifier); // Lấy household notifier
      final userRepository = ref.read(userRepositoryProvider); // Lấy user repository
      final inputName = overrideName ?? _nameController.text.trim(); // Lấy tên từ input hoặc override
      final name = inputName.isEmpty ? 'Household' : inputName; // Dùng "Household" nếu rỗng

      // Tạo household mới
      final householdId = await householdNotifier.createHouseholdForUser(
        ownerUserId: firebaseUser.uid, // ID của chủ hộ
        name: name, // Tên gia đình
      );

      // Cập nhật role của user thành head (chủ hộ) và gán householdId
      await userRepository.updateUserRoleAndHousehold(
        userId: firebaseUser.uid,
        role: UserRoles.head, // Vai trò chủ hộ
        householdId: householdId, // ID gia đình vừa tạo
      );
      // Refresh các providers để cập nhật UI
      ref.invalidate(authUserProvider);
      ref.invalidate(currentUserHouseholdProvider);

      if (mounted) {
        context.go('/home'); // Chuyển đến trang home
      }
    } on FirebaseException catch (_) {
      // Xử lý lỗi Firebase (kết nối, quyền truy cập, v.v.)
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not create household. Please check your connection and try again.'),
        ),
      );
    } catch (e) {
      // Xử lý lỗi không mong đợi
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Kết thúc loading
      }
    }
  }

  // Build UI của màn hình tạo gia đình
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Màu nền sáng
      appBar: AppBar(
        title: const Text('Create Household'), // Tiêu đề "Tạo gia đình"
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Padding xung quanh
          child: Form(
            key: _formKey, // Form key để validate
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Chiếm toàn bộ chiều ngang
              children: [
                // Icon nhà
                const Icon(
                  Icons.home_outlined,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24), // Khoảng cách
                // Tiêu đề chính
                const Text(
                  'Create Your Household',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12), // Khoảng cách
                // Mô tả
                Text(
                  'Manage your finances together with family members', // "Quản lý tài chính cùng gia đình"
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32), // Khoảng cách
                // TextFormField nhập tên gia đình
                TextFormField(
                  controller: _nameController, // Controller quản lý input
                  decoration: const InputDecoration(
                    labelText: 'Household Name', // Label "Tên gia đình"
                    hintText: 'e.g., Smith Family', // Hint ví dụ
                    prefixIcon: Icon(Icons.group), // Icon nhóm
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a household name'; // Lỗi nếu rỗng
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters'; // Lỗi nếu quá ngắn
                    }
                    return null; // Hợp lệ
                  },
                ),
                const SizedBox(height: 32), // Khoảng cách
                // Container hiển thị các tính năng của chủ hộ
                Container(
                  padding: const EdgeInsets.all(16), // Padding bên trong
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.3), // Màu nền nhạt
                    borderRadius: BorderRadius.circular(12), // Bo tròn góc
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header với icon info
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'As the household owner, you can:', // "Với vai trò chủ hộ, bạn có thể:"
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12), // Khoảng cách
                      // Danh sách các tính năng
                      _buildFeatureItem('Invite up to 6 family members'), // Mời tối đa 6 thành viên
                      _buildFeatureItem('Manage shared wallets and accounts'), // Quản lý ví và tài khoản chung
                      _buildFeatureItem('Set budgets and financial goals'), // Đặt ngân sách và mục tiêu tài chính
                      _buildFeatureItem('Approve member transactions'), // Phê duyệt giao dịch của thành viên
                      _buildFeatureItem('View household financial reports'), // Xem báo cáo tài chính gia đình
                    ],
                  ),
                ),
                const SizedBox(height: 32), // Khoảng cách
                // Nút tạo gia đình
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _createHousehold(), // Disable khi đang xử lý
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox( // Hiển thị loading khi đang xử lý
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Household'), // Text "Tạo gia đình"
                ),
                const SizedBox(height: 16), // Khoảng cách
                // Nút bỏ qua - tạo với tên mặc định
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _createHousehold(overrideName: 'Personal Household'), // Tạo với tên "Personal Household"
                  child: const Text('Skip for now'), // Text "Bỏ qua"
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget helper build một item tính năng với icon check
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // Khoảng cách dưới
      child: Row(
        children: [
          // Icon check màu xanh
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8), // Khoảng cách
          // Text tính năng
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
