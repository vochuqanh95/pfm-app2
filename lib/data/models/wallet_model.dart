// Import thư viện Firestore để làm việc với database
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum định nghĩa các loại ví
enum WalletType { 
  cash, // Tiền mặt
  bank, // Tài khoản ngân hàng
  card, // Thẻ tín dụng/ghi nợ
  ewallet // Ví điện tử
}

// Enum định nghĩa phạm vi sử dụng của ví
enum WalletScope { 
  personal, // Ví cá nhân
  householdShared, // Ví chia sẻ trong gia đình
  memberPrivate // Ví riêng của thành viên
}

// Extension thêm các method tiện ích cho WalletScope
extension WalletScopeX on WalletScope {
  // Getter chuyển đổi WalletScope thành chuỗi để lưu vào database
  String get rawValue {
    switch (this) {
      case WalletScope.householdShared:
        return 'household_shared'; // Trả về chuỗi cho ví chia sẻ
      case WalletScope.memberPrivate:
        return 'member_private'; // Trả về chuỗi cho ví riêng thành viên
      case WalletScope.personal:
      default:
        return 'personal'; // Trả về chuỗi cho ví cá nhân
    }
  }

  // Method static chuyển đổi chuỗi từ database thành WalletScope
  static WalletScope fromRaw(String? raw, {String? householdId}) {
    switch (raw) {
      case 'household_shared':
        return WalletScope.householdShared; // Chuyển thành ví chia sẻ
      case 'member_private':
        return WalletScope.memberPrivate; // Chuyển thành ví riêng thành viên
      case 'personal':
        return WalletScope.personal; // Chuyển thành ví cá nhân
      default:
        // Nếu không có giá trị, kiểm tra householdId để xác định scope
        return (householdId?.isNotEmpty ?? false)
            ? WalletScope.householdShared // Có householdId thì là ví chia sẻ
            : WalletScope.personal; // Không có householdId thì là ví cá nhân
    }
  }
}

// Model đại diện cho ví trong ứng dụng
class WalletModel {
  final String walletId; // ID duy nhất của ví
  final String? userId; // ID của user sở hữu ví (có thể null)
  final String? householdId; // ID của gia đình (nếu là ví chia sẻ)
  final String name; // Tên hiển thị của ví
  final WalletType type; // Loại ví (tiền mặt, ngân hàng, thẻ, ví điện tử)
  final WalletScope scope; // Phạm vi sử dụng (cá nhân, chia sẻ, riêng tư)
  final String currency; // Đơn vị tiền tệ (VD: USD, VND)
  final double openingBalance; // Số dư ban đầu khi tạo ví
  final double balance; // Số dư hiện tại của ví
  final bool archived; // Trạng thái lưu trữ (ví đã được lưu trữ hay chưa)
  final bool isDebt; // Đánh dấu ví có phải là khoản nợ không
  final DateTime createdAt; // Thời gian tạo ví
  final DateTime? updatedAt; // Thời gian cập nhật gần nhất (có thể null)

  // Constructor khởi tạo WalletModel với các tham số bắt buộc và tùy chọn
  const WalletModel({
    required this.walletId,
    this.userId,
    this.householdId,
    required this.name,
    required this.type,
    this.scope = WalletScope.personal, // Mặc định là ví cá nhân
    this.currency = 'USD', // Mặc định là USD
    this.openingBalance = 0.0, // Mặc định số dư ban đầu là 0
    this.balance = 0.0, // Mặc định số dư hiện tại là 0
    this.archived = false, // Mặc định chưa lưu trữ
    this.isDebt = false, // Mặc định không phải là nợ
    required this.createdAt,
    this.updatedAt,
  });

  // Getter lấy ID của user sở hữu ví
  String? get ownerUserId => userId;
  // Getter kiểm tra ví có phải là ví chia sẻ không
  bool get isShared => scope == WalletScope.householdShared;
  // Getter kiểm tra ví có phải là ví riêng của thành viên không
  bool get isMemberPrivate => scope == WalletScope.memberPrivate;
  // Getter kiểm tra ví có phải là ví cá nhân không
  bool get isPersonal => scope == WalletScope.personal;

  // Factory method chuyển đổi DocumentSnapshot từ Firestore thành WalletModel
  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>; // Lấy dữ liệu từ document
    final householdId = (data['householdId'] ?? data['household_id']) as String?; // Lấy householdId (hỗ trợ cả 2 format)
    final userId = (data['userId'] ?? data['user_id']) as String?; // Lấy userId (hỗ trợ cả 2 format)
    final createdAtRaw = data['createdAt'] ?? data['created_at']; // Lấy createdAt (hỗ trợ cả 2 format)
    final updatedAtRaw = data['updatedAt'] ?? data['updated_at']; // Lấy updatedAt (hỗ trợ cả 2 format)

    // Tạo và trả về WalletModel từ dữ liệu Firestore
    return WalletModel(
      walletId: doc.id, // Lấy ID từ document
      userId: userId, // Gán userId
      householdId: householdId, // Gán householdId
      name: data['name'] ?? '', // Lấy tên ví, mặc định rỗng
      type: WalletType.values.firstWhere( // Tìm WalletType phù hợp
        (e) => e.name == data['type'], // So sánh tên enum với data
        orElse: () => WalletType.cash, // Mặc định là cash nếu không tìm thấy
      ),
      scope: WalletScopeX.fromRaw( // Chuyển đổi chuỗi thành WalletScope
        data['scope'],
        householdId: householdId, // Truyền householdId để xác định scope mặc định
      ),
      currency: data['currency'] ?? 'USD', // Lấy currency, mặc định USD
      openingBalance: (data['openingBalance'] ?? data['opening_balance'] ?? 0.0).toDouble(), // Lấy số dư ban đầu
      balance: (data['balance'] ?? 0.0).toDouble(), // Lấy số dư hiện tại
      archived: data['archived'] ?? false, // Lấy trạng thái lưu trữ
      isDebt: data['isDebt'] ?? data['is_debt'] ?? false, // Lấy trạng thái nợ
      createdAt: (createdAtRaw as Timestamp?)?.toDate() ?? DateTime.now(), // Chuyển Timestamp thành DateTime
      updatedAt: (updatedAtRaw as Timestamp?)?.toDate(), // Chuyển Timestamp thành DateTime (có thể null)
    );
  }

  // Method chuyển đổi WalletModel thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    final createdTimestamp = Timestamp.fromDate(createdAt); // Chuyển DateTime thành Timestamp
    final updatedTimestamp = updatedAt != null ? Timestamp.fromDate(updatedAt!) : null; // Chuyển DateTime thành Timestamp (có thể null)
    return {
      'walletId': walletId, // ID ví
      // Ghi cả snake_case và camelCase để đảm bảo tương thích
      'user_id': userId, // ID user (snake_case)
      'userId': userId, // ID user (camelCase)
      'household_id': householdId, // ID gia đình (snake_case)
      'householdId': householdId, // ID gia đình (camelCase)
      'name': name, // Tên ví
      'type': type.name, // Loại ví (chuyển enum thành string)
      'scope': scope.rawValue, // Phạm vi sử dụng (chuyển enum thành string)
      'currency': currency, // Đơn vị tiền tệ
      'openingBalance': openingBalance, // Số dư ban đầu (camelCase)
      'opening_balance': openingBalance, // Số dư ban đầu (snake_case)
      'balance': balance, // Số dư hiện tại
      'archived': archived, // Trạng thái lưu trữ
      'isDebt': isDebt, // Trạng thái nợ (camelCase)
      'is_debt': isDebt, // Trạng thái nợ (snake_case)
      'createdAt': createdTimestamp, // Thời gian tạo (camelCase)
      'created_at': createdTimestamp, // Thời gian tạo (snake_case)
      'updatedAt': updatedTimestamp, // Thời gian cập nhật (camelCase)
      'updated_at': updatedTimestamp, // Thời gian cập nhật (snake_case)
    };
  }

  // Method tạo bản copy của WalletModel với các giá trị được cập nhật
  WalletModel copyWith({
    String? walletId,
    String? userId,
    String? householdId,
    String? name,
    WalletType? type,
    WalletScope? scope,
    String? currency,
    double? openingBalance,
    double? balance,
    bool? archived,
    bool? isDebt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // Trả về WalletModel mới với giá trị mới hoặc giữ nguyên giá trị cũ
    return WalletModel(
      walletId: walletId ?? this.walletId, // Dùng walletId mới hoặc giữ nguyên
      userId: userId ?? this.userId, // Dùng userId mới hoặc giữ nguyên
      householdId: householdId ?? this.householdId, // Dùng householdId mới hoặc giữ nguyên
      name: name ?? this.name, // Dùng name mới hoặc giữ nguyên
      type: type ?? this.type, // Dùng type mới hoặc giữ nguyên
      scope: scope ?? this.scope, // Dùng scope mới hoặc giữ nguyên
      currency: currency ?? this.currency, // Dùng currency mới hoặc giữ nguyên
      openingBalance: openingBalance ?? this.openingBalance, // Dùng openingBalance mới hoặc giữ nguyên
      balance: balance ?? this.balance, // Dùng balance mới hoặc giữ nguyên
      archived: archived ?? this.archived, // Dùng archived mới hoặc giữ nguyên
      isDebt: isDebt ?? this.isDebt, // Dùng isDebt mới hoặc giữ nguyên
      createdAt: createdAt ?? this.createdAt, // Dùng createdAt mới hoặc giữ nguyên
      updatedAt: updatedAt ?? this.updatedAt, // Dùng updatedAt mới hoặc giữ nguyên
    );
  }
}
