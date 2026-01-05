// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import Riverpod để quản lý state
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import go_router để điều hướng
import 'package:go_router/go_router.dart';
// Import màu sắc ứng dụng
import '../../../core/theme/app_colors.dart';
// Import HouseholdRepository để xử lý lỗi tham gia gia đình
import '../../../data/repositories/household_repository.dart';
// Import các providers cho auth và household
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';

// Màn hình tham gia gia đình - cho phép user nhập mã mời để tham gia
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

// State của JoinHouseholdScreen quản lý form và trạng thái tham gia
class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _formKey = GlobalKey<FormState>(); // Key cho form validation
  final _codeController = TextEditingController(); // Controller cho input mã mời
  bool _isJoining = false; // Trạng thái đang xử lý tham gia

  // Giải phóng tài nguyên khi widget bị hủy
  @override
  void dispose() {
    _codeController.dispose(); // Hủy controller
    super.dispose();
  }

  // Hàm xử lý tham gia gia đình
  Future<void> _joinHousehold() async {
    if (!_formKey.currentState!.validate()) return; // Validate form trước

    final authUserAsync = ref.read(authUserProvider); // Lấy auth user
    if (authUserAsync.isLoading) { // Nếu đang loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still setting up your account. Please try again in a moment.')),
      );
      return;
    }

    final authUser = authUserAsync.valueOrNull; // Lấy giá trị user
    final firebaseUser = ref.read(authServiceProvider).currentUser; // Lấy Firebase user

    // Kiểm tra user đã đăng nhập chưa
    if (firebaseUser == null || authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to join a household.')),
      );
      return;
    }

    // Kiểm tra user đã thuộc gia đình nào chưa
    if (authUser.householdId != null && authUser.householdId!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already belong to a household.')),
      );
      return;
    }

    setState(() => _isJoining = true); // Bắt đầu loading
    final code = _codeController.text.trim().toUpperCase(); // Lấy mã mời và chuyển thành chữ hoa
    final messenger = ScaffoldMessenger.of(context); // Lưu messenger để dùng sau

    try {
      // Gọi provider method để tham gia gia đình với validations
      final household = await ref.read(householdNotifierProvider.notifier).joinCurrentUserToHousehold(
        inviteCode: code, // Mã mời
        userId: firebaseUser.uid, // ID user
      );

      // Refresh các providers để cập nhật UI
      ref.invalidate(authUserProvider);
      ref.invalidate(currentUserHouseholdProvider);

      if (!mounted) return; // Kiểm tra widget còn mounted không

      // Hiển thị thông báo thành công
      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${household.name}!'), // Tham gia thành công
          backgroundColor: Colors.green,
        ),
      );

      context.go('/member-home'); // Chuyển đến trang home của member
    } on HouseholdJoinFailure catch (e) {
      // Xử lý lỗi tham gia cụ thể
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message), // Hiển thị thông báo lỗi
            backgroundColor: e.code == 'already_member' ? Colors.orange : Colors.red, // Màu khác nhau tùy loại lỗi
          ),
        );
      }
    } catch (e) {
      // Xử lý lỗi không mong đợi
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to join household: ${e.toString().replaceFirst('Exception: ', '')}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false); // Kết thúc loading
      }
    }
  }

  // Build UI của màn hình tham gia gia đình
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Màu nền sáng
      appBar: AppBar(
        title: const Text('Join Household'), // Tiêu đề "Tham gia gia đình"
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Nút quay lại
          onPressed: () {
            if (Navigator.of(context).canPop()) { // Nếu có thể pop
              context.pop(); // Quay lại màn hình trước
            } else {
              context.go('/home'); // Nếu không, về home
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), // Padding xung quanh
          child: Form(
            key: _formKey, // Form key để validate
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Chiếm toàn bộ chiều ngang
              children: [
                // Icon tham gia nhóm
                const Icon(
                  Icons.group_add_outlined,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16), // Khoảng cách
                // Hướng dẫn nhập mã
                const Text(
                  'Enter the invite code your household owner shared with you.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24), // Khoảng cách
                // TextFormField nhập mã mời
                TextFormField(
                  controller: _codeController, // Controller quản lý input
                  decoration: const InputDecoration(
                    labelText: 'Invite Code', // Label "Mã mời"
                    hintText: 'E.g. ABC123', // Hint ví dụ
                    helperText: '6-8 characters (letters and numbers only)', // Text hướng dẫn
                    prefixIcon: Icon(Icons.key), // Icon key
                  ),
                  textCapitalization: TextCapitalization.characters, // Tự động viết hoa
                  maxLength: 8, // Tối đa 8 ký tự
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the invite code'; // Lỗi nếu rỗng
                    }
                    final trimmed = value.trim().toUpperCase();
                    if (!RegExp(r'^[A-Z0-9]{6,8}$').hasMatch(trimmed)) {
                      return 'Invalid format. Use 6-8 letters/numbers only'; // Lỗi format sai
                    }
                    return null; // Hợp lệ
                  },
                ),
                const SizedBox(height: 24), // Khoảng cách
                // Nút tham gia
                ElevatedButton(
                  onPressed: _isJoining ? null : _joinHousehold, // Disable khi đang xử lý
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isJoining
                      ? const SizedBox( // Hiển thị loading khi đang xử lý
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join Household'), // Text "Tham gia"
                ),
                const SizedBox(height: 12), // Khoảng cách
                // Nút bỏ qua
                TextButton(
                  onPressed: () {
                    final user = ref.read(authUserProvider).valueOrNull;
                    final destination = (user?.isMember ?? true) ? '/member-home' : '/home'; // Xác định đích đến
                    context.go(destination); // Chuyển đến đích
                  },
                  child: const Text('Skip for now'), // Text "Bỏ qua"
                ),
                const SizedBox(height: 8), // Khoảng cách
                // Text hướng dẫn
                Text(
                  'You can join a household later from Settings.', // "Có thể tham gia sau từ Settings"
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
