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
- `GET /files/{id}/download` — Lấy presigned GET URL ảnh full-res + wrapped key
- `GET /files/{id}/thumbnail` — **Lấy presigned GET URL cho thumbnail hiển thị nhanh**
- `DELETE /files/{id}` — Xóa file metadata và ciphertext khỏi storage
- `POST /files/upload` — Upload ảnh trực tiếp (multipart/form-data), mã hóa bằng `crypto_secretstream`
- `POST /files/encrypt-upload` — Upload ảnh Base64 JSON, mã hóa bằng `crypto_secretstream`
- `GET /files/{id}/view` — Giải mã và stream trực tiếp ảnh về trình duyệt

#### 5. Pairing (Ủy quyền thiết bị mới bằng QR Code)
- `POST /pairing/start` — Thiết bị B tạo pairing session
- `GET /pairing/{token}` — Thiết bị B poll trạng thái hoàn tất
- `POST /pairing/complete` — Thiết bị A quét QR, nạp wrapped keys cho thiết bị B
