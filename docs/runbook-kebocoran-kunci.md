# Runbook insiden kebocoran kunci/rahasia (TTN-OPS-004)

Berlaku untuk: `DATABASE_URL`, kunci JWT ed25519, `TITENY_API_TOKEN`, `GHCR_TOKEN`, kredensial sumber `SRC_S*`.

## 0. Tetapkan cakupan (menit 0-15)
- Catat: rahasia mana, lingkungan mana, sejak kapan terpapar (commit, log, tangkapan layar), siapa yang melihat.
- Jangan menempelkan nilai rahasia di tiket/obrolan.

## 1. Revoke (segera)
| Rahasia | Tindakan |
|---|---|
| Kredensial sumber `titeny_ro_sNN` | di DB sumber: `ALTER ROLE titeny_ro_sNN NOLOGIN; SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename='titeny_ro_sNN';` (hubungi pemilik sumber) |
| `DATABASE_URL` (`titeny_app`) | `ALTER ROLE titeny_app NOLOGIN` lalu terminasi sesi; akan menghentikan ingest, terima dampaknya |
| Kunci JWT | hapus kunci publik lama dari verifikator, terbitkan kunci baru; semua token akses (15 menit) dan refresh (7 hari) lama menjadi tidak sah |
| `TITENY_API_TOKEN` | cabut di penerbit; terbitkan baru |
| `GHCR_TOKEN` | cabut PAT/token di GitHub; periksa log tarik/dorong image |
Bila rahasia sempat ter-commit: anggap bocor selamanya; bersihkan riwayat hanya setelah rotasi, dan jangan force-push `main` tanpa persetujuan.

## 2. Rotasi
1. Buat nilai baru di secret manager (lingkungan terdampak saja).
2. Sumber S1-S10: jalankan `sql/source-readonly-role.sql` (pemilik sumber) dengan sandi baru, atau slot `_b`.
3. Terapkan ke kluster (`kubectl -n titeny rollout restart` untuk beban kerja pemakai secret).

## 3. Verifikasi
- `sh scripts/setup-secrets.sh <env>` hijau (nilai tidak tercetak).
- Tiap sumber: `psql ... -f sql/audit-privileges.sql` lulus; nilai lama ditolak (`FATAL: password authentication failed` atau role NOLOGIN).
- `GET /health` dan satu event duplikat tetap `duplikat_diabaikan`.
- Jalankan `scripts/audit-log-tulis.sh` pada log sejak waktu paparan: tidak ada tulis tidak sah; simpan keluarannya sebagai bukti.

## 4. Tindak lanjut
- Catat kronologi + akar masalah; tambah pola ke `scripts/scan-rahasia.sh` bila perlu.
- Beri tahu pemilik sumber bila rahasia sumber terlibat (insiden DB sumber diteruskan ke pemilik sumber).
- Jadwalkan rotasi rahasia lain yang berada di tempat yang sama.
