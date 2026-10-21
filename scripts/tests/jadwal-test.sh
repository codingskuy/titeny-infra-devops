#!/bin/sh
# Uji jadwal terkunci v1.0.0 pada k8s/cronjob-insight.yaml. Jalankan: sh scripts/tests/jadwal-test.sh
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
m="$root/k8s/cronjob-insight.yaml"
gagal=0
ok() { echo "lulus: $1"; }
no() { echo "GAGAL: $1"; gagal=1; }

# 1. berkas terkomit sama dengan keluaran generator (tidak ada drift)
if sh "$root/scripts/gen-cronjobs.sh" | diff -q - "$m" >/dev/null; then ok "manifest sinkron dengan generator"; else no "manifest berbeda dari generator"; fi

# 2. jadwal terkunci (WIB): harga 04.00, retry 04.30/05.00, koreksi 15.00, demand 04.30, panen Senin 03.00, MAPE Minggu 23.00
cek() { # cek <nama> <cron>
  if awk -v n="$1" -v c="$2" '
      $1=="name:" && $2==n {hit=1; next}
      hit && $1=="schedule:" {gsub(/"/,"",$0); sub(/^ *schedule: */,"",$0); print; exit}' "$m" | grep -Fqx "$2"; then ok "$1 = $2"; else no "$1 bukan $2"; fi
}
cek harga-0400 "0 4 * * *"
cek harga-retry-0430 "30 4 * * *"
cek harga-retry-0500 "0 5 * * *"
cek harga-koreksi-1500 "0 15 * * *"
cek demand-0430 "30 4 * * *"
cek panen-senin-0300 "0 3 * * 1"
cek mape-minggu-2300 "0 23 * * 0"

# 3. semua CronJob memakai timeZone WIB dan melarang paralel
n=$(grep -c '^kind: CronJob' "$m")
if [ "$(grep -c 'timeZone: Asia/Jakarta' "$m")" -eq "$n" ]; then ok "timeZone Asia/Jakarta di $n CronJob"; else no "timeZone tidak di semua CronJob"; fi
if [ "$(grep -c 'concurrencyPolicy: Forbid' "$m")" -eq "$n" ]; then ok "concurrencyPolicy Forbid di semua"; else no "concurrencyPolicy"; fi

# 4. jadwal lama (UTC, event tak terdaftar) sudah hilang
if grep -qE 'schedule: "(0 1 \* \* \*|15 \* \* \* \*)"|lumbung\.harga\.perbarui' "$m"; then no "jadwal lama masih ada"; else ok "jadwal lama dihapus"; fi

# 5. tidak ada rahasia terkomit: hanya secretKeyRef
if grep -qiE 'postgres(ql)?://|password:|BEGIN (PRIVATE|OPENSSH)' "$m"; then no "ada pola rahasia"; else ok "tanpa pola rahasia"; fi

# 6. validasi skema k8s bila kubeconform ada
if command -v kubeconform >/dev/null 2>&1; then
  if kubeconform -strict "$m" >/dev/null 2>&1; then ok "kubeconform strict"; else no "kubeconform gagal"; fi
else
  echo "lewati: kubeconform tidak terpasang"
fi
exit $gagal
