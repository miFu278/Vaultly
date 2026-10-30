# Vaultly Backend (Go + Clean Architecture)

Vaultly là backend điều phối metadata, mã hóa và lưu trữ ảnh an toàn cho hệ thống lưu trữ ảnh mã hóa đầu cuối (E2EE) hỗ trợ đa thiết bị, lấy cảm hứng từ Samsung Knox Secure Folder.

## Kiến trúc Clean Architecture

Hệ thống được thiết kế theo mô hình **Clean Architecture**, phân tách nghiêm ngặt thành 4 tầng:

```text
be/
├── cmd/
│   └── server/
│       └── main.go                         # Dependency Injection & Entry Point
├── internal/
│   ├── domain/                             # 1. DOMAIN LAYER (Core Business Rules)
│   │   ├── entity/                         # Domain Entities (User, Device, Folder, File, Pairing)
│   │   │   ├── user.go
│   │   │   ├── device.go
│   │   │   ├── folder.go                   # Knox Secure Folder entity
│   │   │   ├── file.go                     # File (full-res + thumbnail) & FileKey
│   │   │   └── pairing.go
│   │   ├── repository/                     # Repository Interfaces (Ports)
│   │   │   ├── user_repository.go
│   │   │   ├── device_repository.go
│   │   │   ├── folder_repository.go
│   │   │   ├── file_repository.go
│   │   │   └── pairing_repository.go
│   │   ├── service/                        # Domain Service Interfaces
│   │   │   ├── crypto.go                   # EncryptionService, PasswordHasher, TokenService
│   │   │   └── storage.go                  # ObjectStorage (S3/R2)
│   │   └── errors.go                       # Domain Sentinel Errors
│   │
│   ├── application/                        # 2. APPLICATION LAYER (Use Cases & DTOs)
│   │   ├── dto/                            # Data Transfer Objects
│   │   │   ├── auth_dto.go
│   │   │   ├── device_dto.go
│   │   │   ├── folder_dto.go               # CreateFolder, FolderDTO
│   │   │   ├── file_dto.go                 # InitUpload, Download, Thumbnail, Cursor Pagination
│   │   │   └── pairing_dto.go
│   │   └── usecase/                        # Application Use Cases
│   │       ├── auth_usecase.go             # Đăng ký, đăng nhập, hồ sơ
│   │       ├── device_usecase.go           # Đăng ký & quản lý thiết bị
│   │       ├── folder_usecase.go           # Tạo và quản lý folder
│   │       ├── file_usecase.go             # Presigned upload + Thumbnail + Cursor Pagination
│   │       └── pairing_usecase.go          # Pairing thiết bị mới qua QR/Token
│   │
│   ├── infras/                             # 3. INFRASTRUCTURE LAYER (Adapters & External)
│   │   ├── config/                         # Environment Configuration
│   │   │   └── config.go
│   │   ├── database/                       # PostgreSQL Connection Pool & Migrations
│   │   │   └── db.go
│   │   ├── repositories/                   # PostgreSQL Implementations
│   │   │   ├── user_repository_pg.go
│   │   │   ├── device_repository_pg.go
│   │   │   ├── folder_repository_pg.go
│   │   │   ├── file_repository_pg.go       # SQL Cursor Pagination & single-query folder list
│   │   │   └── pairing_repository_pg.go
│   │   ├── storage/                        # Cloudflare R2 / AWS S3 Blob Storage
│   │   │   └── s3_storage.go
│   │   └── crypto/                         # Security & Crypto Implementations
│   │       ├── sodium_crypto.go            # libsodium XChaCha20-Poly1305 (secretstream) & crypto_box_seal
│   │       ├── bcrypt.go                   # Bcrypt Password Hasher
│   │       └── jwt.go                      # JWT Token Service
│   │
│   └── presentation/                       # 4. PRESENTATION LAYER (HTTP, Gin, Huma)
│       └── http/
│           ├── handlers/                   # API Handlers
│           │   ├── auth_handler.go
│           │   ├── device_handler.go
│           │   ├── folder_handler.go       # Folders & Cursor-based Pagination
│           │   ├── file_handler.go         # Upload/Download/Thumbnail/View/Init/Complete
│           │   ├── pairing_handler.go
│           │   ├── system_handler.go
│           │   └── common.go
│           ├── middleware/                 # Gin & Context Middlewares
│           │   ├── auth_middleware.go
│           │   └── cors_middleware.go
│           └── router.go                   # Route Wiring & Huma v2 OpenAPI Config
├── migrations/
│   └── 001_initial_schema.up.sql
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## 🔐 Chuẩn mã hóa Libsodium (Đồng bộ với Flutter `sodium_libs`)

Hệ thống tuân thủ chính xác đặc tả kỹ thuật trong `docs/spec.md`:

| Mục đích | Thuật toán | Ghi chú kỹ thuật |
|---|---|---|
| **Mã hóa nội dung ảnh** | **XChaCha20-Poly1305** qua `crypto_secretstream` | Nonce 192-bit (24 bytes) — triệt tiêu hoàn toàn nguy cơ trùng nonce khi nhiều client sinh ngẫu nhiên độc lập; mã hóa chunk 64KB, stream trực tiếp, chống tấn công cắt ngắn (anti-truncation attack) |
| **Wrap File Key cho từng device** | **`crypto_box_seal`** (X25519 sealed box) | Người gửi chỉ cần public key của thiết bị nhận, không cần giữ keypair riêng |
| **Lưu trữ metadata & thumbnail** | Thumbnail mã hóa riêng | Tối ưu gallery load nhanh: client chỉ tải thumbnail nhỏ song song qua HTTP/2, chỉ tải ảnh full-res khi người dùng bấm xem chi tiết |

---

## ⚙️ Hiệu năng, seek O(1) & giới hạn bộ nhớ (server nhỏ, ví dụ 512 MB RAM)

Toàn bộ luồng media đều **streaming**, không buffer cả file vào RAM:

| Luồng | Trước | Sau |
|---|---|---|
| `POST /files/upload` | Đọc cả file vào RAM + `bytes.Buffer` mã hóa (≈2.5× kích thước file) | Stream plaintext → file tạm ciphertext → PUT lên R2 (RAM ≈ 1 chunk 64 KB) |
| `GET /files/{id}/view` | Tải cả ciphertext + giải mã ra RAM (≈2× file) cho **mỗi** Range request | Giải mã theo segment, `http.ServeContent` phục vụ 206/416 (RAM ≈ 64 KB, mạng ≈ 1 segment) |
| `GET /files/{id}/view?variant=thumb` | — | Ảnh xem trước 512px (~30–60 KB) đã mã hóa, sinh sẵn lúc upload |
| `GET /files`, JSON body | Không giới hạn | Body JSON tối đa 8 MB; multipart RAM 4 MB (phần còn lại ra temp disk) |

### Định dạng object chia segment (O(1) seek)

Object mới (`VLTYSEG2`) được chia thành các segment **độc lập**, mỗi segment 1 MiB plaintext (segment cuối nhỏ hơn) và có header secretstream riêng. Mỗi segment dùng khóa riêng suy ra từ file key và **vị trí segment** (`HMAC-SHA256`), nên đảo hay nhân bản segment sẽ hỏng xác thực thay vì giải mã ra nội dung sai:

```text
[8B magic "VLTYSEG2"][u64 plaintextSize][u32 segmentPlainSize][segment 0][segment 1]...
```

Vì mọi segment (trừ segment cuối) đều đúng bằng `segmentPlainSize`, offset ciphertext của segment thứ *i* tính được trong O(1) — không cần bảng index, không phải đọc trước object. Hệ quả:

- **Tua video = 1 range GET**: player đọc `moov` ở cuối file chỉ tải segment cuối, không giải mã cả video → mở video nhanh thay vì chờ giải mã từ đầu.
- **RAM không đổi theo kích thước file**: luôn giữ 1 chunk 64 KB, bất kể video 500 MB.
- Segment cũ (định dạng cũ, 1 secretstream duy nhất) vẫn đọc được: reader tự nhận diện qua magic và coi cả object là 1 segment.
- Object `VLTYSEG1` (segment dùng chung file key) vẫn đọc được bình thường; chỉ object mới ghi ra `VLTYSEG2`.
- Mỗi segment dùng cùng file key nhưng **header random riêng**, nên không tái sử dụng keystream.
- Client muốn giải mã cục bộ cần hỗ trợ định dạng này; `nonce` trong DB vẫn giữ dạng `headerHex:keyHex` như trước.

### Thumbnail

Server giải mã ảnh một lần lúc upload, resize (hộp lọc, cạnh dài 512 px) và mã hóa lại thành JPEG bằng **cùng file key** rồi lưu cạnh object gốc (key `..._thumb`), ghi vào cột `r2_thumbnail_key`. FE dùng `GET /files/{id}/view?variant=thumb` cho lưới gallery. Video (và WebP không có decoder thuần Go) không có thumbnail — sẽ fallback sang ảnh gốc.

Ngoài ra:

- Heap của Go tự động bị chặn ở 80% giới hạn cgroup (`config.ApplyMemoryLimit`), nên khi căng thẳng GC chạy trước khi kernel OOM-kill. Override bằng `GOMEMLIMIT`.
- `MAX_UPLOAD_MB` giờ chỉ giới hạn **temp disk** (plaintext do multipart spool + ciphertext): cần dung lượng trống ≥ 2× file lớn nhất.
- `SegmentPlainSize` (1 MiB) là điểm cân bằng: nhỏ hơn → ít lãng phí khi client hỏi range nhỏ, nhưng nhiều request hơn khi phát liên tục.

Các bước tối ưu tiếp theo (chưa làm): cache segment đã giải mã trong RAM, video poster bằng ffmpeg, ETag + cache trên client, nén JSON.

---

## 🚀 Hướng dẫn chạy cục bộ & Build

> ⚠️ **Lưu ý lệnh build trong Go:**
> Trong thư mục `be`, do file `main.go` nằm trong `cmd/server/main.go`, bạn cần chỉ định đường dẫn tương đối có dấu `./`:
> - **Chạy trực tiếp:** `go run ./cmd/server/main.go`
> - **Build binary:** `go build ./cmd/server` (hoặc `go build -o server.exe ./cmd/server`)
> - *(Tránh gõ `go build cmd/server` vì Go sẽ tìm trong thư mục thư viện chuẩn của Go)*

### 1. Khởi động PostgreSQL

```bash
docker compose up -d
```

### 2. Cấu hình biến môi trường

```bash
cp .env.example .env
```

### 3. Chạy test toàn bộ hệ thống

```bash
cd be
go test -v ./...
```

### 4. Khởi chạy backend server

```bash
go run ./cmd/server/main.go
```

Server sẽ lắng nghe tại `http://localhost:8080`.

### 5. Deploy lên VPS (khuyến nghị)

Postgres dùng Supabase, object dùng Cloudflare R2, VPS chỉ chạy API trong Docker và
Caddy giữ TLS. Toàn bộ file cần thiết đã có trong `be/`:

| File | Việc |
|---|---|
| `Dockerfile` | build tĩnh (`CGO_ENABLED=0`), runtime Alpine, chạy user 10001, healthcheck `/health` |
| `docker-compose.prod.yml` | service `api` + `caddy`, không có Postgres |
| `Caddyfile` | TLS tự động, giới hạn body 600MB, `flush_interval -1` để stream video |
| `.env.prod.example` | mẫu biến môi trường, chép thành `.env.prod` |
| `DEPLOY_VPS.md` | các bước chi tiết, backup và xử lý sự cố |

Tóm tắt:

```bash
cd be
cp .env.prod.example .env.prod    # điền API_DOMAIN, JWT_SECRET, DATABASE_URL, R2_*
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
curl -s https://<API_DOMAIN>/health
```

`--env-file` là bắt buộc vì compose cần `${API_DOMAIN}` để dựng Caddyfile.

### 6. Release production (Render, phương án cũ)

Backend production hiện chạy trên VPS: **https://api-vaultly.mpdev.tech** (xem
`DEPLOY_VPS.md`), và đây cũng là `API_BASE_URL` mặc định của FE. Render vẫn dùng
được như phương án dự phòng, cấu hình như dưới đây.

| Mục | Giá trị |
|---|---|
| Root directory | `be` |
| Build command | `go build -o server ./cmd/server` |
| Start command | `./server` (đọc cổng từ `$PORT`) |

Schema `migrations/001_initial_schema.up.sql` tự chạy lúc khởi động (idempotent, `CREATE ... IF NOT EXISTS`).

Biến môi trường cần đặt (xem `.env.example`): `ENV=production`, `DATABASE_URL` (Supabase), `JWT_SECRET`, `JWT_EXPIRATION_HOURS`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_ENDPOINT`, `PRESIGNED_URL_EXPIRATION_MINUTES`, `MAX_UPLOAD_MB`.

Khuyến nghị cho instance nhỏ (512 MB RAM):

- `MAX_UPLOAD_MB=200` — chặn theo **temp disk** (plaintext multipart spool + ciphertext tạm ≈ 2× file), không phải RAM.
- `GOMEMLIMIT=384MiB` — mặc định code đã tự đặt heap = 80% giới hạn cgroup; đặt biến này chỉ khi muốn override.
- `ENV=production` sẽ từ chối khởi động nếu thiếu `JWT_SECRET` thật hoặc credential R2, nên lỗi cấu hình lộ ra ngay chứ không âm thầm chạy bằng storage trong bộ nhớ.

Sau khi push `main`, Render tự deploy nếu project có bật auto-deploy; deploy FE trước BE cũng an toàn (`?variant=thumb` chỉ là tham số tuỳ chọn).

---

## 📖 Trực quan hóa & Test API trực tiếp (Huma + Scalar)

- **Interactive API Documentation UI:** [http://localhost:8080/docs](http://localhost:8080/docs)
- **OpenAPI 3.1 Specification (JSON):** [http://localhost:8080/openapi.json](http://localhost:8080/openapi.json)

### Danh sách Endpoints

#### 1. Authentication
- `POST /auth/register` — Đăng ký tài khoản
- `POST /auth/login` — Đăng nhập lấy Bearer JWT
- `GET /auth/me` — Xem profile tài khoản hiện tại

#### 2. Devices (Quản lý thiết bị & X25519 Public Key)
- `POST /devices/register` — Đăng ký thiết bị mới kèm public key
- `GET /devices` — Danh sách thiết bị đã authorize
- `POST /devices/{id}/revoke` — Thu hồi quyền truy cập thiết bị

#### 3. Folders (Tổ chức thư mục — Knox Secure Folder style)
- `POST /folders` — Tạo folder mới
- `GET /folders` — Danh sách folders của user
- `GET /folders/{id}/files?cursor=&limit=30` — **Phân trang cursor-based cho danh sách ảnh trong folder (tối ưu 1 query SQL)**

#### 4. Files & Thumbnails (E2EE Photos)
- `POST /files/init` — Tạo presigned PUT URLs cho cả full-res và thumbnail
- `POST /files/{id}/complete` — Báo upload xong và lưu wrapped keys cho từng device
- `GET /files` — Danh sách tất cả file metadata
- `GET /storage` — Dung lượng đã dùng (tổng, ảnh, video, số tệp) và hạn mức của tài khoản (`users.storage_quota_bytes`, mặc định 2 GiB)
- `GET /files/{id}/download` — Lấy presigned GET URL ảnh full-res + wrapped key
- `GET /files/{id}/thumbnail` — **Lấy presigned GET URL cho thumbnail (dành cho client tự giải mã)**
- `DELETE /files/{id}` — Xóa file metadata và ciphertext khỏi storage
- `POST /files/upload` — Upload ảnh **và video** trực tiếp (multipart/form-data), mã hóa chia segment theo luồng, sinh thumbnail cho ảnh; giới hạn `MAX_UPLOAD_MB` (413 nếu vượt)
- `POST /files/encrypt-upload` — Upload media Base64 JSON, mã hóa bằng `crypto_secretstream` (buffer trong RAM: chỉ dùng cho file nhỏ/test API)
- `GET /files/{id}/view` — Giải mã và stream media về client: hỗ trợ **HTTP Range (206/416)** để video phát và tua được, chỉ đọc segment chứa range đó
- `GET /files/{id}/view?variant=thumb` — Ảnh xem trước nhỏ đã giải mã, dùng cho lưới gallery (404 nếu file không có thumbnail)

#### 5. Pairing (Ủy quyền thiết bị mới bằng QR Code)
- `POST /pairing/start` — Thiết bị B tạo pairing session
- `GET /pairing/{token}` — Thiết bị B poll trạng thái hoàn tất
- `POST /pairing/complete` — Thiết bị A quét QR, nạp wrapped keys cho thiết bị B
