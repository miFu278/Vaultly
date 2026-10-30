# Deploy backend lên VPS

Backend Go chạy trong một container, Caddy đứng trước lo TLS. Postgres nằm ở
Supabase, object ở Cloudflare R2, nên VPS chỉ cần chạy API và proxy.

## 1. Chuẩn bị

- VPS Ubuntu 22.04/24.04, tối thiểu 2 GB RAM, 20 GB đĩa. Đĩa cần trống khoảng
  **2 × `MAX_UPLOAD_MB`** vì upload spool ra `$TMPDIR` rồi mới đẩy lên R2.
- Docker Engine và compose plugin:
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER   # logout rồi login lại
  ```
- Một domain trỏ về VPS, ví dụ `api.example.com`:
  - Bản ghi `A` → IP của VPS (thêm `AAAA` nếu VPS có IPv6).
  - Mở firewall chỉ 22, 80, 443: `sudo ufw allow 22,80,443/tcp && sudo ufw enable`.
- Cloudflare R2: bucket **private**, một API token giới hạn đúng bucket đó.
- Supabase: lấy connection string ở **Connect → Transaction pooler (port 6543)**.

## 2. Lấy code và cấu hình

```bash
git clone <repo> vaultly && cd vaultly/be
cp .env.prod.example .env.prod
```

Điền `.env.prod`:

| Biến | Ghi chú |
|---|---|
| `API_DOMAIN` | domain đã trỏ về VPS |
| `JWT_SECRET` | `openssl rand -base64 48` |
| `DATABASE_URL` | connection string pooler của Supabase, giữ `?sslmode=require` |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | token của bucket |
| `R2_BUCKET_NAME`, `R2_ENDPOINT` | endpoint dạng `https://<account_id>.r2.cloudflarestorage.com` |
| `MAX_UPLOAD_MB` | 200 là mức an toàn cho VPS 2 GB |
| `GOMEMLIMIT` | 384MiB cho VPS 2 GB |

Hai bẫy thường gặp:

- **Dùng host `db.<ref>.supabase.co` sẽ timeout** trên phần lớn VPS, vì host đó chỉ
  có IPv6. Luôn dùng host pooler `aws-0-<region>.pooler.supabase.com`.
- Thiếu `JWT_SECRET` hoặc thiếu credential R2 thì server **từ chối khởi động** ở
  `ENV=production`. Đó là chủ ý, xem `internal/infras/config/config.go`.

## 3. Chạy

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

`--env-file` là bắt buộc: compose đọc `${API_DOMAIN}` từ đó để dựng Caddyfile, còn
`env_file` trong service chỉ đưa biến vào container.

Lần chạy đầu, server tự chạy `migrations/001_initial_schema.up.sql` (idempotent,
`CREATE ... IF NOT EXISTS`). Caddy xin chứng chỉ Let's Encrypt trong khoảng 10-30
giây đầu.

## 4. Kiểm tra

```bash
curl -s https://api.example.com/health          # {"status":"healthy",...}
curl -s https://api.example.com/openapi.json | head -c 200
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f api
```

Thử một vòng thật: đăng ký, đăng nhập, gọi `GET /storage` với Bearer token. Nếu
`used_bytes` trả về số thay vì 404 thì schema mới đã lên.

Trỏ app vào API mới:

```bash
cd fe
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

## 5. Cập nhật phiên bản

```bash
cd vaultly && git pull
cd be && docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
docker image prune -f
```

Caddy giữ nguyên chứng chỉ trong volume `caddy_data`. Migration mới phải viết theo
hướng cộng thêm (`ADD COLUMN IF NOT EXISTS`), vì mỗi lần khởi động đều chạy lại.

## 6. Vận hành

- Log: `docker compose ... logs -f api`. Log request chỉ ghi path, không ghi query,
  nên token media không lọt vào log.- Đĩa: `df -h`. Upload lớn để lại file tạm trong `$TMPDIR` của container; nếu đầy,
  upload trả 500. Dọn bằng cách restart container.
- RAM: container bị OOM thì hạ `MAX_UPLOAD_MB` và `GOMEMLIMIT`, không phải tăng
  worker.
- Dữ liệu: object nằm ở R2 (bật versioning), metadata ở Supabase (bật backup hằng
  ngày hoặc PITR). VPS mất thì dựng lại từ hai nguồn này, không cần backup VPS.
- Đổi `JWT_SECRET` sẽ đăng xuất toàn bộ thiết bị. Đó cũng là cách thu hồi khẩn cấp.

## 7. Xem log

Chạy trong thư mục `be/` trên VPS, nơi có `docker-compose.prod.yml`:

```bash
# theo dõi trực tiếp, 200 dòng gần nhất
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f --tail 200 api

# log của Caddy: truy cập và lỗi cấp chứng chỉ TLS
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f caddy

# 30 phút gần nhất, có dấu thời gian
docker compose --env-file .env.prod -f docker-compose.prod.yml logs --since 30m -t api
```

Tên container là `vaultly-api-1` và `vaultly-caddy-1`, nên `docker logs -f vaultly-api-1`
cũng tương đương khi đã ở đúng máy.

Log của API gồm: cấu hình lúc khởi động, kết quả migration, dòng `listening on`,
mỗi request dạng `GET /files/<id>/view 206 42ms`, và cảnh báo như
`WARNING: R2 credentials are not configured`. Định dạng này không có IP, muốn xem
IP thì đọc log Caddy: `docker compose ... logs caddy | grep '/files/'`.

Lọc nhanh:

```bash
# chỉ request lỗi 5xx
... logs --since 2h api | grep -E ' 5[0-9]{2} '

# lỗi khởi động: thiếu biến, DB không kết nối được, migration hỏng
... logs --since 1h api | grep -E 'Failed|refusing|migration|error'

# request chậm hơn 1 giây
... logs --since 2h api | grep -E '[0-9]+(\.[0-9]+)?s$'
```

Lưu ý: log xoay vòng 10MB × 3 file mỗi container, tự mất khi vượt. Cần lịch sử
lâu hơn thì phải đẩy log ra ngoài (ví dụ `docker logs` vào Loki hoặc gửi lên một
aggregator), VPS không tự giữ.

## 8. Sự cố

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| Container api thoát ngay, log `production requires JWT_SECRET` / `R2_...` | `.env.prod` thiếu biến hoặc chưa truyền `--env-file` |
| Caddy trả 502 | api chưa healthy: xem `logs api`, thường là `DATABASE_URL` sai hoặc Supabase chặn IP |
| `failed to connect to database` | dùng host direct IPv6, hoặc thiếu `sslmode=require` |
| Upload trả 413 | vượt `MAX_UPLOAD_MB` hoặc `max_size` trong `Caddyfile` |
| Không có chứng chỉ TLS | DNS chưa trỏ đúng, hoặc cổng 80/443 bị chặn |
| Mọi request 401 sau khi deploy | `JWT_SECRET` khác lần trước |
| Log `WARNING: R2 credentials are not configured` | chạy ngoài `ENV=production` mà thiếu key; dữ liệu chỉ nằm trong RAM |

## 9. Điều cần biết về mô hình bảo mật

Server giữ khoá giải mã trong cột `nonce` và giải mã hộ khi trả ảnh, nên VPS và
Supabase đều nằm trong vùng tin cậy. Hãy coi chúng như máy chủ chứa dữ liệu thật:
bật 2FA cho tài khoản Cloudflare và Supabase, không dùng chung token R2 cho việc
khác, và giới hạn IP SSH. Muốn bỏ hẳn tin cậy vào server thì phải chuyển sang mã
hoá phía client, việc đó chưa làm.
