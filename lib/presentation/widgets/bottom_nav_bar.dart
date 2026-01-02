import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context,
              icon: Icons.home,
              label: 'Home',
              index: 0,
              route: '/home',
            ),
            _buildNavItem(
              context,
              icon: Icons.account_balance_wallet,
              label: 'Wallets',
              index: 1,
              route: '/wallets',
            ),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(
              context,
              icon: Icons.savings,
              label: 'Goals',
              index: 2,
              route: '/goals',
            ),
            _buildNavItem(
              context,
              icon: Icons.bar_chart,
              label: 'Reports',
              index: 3,
              route: '/reports',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required String route,
  }) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          context.go(route);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
