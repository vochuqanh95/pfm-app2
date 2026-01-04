// Import BudgetModel để sử dụng thông tin ngân sách
import 'budget_model.dart';

// Class đại diện cho thông tin sử dụng ngân sách trong một kỳ
class BudgetUsage {
  final String periodKey; // Key định danh kỳ ngân sách (VD: "2024-01" cho tháng 1/2024)
  final double spentAmount; // Số tiền đã chi tiêu trong kỳ
  final int lastAlertLevelSent; // Mức cảnh báo cuối cùng đã gửi (0, 80, 90, 100)
  final DateTime? updatedAt; // Thời gian cập nhật gần nhất (có thể null)

  // Constructor khởi tạo BudgetUsage
  const BudgetUsage({
    required this.periodKey,
    required this.spentAmount,
    this.lastAlertLevelSent = 0, // Mặc định chưa gửi cảnh báo nào
    this.updatedAt,
  });

  // Method chuyển BudgetUsage thành Map để lưu vào database
  Map<String, dynamic> toMap() => {
        'period_key': periodKey, // Key kỳ ngân sách
        'spent_amount': spentAmount, // Số tiền đã chi
        'last_alert_level_sent': lastAlertLevelSent, // Mức cảnh báo cuối
        'updated_at': updatedAt, // Thời gian cập nhật
      };
}

// Class kết hợp thông tin ngân sách và dữ liệu sử dụng đã tính toán/denormalized
class BudgetWithUsage {
  final BudgetModel budget; // Thông tin ngân sách
  final BudgetUsage usage; // Thông tin sử dụng ngân sách

  // Constructor khởi tạo BudgetWithUsage
  const BudgetWithUsage({
    required this.budget,
    required this.usage,
  });

  // Các thuộc tính tính toán
  double get remainingAmount => budget.amount - usage.spentAmount; // Tính số tiền còn lại

  // Tính phần trăm đã sử dụng
  double get usagePercent {
    if (budget.amount == 0) return 0.0; // Tránh chia cho 0
    return (usage.spentAmount / budget.amount) * 100; // Tính % sử dụng
  }

  // Kiểm tra có vượt ngân sách không
  bool get isOverBudget => usage.spentAmount > budget.amount;

  // Kiểm tra có gần đến giới hạn không (đạt ngưỡng cảnh báo)
  bool get isNearLimit => usagePercent >= (budget.alertThreshold * 100);

  // Xác định mức ngưỡng hiện tại đang ở (0, 80, 90, 100)
  int get currentThreshold {
    if (usagePercent >= 100) return 100; // Vượt 100%
    if (usagePercent >= 90) return 90; // Vượt 90%
    if (usagePercent >= 80) return 80; // Vượt 80%
    return 0; // Dưới 80%
  }
}
