#!/usr/bin/env bash
# Smoke dev-stack Titeny: healthcheck + login layanan dan analis (OTP dibaca dari log backend mode dev).
# Env:
#   BASE_URL     default http://127.0.0.1:8080
#   SERVER_LOG   berkas log backend (mode native). Kosong = baca dari `docker compose logs backend`.
#   COMPOSE_FILE default dev-stack/docker-compose.yml (untuk membaca log)
#   SANDI        default sandi-uji-lokal-1 (lihat seed.sql); PIN_PETANI default 482013
#   TUNGGU_DETIK default 60 (menunggu backend sehat)
# Keluar 0 bila semua pemeriksaan lulus; selain itu 1 dengan pesan GAGAL.
set -uo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
SANDI="${SANDI:-sandi-uji-lokal-1}"
TUNGGU_DETIK="${TUNGGU_DETIK:-60}"
dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_FILE="${COMPOSE_FILE:-$dir/docker-compose.yml}"
gagal=0

ok() { echo "OK    $*"; }
gg() { echo "GAGAL $*" >&2; gagal=1; }
cek() { # status-harapan status label
  if [ "$1" = "$2" ]; then ok "$3 -> $2"; else gg "$3 -> $2 (harapan $1)"; fi
}

json_ambil() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"; }

# status HTTP + badan ke berkas sementara
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
http() { # metode jalur [curl-opsi...] -> status di stdout, badan di $tmp
  local metode="$1" jalur="$2"; shift 2
  curl -s -o "$tmp" -w '%{http_code}' -X "$metode" "$BASE_URL$jalur" "$@"
}

log_backend() {
  if [ -n "${SERVER_LOG:-}" ]; then cat "$SERVER_LOG"; else docker compose -f "$COMPOSE_FILE" logs --no-color backend 2>/dev/null; fi
}

otp_terakhir() { # username
  log_backend | sed 's/\x1b\[[0-9;]*m//g' | grep "username=$1 " | grep -E 'otp=[0-9]{6}' | tail -1 | sed -E 's/.*otp=([0-9]{6}).*/\1/'
}

login_json() { printf '{"username":"%s","password":"%s"}' "$1" "$SANDI"; }

# 1. healthcheck (tunggu backend naik)
sehat=0
for _ in $(seq 1 "$TUNGGU_DETIK"); do
  s=$(http GET /api/v1/kesehatan) && [ "$s" = 200 ] && { sehat=1; break; }
  sleep 1
done
if [ "$sehat" = 1 ]; then ok "GET /api/v1/kesehatan -> 200"; else gg "backend tidak sehat dalam ${TUNGGU_DETIK}s (/api/v1/kesehatan)"; exit 1; fi
s=$(http GET /health); cek 200 "$s" "GET /health"

# 2. layanan: tanpa OTP, token langsung terbit
s=$(http POST /api/v1/auth/login -H 'content-type: application/json' -d "$(login_json layanan-uji)")
tok_layanan=$(json_ambil access_token < "$tmp")
if [ "$s" = 200 ] && [ -n "$tok_layanan" ]; then ok "login layanan-uji -> token (peran $(json_ambil peran < "$tmp"))"; else gg "login layanan-uji -> $s (seed sudah jalan?)"; fi

# least-privilege: token layanan ditolak di endpoint baca
if [ -n "$tok_layanan" ]; then
  s=$(http GET /api/v1/harga -H "Authorization: Bearer $tok_layanan")
  cek 403 "$s" "token layanan di GET /api/v1/harga (least-privilege)"
fi

# 3. analis: login -> sesi_id -> OTP dari log -> token
s=$(http POST /api/v1/auth/login -H 'content-type: application/json' -d "$(login_json analis-uji)")
sesi=$(json_ambil sesi_id < "$tmp")
if [ "$s" = 200 ] && [ -n "$sesi" ]; then
  ok "login analis-uji -> tantangan OTP"
  otp=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do otp=$(otp_terakhir analis-uji); [ -n "$otp" ] && break; sleep 0.5; done
  if [ -z "$otp" ]; then
    gg "OTP analis-uji tidak ditemukan di log backend (OTP_LOG_DEV=true? SERVER_LOG?)"
  else
    s=$(http POST /api/v1/auth/otp/verifikasi -H 'content-type: application/json' -d "{\"sesi_id\":\"$sesi\",\"otp\":\"$otp\"}")
    tok_analis=$(json_ambil access_token < "$tmp")
    if [ "$s" = 200 ] && [ -n "$tok_analis" ]; then
      ok "verifikasi OTP analis-uji -> token (peran $(json_ambil peran < "$tmp"))"
      s=$(http GET /api/v1/analis/antrean -H "Authorization: Bearer $tok_analis")
      cek 200 "$s" "GET /api/v1/analis/antrean (analis)"
    else
      gg "verifikasi OTP analis-uji -> $s"
    fi
  fi
else
  gg "login analis-uji -> $s (seed sudah jalan?)"
fi

# 4. papan PIN zona (petani): PIN dev dari seed diterima, PIN asing ditolak
s=$(http GET "/api/v1/harga?komoditas_id=cmd_cabai_merah" -H "X-Zona-PIN: ${PIN_PETANI:-482013}")
cek 200 "$s" "GET /api/v1/harga dengan PIN zona petani (seed)"
s=$(http GET "/api/v1/harga?komoditas_id=cmd_cabai_merah" -H "X-Zona-PIN: 111111")
cek 401 "$s" "GET /api/v1/harga dengan PIN asing"

# 5. kredensial salah ditolak
s=$(http POST /api/v1/auth/login -H 'content-type: application/json' -d "$(printf '{"username":"analis-uji","password":"salah"}')")
cek 401 "$s" "login kata sandi salah"

if [ "$gagal" = 0 ]; then echo "SMOKE LULUS"; else echo "SMOKE GAGAL" >&2; fi
exit "$gagal"
