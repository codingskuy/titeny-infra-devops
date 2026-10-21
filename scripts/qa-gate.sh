#!/bin/sh
# Gerbang QA-002: build gagal bila ada test yang dilewati; gerbang fixture event.
# Pemakaian:
#   qa-gate.sh <dir> rust|web|python|kotlin
#   qa-gate.sh <dir> fixtures <subdir> <jumlah>
# Keluaran: 0 lulus, 1 gagal. Tidak mencetak isi rahasia (hanya path:baris).
set -eu

dir=${1:?pakai: qa-gate.sh <dir> <rust|web|python|kotlin|fixtures> ...}
mode=${2:?mode wajib}

case "$mode" in
  fixtures)
    sub=${3:?subdir fixture wajib}
    want=${4:?jumlah fixture wajib}
    n=0
    if [ -d "$dir/$sub" ]; then
      n=$(find "$dir/$sub" -type f -name '*.json' | wc -l | tr -d ' ')
    fi
    if [ "$n" -ne "$want" ]; then
      echo "GAGAL: fixture event di $sub = $n, diharapkan $want"
      exit 1
    fi
    echo "OK: $n fixture event di $sub"
    exit 0
    ;;
  rust)   pola='#\[ignore|#\[should_panic\(ignore' ; glob='*.rs' ;;
  web)    pola='(^|[^A-Za-z_])(test|it|describe)\.(skip|todo)\(|(^|[^A-Za-z_])x(it|describe|test)\(' ; glob='*.ts *.js *.svelte' ;;
  python) pola='pytest\.mark\.(skip|xfail)|pytest\.(skip|xfail)\(|@unittest\.skip' ; glob='*.py' ;;
  kotlin) pola='@Ignore|@Disabled' ; glob='*.kt *.kts' ;;
  *) echo "mode tidak dikenal: $mode"; exit 2 ;;
esac

hasil=$(
  for g in $glob; do
    find "$dir" \( -path '*/node_modules' -o -path '*/target' -o -path '*/build' -o -path '*/.git' -o -path '*/.infra' -o -path '*/.venv' \) -prune \
      -o -type f -name "$g" -print
  done | while IFS= read -r f; do
    case "$f" in
      (*[Tt]est*|*spec*) grep -nE "$pola" "$f" 2>/dev/null | sed "s|^|$f:|" || true ;;
    esac
  done
)

if [ -n "$hasil" ]; then
  echo "GAGAL QA-002: test dilewati ditemukan:"
  echo "$hasil"
  exit 1
fi
echo "OK: tidak ada test yang dilewati ($mode)"
