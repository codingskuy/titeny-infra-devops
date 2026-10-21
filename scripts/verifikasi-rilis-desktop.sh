#!/bin/sh
# Verifikasi artefak rilis desktop analis (TTN-OPS-005).
# Pemakaian: verifikasi-rilis-desktop.sh <versi x.y.z> <dir-artefak>
# Cek: versi valid; tepat satu berkas Titeny-Analis-<versi>.msi; SHA256SUMS.txt memuat entri MSI itu dan cocok;
#      bila `msiinfo` ada: arsitektur x64. Keluaran 0 lulus; 1 gagal; 2 salah pakai.
set -eu
versi=${1:-}
dir=${2:-}
[ -n "$versi" ] && [ -d "$dir" ] || { echo "pakai: verifikasi-rilis-desktop.sh <x.y.z> <dir>" >&2; exit 2; }
case "$versi" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "GAGAL: versi harus x.y.z"; exit 1 ;;
esac
if [ "$(echo "$versi" | tr -cd '.' | wc -c | tr -d ' ')" -ne 2 ]; then echo "GAGAL: versi harus x.y.z"; exit 1; fi

msi="Titeny-Analis-$versi.msi"
n=$(find "$dir" -maxdepth 1 -name '*.msi' -type f | wc -l | tr -d ' ')
[ "$n" -eq 1 ] || { echo "GAGAL: harus tepat satu MSI di $dir (ada $n)"; exit 1; }
[ -f "$dir/$msi" ] || { echo "GAGAL: $msi tidak ada"; exit 1; }
[ -f "$dir/SHA256SUMS.txt" ] || { echo "GAGAL: SHA256SUMS.txt tidak ada"; exit 1; }
if [ "$(wc -l < "$dir/SHA256SUMS.txt" | tr -d ' ')" -ne 1 ] || ! grep -q "  $msi\$" "$dir/SHA256SUMS.txt"; then
  echo "GAGAL: SHA256SUMS.txt harus berisi tepat satu entri untuk $msi"; exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$dir" && sha256sum -c SHA256SUMS.txt >/dev/null) || { echo "GAGAL: checksum tidak cocok"; exit 1; }
else
  (cd "$dir" && shasum -a 256 -c SHA256SUMS.txt >/dev/null) || { echo "GAGAL: checksum tidak cocok"; exit 1; }
fi
echo "OK: $msi + checksum cocok"
if command -v msiinfo >/dev/null 2>&1; then
  if msiinfo suminfo "$dir/$msi" 2>/dev/null | grep -qi 'Template:.*x64'; then echo "OK: MSI 64-bit (x64)"
  else echo "GAGAL: MSI bukan x64"; exit 1; fi
else
  echo "lewati: msiinfo tidak ada, arsitektur tidak diperiksa"
fi
