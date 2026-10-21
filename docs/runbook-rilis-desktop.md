# Runbook rilis desktop analis MSI (TTN-OPS-005)

Rujukan: `produk/22-kontrak-desktop-windows.md` §6, `roadmap/MILESTONE.md` (M-006). Target: `Titeny-Analis-1.0.0.msi` 64-bit, Windows 10 21H2+ / Windows 11, bersama `SHA256SUMS.txt`. Hanya Windows; mobile V1 tidak dirilis.

## Prasyarat (cek sebelum menandai rilis)
1. `titeny-app-kmp`: `packageVersion = "1.0.0"` di `analis-desktop/build.gradle.kts`, Gradle wrapper terkomit, tag `v1.0.0` di repo itu (saat ini `packageVersion = "0.1.0"`, tanpa `gradlew`).
2. CI desktop hijau (`ci-desktop`; QA gate tanpa test dilewati).
3. Persetujuan manusia untuk tag rilis (proteksi tag/branch diatur manusia, bukan PR ini).

## Rilis
1. Latihan tanpa rilis: Actions > `release-desktop` > Run workflow, `versi=1.0.0`, `publish=false`. Pastikan job `build`, `verifikasi`, `smoke-install` hijau.
2. Rilis: buat tag di repo ini `git tag analis-v1.0.0 && git push origin analis-v1.0.0` (atau dispatch dengan `publish=true`).
3. Alur otomatis: `siapkan` -> `build` (`ci-desktop`: `./gradlew test`, `:analis-desktop:packageMsi`) -> `verifikasi` (nama `Titeny-Analis-1.0.0.msi`, tepat satu MSI, checksum, x64) -> `smoke-install` (msiexec senyap, aplikasi terpasang dan hidup 15 detik, copot) -> `rilis` (GitHub Release `analis-v1.0.0` berisi MSI + `SHA256SUMS.txt`).
4. Verifikasi pengguna: `sha256sum -c SHA256SUMS.txt` (atau `Get-FileHash -Algorithm SHA256`) lalu pasang MSI.

## Bukti M-006 (manual, dicatat di tiket)
- Pasang di Windows 10 21H2 dan Windows 11 bersih; aplikasi terpasang, login analis, layar Antrean Validasi memuat daftar (polling 5 menit), aksi `setuju/koreksi_nilai/tolak` terkirim. Smoke otomatis hanya membuktikan terpasang + proses hidup; antrean validasi butuh API nyata (belum diotomasi).

## Pembaruan
MSI penuh tiap rilis minor (kontrak §6). Pertahankan `upgradeUuid` yang sama antar rilis agar MSI memperbarui versi terpasang (di luar repo ini: `titeny-app-kmp`).

## Rollback
Rilis lama tidak pernah dihapus; tiap rilis menyimpan MSI + checksum.
1. Pastikan rilis tujuan: `gh release list -R Coding-Skuy/titeny-infra-devops`.
2. Latihan: `sh scripts/rollback-desktop.sh analis-v<lama>` (unduh + verifikasi checksum, tanpa perubahan).
3. Terapkan: `sh scripts/rollback-desktop.sh analis-v<lama> --terapkan` (menandai rilis lama sebagai `latest`).
4. Analis: copot versi baru (Settings > Apps) lalu pasang `Titeny-Analis-<lama>.msi`; MSI biasanya menolak downgrade langsung. Cache SQLite `%LOCALAPPDATA%/Titeny/analis.db` dipertahankan; aksi tulis antre tetap terkirim (`aksi_id` idempoten).
5. Verifikasi: aplikasi terbuka, versi sesuai, antrean validasi memuat. Catat insiden dan buat tiket perbaikan sebelum rilis ulang (nomor versi baru; jangan menimpa tag).
6. Server (backend/web): rollback = tag image sebelumnya `ghcr.io/coding-skuy/titeny-backend-service:<tag-lama>` + migrasi DOWN (lihat `versions/v1.0.0/docs/60-BLAST-RADIUS.md`); di luar cakupan skrip ini.

## Batas
Repo ini tidak mengubah proteksi branch/tag atau pengaturan repo; rilis hanya membaca `titeny-app-kmp`.
