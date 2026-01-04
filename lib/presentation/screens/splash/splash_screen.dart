// Import các thư viện cần thiết cho Flutter UI
import 'package:flutter/material.dart';
// Import go_router để điều hướng giữa các màn hình
import 'package:go_router/go_router.dart';
// Import màu sắc ứng dụng
import '../../../core/theme/app_colors.dart';

// Màn hình Splash - màn hình đầu tiên khi mở app
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// State của SplashScreen
class _SplashScreenState extends State<SplashScreen> {
  // Khởi tạo state khi màn hình được tạo
  @override
  void initState() {
    super.initState();
    _navigateToNext(); // Gọi hàm điều hướng đến màn hình tiếp theo
  }

  // Hàm điều hướng đến màn hình onboarding sau 3 giây
  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3)); // Chờ 3 giây
    if (mounted) { // Kiểm tra widget còn được mount không
      context.go('/onboarding'); // Chuyển đến màn hình onboarding
    }
  }

  // Build UI của màn hình splash
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary, // Màu nền phụ
      body: Container(
        // Gradient nền từ xanh ngọc sang xanh dương
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF50E3C2), Color(0xFF4A90E2)], // Màu gradient từ trên xuống
            begin: Alignment.topCenter, // Bắt đầu từ trên
            end: Alignment.bottomCenter, // Kết thúc ở dưới
          ),
        ),
        child: Stack(
          children: [
            // PHẦN CÁC ICON NỀN TRANG TRÍ
            // Icon ví ở góc trên bên trái
            Positioned(
              top: 100, // Vị trí từ trên
              left: 40, // Vị trí từ trái
              child: Icon(
                Icons.account_balance_wallet_outlined, // Icon ví
                size: 80, // Kích thước icon
                color: Colors.white.withValues(alpha: 0.2), // Màu trắng trong suốt
              ),
            ),
            // Icon trending up ở góc trên bên phải
            Positioned(
              top: 120, // Vị trí từ trên
              right: 60, // Vị trí từ phải
              child: Icon(
                Icons.trending_up, // Icon xu hướng tăng
                size: 100, // Kích thước icon
                color: Colors.white.withValues(alpha: 0.2), // Màu trắng trong suốt
              ),
            ),
            // Icon trending up ở góc dưới bên trái
            Positioned(
              bottom: 200, // Vị trí từ dưới
              left: 60, // Vị trí từ trái
              child: Icon(
                Icons.trending_up, // Icon xu hướng tăng
                size: 80, // Kích thước icon
                color: Colors.white.withValues(alpha: 0.2), // Màu trắng trong suốt
              ),
            ),
            // Icon nhà ở góc dưới bên phải
            Positioned(
              bottom: 150, // Vị trí từ dưới
              right: 40, // Vị trí từ phải
              child: Icon(
                Icons.home, // Icon nhà
                size: 90, // Kích thước icon
                color: Colors.white.withValues(alpha: 0.2), // Màu trắng trong suốt
              ),
            ),
            // PHẦN LOGO VÀ TÊN ỨNG DỤNG Ở GIỮA MÀN HÌNH
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Căn giữa theo chiều dọc
                children: [
                  // Container chứa logo ứng dụng
                  Container(
                    width: 150, // Chiều rộng container
                    height: 150, // Chiều cao container
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, // Hình tròn
                      color: Colors.white.withValues(alpha: 0.3), // Màu nền trắng trong suốt
                    ),
                    child: Stack(
                      alignment: Alignment.center, // Căn giữa các phần tử
                      children: [
                        // Vòng tròn chính chứa icon nhóm
                        Container(
                          width: 120, // Chiều rộng
                          height: 120, // Chiều cao
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, // Hình tròn
                            border: Border.all(
                              color: Colors.white, // Viền màu trắng
                              width: 4, // Độ dày viền
                            ),
                          ),
                          child: const Icon(
                            Icons.groups, // Icon nhóm người
                            size: 60, // Kích thước icon
                            color: Colors.white, // Màu trắng
                          ),
                        ),
                        // Icon trending nhỏ ở góc dưới phải của logo
                        Positioned(
                          bottom: 15, // Vị trí từ dưới
                          right: 15, // Vị trí từ phải
                          child: Container(
                            width: 40, // Chiều rộng
                            height: 40, // Chiều cao
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, // Hình tròn
                              color: Color(0xFFFFD166), // Màu vàng
                            ),
                            child: const Icon(
                              Icons.trending_up, // Icon xu hướng tăng
                              size: 24, // Kích thước icon
                              color: Colors.white, // Màu trắng
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Khoảng cách giữa logo và tên
                  // Tên ứng dụng "FamilyWealth"
                  Text(
                    'FamilyWealth',
                    style: TextStyle(
                      fontSize: 42, // Kích thước chữ lớn
                      fontWeight: FontWeight.bold, // Chữ đậm
                      color: Colors.white, // Màu trắng
                      letterSpacing: 1.2, // Khoảng cách giữa các chữ cái
                      shadows: [
                        // Đổ bóng cho chữ
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.1), // Màu bóng đen nhạt
                          offset: const Offset(0, 2), // Độ lệch bóng
                          blurRadius: 4, // Độ mờ của bóng
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8), // Khoảng cách
                  // Slogan ứng dụng
                  Text(
                    'Manage Your Family Finances', // "Quản lý tài chính gia đình"
                    style: TextStyle(
                      fontSize: 16, // Kích thước chữ nhỏ hơn
                      color: Colors.white.withValues(alpha: 0.9), // Màu trắng hơi trong suốt
                      letterSpacing: 0.5, // Khoảng cách chữ cái
                    ),
                  ),
                ],
              ),
            ),
            // PHẦN LOADING INDICATOR Ở DƯỚI CÙNG
            Positioned(
              bottom: 80, // Vị trí từ dưới lên
              left: 0, // Từ trái
              right: 0, // Đến phải (chiếm toàn bộ chiều ngang)
              child: Center(
                child: SizedBox(
                  width: 40, // Chiều rộng loading indicator
                  height: 40, // Chiều cao loading indicator
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8), // Màu trắng hơi trong suốt
                    ),
                    strokeWidth: 3, // Độ dày của vòng xoay
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
