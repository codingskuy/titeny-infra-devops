# CHANGELOG — titeny-infra-devops

Format: satu seksi per rilis, terbaru di atas. Wajib diperbarui pada setiap commit `feat:` / `fix:` / `docs:`.

## [Belum dirilis]

### Ditambahkan
- `docs/ci.md`: peta CI, QA gate, prasyarat repo kode, usulan proteksi `main` (TTN-OPS-002).
- Workflow CI reusable `ci-backend`, `ci-web`, `ci-model`, `ci-desktop` (MSI + `SHA256SUMS.txt`), orkestrator `ci-semua`, dan templat pemanggil `ci-templates/` (TTN-OPS-002).
- `scripts/qa-gate.sh` + uji `scripts/tests/qa-gate-test.sh`: gerbang QA-002 (tanpa test dilewati) dan gerbang 11 fixture event (TTN-OPS-002).
- Fondasi AI-dev v1.0.0: `AGENTS.md`, `CLAUDE.md`, `docs/decisions/ADR-0001-fondasi-teknis.md`, `versions/v1.0.0/docs/40-TECHSTACK.md` dan `60-BLAST-RADIUS.md` (versi lengkap, menggantikan ringkasan awal).
