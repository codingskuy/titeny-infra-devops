#!/bin/sh
# Rollback rilis desktop analis ke rilis sebelumnya (TTN-OPS-005). Default DRY-RUN.
# Pemakaian: rollback-desktop.sh <tag-tujuan, mis. analis-v1.0.0> [--terapkan]
# Langkah: unduh MSI + SHA256SUMS.txt rilis tujuan dari repo ini, verifikasi checksum + nama,
# lalu (hanya dengan --terapkan) tandai rilis tujuan sebagai "latest". Rilis tidak pernah dihapus.
# Memerlukan gh terautentikasi dengan hak tulis rilis untuk --terapkan.
set -eu
tag=${1:-}
mode=${2:-}
[ -n "$tag" ] || { echo "pakai: rollback-desktop.sh <tag> [--terapkan]" >&2; exit 2; }
case "$tag" in analis-v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "tag harus analis-vX.Y.Z" >&2; exit 2 ;; esac
repo=${REPO_RILIS:-Coding-Skuy/titeny-infra-devops}
versi=${tag#analis-v}
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Rilis tujuan: $repo $tag"
gh release download "$tag" -R "$repo" -D "$tmp" -p "Titeny-Analis-$versi.msi" -p SHA256SUMS.txt
sh "$here/verifikasi-rilis-desktop.sh" "$versi" "$tmp"

if [ "$mode" = "--terapkan" ]; then
  gh release edit "$tag" -R "$repo" --latest
  echo "TERAPKAN: $tag ditandai latest. Umumkan ke analis: uninstall versi baru lalu pasang Titeny-Analis-$versi.msi."
else
  echo "DRY-RUN: tidak ada perubahan. Tambahkan --terapkan untuk menandai $tag sebagai latest."
fi
