# ADR-0004 — Rilis desktop analis: GitHub Release, verifikasi, smoke install, rollback berbasis rilis lama

- **Status**: Diusulkan (menunggu persetujuan manusia)
- **Tanggal**: 2026-10-21
- **Tiket**: TTN-OPS-005 (#5)

## Konteks
`produk/22-kontrak-desktop-windows.md` §6: MSI 64-bit Windows 10 21H2+ / Windows 11, pembaruan MSI penuh tiap rilis minor. Ticket: artefak `Titeny-Analis-1.0.0.msi` + `SHA256SUMS.txt`, tag menyimpan build sebelumnya untuk rollback, instalasi teruji, runbook.

## Keputusan
1. Saluran distribusi: GitHub Release di repo ini, tag `analis-vX.Y.Z`; aset = MSI + `SHA256SUMS.txt`. Rilis tidak pernah dihapus (rollback = rilis lama).
2. Pipeline `release-desktop.yml` memakai `ci-desktop.yml` (TTN-OPS-002) lalu `verifikasi-rilis-desktop.sh` (nama, satu MSI, checksum, x64 via `msiinfo`) dan smoke install di Windows (msiexec senyap, proses hidup 15 detik, copot).
3. Rollback: `scripts/rollback-desktop.sh` (default dry-run; `--terapkan` menandai rilis lama `latest`) + langkah manual copot-pasang untuk analis.
4. Nomor versi MSI diturunkan dari `packageVersion` repo app; pipeline menolak bila tidak cocok dengan tag.

## Asumsi / perlu keputusan manusia
- Direktori instalasi default jpackage `C:\Program Files\id.skuy.titeny.analis` (smoke install bergantung padanya).
- Penandatanganan kode (code signing) MSI belum ada; tidak ada sertifikat di repo. Tanpa tanda tangan Windows SmartScreen akan memperingatkan; keputusan pembelian sertifikat di luar cakupan.
- Syarat OS minimum (Windows 10 21H2+) belum ditegakkan oleh MSI (jpackage tidak menyediakan kondisi versi OS bawaan); hanya diuji pada windows-2022.
- Bukti M-006 (antrean validasi berjalan) butuh API nyata; smoke otomatis terbatas pada terpasang + proses hidup.

## Konsekuensi
Rilis 1.0.0 terblokir sampai `titeny-app-kmp` memiliki `gradlew`, `packageVersion = 1.0.0`, dan tag `v1.0.0`.
