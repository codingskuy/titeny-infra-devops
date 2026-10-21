# Dev-stack lokal Titeny (TTN-OPS-006)

Satu perintah menaikkan `titeny-backend-service` + Postgres 16.4 + data seed untuk pengembangan web/desktop dan uji kontrak. **Hanya untuk lokal**: kredensial, OTP-ke-log, dan rate limit longgar di sini bukan konfigurasi produksi.

## Isi

| Berkas | Fungsi |
|---|---|
| `docker-compose.yml` | `db` (Postgres 16.4), `backend` (build dari repo backend), `seed` (sekali jalan) |
| `seed.sh` / `seed.sql` | tunggu migrasi backend, lalu isi akun dev, PIN zona, prediksi, rekomendasi (idempoten) |
| `smoke.sh` | healthcheck + login layanan dan analis + papan PIN zona |
| `.env` (opsional, diabaikan git) | override variabel (lihat bawah) |

## Cara pakai

```sh
cd dev-stack
docker compose up --build -d db backend   # build pertama memakan beberapa menit (cargo build --release)
docker compose run --rm seed              # tunggu migrasi, isi seed (boleh diulang)
./smoke.sh                                # harus berakhir "SMOKE LULUS"
docker compose down -v                    # bersihkan (hapus volume DB)
```

API di `http://127.0.0.1:8080` (`/api/v1/...`, spesifikasi: `docs/api/openapi.yaml` di repo backend). Postgres di `127.0.0.1:5433` (user `titeny`, DB `titeny`).

### Sumber backend

Default membangun dari cabang `feat/ttn-be-005-aksi-analis-audit` di fork `codingskuy/titeny-backend-service` (PR upstream #10, sudah memuat auth, event, insight, aksi analis). Setelah PR backend merge, ganti ke `#main`. Untuk checkout lokal:

```sh
BACKEND_CONTEXT=../../titeny-backend-service docker compose up --build -d db backend
```

### Variabel (semua opsional)

`BACKEND_CONTEXT`, `BACKEND_PORT` (8080), `DB_PORT` (5433), `DB_PASSWORD`, `JWT_SECRET` (min. 32 karakter; **seed menurunkan digest PIN dari nilai ini**, jadi jalankan `seed` dengan nilai yang sama).

## Akun dan PIN dev (dari `seed.sql`)

| Peran | Kredensial |
|---|---|
| CEO | `ceo-uji` / `sandi-uji-lokal-1` (OTP) |
| Analis | `analis-uji` / `sandi-uji-lokal-1` (OTP) |
| Layanan (sumber event) | `layanan-uji` / `sandi-uji-lokal-1` (tanpa OTP) |
| Petani (PIN zona `psr_jakarta_timur_01`) | `482013` di header `X-Zona-PIN` |
| Vendor | `739204` |

Nilai sama dengan `contract/seed.py` di titeny-web (PR #16/#17), sehingga `contract/schemathesis.sh` web/app-kmp berjalan terhadap stack ini. OTP login CEO/analis dicetak backend ke log (`OTP_LOG_DEV=true`):

```sh
docker compose logs backend | grep 'username=analis-uji' | tail -1
```

## Smoke

`./smoke.sh` memeriksa: `/api/v1/kesehatan` dan `/health` 200; login `layanan-uji` langsung bertoken dan token itu ditolak 403 di endpoint baca (least-privilege); login `analis-uji` -> OTP dari log -> token -> `GET /analis/antrean` 200; PIN petani 200 dan PIN asing 401; kata sandi salah 401. Variabel: `BASE_URL`, `SERVER_LOG` (backend native, bukan docker), `SANDI`, `TUNGGU_DETIK`.

Backend native tanpa docker (cara skrip ini diuji di mesin pengembang tanpa daemon docker):

```sh
export DATABASE_URL=postgres://localhost/titeny JWT_SECRET=<min-32-karakter> OTP_LOG_DEV=true RATE_LIMIT_PER_MENIT=100000
cargo run > be.log 2>&1 &                                  # di repo backend; migrasi jalan otomatis
PGDATABASE=titeny JWT_SECRET="$JWT_SECRET" sh dev-stack/seed.sh
SERVER_LOG=be.log dev-stack/smoke.sh
```

## Batas dan asumsi

- `seed.sql` mengikuti skema migrasi `001..005` backend (TTN-BE-005). Migrasi baru yang mengubah tabel `pengguna`, `zona_pin`, `prediksi_*`, atau `rekomendasi` memerlukan pembaruan seed; `MIGRASI_MIN` (default 5) menentukan jumlah migrasi yang ditunggu seed.
- `Dockerfile` backend memakai `rust:1.83-slim` dan membangun ulang tanpa cache dependensi (lambat; optimasi layer ada di repo backend, bukan di sini).
- Tidak ada layanan mock terpisah: respons berasal dari backend nyata dengan seed. Mock Pact/Maestro tetap milik repo web/app-kmp.
- CI: workflow `dev-stack` memvalidasi `docker compose config` + shellcheck pada setiap PR yang menyentuh `dev-stack/`; smoke penuh (docker) hanya manual (`workflow_dispatch`).
