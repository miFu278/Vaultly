# Vaultly Frontend (Flutter Web + Android)

Giao diện Flutter quản lý ảnh bảo mật (**Secure Vault Photos**) phong cách tối giản, sạch sẽ, hỗ trợ responsive hoàn hảo cho cả Web/Desktop (2-pane) và Mobile/Android (Drawer).

---

## 📁 Cấu trúc thư mục (`fe/lib`)

```
fe/lib/
├── main.dart                       # Khởi tạo MaterialApp, kết nối Light/Dark theme & HomeScreen
├── theme/
│   └── app_theme.dart              # ThemeData trung tính (Light/Dark mode Material 3)
├── models/
│   ├── folder.dart                 # Model Folder (id, name, icon, photoCount, isSecure, coverUrl)
│   └── photo_item.dart             # Model PhotoItem (id, folderId, title, url, size, isEncrypted)
├── data/
│   └── mock_data.dart              # Mock data dùng khi chưa đăng nhập / offline
├── services/
│   └── api_service.dart            # REST client + session/PIN + upload (ApiException cho lỗi HTTP)
├── widgets/
│   ├── folder_sidebar.dart         # Sidebar dạng 1 cột dọc (hỗ trợ collapse 68px/250px & Drawer)
│   ├── photo_grid.dart             # Lưới ảnh GridView.builder động (2x/3x/4x, pinch-to-zoom)
│   ├── photo_grid_item.dart        # Ô ảnh vuông 1:1, hover scale nhẹ (web), long-press (mobile)
│   └── photo_detail_dialog.dart    # Modal xem ảnh phóng to với InteractiveViewer & metadata
└── screens/
    ├── home_screen.dart            # LayoutBuilder điều phối 2-pane (Web) và Drawer (Mobile)
    ├── auth_screen.dart            # Đăng nhập / đăng ký + cấu hình API base URL
    ├── pin_lock_screen.dart        # Khóa/mở Vault bằng PIN 6 số (đồng bộ server)
    └── photo_viewer_screen.dart    # Trình xem ảnh full-screen (PageView + filmstrip)
```

---

## 🚀 Tính năng nổi bật

1. **Bố cục 2-pane (Desktop / Web)**:
   - Sidebar bên trái liệt kê danh sách folder dạng `ListView`.
   - Nút toggle thu gọn / mở rộng sidebar mượt mà với `AnimatedContainer` (thu về 68px chỉ hiện icon với `Tooltip`, hoặc mở 250px đầy đủ thông tin).
   - Nút tạo thư mục mới "+ Thư mục mới" trực tiếp trên giao diện.

2. **Photo Grid động (2×n / 3×n / 4×n)**:
   - Sử dụng `GridView.builder` với aspect ratio vuông 1:1, bo góc nhẹ.
   - Số cột `crossAxisCount` điều chỉnh mượt qua:
     - Các nút `2x | 3x | 4x`.
     - Slider zoom nhỏ gọn trên thanh điều khiển.
     - Thao tác phóng to / thu nhỏ hai ngón tay (**Pinch-to-zoom**) qua `GestureDetector(onScaleUpdate)`.
   - Số hàng tự động tính toán theo số lượng ảnh trong folder.

3. **Responsive Breakpoint (680px)**:
   - Màn hình rộng (>= 680px): Hiển thị cố định 2-pane (Sidebar + PhotoGrid).
   - Màn hình hẹp (< 680px, Android/Mobile): Sidebar tự động chuyển thành `Drawer` trượt ra từ cạnh trái, AppBar xuất hiện nút menu hamburger.

4. **Style & Theme**:
   - Tông màu trung tính (đen, trắng, xám), typography chuẩn Material 3.
   - Hỗ trợ đầy đủ **Light mode** và **Dark mode**, chuyển đổi tức thì qua nút trên AppBar.

5. **Đồng bộ dữ liệu với backend**:
   - Nạp thư mục + toàn bộ ảnh một lần, tính `photoCount` và ảnh bìa theo từng thư mục (backend không trả sẵn).
   - Chuyển thư mục tức thì (lọc client-side), không phát sinh round-trip.
   - Tự động đăng xuất + quay về dữ liệu mock khi token hết hạn (HTTP 401).

6. **PIN bảo vệ Vault (đồng bộ đa thiết bị)**:
   - PIN 6 số lưu cục bộ và đồng bộ lên server qua `/auth/pin/set`.
   - Máy mới chưa có PIN cục bộ vẫn mở khóa được bằng `/auth/pin/verify`.
   - Tự động khóa sau 15 phút không tương tác.

---

## 🛠 Hướng dẫn chạy

### 1. Kiểm tra môi trường
```bash
flutter doctor
```

### 2. Chạy trên Web
```bash
cd fe
flutter run -d chrome
# hoặc
flutter run -d web-server --web-port=8080
```

### 3. Chạy trên thiết bị Android
```bash
cd fe
flutter run -d android
```

### 4. Chạy kiểm thử tự động (Unit & Widget Tests)
```bash
cd fe
flutter test
```
