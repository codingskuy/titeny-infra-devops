# CHANGELOG — titeny-infra-devops

Format: satu seksi per rilis, terbaru di atas. Wajib diperbarui pada setiap commit `feat:` / `fix:` / `docs:`.

## [Belum dirilis]

### Ditambahkan
- Dev-stack lokal `dev-stack/`: docker-compose backend-service + Postgres 16.4 + seed, `smoke.sh` (healthcheck, login layanan/analis, PIN zona), README, workflow `dev-stack` (validasi per PR, smoke penuh manual) (TTN-OPS-006).
- Rilis desktop analis: workflow `release-desktop` (build -> verifikasi -> smoke install -> GitHub Release), `scripts/verifikasi-rilis-desktop.sh`, `scripts/rollback-desktop.sh`, uji `scripts/tests/rilis-test.sh`, workflow `uji-skrip-rilis`, ADR-0004, `docs/runbook-rilis-desktop.md` (TTN-OPS-005).
- `docs/ci.md`: peta CI, QA gate, prasyarat repo kode, usulan proteksi `main` (TTN-OPS-002).
- Workflow CI reusable `ci-backend`, `ci-web`, `ci-model`, `ci-desktop` (MSI + `SHA256SUMS.txt`), orkestrator `ci-semua`, dan templat pemanggil `ci-templates/` (TTN-OPS-002).
- `scripts/qa-gate.sh` + uji `scripts/tests/qa-gate-test.sh`: gerbang QA-002 (tanpa test dilewati) dan gerbang 11 fixture event (TTN-OPS-002).
- Fondasi AI-dev v1.0.0: `AGENTS.md`, `CLAUDE.md`, `docs/decisions/ADR-0001-fondasi-teknis.md`, `versions/v1.0.0/docs/40-TECHSTACK.md` dan `60-BLAST-RADIUS.md` (versi lengkap, menggantikan ringkasan awal).
