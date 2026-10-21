# CHANGELOG — titeny-infra-devops

Format: satu seksi per rilis, terbaru di atas. Wajib diperbarui pada setiap commit `feat:` / `fix:` / `docs:`.

## [Belum dirilis]

### Ditambahkan
- Secrets per lingkungan: templat `secrets/*.env.example`, `scripts/secrets-lib.sh`, `scripts/audit-koneksi.sh`, `scripts/scan-rahasia.sh`, `sql/source-readonly-role.sql`, `sql/audit-privileges.sql`, `scripts/audit-log-tulis.sh`, workflow `audit-secrets`, ADR-0003, `docs/secrets.md`, `docs/runbook-kebocoran-kunci.md` (TTN-OPS-004).
- Uji: `scripts/tests/secrets-test.sh` dan `scripts/tests/sql-readonly-test.sh` (Postgres sementara).
- Fondasi AI-dev v1.0.0: `AGENTS.md`, `CLAUDE.md`, `docs/decisions/ADR-0001-fondasi-teknis.md`, `versions/v1.0.0/docs/40-TECHSTACK.md` dan `60-BLAST-RADIUS.md` (versi lengkap, menggantikan ringkasan awal).

### Diperbaiki
- `scripts/setup-secrets.sh`: pemeriksaan sebelumnya salah (memeriksa nama variabel); kini per lingkungan, menolak placeholder, memanggil audit koneksi (TTN-OPS-004).
