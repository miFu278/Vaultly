---
version: 2.0
name: Vaultly
description: Modern multi-pane layout with Neumorphic (soft-UI) design language for Vaultly secure photo & video vault (Flutter web + Android).
colors:
  background: "#E8EDF3"
  surface: "#E8EDF3"
  surface-muted: "#E0E6ED"
  media-canvas: "#DDE4EC"
  border: "#D5DDE6"
  foreground: "#2C333D"
  foreground-muted: "#555F6B"
  primary: "#2C333D"
  accent-action: "#1E293B"
  accent-pill: "#FFFFFF"
  danger: "#AE2F2A"
  scrim: "#000000"
typography:
  brand:
    fontSize: 17px
    fontWeight: 700
    letterSpacing: -0.4px
  title-lg:
    fontSize: 24px
    fontWeight: 700
    letterSpacing: -0.5px
  title:
    fontSize: 18px
    fontWeight: 600
    letterSpacing: -0.2px
  heading:
    fontSize: 14px
    fontWeight: 600
    letterSpacing: -0.2px
  body:
    fontSize: 13px
    fontWeight: 500
  label:
    fontSize: 12px
    fontWeight: 500
  caption:
    fontSize: 11px
    fontWeight: 500
  micro:
    fontSize: 10px
    fontWeight: 500
rounded:
  xs: 8px
  sm: 10px
  md: 12px
  lg: 16px
  xl: 20px
  pill: 999px
depth:
  light-from: top-left
  raised-offset: 4px
  raised-blur: 8px
  raised-color-light: "rgba(163, 177, 198, 0.30)"
  raised-highlight-light: "rgba(255, 255, 255, 0.80)"
  raised-color-dark: "rgba(0, 0, 0, 0.45)"
  raised-highlight-dark: "rgba(255, 255, 255, 0.07)"
  inset-shade-light: "rgba(0, 0, 0, 0.07)"
  inset-sheen-light: "rgba(255, 255, 255, 0.70)"
  inset-shade-dark: "rgba(0, 0, 0, 0.35)"
  inset-sheen-dark: "rgba(255, 255, 255, 0.05)"
  hover-lift: 1.3
  pressed-scale: 0.98
motion:
  fast: 130ms
  medium: 200ms
  ease: ease-out
spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  touch-target: 44px
  nav-rail-width: 68px
  sidebar-width: 240px
  top-header-height: 56px
  pane-breakpoint: 680px
  desktop-breakpoint: 1024px
  form-max: 440px
  dialog-max: 800px
components:
  nav-rail:
    width: "{spacing.nav-rail-width}"
    itemSize: 52px
    iconSize: 20px
  nav-sidebar:
    width: "{spacing.sidebar-width}"
    itemHeight: 38px
    rounded: "{rounded.sm}"
  top-header:
    height: "{spacing.top-header-height}"
    searchMaxWidth: 440px
  action-pill:
    height: 38px
    rounded: "{rounded.pill}"
  dropzone-canvas:
    minHeight: 360px
    borderStyle: dashed
    rounded: "{rounded.lg}"
  photo-tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.sm}"
    depth: 0.8
  folder-item:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.sm}"
    depth: 0.55
  segmented-control:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.pill}"
    inset: true
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
    depth: 1.4
  media-viewer:
    backgroundColor: "{colors.media-canvas}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.xl}"
---

# Vaultly Design System & Layout Architecture

## 1. Overview

**Vaultly** là ứng dụng kho lưu trữ ảnh và video bảo mật đa nền tảng (Flutter Web + Android): các thư mục chứa dữ liệu media được mã hóa đầu cuối, truy cập thông qua tài khoản và mã PIN 6 số.

Hệ thống giao diện sử dụng ngôn ngữ **Neumorphism (Soft-UI)**: canvas và toàn bộ bề mặt dùng chung một tone màu cơ sở, các khối tử nổi (raised) hoặc lõm (inset/debossed) tách biệt bởi cặp bóng đổ sáng/tối tự nhiên từ góc trên-trái.

Bố cục không gian làm việc (Workspace Layout) mới được tinh chỉnh theo cấu trúc phân tầng trực quan và gọn gàng:
1. **Tier 1 — Global Navigation Rail (Cột bên trái ngoài cùng, 68px)**: Chuyển đổi ngữ cảnh chính (Kho ảnh, Thư mục, Mục yêu thích, Khóa PIN & Cài đặt).
2. **Tier 2 — Folder & Vault Sidebar (Cột danh mục thư mục, 240px)**: Quản lý cây thư mục mã hóa, truy cập nhanh (Quick access), và thẻ trạng thái bảo mật PIN / bộ nhớ.
3. **Tier 3 — Main Vault Canvas (Không gian hiển thị & thao tác chính)**:
   - **Thanh công cụ trên cùng (Top Command Bar, 56px)**: Nút hành động nhanh `+ Thêm mới`, ô tìm kiếm media, trạng thái mã hóa, nút khóa nhanh Vault (`Lock Now`), và tài khoản.
   - **Thanh tiêu đề thư mục (Workspace Action Header)**: Tên thư mục hiện tại, tổng số ảnh/video, bộ lọc loại media (Ảnh, Video, Yêu thích), nút Upload/Tạo thư mục, và nút chuyển chế độ hiển thị (Lưới ảnh ⊞ / Danh sách ☰).
   - **Vùng Canvas chính (Media Canvas)**: Vùng Drag & Drop nét đứt trực quan khi thư mục trống, hoặc lưới ảnh/video bảo mật với khung viền extruded bezel khi có dữ liệu.

---

## 2. Bố cục Workspace Layout

```
┌──────┬──────────────────────┬──────────────────────────────────────────────────────────────┐
│  🛡️  │ [Vaultly / Thư mục]  │ [+ Tải lên]  [ 🔍 Tìm kiếm ảnh, video... ]   [🔒 Khóa PIN] [PT]│ Top Command Bar (56px)
├──────┼──────────────────────┼──────────────────────────────────────────────────────────────┤
│ 🖼️   │ • Tất cả ảnh & video │ Thư mục cá nhân (24 ảnh)               [↑ Tải lên ⌵] [+ Thư mục] ⊞ ☰│ Action Header
│ Photos│ • Mục yêu thích      │ ( Tất cả )  ( Ảnh )  ( Video )                                │ Filter Pills
│      │ • Gần đây            ├──────────────────────────────────────────────────────────────┤
│ 📁   │                      │ ┌ - - - - - - - - - - - - - - - - - - - - - - - - - - - - ┐  │
│Vaults│ Danh sách thư mục  + │ │                                                         │  │ Media Canvas
│      │ • Chuyến du lịch (12)│ │                      🛡️                                 │  │ (Dashed Dropzone
│ ⭐   │ • Hóa đơn & giấy tờ  │ │       Kéo thả ảnh hoặc video vào đây để mã hóa          │  │  hoặc Lưới ảnh/video
│ Favs │                      │ │                                                         │  │  khi đã có dữ liệu)
│      │ Truy cập nhanh       │ │                 Cách khác để bắt đầu:                   │  │
│ ⚙    │ ★ Thư mục bí mật     │ │       [+ Tạo thư mục mới]    [📁 Chọn từ thiết bị]      │  │
│ Set  │                      │ └ - - - - - - - - - - - - - - - - - - - - - - - - - - - - ┘  │
├──────┤ ┌──────────────────┐ │                                                              │
│ 🌙   │ │ 🛡️ Đã bật mã PIN  │ │                                                              │
│ 👤PT │ │ Tự khóa sau 15p  │ │                                                              │
│      │ └──────────────────┘ │                                                              │
└──────┴──────────────────────┴──────────────────────────────────────────────────────────────┘
 Tier 1        Tier 2                                     Tier 3
 Nav Rail      Sidebar                              Main Workspace
 (68px)        (240px)                             (Flexible Canvas)
```

### 2.1 Tier 1: Global Navigation Rail (`NavRail`)
- **Chiều rộng**: Cố định `68px`, toàn chiều cao màn hình.
- **Vị trí**: Cạnh ngoài cùng bên trái.
- **Phía trên**:
  - **Logo Vaultly**: Biểu tượng khiên / vault bảo mật extruded (`28px`).
  - **Icon điều hướng chính** (Xếp dọc, icon trên nhãn chữ):
    - `Kho ảnh` (`Icons.photo_library_outlined`) — Xem toàn bộ media theo dòng thời gian.
    - `Thư mục` (`Icons.folder_outlined`) — Quản lý các vault/thư mục mã hóa.
    - `Yêu thích` (`Icons.favorite_border_rounded`) — Các ảnh/video được gắn dấu sao.
    - `Cài đặt` (`Icons.tune_rounded`) — Cấu hình lưu trữ và tài khoản.
- **Phía dưới**:
  - `Đổi Theme`: Nút chuyển đổi giao diện Sáng / Tối.
  - `Avatar Người dùng`: Ký hiệu viết tắt tên tài khoản (ví dụ `PT`), bấm vào để xem thông tin hoặc đăng xuất.

### 2.2 Tier 2: Folder & Vault Sidebar (`NavSidebar`)
- **Chiều rộng**: `240px` (có thể thu gọn/mở rộng trên màn hình vừa).
- **Phần danh mục hệ thống**:
  - `Tất cả ảnh & video` (chế độ xem tổng hợp).
  - `Mục yêu thích` (đã đánh dấu sao).
  - `Mới tải lên gần đây`.
- **Phần Thư mục Vault (`Folders`)**:
  - Tiêu đề nhóm có nút `+` để tạo nhanh thư mục mới.
  - Mỗi mục thư mục hiển thị: Icon thư mục, tên thư mục, số lượng media (`photoCount`), và badge trạng thái nếu có.
  - Trạng thái đang chọn: Khối nổi debossed vào nền với độ tương phản rõ ràng.
- **Thẻ bảo mật PIN (`PinStatusCard`)**:
  - Nằm ở chân sidebar:
    - Trạng thái mã PIN: *"Đã bật mã PIN • Tự khóa sau 15p"*.
    - Dung lượng đã dùng (ví dụ: *"Đã lưu trữ: 124 MB"*).

### 2.3 Tier 3: Main Workspace & Media Canvas
- **Thanh công cụ trên cùng (Top Command Bar, 56px)**:
  - **Nút `+ Tải lên`**: Nút pill màu sáng tương phản cao (`accent-pill`), chữ đậm, bấm vào mở menu:
    - *Tải lên ảnh*
    - *Tải lên video*
    - *Tạo thư mục mới*
  - **Ô tìm kiếm (`SearchPill`)**: Thiết kế dạng well debossed với icon kính lúp, placeholder *"Tìm kiếm ảnh, video, thư mục..."*.
  - **Nhóm hành động phải**:
    - Nút **`Khóa Vault`** (`Icons.lock_outline`): Bấm vào lập tức khóa màn hình bằng PIN để bảo vệ dữ liệu.
    - Trạng thái đồng bộ: Chấm xanh báo đã đồng bộ với máy chủ.
    - Badge tài khoản người dùng.

- **Thanh tác vụ thư mục (Workspace Action Header)**:
  - Tiêu đề thư mục đang mở, kèm tổng số lượng media.
  - Bộ lọc nhanh (Filter pills): `Tất cả`, `Ảnh`, `Video`.
  - Nút tác vụ nhanh: `[↑ Tải lên ⌵]`, `[+ Thư mục]`.
  - **View Mode Switcher**: Nút chuyển đổi giữa Lưới ảnh (`⊞`) và Danh sách chi tiết (`☰`).

- **Vùng hiển thị Canvas (`DropzoneCanvas`)**:
  - **Trạng thái thư mục trống (Empty Dropzone)**:
    - Khung viền nét đứt lớn (`1px dashed AppColors.border`), bo tròn 16px (`rounded.lg`), nền debossed nhẹ.
    - Icon bảo mật / media tối giản ở tâm.
    - Tiêu đề: *"Kéo thả ảnh hoặc video vào đây để mã hóa"*.
    - Hàng nút hành động: `[+ Tạo thư mục mới]` và `[📁 Chọn từ thiết bị]`.
  - **Trạng thái có dữ liệu**:
    - **Chế độ Lưới (Grid View)**: Các ô vuông media (`PhotoTile`) với viền extruded bezel 2–3px, nhãn thời lượng cho video, badge chọn nhiều ảnh/video.
    - **Chế độ Danh sách (List View)**: Bảng chi tiết gồm: Thumbnail (40px), Tên tệp, Loại định dạng, Kích thước, Ngày tải lên, và menu tác vụ (`...`).

---

## 3. Khả năng thích ứng màn hình (Responsive Layout)

| Thiết bị | Tier 1 (Nav Rail) | Tier 2 (Sidebar) | Top Command Bar | Media Canvas |
|---|---|---|---|---|
| **Desktop (≥ 1024px)** | Cố định (68px) | Cố định (240px) | Đầy đủ tìm kiếm + nút Tải lên + Khóa PIN | Lưới ảnh 3–5 cột hoặc Danh sách bảng |
| **Tablet (680px - 1023px)** | Cố định (68px) | Trượt dạng Drawer / Collapsible | Tinh gọn ô tìm kiếm + nút Tải lên | Lưới ảnh 2–3 cột |
| **Mobile (< 680px)** | Chuyển thành Bottom Bar | Chuyển vào Drawer trượt | Top Bar với Logo, Tìm kiếm và Khóa PIN | Lưới ảnh 2 cột |

---

## 4. Bảng màu & Quy chuẩn Theme

### 4.1 Danh sách Token màu

| Token | Sáng (Light) | Tối (Dark) | Mục đích sử dụng |
|---|---|---|---|
| `colors.background` | `#E8EDF3` | `#23262B` | Màu nền canvas chính |
| `colors.surface` | `#E8EDF3` | `#23262B` | Bằng background để đảm bảo hiệu ứng Neumorphic |
| `colors.surface-muted` | `#E0E6ED` | `#1E2126` | Nền Nav Rail, ô tìm kiếm lõm, rãnh trượt |
| `colors.media-canvas` | `#DDE4EC` | `#191B1F` | Vùng nền sau ảnh/video trong trình xem phóng to |
| `colors.border` | `#D5DDE6` | `#2E3238` | Viền hairline 1px bên trong rãnh lõm và viền nét đứt dropzone |
| `colors.foreground` | `#2C333D` | `#E8EAED` | Chữ chính, tiêu đề, icon chính |
| `colors.foreground-muted` | `#555F6B` | `#9BA3AE` | Chữ phụ, số lượng ảnh, placeholder |
| `colors.primary` | `#2C333D` | `#E8EAED` | Chữ/icon của hành động chính |
| `colors.accent-pill` | `#FFFFFF` | `#FFFFFF` | Nền trắng tương phản cao cho nút `+ Tải lên` |
| `colors.accent-action` | `#1E293B` | `#1E293B` | Màu chữ trên nền nút `accent-pill` |
| `colors.danger` | `#AE2F2A` | `#FF6B6B` | Cảnh báo xóa ảnh/thư mục, sai mã PIN |
| `colors.scrim` | `#000000` | `#000000` | Lớp mờ nền khi mở ảnh toàn màn hình hoặc hộp thoại |

### 4.2 Tiêu chuẩn tương phản (Contrast Standards)
- Độ tương phản chữ nội dung và metadata luôn đạt **≥ 4.5:1** trên mọi bề mặt (`background`, `surface`, `surface-muted`).
- Icon chức năng và đường viền đạt **≥ 3:1**.
- Tất cả thay đổi token màu phải vượt qua bài test độ tương phản tự động trong `test/neumorphic_test.dart`.

---

## 5. Quy cách các Thành phần (Component Specs)

### 5.1 Nút hành động nhanh `+ Tải lên`
- **Hình dáng**: Pill tròn hai đầu (`rounded.pill`).
- **Màu sắc**: Nền sáng tương phản cao (`accent-pill`), chữ đậm `accent-action`.
- **Chức năng**: Mở popup menu cho phép chọn tải ảnh, tải video hoặc tạo thư mục.

### 5.2 Ô tìm kiếm (`SearchPill`)
- **Hình dáng**: Khối debossed lõm vào bề mặt canvas, chiều cao 38px, bo góc `rounded.pill`.
- **Nội dung**: Icon kính lúp, chữ gợi ý, nút xóa nhanh khi đã nhập văn bản.

### 5.3 Vùng kéo thả tệp (`DropzoneCanvas`)
- **Đường viền**: `1px dashed AppColors.border`.
- **Chiều cao tối thiểu**: 360px, bo góc 16px (`rounded.lg`).
- **Tương tác**: Khi kéo tệp qua vùng này, viền chuyển sang nét liền với hiệu ứng viền sáng và phóng to nhẹ (scale 1.01).

### 5.4 Ô hiển thị ảnh (`PhotoTile`) & Video (`VideoTile`)
- **PhotoTile**: Bề mặt Neumorphic nổi (`depth 0.8`), viền bezel lõm 3px bao quanh thumbnail ảnh.
- **VideoTile**: Card hiển thị đĩa icon play nổi, tên tệp và kích thước tệp video (không tải trực tiếp video vào thẻ ảnh để tối ưu băng thông).

### 5.5 Bộ chuyển đổi chế độ xem (`ViewModeSwitcher`)
- Gồm hai nút chuyển: Lưới (Grid) và Danh sách (List), sử dụng cấu trúc `SegmentedControl` debossed với khối đang chọn nổi lên trên.

---

## 6. Lộ trình thực hiện trong Code (Implementation Checklist)

1. **Tokens (`lib/theme/app_tokens.dart`)**:
   - Khai báo kích thước `navRailWidth = 68`, `sidebarWidth = 240`, `topHeaderHeight = 56`.
   - Cung cấp token màu `accentPill` và `accentAction`.
2. **NavRail Widget (`lib/widgets/nav_rail.dart`)**:
   - Xây dựng thanh công cụ rail bên trái với logo Vaultly, icon điều hướng và nút đổi theme.
3. **FolderSidebar Widget (`lib/widgets/folder_sidebar.dart`)**:
   - Cập nhật layout sidebar với các danh mục: Tất cả media, Yêu thích, Thư mục và Thẻ bảo mật PIN.
4. **TopHeader Widget (`lib/widgets/top_header.dart`)**:
   - Xây dựng thanh công cụ trên cùng gồm nút `+ Tải lên`, ô tìm kiếm và nút Khóa PIN khẩn cấp.
5. **Dropzone Canvas Widget (`lib/widgets/dropzone_canvas.dart`)**:
   - Xây dựng khung viền nét đứt khi chưa có ảnh, hỗ trợ kéo thả hoặc click chọn file từ máy.
6. **HomeScreen (`lib/screens/home_screen.dart`)**:
   - Lắp ráp bố cục tổng thể đáp ứng responsive: Rail + Sidebar + Top Header + Canvas.
