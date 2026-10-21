#!/bin/sh
# Pindai berkas terlacak git untuk rahasia yang ter-commit (TTN-OPS-004). Tidak mencetak isi, hanya path:baris.
# Pemakaian: scan-rahasia.sh [dir]   (default: direktori kerja). Keluaran 0 bersih; 1 ada temuan.
set -eu
dir=${1:-.}
cd "$dir"
if git rev-parse --git-dir >/dev/null 2>&1; then
  daftar=$(git ls-files)
else
  daftar=$(find . -type f -not -path './.git/*' | sed 's#^\./##')
fi

pola='-----BEGIN ([A-Z ]*)PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|postgres(ql)?://[^:@/ ]+:[^@ ]+@'
temuan=""
for f in $daftar; do
  [ -f "$f" ] || continue
  # fixture uji (nilai palsu sengaja) dikecualikan
  case "$f" in scripts/tests/fixtures/*) continue ;; esac
  baris=$(grep -nIE -e "$pola" "$f" 2>/dev/null | grep -vE 'GANTI_DARI_SECRET_MANAGER|titeny_ci_lokal|<[A-Za-z_]+>|\$[{A-Za-z_]' | cut -d: -f1 || true)
  for b in $baris; do temuan="$temuan$f:$b
"; done
done
# berkas rahasia yang dilacak
for f in $daftar; do
  case "$f" in
    *.env.example) ;;
    .env|*/.env|.env.*|*/.env.*|*.pem|*.key|*.p12) temuan="$temuan$f:(berkas rahasia dilacak)
" ;;
  esac
done
if [ -n "$temuan" ]; then
  echo "GAGAL: kemungkinan rahasia ter-commit:"
  printf '%s' "$temuan"
  exit 1
fi
echo "OK: tidak ada rahasia terlacak"
