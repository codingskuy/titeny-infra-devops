# ADR-0002 — Job terjadwal: CronJob WIB, kunci berkas, retry berbasis penanda, pager via log

- **Status**: Diusulkan (menunggu persetujuan manusia)
- **Tanggal**: 2026-10-21
- **Tiket**: TTN-OPS-003 (#3)

## Konteks

`FSD/10-alur.md` butir 2 dan `40-TECHSTACK.md` mengunci jadwal (WIB): harga 04.00 (+15.00 bila ada koreksi siang), demand 04.30, panen Senin 03.00, skor MAPE Minggu 23.00; retry harga 04.30 dan 05.00 sebelum memakai prediksi H-1 berlabel basi; kunci berkas mencegah job ganda; gagal 3x memicu log `pager: true`. Kode awal memakai `0 1 * * *` dan `15 * * * *` (UTC) dan event `lumbung.harga.perbarui` (di luar 11 event terkunci).

## Keputusan

1. Jadwal hidup di `k8s/cronjob-insight.yaml` yang DIBANGKITKAN dari satu tabel (`scripts/gen-cronjobs.sh`); uji `scripts/tests/jadwal-test.sh` memastikan tidak ada drift dan jadwal sesuai kunci. Semua CronJob `timeZone: Asia/Jakarta`, `concurrencyPolicy: Forbid`, `backoffLimit: 0`.
2. `scripts/job-wrapper.sh` membungkus tiap job: kunci berkas atomik (`mkdir`, TTL 120 menit untuk kunci basi), penanda sukses harian, penghitung gagal berturut-turut, log JSON-lines ISO-8601 +07:00.
3. Retry = CronJob terpisah (`harga-retry-0430`, `harga-retry-0500`) dengan `--only-if-missing`; retry 05.00 memakai `--stale-on-fail` sehingga log memuat `"label":"basi"` (konsumen memakai prediksi H-1).
4. Pager = baris log `"pager":true` pada gagal berturut ke-3 (04.00, 04.30, 05.00 menghasilkan tepat 3 kegagalan). Pengirim pager/alert memantau log tersebut (di luar repo ini).
5. Hitung ulang 15.00 hanya bila `koreksi.flag` ada (ditulis ingest saat koreksi siang) dan dikonsumsi saat sukses.
6. Log di PVC bersama, retensi default 35 hari (minimal 30; wrapper menolak <30); stdout juga ditangkap kolektor log kluster.
7. Workflow GitHub `scheduled-insight.yml` tidak lagi menjadwalkan (hanya manual) agar tidak ganda dengan CronJob. Job `harga-per-jam` dihapus (event `lumbung.harga.perbarui` tidak terdaftar; tidak ada jadwal per jam di v1.0.0).

## Asumsi (belum ada kontrak; harus dikonfirmasi pemilik repo model)

- Image `ghcr.io/coding-skuy/titeny-ai-models:1.0.0` berisi `sh`, `find`, dan modul `titeny_models.jobs` dengan sub-perintah `harga|demand|panen|mape` (kode-keluar non-nol = gagal). Saat ini modul itu belum ada.
- StorageClass RWX tersedia untuk PVC `titeny-job-state`.

## Konsekuensi

- Perubahan jadwal wajib lewat tabel di generator + pembaruan TownHall (jadwal terkunci v1.0.0).
- Wrapper tidak menjamin kunci lintas-node bila PVC bukan RWX; `concurrencyPolicy: Forbid` tetap melindungi per CronJob.
