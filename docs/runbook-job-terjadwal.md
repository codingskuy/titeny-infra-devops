# Runbook job terjadwal model (TTN-OPS-003)

| Job (CronJob) | Jadwal WIB | Catatan |
|---|---|---|
| harga-0400 | 04.00 harian | harga H+1-H+7 (12 x 8) |
| harga-retry-0430 / harga-retry-0500 | 04.30 / 05.00 | hanya bila belum sukses hari ini; 05.00 menandai `basi` bila gagal |
| harga-koreksi-1500 | 15.00 | hanya bila `koreksi.flag` ada |
| demand-0430 | 04.30 | H+7/H+30 |
| panen-senin-0300 | Senin 03.00 | M+1-M+4 |
| mape-minggu-2300 | Minggu 23.00 | skor MAPE mingguan |

## Memantau
- Log: `/var/log/titeny-jobs/jobs-YYYY-MM-DD.jsonl` (PVC `titeny-job-state`, subPath `log`), minimal 30 hari. Cari pager: `grep '"pager":true' jobs-*.jsonl`.
- Status penanda: `/var/lib/titeny-jobs/<job>.<tanggal>.ok|stale`, penghitung `<job>.gagal`.

## Bila pager menyala (`"pager":true`)
1. Baca baris `gagal` terakhir (`kode`, `gagal_berturut`) dan log stdout pod (`kubectl logs -n titeny job/<nama>`).
2. Perbaiki penyebab (DB `titeny`, sumber event, image). Jangan mengubah DB sumber.
3. Jalankan ulang manual: `kubectl create job --from=cronjob/<nama> manual-$(date +%s) -n titeny`. Sukses mereset penghitung.
4. Bila lewat 05.00 tanpa sukses, prediksi H-1 berlabel `basi` tetap tayang; catat di insiden.

## Kunci macet
`<job>.lock` lebih tua dari 120 menit diambil alih otomatis. Hapus manual hanya bila pod pemegang dipastikan mati: `rm -rf /var/lib/titeny-jobs/<job>.lock`.

## Uji lokal
`sh scripts/tests/job-wrapper-test.sh && sh scripts/tests/jadwal-test.sh`
