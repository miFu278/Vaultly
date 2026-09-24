# Vaultly Backend (Go + Gin)

Vaultly là backend điều phối metadata và presigned URL cho hệ thống lưu trữ ảnh mã hóa đầu cuối (E2EE) hỗ trợ đa thiết bị.

## Kiến trúc & Công nghệ

- **Language:** Go 1.27
- **Web Framework:** [Gin Web Framework](https://github.com/gin-gonic/gin)
- **Database:** PostgreSQL 16 (kết nối qua `pgxpool`)
- **Storage:** Cloudflare R2 (S3-compatible via `aws-sdk-go-v2`)
- **Auth:** JWT (HMAC-SHA256) + bcrypt

## Cấu trúc thư mục

```text
be/
├── cmd/
│   └── server/
│       └── main.go           # Entry point của ứng dụng
├── internal/
│   ├── auth/                 # Đăng ký, đăng nhập, JWT
│   ├── config/               # Đọc file .env & cấu hình
│   ├── database/             # Kết nối PostgreSQL (pgxpool) & migrations
│   ├── device/               # Quản lý thiết bị & public key X25519
│   ├── file/                 # File metadata, presigned PUT/GET URLs, wrapped keys
│   ├── middleware/           # JWT Auth, CORS, Logger, Recovery
│   ├── models/               # Domain models & Request/Response DTOs
│   ├── pairing/              # Luồng authorize/pairing thiết bị mới bằng QR/Token
│   └── storage/              # Cloudflare R2 client (AWS S3 SDK)
├── migrations/
│   └── 001_initial_schema.up.sql  # SQL schema ban đầu
├── docker-compose.yml        # Chạy PostgreSQL cục bộ
├── .env.example              # Mẫu biến môi trường
└── README.md
```

## Hướng dẫn chạy cục bộ

### 1. Khởi động PostgreSQL

Sử dụng Docker Compose:
```bash
docker compose up -d
```
Container `vaultly-postgres` sẽ được tạo và tự động nạp migration `001_initial_schema.up.sql`.

### 2. Cấu hình biến môi trường

Tạo file `.env` từ file `.env.example`:
```bash
cp .env.example .env
```
Cập nhật thông tin Cloudflare R2 (`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`) nếu muốn test upload/download R2 thật.

### 3. Chạy backend

```bash
go run ./cmd/server/main.go
```

Server sẽ lắng nghe tại `http://localhost:8080`.

## 📖 Trực quan hóa & Test API trực tiếp (Huma + Scalar)

Dự án đã tích hợp **Huma v2** cùng giao diện **Scalar Docs** hiện đại:
- **Interactive API Documentation & Testing UI:** [http://localhost:8080/docs](http://localhost:8080/docs)
- **OpenAPI 3.1 Specification (JSON):** [http://localhost:8080/openapi.json](http://localhost:8080/openapi.json)
- **OpenAPI 3.1 Specification (YAML):** [http://localhost:8080/openapi.yaml](http://localhost:8080/openapi.yaml)

Tại giao diện `/docs`, bạn có thể:
1. Xem chi tiết request/response schema của tất cả các API.
2. Bấm nút **"Test Request"** để gửi request trực tiếp trên trình duyệt.
3. Đăng nhập qua `/auth/login` lấy token, sau đó bấm nút **"Authorize"** ở góc trang `/docs` để test các endpoint yêu cầu xác thực JWT.

- `GET /health` — Kiểm tra trạng thái server
- `POST /auth/register` — Đăng ký tài khoản
- `POST /auth/login` — Đăng nhập lấy Bearer token
- `POST /devices/register` — Đăng ký thiết bị (cung cấp X25519 public key)
- `GET /devices` — Danh sách thiết bị đã authorize
- `POST /devices/:id/revoke` — Thu hồi quyền truy cập thiết bị
- `POST /files/init` — Tạo presigned PUT URL để upload ảnh trực tiếp lên R2
- `POST /files/:id/complete` — Hoàn tất upload và lưu wrapped key cho từng thiết bị
- `GET /files` — Lấy danh sách metadata ảnh
- `GET /files/:id/download` — Lấy presigned GET URL và wrapped key cho thiết bị hiện tại
- `POST /pairing/start` — Bắt đầu session pairing cho thiết bị mới
- `GET /pairing/:token` — Thiết bị mới poll trạng thái hoàn tất
- `POST /pairing/complete` — Thiết bị cũ xác thực và nạp wrapped keys cho thiết bị mới
