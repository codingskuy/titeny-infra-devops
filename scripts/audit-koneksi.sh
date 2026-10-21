#!/bin/sh
# Audit string koneksi (TTN-OPS-004; BR-004, US-006). Tidak mencetak string, hanya nama variabel.
# Aturan:
#   DATABASE_URL            -> nama DB tepat "titeny"
#   SRC_S{1..10}_DATABASE_URL -> role "titeny_ro_*" dan DB BUKAN "titeny"; wajib sslmode=require pada prod/staging
# Pemakaian: audit-koneksi.sh <dev|staging|prod>
# Keluaran 0 lulus; 1 pelanggaran; 2 salah pakai. Variabel yang kosong dilewati (diperiksa setup-secrets.sh).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=secrets-lib.sh
. "$here/secrets-lib.sh"

env_nama=${1:-}
case "$env_nama" in
  dev|staging|prod) ;;
  *) echo "pakai: audit-koneksi.sh <dev|staging|prod>" >&2; exit 2 ;;
esac

# user_dari <url> / db_dari <url>
user_dari() { echo "$1" | sed -E 's#^[a-z]+://([^:@/]+)[:@].*#\1#'; }
db_dari()   { echo "$1" | sed -E 's#^[a-z]+://[^/]+/([^?]*).*#\1#'; }

gagal=0
isi=$(nilai_env DATABASE_URL)
if [ -n "$isi" ]; then
  db=$(db_dari "$isi")
  if [ "$db" = "titeny" ]; then echo "OK: DATABASE_URL -> DB titeny"
  else echo "LANGGAR: DATABASE_URL tidak menunjuk DB titeny"; gagal=1; fi
fi

for v in $NAMA_SUMBER; do
  isi=$(nilai_env "$v")
  [ -n "$isi" ] || continue
  u=$(user_dari "$isi"); db=$(db_dari "$isi")
  case "$u" in
    titeny_ro_*) ;;
    *) echo "LANGGAR: $v memakai role non-read-only (harus titeny_ro_*)"; gagal=1 ;;
  esac
  if [ "$db" = "titeny" ]; then echo "LANGGAR: $v menunjuk DB titeny (sumber harus DB sumber)"; gagal=1; fi
  if [ "$env_nama" != "dev" ]; then
    case "$isi" in *sslmode=require*|*sslmode=verify-full*) ;; *) echo "LANGGAR: $v tanpa sslmode=require"; gagal=1 ;; esac
  fi
  [ "$gagal" -eq 0 ] && echo "OK: $v read-only ($u)"
done
exit $gagal
