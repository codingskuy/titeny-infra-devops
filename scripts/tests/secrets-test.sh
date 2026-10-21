#!/bin/sh
# Uji setup-secrets.sh, audit-koneksi.sh, scan-rahasia.sh, audit-log-tulis.sh. Jalankan: sh scripts/tests/secrets-test.sh
# Semua nilai di sini PALSU dan hanya hidup di memori proses uji.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
s="$root/scripts"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
gagal=0
harap() { want=$1; desc=$2; shift 3; set +e; "$@" >"$t/out" 2>&1; got=$?; set -e
  if [ "$got" -eq "$want" ]; then echo "lulus: $desc"; else echo "GAGAL: $desc (kode $got, harap $want)"; gagal=1; fi; }
tak_cetak() { # tak_cetak <desc> <teks-rahasia>  : keluaran terakhir tidak boleh memuat teks itu
  if grep -qF -- "$2" "$t/out"; then echo "GAGAL: $1 (bocor)"; gagal=1; else echo "lulus: $1"; fi; }

# --- lingkungan sehat (palsu) ---
sehat() {
  export DATABASE_URL='postgres://titeny_app:RAHASIA_PALSU_123@db.internal:5432/titeny'
  export JWT_ED25519_PRIVATE=kunci-privat-palsu JWT_ED25519_PUBLIC=kunci-publik-palsu TITENY_API_TOKEN=tok-palsu GHCR_TOKEN=ghcr-palsu
  i=1; while [ $i -le 10 ]; do
    n=$(printf '%02d' $i)
    export "SRC_S${i}_DATABASE_URL=postgres://titeny_ro_s$n:RAHASIA_PALSU_123@sumber$n.internal:5432/db_sumber?sslmode=require"
    i=$((i+1))
  done
}
bersih() { for v in $(sh "$s/setup-secrets.sh" prod --daftar); do unset "$v"; done; }

bersih; sehat
harap 0 "setup-secrets prod sehat lulus" -- sh "$s/setup-secrets.sh" prod
tak_cetak "nilai rahasia tidak dicetak" "RAHASIA_PALSU_123"

bersih
harap 1 "setup-secrets tanpa isi gagal" -- sh "$s/setup-secrets.sh" staging
harap 2 "lingkungan tidak valid -> 2" -- sh "$s/setup-secrets.sh" ngawur

sehat; export TITENY_API_TOKEN=GANTI_DARI_SECRET_MANAGER
harap 1 "placeholder ditolak" -- sh "$s/setup-secrets.sh" prod

# audit-koneksi: role tulis pada sumber -> LANGGAR
sehat; export SRC_S3_DATABASE_URL='postgres://titeny_app:x@sumber03.internal:5432/db_sumber?sslmode=require'
harap 1 "role non-read-only di sumber ditolak" -- sh "$s/audit-koneksi.sh" prod
if grep -q 'SRC_S3_DATABASE_URL memakai role non-read-only' "$t/out"; then echo "lulus: pesan menyebut S3"; else echo "GAGAL: pesan S3"; gagal=1; fi

# sumber menunjuk DB titeny -> LANGGAR
sehat; export SRC_S4_DATABASE_URL='postgres://titeny_ro_s04:x@sumber04.internal:5432/titeny?sslmode=require'
harap 1 "sumber menunjuk DB titeny ditolak" -- sh "$s/audit-koneksi.sh" prod

# DATABASE_URL bukan titeny -> LANGGAR
sehat; export DATABASE_URL='postgres://titeny_app:x@db.internal:5432/lumbung'
harap 1 "DATABASE_URL ke DB lain ditolak" -- sh "$s/audit-koneksi.sh" prod

# tanpa sslmode di prod ditolak, di dev boleh
sehat; export SRC_S1_DATABASE_URL='postgres://titeny_ro_s01:x@sumber01.internal:5432/db_sumber'
harap 1 "prod tanpa sslmode ditolak" -- sh "$s/audit-koneksi.sh" prod
harap 0 "dev tanpa sslmode boleh" -- sh "$s/audit-koneksi.sh" dev
bersih

# --- scan-rahasia ---
g="$t/repo"; mkdir -p "$g"; (cd "$g" && git init -q && git config user.email t@t && git config user.name t)
printf 'DATABASE_URL=postgres://u:GANTI_DARI_SECRET_MANAGER@h:5432/titeny\n' > "$g/a.env.example"
(cd "$g" && git add -A && git commit -qm x)
harap 0 "scan: templat placeholder bersih" -- sh "$s/scan-rahasia.sh" "$g"
printf 'url=postgres://admin:SuperRahasia9@db:5432/x\n' > "$g/c.txt"
(cd "$g" && git add -A && git commit -qm y)
harap 1 "scan: string koneksi dengan sandi terdeteksi" -- sh "$s/scan-rahasia.sh" "$g"
tak_cetak "scan tidak mencetak sandi" "SuperRahasia9"
(cd "$g" && git rm -q c.txt && printf -- '-----BEGIN %s KEY-----\n' 'OPENSSH PRIVATE' > k.txt && git add -A && git commit -qm z)
harap 1 "scan: kunci privat terdeteksi" -- sh "$s/scan-rahasia.sh" "$g"
(cd "$g" && git rm -q k.txt && : > .env && git add -f .env && git commit -qm w)
harap 1 "scan: .env terlacak terdeteksi" -- sh "$s/scan-rahasia.sh" "$g"
harap 0 "scan: repo ini sendiri bersih" -- sh "$s/scan-rahasia.sh" "$root"

# --- audit-log-tulis ---
log="$t/pg.log"
{
  echo '2026-09-01 04:00:01.100 WIB [11] titeny_app@titeny LOG:  statement: INSERT INTO prediksi VALUES (1)'
  echo '2026-09-15 04:00:02.100 WIB [12] titeny_ro_s01@db_sumber LOG:  statement: SELECT 1'
  echo '2026-09-20 04:00:03.100 WIB [13] lumbung_app@db_sumber LOG:  statement: INSERT INTO x VALUES (1)'
  echo '2026-09-30 04:00:04.100 WIB [14] titeny_app@titeny LOG:  statement: UPDATE prediksi SET a=1'
} > "$log"
harap 0 "audit log bersih + cakupan 30 hari" -- sh "$s/audit-log-tulis.sh" --hari-ini 2026-09-30 "$log"
harap 3 "cakupan kurang (log mulai 09-01, jendela 30 hari butuh log lebih tua)" -- sh "$s/audit-log-tulis.sh" --hari-ini 2026-09-10 "$log"
echo '2026-09-25 04:00:05.100 WIB [15] titeny_ro_s02@db_sumber LOG:  statement: DELETE FROM x' >> "$log"
harap 1 "role read-only menulis -> pelanggaran" -- sh "$s/audit-log-tulis.sh" --hari-ini 2026-09-30 "$log"
tak_cetak "audit log tidak mencetak pernyataan" "DELETE FROM x"
sed -i.bak '$d' "$log"
echo '2026-09-26 04:00:06.100 WIB [16] titeny_app@db_sumber LOG:  statement: UPDATE x SET a=1' >> "$log"
harap 1 "role titeny_* menulis di DB sumber -> pelanggaran" -- sh "$s/audit-log-tulis.sh" --hari-ini 2026-09-30 "$log"
harap 2 "tanpa berkas -> 2" -- sh "$s/audit-log-tulis.sh"

exit $gagal
