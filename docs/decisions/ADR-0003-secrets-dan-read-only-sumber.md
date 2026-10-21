# ADR-0003 — Secrets per lingkungan dan penegakan read-only DB sumber

- **Status**: Diusulkan (menunggu persetujuan manusia)
- **Tanggal**: 2026-10-21
- **Tiket**: TTN-OPS-004 (#4)

## Konteks
BR-004/US-006: Titeny read-only terhadap DB Lumbung/TitipO/Pasaree; satu-satunya basis tulis `titeny`; audit 30 hari harus membuktikan nol tulis di luar `titeny`. BR-005: JWT `aud=titeny`. `setup-secrets.sh` lama memiliki bug (memeriksa nama variabel, bukan nilainya) dan tidak membedakan lingkungan.

## Keputusan
1. Nilai rahasia hanya di secret manager per lingkungan; repo hanya memuat templat placeholder dan skrip pemeriksa yang tidak mencetak nilai.
2. Konvensi: sumber `SRC_S{1..10}_DATABASE_URL`, role `titeny_ro_sNN`; DB tulis `DATABASE_URL` -> `titeny`. Pelanggaran konvensi menggagalkan `audit-koneksi.sh`.
3. Least-privilege ditegakkan berlapis: role tanpa hak tulis (`sql/source-readonly-role.sql`), `default_transaction_read_only=on`, bukti hak (`sql/audit-privileges.sql`, diuji pada Postgres nyata), audit log (`scripts/audit-log-tulis.sh`).
4. Rotasi: 90 hari dengan tenggang 7 hari (selaras `docs/auth.md` Lumbung) untuk kredensial/token; kunci JWT 180 hari (USULAN, perlu keputusan manusia); pola dua-slot role untuk sumber.
5. CI `audit-secrets` memindai rahasia terlacak pada tiap PR dan mingguan.
6. Usulan proteksi (BUKAN diterapkan): aktifkan GitHub secret scanning + push protection pada repo kode; wajibkan check `audit-secrets` sebelum merge.

## Asumsi
- Jumlah dan identitas sumber S1-S10 belum dipetakan di dokumen beku; nama `SRC_Sn` hanya indeks.
- Secret manager belum dipilih di TECHSTACK; templat netral.
- Log server sumber dapat dikonfigurasi (`log_statement=mod`, prefix `%u@%d`) oleh pemilik sumber.

## Konsekuensi
Pemilik DB sumber harus menjalankan SQL role dan mengaktifkan log; tanpa itu bukti M-007 tidak lengkap (`audit-log-tulis.sh` keluar 3).
