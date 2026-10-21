#!/bin/sh
# Pembungkus job terjadwal Titeny (TTN-OPS-003): kunci berkas, retry berbasis penanda,
# eskalasi pager setelah gagal berturut-turut, log JSON-lines yang dapat diaudit.
#
# Pemakaian:
#   job-wrapper.sh <nama> [--only-if-missing] [--stale-on-fail] [--require-flag <nama>] -- <perintah...>
#
# Lingkungan (semua opsional):
#   JOB_STATE_DIR (/var/lib/titeny-jobs)  kunci, penanda, penghitung gagal
#   JOB_LOG_DIR   (/var/log/titeny-jobs)  jobs-YYYY-MM-DD.jsonl
#   JOB_FAIL_LIMIT (3)  gagal berturut-turut -> "pager": true
#   JOB_LOG_RETENTION_DAYS (35)  harus >= 30 (BR audit)
#   JOB_LOCK_TTL_MIN (120)  kunci lebih tua dari ini dianggap basi dan diambil alih
# Kode keluar: 0 sukses atau dilewati (sudah ada hasil / kunci dipegang / tanpa penanda); 1 job gagal; 2 salah pakai.
set -eu

state=${JOB_STATE_DIR:-/var/lib/titeny-jobs}
logdir=${JOB_LOG_DIR:-/var/log/titeny-jobs}
limit=${JOB_FAIL_LIMIT:-3}
retention=${JOB_LOG_RETENTION_DAYS:-35}
lockttl=${JOB_LOCK_TTL_MIN:-120}

if [ "$retention" -lt 30 ]; then
  echo "JOB_LOG_RETENTION_DAYS harus >= 30" >&2
  exit 2
fi

nama=${1:-}
[ -n "$nama" ] || { echo "pakai: job-wrapper.sh <nama> [opsi] -- <perintah...>" >&2; exit 2; }
shift
case "$nama" in
  *[!a-z0-9-]*) echo "nama job hanya a-z 0-9 -" >&2; exit 2 ;;
esac

only_missing=0
stale_on_fail=0
flag=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only-if-missing) only_missing=1; shift ;;
    --stale-on-fail) stale_on_fail=1; shift ;;
    --require-flag) flag=${2:?--require-flag butuh nama}; shift 2 ;;
    --) shift; break ;;
    *) echo "opsi tak dikenal: $1" >&2; exit 2 ;;
  esac
done
[ $# -gt 0 ] || { echo "perintah job kosong" >&2; exit 2; }

mkdir -p "$state" "$logdir"
export TZ=Asia/Jakarta
hari=$(date +%F)
waktu() { date +%Y-%m-%dT%H:%M:%S%z | sed 's/\(..\)$/:\1/'; }

# log <level> <status> <extra-json-tanpa-kurung>
log() {
  baris=$(printf '{"ts":"%s","job":"%s","level":"%s","status":"%s"%s}' "$(waktu)" "$nama" "$1" "$2" "${3:+,$3}")
  echo "$baris"
  echo "$baris" >> "$logdir/jobs-$hari.jsonl"
}

# Retensi log (tidak pernah di bawah 30 hari).
find "$logdir" -name 'jobs-*.jsonl' -type f -mtime +"$retention" -exec rm -f {} + 2>/dev/null || true

ok_marker="$state/$nama.$hari.ok"
count_file="$state/$nama.gagal"

if [ -n "$flag" ] && [ ! -f "$state/$flag.flag" ]; then
  log info dilewati '"alasan":"tanpa penanda"'
  exit 0
fi
if [ "$only_missing" -eq 1 ] && [ -f "$ok_marker" ]; then
  log info dilewati '"alasan":"hasil hari ini sudah ada"'
  exit 0
fi

# Kunci berkas: mkdir atomik; kunci basi diambil alih.
lock="$state/$nama.lock"
if ! mkdir "$lock" 2>/dev/null; then
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +"$lockttl" 2>/dev/null)" ]; then
    log warn kunci_basi_diambil '"alasan":"kunci lebih tua dari TTL"'
    rm -rf "$lock"
    mkdir "$lock"
  else
    log warn dilewati '"alasan":"job ganda dicegah kunci berkas"'
    exit 0
  fi
fi
trap 'rm -rf "$lock"' EXIT INT TERM
echo $$ > "$lock/pid"

log info mulai ""
set +e
"$@"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  : > "$ok_marker"
  rm -f "$count_file" "$state/$nama.$hari.stale"
  [ -n "$flag" ] && rm -f "$state/$flag.flag"
  log info sukses '"kode":0'
  exit 0
fi

gagal=0
[ -f "$count_file" ] && gagal=$(cat "$count_file")
gagal=$((gagal + 1))
echo "$gagal" > "$count_file"

ekstra=$(printf '"kode":%s,"gagal_berturut":%s' "$rc" "$gagal")
if [ "$stale_on_fail" -eq 1 ]; then
  : > "$state/$nama.$hari.stale"
  ekstra="$ekstra"',"label":"basi","catatan":"memakai prediksi H-1 berlabel basi"'
fi
if [ "$gagal" -ge "$limit" ]; then
  ekstra="$ekstra"',"pager":true'
fi
log error gagal "$ekstra"
exit 1
