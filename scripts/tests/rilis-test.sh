#!/bin/sh
# Uji verifikasi-rilis-desktop.sh dan rollback-desktop.sh (dengan gh palsu). Jalankan: sh scripts/tests/rilis-test.sh
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
s="$root/scripts"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
gagal=0
harap() { want=$1; desc=$2; shift 3; set +e; "$@" >"$t/out" 2>&1; got=$?; set -e
  if [ "$got" -eq "$want" ]; then echo "lulus: $desc"; else echo "GAGAL: $desc (kode $got, harap $want)"; gagal=1; fi; }
hash_ke() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi; }

# --- artefak sah palsu ---
a="$t/ok"; mkdir -p "$a"
printf 'msi-palsu' > "$a/Titeny-Analis-1.0.0.msi"
(cd "$a" && hash_ke Titeny-Analis-1.0.0.msi > SHA256SUMS.txt)
harap 0 "artefak sah lulus" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0.0 "$a"

harap 1 "versi tidak cocok nama berkas" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0.1 "$a"
harap 1 "versi bukan x.y.z" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0 "$a"
harap 2 "tanpa argumen" -- sh "$s/verifikasi-rilis-desktop.sh"

b="$t/rusak"; cp -R "$a" "$b"; printf 'diubah' >> "$b/Titeny-Analis-1.0.0.msi"
harap 1 "checksum tidak cocok" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0.0 "$b"

c="$t/tanpa-sum"; mkdir -p "$c"; cp "$a/Titeny-Analis-1.0.0.msi" "$c/"
harap 1 "tanpa SHA256SUMS.txt" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0.0 "$c"

d="$t/dua"; cp -R "$a" "$d"; cp "$a/Titeny-Analis-1.0.0.msi" "$d/Lain.msi"
harap 1 "dua MSI ditolak" -- sh "$s/verifikasi-rilis-desktop.sh" 1.0.0 "$d"

# --- rollback dengan gh palsu ---
bin="$t/bin"; mkdir -p "$bin"
cat > "$bin/gh" <<GH
#!/bin/sh
echo "\$@" >> "$t/gh.log"
case "\$1 \$2" in
  "release download")
    shift 2
    while [ \$# -gt 0 ]; do case "\$1" in -D) dest=\$2; shift 2 ;; *) shift ;; esac; done
    cp "$a/Titeny-Analis-1.0.0.msi" "$a/SHA256SUMS.txt" "\$dest/" ;;
  "release edit") : ;;
esac
GH
chmod +x "$bin/gh"
PATH="$bin:$PATH" harap 0 "rollback dry-run lulus" -- sh "$s/rollback-desktop.sh" analis-v1.0.0
if grep -q 'release edit' "$t/gh.log"; then echo "GAGAL: dry-run mengubah rilis"; gagal=1; else echo "lulus: dry-run tidak mengubah rilis"; fi
PATH="$bin:$PATH" harap 0 "rollback --terapkan lulus" -- sh "$s/rollback-desktop.sh" analis-v1.0.0 --terapkan
if grep -q 'release edit analis-v1.0.0 .* --latest' "$t/gh.log"; then echo "lulus: --terapkan menandai latest"; else echo "GAGAL: latest tidak ditandai"; gagal=1; fi
PATH="$bin:$PATH" harap 2 "tag tidak valid" -- sh "$s/rollback-desktop.sh" v1.0.0

exit $gagal
