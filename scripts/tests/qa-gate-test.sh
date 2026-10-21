#!/bin/sh
# Uji merah-hijau untuk scripts/qa-gate.sh. Jalankan: sh scripts/tests/qa-gate-test.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
gate="$here/qa-gate.sh"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
gagal=0

harap() { # harap <kode> <deskripsi> -- perintah...
  want=$1; desc=$2; shift 3
  set +e; "$@" >/dev/null 2>&1; got=$?; set -e
  if [ "$got" -eq "$want" ]; then echo "lulus: $desc"; else echo "GAGAL: $desc (kode $got, harap $want)"; gagal=1; fi
}

mkdir -p "$t/r/tests" "$t/w/src" "$t/p/tests" "$t/k/src/test" "$t/f/tests/fixtures/events"
printf '#[test]\n#[ignore]\nfn a() {}\n' > "$t/r/tests/a.rs"
printf 'test.skip("x", () => {})\n' > "$t/w/src/a.test.ts"
printf 'import pytest\n@pytest.mark.skip\ndef test_a(): pass\n' > "$t/p/tests/test_a.py"
printf '@Ignore\nclass ATest\n' > "$t/k/src/test/ATest.kt"
harap 1 "rust: #[ignore] ditolak"        -- sh "$gate" "$t/r" rust
harap 1 "web: test.skip ditolak"         -- sh "$gate" "$t/w" web
harap 1 "python: mark.skip ditolak"      -- sh "$gate" "$t/p" python
harap 1 "kotlin: @Ignore ditolak"        -- sh "$gate" "$t/k" kotlin

printf '#[test]\nfn a() {}\n' > "$t/r/tests/a.rs"
printf 'test("x", () => {})\n' > "$t/w/src/a.test.ts"
printf 'def test_a(): pass\n' > "$t/p/tests/test_a.py"
printf 'class ATest\n' > "$t/k/src/test/ATest.kt"
harap 0 "rust bersih lulus"   -- sh "$gate" "$t/r" rust
harap 0 "web bersih lulus"    -- sh "$gate" "$t/w" web
harap 0 "python bersih lulus" -- sh "$gate" "$t/p" python
harap 0 "kotlin bersih lulus" -- sh "$gate" "$t/k" kotlin

harap 1 "fixture 0 dari 11 ditolak" -- sh "$gate" "$t/f" fixtures tests/fixtures/events 11
i=1; while [ $i -le 11 ]; do echo '{}' > "$t/f/tests/fixtures/events/e$i.json"; i=$((i+1)); done
harap 0 "fixture 11 lulus" -- sh "$gate" "$t/f" fixtures tests/fixtures/events 11
harap 2 "mode tak dikenal" -- sh "$gate" "$t/f" ngawur

exit $gagal
