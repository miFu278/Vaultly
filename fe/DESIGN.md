---
version: 3.0
name: Vaultly
description: Flat Material 3 interface for Vaultly, derived from the "Nimbus Soft File System" reference in docs/nimbus_soft_file_system/DESIGN.md. Light and dark, phone first with a rail on wide screens.
colors:
  background: "#F4F6FA"
  surface: "#FFFFFF"
  surface-muted: "#EDF2F7"
  media-canvas: "#E2E8F0"
  border: "#E2E8F0"
  foreground: "#0F172A"
  foreground-muted: "#475569"
  primary: "#2563EB"
  on-primary: "#FFFFFF"
  primary-soft: "#DBE7FE"
  success: "#047857"
  danger: "#B3261E"
typography:
  brand:
    fontSize: 18px
    fontWeight: 700
    letterSpacing: -0.4px
  title-lg:
    fontSize: 28px
    fontWeight: 700
    letterSpacing: -0.6px
  title:
    fontSize: 20px
    fontWeight: 700
    letterSpacing: -0.3px
  heading:
    fontSize: 16px
    fontWeight: 600
  body:
    fontSize: 14px
    fontWeight: 400
  label:
    fontSize: 13px
    fontWeight: 600
  caption:
    fontSize: 12px
    fontWeight: 500
rounded:
  xs: 8px
  sm: 12px
  md: 16px
  lg: 20px
  xl: 28px
  pill: 999px
spacing:
  gutter: 16px
  margin: 20px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
---

## Ngôn ngữ thiết kế

Bản thiết kế gốc nằm ở `docs/nimbus_soft_file_system/DESIGN.md` và bốn màn hình
`docs/*_light_mode/` (Gallery, Albums, Files, Unlock). Bản trong app giữ lại bố
cục, hệ màu và kiểu chữ của bản gốc, nhưng đổi cách tạo độ sâu sang **flat**:

- **Bỏ neumorphism.** Không còn cặp bóng sáng/tối, không gradient lõm. Bề mặt
  tách nhau bằng **nền trắng + viền hairline 1px**, không dùng bóng.
- **Bóng chỉ dành cho lớp thật sự nổi**: dock điều hướng, thanh chọn nhiều mục,
  FAB, bottom sheet. Xem `AppElevation.floating`.
- **Một hành động chính mỗi màn hình**: một pill xanh đặc (`primary`), các hành
  động còn lại là pill viền trắng hoặc chữ.
- **Bo góc lớn, dạng viên thuốc**: card 20-28px, mọi nút/chip đều pill.

## Màu

Light mode là bản mặc định khi mở app. Dark mode vẫn giữ nguyên trong Settings và
ở header, nhưng không tự bật theo theme của hệ điều hành.
| Vai trò | Light | Dark |
|---|---|---|
| Canvas | `#F4F6FA` | `#0B1220` |
| Card | `#FFFFFF` | `#131C2B` |
| Vùng lõm (ô nhập, track) | `#EDF2F7` | `#1B2637` |
| Hairline | `#E2E8F0` | `#263349` |
| Chữ chính | `#0F172A` | `#E7EDF7` |
| Chữ phụ | `#475569` | `#9FB0C7` |
| Primary | `#2563EB` | `#7FA8FF` |
| Success / Danger | `#047857` / `#B3261E` | `#34D399` / `#FF8A80` |

`foregroundMuted` ở bản light đậm hơn màu gốc (`#64748B`) một bậc để chữ phụ
trên nền ô nhập `#EDF2F7` vẫn đạt 4.5:1. Dark mode đổi primary sang xanh nhạt để
chữ trắng trên nút vẫn đọc được.

## Kiểu chữ

Không nhúng font riêng: app dùng font hệ thống, giữ nguyên thang kích thước và
độ đậm của bản thiết kế (`AppTypography`). Số liệu (dung lượng, số mục, thời
lượng) luôn bật `tabularFigures` để cột không nhảy.

## Bố cục

- **Hẹp (< 680px)**: header dính trên (mark + tên mục + trạng thái + avatar),
  nội dung cuộn, dock điều hướng nổi ở đáy (5 điểm đến, tab đang chọn là hình
  tròn tô primary, các tab khác chỉ có icon kèm tooltip), FAB tải tệp phía trên dock.- **Rộng (>= 680px)**: rail 248px bên trái (điều hướng + danh sách album + trạng
  thái), nội dung giới hạn `1040px` và canh giữa.
- Lưới ảnh mặc định 3 cột trên điện thoại, 4 cột trên màn rộng; pill mật độ
  (`3x` → `4x` → `2x`) đổi số cột và luôn hiển thị đúng số cột đang dùng.

## Thành phần

Toàn bộ primitive nằm ở `lib/widgets/flat.dart`:

| Widget | Dùng cho |
|---|---|
| `VaultMark` | Ô bo góc màu primary + ổ khoá, dùng ở header, unlock, auth |
| `SurfaceCard` | Card trắng viền hairline, có `onTap` |
| `PillButton` | Nút pill: `primary / secondary / ghost / danger` |
| `RoundIconButton` | Nút tròn 44px cho header và toolbar |
| `SegmentedPills` | Nhóm pill chọn một (filter media, đăng nhập/đăng ký) |
| `AppBadge` | Chip nhỏ: số mục, `E2EE`, `Đã bảo vệ` |
| `InfoBanner` | Dải trạng thái bo 16px (bảo mật, lỗi form) |
| `SectionHeader` | Tiêu đề mục + chip số lượng + hành động phải |
| `EmptyState` | Trạng thái rỗng kèm CTA |
| `AppDialog` | Hộp thoại phẳng: tiêu đề, mô tả, nội dung, hàng nút |
| `SheetAction` | Một dòng trong bottom sheet: icon, tiêu đề, phụ đề |

`lib/widgets/tiles.dart` thêm ba thứ lấy từ bản tham chiếu: `TintedIconTile` (ô
icon pastel theo loại tệp), `FolderCard` (card cắt theo hình folder có tab, vẽ
bằng `CustomPainter` để viền liền mạch) và `StorageGauge` (vòng đo hai cung Ảnh
và Video, số láy từ `GET /storage`).

Bảng màu pastel nằm ở `AppTint` với 5 tông: amber (Ảnh), blue (Video), green
(thư mục), pink (tệp), violet (album).

Media dùng `PhotoTile` (`lib/widgets/photo_tile.dart`): ô vuông, ảnh bọc
`Image.network`, video **không** đi qua `Image` mà hiện icon play + chip `Video`.

## Màn hình

| Màn hình | File | Nội dung |
|---|---|---|
| Gallery | `screens/gallery_view.dart` | Tìm kiếm, filter Tất cả/Ảnh/Video, mật độ lưới, timeline theo ngày (Hôm nay / Hôm qua / dd/mm/yyyy), thanh chọn nhiều |
| Albums | `screens/albums_view.dart` | Lưới album 2-4 cột, cover ghép 1-4 ảnh, số mục, badge khoá, menu xoá |
| Files | `screens/files_view.dart` | Breadcrumb, banner bảo mật, danh sách album, danh sách tệp gần đây (nhãn JPG/PNG/VID, dung lượng, ngày) |
| Settings | `screens/settings_view.dart` | Tài khoản, khoá Vault, đăng xuất, đổi theme, đồng bộ, API base URL |
| Unlock | `screens/pin_lock_screen.dart` | Mark + pill E2EE, card tài khoản, 6 chấm PIN, keypad, nút mở khoá, fallback đăng nhập mật khẩu |
| Auth | `screens/auth_screen.dart` | Đăng nhập / đăng ký, cấu hình API URL |
| Overview | `screens/overview_view.dart` | Card dung lượng Ảnh/Video/Album/Tệp, vòng đo hạn mức, kệ album |
| Onboarding | `screens/onboarding_screen.dart` | 3 trang giới thiệu, hiện một lần ở lần mở đầu |
| Viewer | `screens/photo_viewer_screen.dart` | PageView ảnh + filmstrip, player video, sheet thông tin tệp |

## Chống slop (bắt buộc)

Những điều dưới đây đã từng sai trong dự án này và không được lặp lại:

- **Không có claim bảo mật chưa kiểm chứng.** UI từng ghi "E2EE", "zero-knowledge",
  "máy chủ không đọc được nội dung" trong khi backend giữ khoá và giải mã hộ. Copy
  phải nói đúng: ảnh được mã hoá trước khi ghi lên máy chủ, mở kho bằng PIN 6 số.
- **Một hành động, một chỗ.** Tải tệp chỉ có FAB; đổi theme ở header và Settings;
  khoá kho ở header (màn rộng) và Settings. Không thêm lối thứ ba.
- **Một con số, một lần.** Dung lượng chỉ xuất hiện trong card dung lượng, không lặp
  ở card thống kê phụ.
- **Không card lồng nhau, không card cho từng dòng.** Danh sách hành động và danh sách
  album dùng một card có hairline phân cách.
- **Không nhãn eyebrow** kiểu chữ IN HOA giãn chữ phía trên một mục.
- **Không glyph Unicode làm icon.** Keypad dùng `Icons.backspace_rounded`, mọi icon
  đến từ Material.
- **Bán kính card 12-16px**, pill 999px. Chỉ lớp nổi (dock, thanh chọn, FAB) mới có
  bóng; phần còn lại tách bằng nền và hairline.
- **Ngôn ngữ điều hướng là tiếng Việt**: Tổng quan, Thư viện, Album, Tệp, Cài đặt.

## Kiểm thử

- `test/theme_test.dart`: tương phản từng cặp màu (>= 4.5:1) cho cả hai theme,
  card phẳng không đổ bóng, và layout unlock/auth vừa màn 320x568.
- `test/responsive_layout_test.dart`: rail ở màn rộng, drawer + dock ở màn hẹp,
  pill mật độ đổi số cột, chọn album lọc đúng ảnh, mở viewer.
- `test/video_playback_test.dart`: ô video không gọi `Image`, player lỗi có nút
  thử lại.
