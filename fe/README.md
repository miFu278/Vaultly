# Vaultly Frontend (Flutter Web + Android)

Giao diện Flutter quản lý **ảnh & video** bảo mật (**Secure Media Vault**) — ngôn ngữ thiết kế flat Material 3 theo hệ "Nimbus Soft" (xem `DESIGN.md`) — responsive cho cả Web/Desktop (rail + nội dung) và Mobile/Android (drawer + dock).

---

## 📁 Cấu trúc thư mục (`fe/lib`)

```
fe/lib/
├── main.dart                       # Khởi tạo MaterialApp, kết nối Light/Dark theme & HomeScreen
├── theme/
│   ├── app_theme.dart              # ThemeData flat Material 3 (Light/Dark)
│   └── app_tokens.dart             # Tokens: màu, AppElevation, typography, radius, spacing
├── models/
│   ├── folder.dart                 # Model Folder (id, name, icon, photoCount, isSecure, coverUrl)
│   └── photo_item.dart             # Model PhotoItem (id, folderId, title, url, size, isEncrypted, isVideo)
├── data/
│   └── mock_data.dart              # Mock data dùng khi chưa đăng nhập / offline
├── services/
│   └── api_service.dart            # REST client + session/PIN + upload (ApiException cho lỗi HTTP)
├── widgets/
│   ├── flat.dart                   # Primitive: VaultMark, SurfaceCard, PillButton, SegmentedPills, AppDialog
│   ├── tiles.dart                  # TintedIconTile, FolderCard (hình folder có tab), StorageGauge
│   ├── album_card.dart             # Card album: cover ghép + tên + số mục + menu xoá
│   ├── photo_tile.dart             # Ô ảnh/video vuông cho gallery
│   └── video_player_view.dart      # Trình phát video E2EE (play/pause, seek, buffering, retry)
└── screens/
    ├── main.dart                   # Chọn onboarding lần đầu hay vào thẳng shell
    ├── home_screen.dart            # Shell: header, rail/drawer, dock, FAB + toàn bộ logic dữ liệu
    ├── overview_view.dart          # Tổng quan dung lượng (Ảnh/Video/Album/Tệp) + vòng đo hạn mức
    ├── onboarding_screen.dart      # 3 trang giới thiệu, chỉ hiện một lần
    ├── gallery_view.dart           # Timeline theo ngày, search, filter media, mật độ lưới
    ├── albums_view.dart            # Lưới album (folder) với cover ghép
    ├── files_view.dart             # Duyệt album + danh sách tệp gần đây
    ├── settings_view.dart          # Tài khoản, khoá, theme, đồng bộ, API URL
    ├── auth_screen.dart            # Đăng nhập / đăng ký + cấu hình API base URL
    ├── pin_lock_screen.dart        # Khóa/mở Vault bằng PIN 6 số (đồng bộ server)
    └── photo_viewer_screen.dart    # Trình xem full-screen: ảnh (PageView + filmstrip) & video (player)
```

---

## 🚀 Tính năng nổi bật

1. **Tổng quan dung lượng (tab đầu tiên)**:
   - Bốn card Ảnh / Video / Album / Tệp lấy số thật từ `GET /storage` (BE) — không có số bịa.
   - Vòng đo hạn mức: cung Ảnh (amber) và Video (blue), phần trăm dùng trên tổng quota của tài khoản.
   - Kệ album dùng thẻ hình folder; bấm là mở gallery đã lọc theo album đó.

2. **Điều hướng theo màn hình rộng (Desktop / Web)**:
   - Rail bên trái 248px: 4 điểm đến (Gallery, Albums, Files, Settings) + danh sách album kèm số mục + nút "Album mới".
   - Nội dung giới hạn 1040px và canh giữa để mắt không phải quét ngang quá xa.

3. **Lưới ảnh theo timeline (Gallery)**:
   - Ảnh gom theo ngày với tiêu đề `Hôm nay` / `Hôm qua` / `dd/mm/yyyy` và chip số lượng.
   - Pill chọn mật độ `3x → 4x → 2x` (mặc định 3 cột trên điện thoại, 4 cột trên màn rộng).
   - Filter `Tất cả | Ảnh | Video` và ô tìm kiếm theo tên tệp.
   - Chọn nhiều: thanh nổi ở đáy với chọn tất cả, thêm vào album, xoá.

4. **Responsive Breakpoint (680px)**:
   - Màn hình rộng (>= 680px): rail cố định + nội dung.
   - Màn hình hẹp (< 680px): rail chuyển thành `Drawer` (mở từ logo ở header), dock điều hướng nổi ở đáy, FAB tải tệp phía trên dock.

5. **Style & Theme (flat)**:
   - Bề mặt trắng + viền hairline 1px; bóng chỉ dùng cho dock, thanh chọn và FAB (`AppElevation.floating`).
   - Bo góc lớn (20-28px) và mọi nút/chip đều dạng pill; một hành động primary mỗi màn hình.
   - Hỗ trợ **Light mode** và **Dark mode**, đổi ngay trong Settings hoặc ở header. App mở mặc định ở light mode, không phụ thuộc theme hệ thống của máy.
   - Toàn bộ token ở `theme/app_tokens.dart`; `test/theme_test.dart` chặn hồi quy tương phản text (>= 4.5:1).

6. **Video E2EE (upload → xem → phát)**:
   - Upload video (`.mp4/.mov/.webm/.mkv` hoặc chọn hỗn hợp ảnh + video); server nhận diện bằng magic bytes và lưu `content_type = video/*`.
   - Ô video trong lưới là card có nút play (không tải stream qua `Image.network`).
   - Trình xem full-screen phát video qua `video_player` với play/pause, thanh tua (seek), chỉ báo buffering và nút **Thử lại** khi lỗi.
   - Seek hoạt động nhờ backend trả **HTTP Range (206)** cho `/files/{id}/view`.

7. **Đồng bộ dữ liệu với backend**:
   - Nạp thư mục + toàn bộ ảnh một lần, tính `photoCount` và ảnh bìa theo từng thư mục (backend không trả sẵn).
   - Chuyển thư mục tức thì (lọc client-side), không phát sinh round-trip.
   - Tự động đăng xuất + quay về dữ liệu mock khi token hết hạn (HTTP 401).

8. **PIN bảo vệ Vault (đồng bộ đa thiết bị)**:
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

### 5. Release lên Cloudflare Pages (production)

Web production: **https://vaultly-ct9.pages.dev** — Pages project `vaultly`, branch production `main`.

```bash
cd fe
flutter build web --release                                        # → build/web
npx -y wrangler@4 pages deploy build/web --project-name=vaultly --branch=main
```

- `--branch=main` là bắt buộc để ghi vào **Production**; thiếu cờ này wrangler tạo preview deployment (URL dạng `<hash>.vaultly-ct9.pages.dev`).
- Máy mới cần đăng nhập 1 lần: `npx -y wrangler@4 login` (mở trình duyệt, chọn đúng account Cloudflare).

Kiểm tra bản đã lên sóng đúng là bản vừa build:

```bash
md5sum build/web/main.dart.js
curl -s https://vaultly-ct9.pages.dev/main.dart.js | md5sum        # phải trùng nhau
npx -y wrangler@4 pages deployment list --project-name=vaultly     # xem Environment / Commit
```

Đổi API backend khi build (mặc định `https://vaultly-ghqy.onrender.com`):

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

> Flutter web dùng service worker: máy đang mở app có thể phải reload 1–2 lần mới nhận bundle mới.

### 6. Release app Android (APK / AAB)

App id `com.vaultly.vaultly`, `minSdk 24`, `targetSdk 36`, version lấy từ `pubspec.yaml` (`version: 1.0.0+1`).

#### 6.1 Ký release (làm 1 lần cho mỗi máy)

Bản release **không** dùng debug key; cần upload keystore + `android/key.properties` (cả hai đã được `android/.gitignore` bỏ qua, **không bao giờ commit**):

```bash
cd fe/android
keytool -genkeypair -v -keystore vaultly-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias vaultly \
  -dname "CN=Vaultly, OU=Vaultly, O=Vaultly, L=Ho Chi Minh, ST=HCM, C=VN"

# key.properties trỏ tới keystore (storeFile tính từ thư mục fe/android)
cat > key.properties <<'EOF'
storePassword=<mật khẩu keystore>
keyPassword=<mật khẩu key>
keyAlias=vaultly
storeFile=vaultly-upload.jks
EOF
```

> ⚠️ **Backup `vaultly-upload.jks` + mật khẩu ở nơi an toàn.** Mất keystore là không thể cập nhật app trên Google Play dưới cùng application id (trừ khi bật Play App Signing và xin reset upload key). File này không nằm trong git.

#### 6.2 Build artifact

```bash
cd fe
flutter build appbundle --release      # → build/app/outputs/bundle/release/app-release.aab  (Google Play)
flutter build apk --release            # → build/app/outputs/flutter-apk/app-release.apk    (cài trực tiếp, mọi ABI)
flutter build apk --release --split-per-abi   # 3 APK nhỏ hơn: armeabi-v7a / arm64-v8a / x86_64
```

- APK `--split-per-abi` cộng thêm `1000 × chỉ số ABI` vào versionCode (arm64-v8a → `2001`), APK universal và AAB giữ nguyên versionCode trong `pubspec.yaml`.
- Muốn lên bản mới: tăng `version:` trong `pubspec.yaml` (ví dụ `1.0.1+2`) rồi build lại; Google Play yêu cầu versionCode tăng dần.
- Máy không có `key.properties` vẫn build được nhưng ký bằng debug key — **không phát hành** artifact đó.

Kiểm tra artifact đã ký bằng đúng upload key:

```bash
APKSIGNER=$(ls "$ANDROID_HOME"/build-tools/*/apksigner.bat | sort -V | tail -1)
"$APKSIGNER" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# SHA-256 phải khớp keystore: B3:0B:FC:4F:8C:EC:B6:F3:C2:DB:6B:68:A1:BD:55:AC:BE:BB:08:7F:6A:75:3C:B2:D1:32:EF:AF:93:52:B0:D1
```

#### 6.3 Phát hành

- **Google Play**: Play Console → tạo app → upload file `.aab` (nên test ở kênh *Internal testing* trước) → điền Data safety (app lưu ảnh/video lên server, có đăng nhập). Play App Signing sẽ giữ app signing key riêng, keystore ở trên chỉ là upload key.
- **Cài trực tiếp / tester**: gửi file APK universal hoặc `arm64-v8a` (hầu hết điện thoại hiện nay); máy cài lần đầu phải bật "Cài đặt từ nguồn không xác định".
- API backend lấy mặc định `https://vaultly-ghqy.onrender.com`, muốn trỏ nơi khác thì build kèm `--dart-define=API_BASE_URL=https://...` (hoặc đổi trong màn hình đăng nhập).
