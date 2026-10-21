#!/bin/sh
# Periksa secrets wajib Titeny per lingkungan sebelum deploy (TTN-OPS-004).
# Tidak mencetak isi secrets; hanya nama dan status.
# Pemakaian: setup-secrets.sh <dev|staging|prod> [--daftar]
#   --daftar : cetak nama secret wajib lalu keluar.
# Keluaran 0 = semua terisi (bukan placeholder) dan lolos audit-koneksi.sh; 1 = ada yang hilang/placeholder/langgar; 2 = salah pakai.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=secrets-lib.sh
. "$here/secrets-lib.sh"

env_nama=${1:-}
case "$env_nama" in
  dev|staging|prod) ;;
  *) echo "pakai: setup-secrets.sh <dev|staging|prod> [--daftar]" >&2; exit 2 ;;
esac
if [ "${2:-}" = "--daftar" ]; then
  for v in $NAMA_WAJIB $NAMA_SUMBER; do echo "$v"; done
  exit 0
fi

gagal=0
for v in $NAMA_WAJIB $NAMA_SUMBER; do
  isi=$(nilai_env "$v")
  if [ -z "$isi" ]; then
    echo "HILANG: $v"
    gagal=1
  else
    case "$isi" in
      *"$PLACEHOLDER"*|*GANTI_NAMA_DB_SUMBER*) echo "PLACEHOLDER: $v belum diisi"; gagal=1 ;;
      *) echo "OK: $v terisi" ;;
    esac
  fi
done

if ! sh "$here/audit-koneksi.sh" "$env_nama"; then
  gagal=1
fi
exit $gagal
