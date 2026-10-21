#!/bin/sh
# Audit log pernyataan Postgres: bukti nol INSERT/UPDATE/DELETE dari role Titeny di luar DB `titeny` (TTN-OPS-004; M-007).
# Pemakaian: audit-log-tulis.sh [--hari 30] [--hari-ini YYYY-MM-DD] <berkas-log>...
# Prasyarat log server: log_statement='mod' dan log_line_prefix='%m [%p] %u@%d ' (user@db terbaca per baris).
# Pelanggaran:
#   (a) role titeny_ro_* menjalankan pernyataan tulis/DDL apa pun,
#   (b) role titeny_* menjalankan pernyataan tulis/DDL pada DB selain `titeny`.
# Cakupan: tanggal log tertua harus <= hari-ini - (hari-1); bila tidak, keluaran 3 (bukti tidak cukup).
# Keluaran 0 bersih+cakupan cukup; 1 pelanggaran; 2 salah pakai; 3 cakupan kurang. Tidak mencetak isi pernyataan.
set -eu

hari=30
hari_ini=""
while [ $# -gt 0 ]; do
  case "$1" in
    --hari) hari=${2:?}; shift 2 ;;
    --hari-ini) hari_ini=${2:?}; shift 2 ;;
    --) shift; break ;;
    -*) echo "opsi tak dikenal: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { echo "pakai: audit-log-tulis.sh [--hari N] [--hari-ini YYYY-MM-DD] <log>..." >&2; exit 2; }

[ -n "$hari_ini" ] || hari_ini=$(TZ=Asia/Jakarta date +%F)
mundur=$((hari - 1))
batas=$(date -j -v-"${mundur}"d -f %F "$hari_ini" +%F 2>/dev/null || date -d "$hari_ini - $mundur days" +%F)

awk -v batas="$batas" '
  function tulis(s) { return s ~ /^(INSERT|UPDATE|DELETE|TRUNCATE|MERGE|COPY|CREATE|ALTER|DROP|GRANT|REVOKE)([ \t]|$)/ }
  {
    if (match($1, /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)) {
      if (min == "" || $1 < min) min = $1
    } else { next }
    user = ""; db = ""
    for (i = 2; i <= NF && i <= 6; i++) {
      if ($i ~ /^[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+$/) { split($i, ud, "@"); user = ud[1]; db = ud[2]; break }
    }
    if (user !~ /^titeny_/) next
    idx = index($0, "statement: ")
    if (idx == 0) { idx = index($0, "execute "); if (idx == 0) next; s = substr($0, idx); sub(/^execute [^:]*: /, "", s) }
    else s = substr($0, idx + 11)
    s = toupper(substr(s, 1, 12))
    if (!tulis(s)) next
    if (user ~ /^titeny_ro_/) { n++; printf "PELANGGARAN: %s %s role read-only menjalankan pernyataan tulis (%s)\n", FILENAME ":" FNR, $1, user; next }
    if (db != "titeny") { n++; printf "PELANGGARAN: %s %s role %s menulis ke DB %s\n", FILENAME ":" FNR, $1, user, db }
  }
  END {
    if (min == "") { print "CAKUPAN: tidak ada baris log berstempel tanggal"; exit 3 }
    print "CAKUPAN: log tertua " min ", batas " batas
    if (n > 0) { printf "GAGAL: %d pelanggaran\n", n; exit 1 }
    if (min > batas) { print "KURANG: cakupan log kurang dari jendela audit"; exit 3 }
    print "OK: nol tulis di luar DB titeny pada jendela audit"
  }' "$@"
