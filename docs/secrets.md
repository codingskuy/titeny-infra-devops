# Secrets per lingkungan + penegakan read-only DB sumber (TTN-OPS-004)

Rujukan: BR-004, BR-005, US-006; `docs/auth.md` lumbung-backend-service (JWT ed25519, rotasi 90 hari dengan tenggang 7 hari); KONTEKS §6; `townhall-roadmap.md` §2.

## Daftar secret (nama saja; nilai hanya di secret manager)

| Nama | Isi | dev | staging | prod |
|---|---|---|---|---|
| `DATABASE_URL` | DB logis `titeny`, user `titeny_app` (satu-satunya hak tulis) | ya | ya | ya |
| `JWT_ED25519_PRIVATE` / `JWT_ED25519_PUBLIC` | kunci tanda tangan JWT `aud=titeny`, `iss=chefgenie-auth` | ya | ya | ya |
| `TITENY_API_TOKEN` | token layanan sumber event | ya | ya | ya |
| `GHCR_TOKEN` | tarik/dorong image `ghcr.io/coding-skuy/titeny-*` | ya | ya | ya |
| `SRC_S1_DATABASE_URL` .. `SRC_S10_DATABASE_URL` | role `titeny_ro_sNN`, SELECT saja pada DB sumber | ya (data uji) | ya | ya |

Templat: `secrets/{dev,staging,prod}.env.example` (hanya placeholder `GANTI_DARI_SECRET_MANAGER`). `.gitignore` memblokir `.env*`, `*.pem`, `*.key`. Tiap lingkungan memakai secret manager/namespace terpisah; tidak ada nilai dipakai lintas lingkungan.

## Pemeriksaan otomatis

| Skrip | Fungsi |
|---|---|
| `scripts/setup-secrets.sh <env>` | semua nama terisi dan bukan placeholder, lalu panggil `audit-koneksi.sh`; tidak mencetak nilai |
| `scripts/audit-koneksi.sh <env>` | `DATABASE_URL` -> DB `titeny`; `SRC_S*` -> role `titeny_ro_*`, bukan DB `titeny`, `sslmode=require` (staging/prod) |
| `scripts/scan-rahasia.sh` | tidak ada kunci privat/token/string koneksi berkata sandi/`.env` terlacak (job `audit-secrets`, tiap PR + mingguan) |
| `sql/source-readonly-role.sql` | dijalankan PEMILIK DB sumber: buat role SELECT-saja, `default_transaction_read_only=on`, `statement_timeout` |
| `sql/audit-privileges.sql` | bukti hak: gagal bila role punya INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER, CREATE, atau atribut berbahaya |
| `scripts/audit-log-tulis.sh` | audit log Postgres 30 hari: nol tulis `titeny_*` di luar DB `titeny`, nol tulis `titeny_ro_*` sama sekali |

Prasyarat log server sumber: `log_statement = 'mod'`, `log_line_prefix = '%m [%p] %u@%d '`, retensi >= 30 hari. Jadwal usulan: `audit-log-tulis.sh` mingguan dan sebelum rilis; keluaran 0 = bukti M-007, 3 = cakupan log kurang.

## Rotasi terjadwal (usulan; eksekusi manusia/secret manager)

- Kredensial S1-S10: tiap 90 hari, tenggang 7 hari. Pola dua-slot: buat role pasangan `titeny_ro_sNN_b` dengan `sql/source-readonly-role.sql`, ganti secret `SRC_Sn_DATABASE_URL`, verifikasi `audit-privileges.sql` dan `setup-secrets.sh`, lalu `DROP ROLE` slot lama setelah tenggang. Role juga `VALID UNTIL` 100 hari sebagai pagar.
- Kunci JWT ed25519: tiap 180 hari (usulan; docs/auth.md hanya menetapkan 90 hari untuk device key), verifikator menerima kunci lama selama masa tenggang token (15 menit akses, 7 hari refresh).
- `TITENY_API_TOKEN`, `GHCR_TOKEN`: tiap 90 hari.
- Insiden kebocoran: lihat `docs/runbook-kebocoran-kunci.md`.

## Batas

Repo ini tidak membuat user/secret/koneksi dengan hak tulis ke DB Lumbung, TitipO, atau Pasaree. Pembuatan role sumber dijalankan pemilik sumber; repo hanya menyediakan skrip dan bukti.
