# Tóm Tắt Sửa Lỗi Module Budgets

## Vấn Đề Ban Đầu

Module Budgets (Ngân sách) không hoạt động. Khi thành viên tạo giao dịch, số tiền không được tính vào ngân sách mà chủ hộ đã đặt ra.

## Nguyên Nhân

Tính năng theo dõi ngân sách **đã được lập trình đầy đủ** trong code, nhưng các **Cloud Functions chưa được deploy** lên Firebase. Cụ thể:

✅ **Phần Client (Flutter App) - Đã có:**
- Models và services cho budgets
- Giao diện hiển thị budgets
- Kết nối Firestore
- Firestore rules

✅ **Phần Backend (Cloud Functions) - Đã có nhưng chưa deploy:**
- File `functions/src/index.ts` với logic đầy đủ
- 3 triggers: khi tạo/sửa/xóa giao dịch
- Logic phân loại ngân sách family vs member
- Hệ thống thông báo khi vượt 80%, 90%, 100%

❌ **Thiếu:**
- Hướng dẫn deploy Cloud Functions
- Hướng dẫn test tính năng

## Giải Pháp Đã Thực Hiện

### Tạo Tài Liệu Hướng Dẫn Đầy Đủ

1. **CLOUD_FUNCTIONS_SETUP.md** (tiếng Anh)
   - Hướng dẫn deploy Cloud Functions từng bước
   - Cách kiểm tra và khắc phục lỗi
   - Ước tính chi phí (~$0.10-0.50/tháng)

2. **BUDGET_TESTING_GUIDE.md** (tiếng Anh)
   - 8 kịch bản test chi tiết
   - Cách xác nhận tính năng hoạt động
   - Giải quyết các lỗi thường gặp

3. **BUDGET_FIX_SUMMARY.md** (tiếng Anh)
   - Tóm tắt toàn bộ vấn đề và giải pháp
   - Hướng dẫn deploy nhanh

4. **scripts/deploy-functions.sh**
   - Script tự động deploy
   - Kiểm tra điều kiện trước khi deploy

### Cập Nhật README.md
- Thêm phần giải thích về tính năng Budgets
- Thêm hướng dẫn deploy Cloud Functions
- Thêm phần troubleshooting cho budgets

## Cách Deploy (Triển Khai)

### Bước 1: Nâng cấp Firebase Plan

Cloud Functions yêu cầu **Firebase Blaze Plan** (trả theo mức sử dụng).

1. Vào [Firebase Console](https://console.firebase.google.com)
2. Chọn project của bạn
3. Vào **Settings** → **Usage and billing**
4. Chọn **Modify plan** → **Blaze**

**Chi phí ước tính:** $0.10 - $0.50/tháng cho hộ gia đình nhỏ (5-10 giao dịch/ngày)

### Bước 2: Deploy Cloud Functions

**Cách 1: Sử dụng script (Dễ nhất)**
```bash
./scripts/deploy-functions.sh
```

**Cách 2: Deploy thủ công**
```bash
cd functions
npm install
npm run build
npm run deploy
```

### Bước 3: Xác Nhận Deploy Thành Công

```bash
firebase functions:list
```

Bạn sẽ thấy 3 functions:
- `onTransactionCreate`
- `onTransactionUpdate`
- `onTransactionDelete`

## Cách Test Tính Năng

### Test Nhanh

1. **Tạo ngân sách:**
   - Đăng nhập với tài khoản chủ hộ
   - Vào **Budgets** → **Add Budget**
   - Tạo ngân sách cho 1 thành viên: $1000/tháng

2. **Tạo giao dịch:**
   - Đăng nhập với tài khoản thành viên đó
   - Tạo giao dịch chi tiêu: $500
   - Chọn ví **household_shared** (ví gia đình)
   - Lưu

3. **Kiểm tra ngân sách:**
   - Vào màn hình **Budgets**
   - Ngân sách sẽ hiển thị:
     - Đã chi: $500
     - Còn lại: $500
     - Tiến độ: 50%

### Test Chi Tiết

Xem file **BUDGET_TESTING_GUIDE.md** để có 8 kịch bản test đầy đủ.

## Cách Hoạt Động

Khi Cloud Functions đã được deploy:

1. **Thành viên tạo giao dịch chi tiêu** từ ví household_shared
2. **Cloud Function tự động chạy** → `onTransactionCreate`
3. **Truy vấn ngân sách** phù hợp (family hoặc member)
4. **Cập nhật budget_usages** với tổng chi tiêu mới
5. **Giao diện tự động cập nhật** hiển thị chi tiêu mới
6. **Gửi thông báo** nếu vượt 80%, 90%, hoặc 100%

## Loại Ngân Sách

### Family Budgets (Ngân sách gia đình)
- Tính tổng chi tiêu của **tất cả thành viên**
- Ví dụ: Toàn gia đình chi tối đa $2000/tháng cho ăn uống

### Member Budgets (Ngân sách cá nhân)
- Chỉ tính chi tiêu của **1 thành viên cụ thể**
- Ví dụ: Anh A chi tối đa $500/tháng cho mua sắm

## Điều Kiện Tính Vào Ngân Sách

Giao dịch chỉ ảnh hưởng đến ngân sách khi:
- ✅ Loại giao dịch: **Chi tiêu** (expense)
- ✅ Từ ví: **household_shared** (ví gia đình chia sẻ)
- ✅ Có household_id và actor_user_id
- ✅ Trong cùng tháng với ngân sách

❌ Các giao dịch này KHÔNG tính:
- Thu nhập (income)
- Chuyển khoản (transfer)
- Chi tiêu từ ví cá nhân (personal wallet)
- Chi tiêu từ ví riêng của thành viên (member_private wallet)

## Thông Báo Cảnh Báo

Hệ thống sẽ gửi thông báo khi:
- 80% ngân sách: "Budget 80%" (Cảnh báo đầu tiên)
- 90% ngân sách: "Budget 90%" (Cảnh báo thứ hai)
- 100% ngân sách: "Budget 100%" (Vượt ngân sách)

Thông báo được gửi đến:
- Chủ hộ (người tạo ngân sách)
- Thành viên (nếu là ngân sách cá nhân)

## Khắc Phục Lỗi

### Ngân sách không cập nhật sau khi tạo giao dịch

1. **Kiểm tra Cloud Functions đã deploy:**
   ```bash
   firebase functions:list
   ```

2. **Xem log của functions:**
   ```bash
   firebase functions:log
   ```

3. **Kiểm tra giao dịch:**
   - Loại: expense ✓
   - Ví: household_shared ✓
   - Có household_id ✓
   - Có actor_user_id ✓

### Không nhận được thông báo

1. Kiểm tra collection `budget_usages` trong Firestore
2. Xem field `last_alert_level_sent`
3. Kiểm tra collection `notifications`
4. Xem log functions: `firebase functions:log`

### Lỗi permission denied

1. Xác nhận Firestore rules đã deploy
2. Kiểm tra user đã đăng nhập
3. Xác nhận user thuộc household của ngân sách

## Chi Phí

### Firebase Blaze Plan

Cloud Functions yêu cầu Blaze plan (trả theo sử dụng).

**Cho hộ gia đình nhỏ (5-10 giao dịch/ngày):**
- Lượt gọi functions: ~15-30/ngày = ~450-900/tháng
- Đọc/ghi Firestore: ~30-60/ngày
- **Chi phí ước tính: $0.10 - $0.50/tháng**

**Miễn phí:**
- 2 triệu lượt gọi functions/tháng
- 50,000 lượt đọc Firestore/ngày
- 20,000 lượt ghi Firestore/ngày

→ Hầu hết các hộ gia đình nhỏ đều nằm trong mức miễn phí!

## Tổng Kết

### Vấn đề
- Module Budgets không hoạt động vì Cloud Functions chưa được deploy

### Giải pháp
- Tạo tài liệu hướng dẫn deploy đầy đủ
- Tạo script tự động deploy
- Tạo hướng dẫn test chi tiết
- Cập nhật README.md

### Không thay đổi code
- ✅ Code Flutter app đã đúng
- ✅ Code Cloud Functions đã đúng
- ✅ Firestore rules đã đúng
- ✅ Chỉ cần deploy Cloud Functions và test!

## Các File Tài Liệu

- **[CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md)** - Hướng dẫn deploy Cloud Functions (Tiếng Anh)
- **[BUDGET_TESTING_GUIDE.md](BUDGET_TESTING_GUIDE.md)** - Hướng dẫn test (Tiếng Anh)
- **[BUDGET_FIX_SUMMARY.md](BUDGET_FIX_SUMMARY.md)** - Tóm tắt chi tiết (Tiếng Anh)
- **[BUDGET_FIX_SUMMARY_VI.md](BUDGET_FIX_SUMMARY_VI.md)** - File này (Tiếng Việt)
- **[functions/README.md](functions/README.md)** - Chi tiết về Cloud Functions

## Liên Hệ

Nếu gặp vấn đề:
1. Xem phần Troubleshooting trong CLOUD_FUNCTIONS_SETUP.md
2. Kiểm tra Firebase Console logs
3. Xem BUDGET_TESTING_GUIDE.md để test từng bước

---

**Thời gian deploy:** 5-10 phút  
**Chi phí ước tính:** ~$0.10-0.50/tháng  
**Độ phức tạp:** Thấp (1 lệnh deploy)  
**Rủi ro:** Không có (functions chỉ đọc và ghi budget_usages)
