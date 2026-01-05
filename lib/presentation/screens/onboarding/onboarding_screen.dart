// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import go_router để điều hướng giữa các màn hình
import 'package:go_router/go_router.dart';
// Import màu sắc ứng dụng
import '../../../core/theme/app_colors.dart';

// Màn hình Onboarding - giới thiệu tính năng app cho người dùng mới
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// State của OnboardingScreen quản lý trạng thái các trang giới thiệu
class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(); // Controller điều khiển PageView
  int _currentPage = 0; // Trang hiện tại đang hiển thị

  // Danh sách các trang onboarding với nội dung giới thiệu
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Track Your Spending', // Theo dõi chi tiêu
      description: 'Keep track of all your income and expenses in one place', // Theo dõi thu chi một chỗ
      icon: Icons.account_balance_wallet, // Icon ví
      color: AppColors.primary, // Màu primary
    ),
    OnboardingPage(
      title: 'Set Budget Goals', // Đặt mục tiêu ngân sách
      description: 'Create budgets and achieve your financial goals together', // Tạo ngân sách và đạt mục tiêu tài chính
      icon: Icons.track_changes, // Icon theo dõi thay đổi
      color: AppColors.secondary, // Màu secondary
    ),
    OnboardingPage(
      title: 'Manage as a Family', // Quản lý cùng gia đình
      description: 'Collaborate with your family to manage finances smartly', // Hợp tác với gia đình quản lý tài chính thông minh
      icon: Icons.groups, // Icon nhóm người
      color: AppColors.chartYellow, // Màu vàng
    ),
  ];

  // Giải phóng tài nguyên khi widget bị hủy
  @override
  void dispose() {
    _pageController.dispose(); // Hủy PageController
    super.dispose();
  }

  // Callback khi trang thay đổi
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page; // Cập nhật trang hiện tại
    });
  }

  // Xử lý khi nhấn nút Next/Get Started
  void _onNext() {
    if (_currentPage < _pages.length - 1) { // Nếu chưa phải trang cuối
      _pageController.nextPage( // Chuyển sang trang tiếp theo
        duration: const Duration(milliseconds: 300), // Thời gian animation
        curve: Curves.easeInOut, // Đường cong animation
      );
    } else { // Nếu đã là trang cuối
      context.go('/login'); // Chuyển đến màn hình đăng nhập
    }
  }

  // Xử lý khi nhấn nút Skip
  void _onSkip() {
    context.go('/login'); // Bỏ qua onboarding và chuyển thẳng đến đăng nhập
  }

  // Build UI của màn hình onboarding
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight, // Màu nền sáng
      body: SafeArea(
        child: Column(
          children: [
            // Nút Skip ở góc trên bên phải
            Align(
              alignment: Alignment.topRight, // Căn phải trên
              child: TextButton(
                onPressed: _onSkip, // Gọi hàm skip
                child: const Text('Skip'), // Text "Bỏ qua"
              ),
            ),
            // PageView hiển thị các trang onboarding
            Expanded(
              child: PageView.builder(
                controller: _pageController, // Controller quản lý trang
                onPageChanged: _onPageChanged, // Callback khi đổi trang
                itemCount: _pages.length, // Số lượng trang
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]); // Build từng trang
                },
              ),
            ),
            // Indicators (các chấm tròn chỉ trang hiện tại)
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Căn giữa
              children: List.generate(
                _pages.length, // Tạo số lượng indicator bằng số trang
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4), // Khoảng cách giữa các chấm
                  width: _currentPage == index ? 24 : 8, // Chấm hiện tại rộng hơn
                  height: 8, // Chiều cao chấm
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary // Màu primary cho trang hiện tại
                        : Colors.grey.shade300, // Màu xám cho các trang khác
                    borderRadius: BorderRadius.circular(4), // Bo tròn góc
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32), // Khoảng cách
            // Nút Next/Get Started ở dưới cùng
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24), // Padding 2 bên
              child: ElevatedButton(
                onPressed: _onNext, // Gọi hàm next
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56), // Chiều rộng tối thiểu full width
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next', // "Bắt đầu" hoặc "Tiếp"
                ),
              ),
            ),
            const SizedBox(height: 32), // Khoảng cách cuối
          ],
        ),
      ),
    );
  }

  // Method build UI cho một trang onboarding
  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40.0), // Padding xung quanh
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Căn giữa theo chiều dọc
        children: [
          // Container chứa icon với màu nền tròn
          Container(
            width: 200, // Chiều rộng
            height: 200, // Chiều cao
            decoration: BoxDecoration(
              shape: BoxShape.circle, // Hình tròn
              color: page.color.withOpacity(0.1), // Màu nền nhạt
            ),
            child: Icon(
              page.icon, // Icon của trang
              size: 100, // Kích thước icon
              color: page.color, // Màu icon
            ),
          ),
          const SizedBox(height: 48), // Khoảng cách
          // Tiêu đề trang
          Text(
            page.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold, // Chữ đậm
                  color: AppColors.textPrimary, // Màu chữ chính
                ),
            textAlign: TextAlign.center, // Căn giữa
          ),
          const SizedBox(height: 16), // Khoảng cách
          // Mô tả trang
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary, // Màu chữ phụ
                ),
            textAlign: TextAlign.center, // Căn giữa
          ),
        ],
      ),
    );
  }
}

// Model dữ liệu cho một trang onboarding
class OnboardingPage {
  final String title; // Tiêu đề trang
  final String description; // Mô tả chi tiết
  final IconData icon; // Icon hiển thị
  final Color color; // Màu sắc chủ đạo của trang

  // Constructor
  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
