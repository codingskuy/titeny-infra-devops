# CHANGELOG — titeny-infra-devops

Format: satu seksi per rilis, terbaru di atas. Wajib diperbarui pada setiap commit `feat:` / `fix:` / `docs:`.

## [Belum dirilis]

### Ditambahkan
- `scripts/job-wrapper.sh`: kunci berkas, retry berbasis penanda, `pager: true` pada gagal ke-3, log JSON retensi >= 30 hari, beserta uji `scripts/tests/job-wrapper-test.sh` (TTN-OPS-003).
- `scripts/gen-cronjobs.sh` dan uji `scripts/tests/jadwal-test.sh`; `k8s/cronjob-insight.yaml` kini dibangkitkan dengan jadwal terkunci WIB (TTN-OPS-003).
- ADR-0002 dan `docs/runbook-job-terjadwal.md` (TTN-OPS-003).
- Fondasi AI-dev v1.0.0: `AGENTS.md`, `CLAUDE.md`, `docs/decisions/ADR-0001-fondasi-teknis.md`, `versions/v1.0.0/docs/40-TECHSTACK.md` dan `60-BLAST-RADIUS.md` (versi lengkap, menggantikan ringkasan awal).

### Diubah
- `k8s/cronjob-insight.yaml`: jadwal UTC lama diganti jadwal terkunci WIB; `harga-per-jam` dihapus.
- `.github/workflows/scheduled-insight.yml`: tanpa jadwal (hanya manual) agar tidak ganda dengan CronJob.
