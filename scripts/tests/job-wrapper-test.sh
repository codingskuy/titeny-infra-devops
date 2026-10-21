#!/bin/sh
# Uji job-wrapper.sh: kunci, retry, pager 3x, label basi, log 30 hari. Jalankan: sh scripts/tests/job-wrapper-test.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
w="$here/job-wrapper.sh"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export JOB_STATE_DIR="$t/state" JOB_LOG_DIR="$t/log"
gagal=0
hari=$(TZ=Asia/Jakarta date +%F)
logfile="$t/log/jobs-$hari.jsonl"

cek() { # cek <deskripsi> <kode-asli> <kode-harap>
  if [ "$2" -eq "$3" ]; then echo "lulus: $1"; else echo "GAGAL: $1 (kode $2, harap $3)"; gagal=1; fi
}
ada() { # ada <deskripsi> <pola> <berkas>
  if grep -q -- "$2" "$3" 2>/dev/null; then echo "lulus: $1"; else echo "GAGAL: $1 (tidak ada $2)"; gagal=1; fi
}
tidak() {
  if grep -q -- "$2" "$3" 2>/dev/null; then echo "GAGAL: $1 (ada $2)"; gagal=1; else echo "lulus: $1"; fi
}
berkas() { # berkas <deskripsi> <ada|tak> <path>
  if [ "$2" = ada ] && [ -f "$3" ]; then echo "lulus: $1"
  elif [ "$2" = tak ] && [ ! -f "$3" ]; then echo "lulus: $1"
  else echo "GAGAL: $1"; gagal=1; fi
}
jalan() { set +e; sh "$w" "$@" >/dev/null 2>&1; r=$?; set -e; }

# 1. sukses menulis penanda dan log
jalan harga -- true; cek "sukses kode 0" "$r" 0
berkas "penanda ok dibuat" ada "$t/state/harga.$hari.ok"
ada "log sukses" '"status":"sukses"' "$logfile"
ada "log ISO-8601 WIB +07:00" '+07:00"' "$logfile"

# 2. --only-if-missing dilewati bila hasil hari ini ada
jalan harga --only-if-missing -- false; cek "retry dilewati bila sudah sukses" "$r" 0
ada "log dilewati" '"status":"dilewati"' "$logfile"

# 3. kunci berkas mencegah job ganda
mkdir "$t/state/demand.lock"
jalan demand -- false; cek "kunci dipegang -> dilewati, bukan gagal" "$r" 0
rmdir "$t/state/demand.lock"
ada "log job ganda" 'job ganda dicegah' "$logfile"

# 4. kunci basi diambil alih
mkdir "$t/state/panen.lock"; touch -t 202001010000 "$t/state/panen.lock"
jalan panen -- true; cek "kunci basi diambil alih" "$r" 0
ada "log kunci basi" 'kunci_basi_diambil' "$logfile"

# 5. gagal 3x -> pager: true hanya pada gagal ke-3
jalan mape -- false; cek "gagal ke-1 kode 1" "$r" 1
jalan mape -- false; cek "gagal ke-2 kode 1" "$r" 1
tidak "belum pager sebelum ke-3" '"pager":true' "$logfile"
jalan mape -- false; cek "gagal ke-3 kode 1" "$r" 1
ada "pager true pada gagal ke-3" '"gagal_berturut":3,"pager":true' "$logfile"

# 6. sukses mereset penghitung
jalan mape -- true
berkas "penghitung direset" tak "$t/state/mape.gagal"

# 7. --stale-on-fail memberi label basi
jalan harga-x --stale-on-fail -- false; cek "stale-on-fail kode 1" "$r" 1
ada "label basi" '"label":"basi"' "$logfile"

# 8. --require-flag
jalan koreksi --require-flag koreksi -- false; cek "tanpa penanda dilewati" "$r" 0
: > "$t/state/koreksi.flag"
jalan koreksi --require-flag koreksi -- true; cek "dengan penanda berjalan" "$r" 0
berkas "penanda koreksi dikonsumsi" tak "$t/state/koreksi.flag"

# 9. retensi: log sangat lama dipangkas, 31 hari masih disimpan (retensi 35); <30 ditolak
mkdir -p "$t/log"
: > "$t/log/jobs-2020-01-01.jsonl"; touch -t 202001010000 "$t/log/jobs-2020-01-01.jsonl"
: > "$t/log/jobs-baru.jsonl"
touch -t "$(date -v-31d +%Y%m%d0000 2>/dev/null || date -d '31 days ago' +%Y%m%d0000)" "$t/log/jobs-baru.jsonl"
jalan harga-y -- true
berkas "log sangat lama dipangkas" tak "$t/log/jobs-2020-01-01.jsonl"
berkas "log 31 hari masih disimpan" ada "$t/log/jobs-baru.jsonl"
JOB_LOG_RETENTION_DAYS=29 jalan harga-z -- true; cek "retensi <30 ditolak" "$r" 2

# 10. salah pakai
jalan; cek "tanpa argumen -> 2" "$r" 2
jalan "Nama Salah" -- true; cek "nama tidak valid -> 2" "$r" 2
jalan harga-q; cek "tanpa perintah -> 2" "$r" 2

exit $gagal
