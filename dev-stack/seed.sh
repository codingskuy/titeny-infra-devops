#!/bin/sh
# Menunggu migrasi backend selesai, lalu memasang seed dev (dev-stack/seed.sql).
# Env: PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE (psql), JWT_SECRET (wajib), SEED_SQL (default seed.sql di samping skrip),
#      SEED_TUNGGU_DETIK (default 120), MIGRASI_MIN (jumlah migrasi minimal, default 5 = 001..005 di TTN-BE-005).
set -eu

: "${JWT_SECRET:?isi JWT_SECRET (sama dengan backend)}"
dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
sql="${SEED_SQL:-$dir/seed.sql}"
tunggu="${SEED_TUNGGU_DETIK:-120}"
min="${MIGRASI_MIN:-5}"

i=0
while :; do
  n=$(psql -tAqc "SELECT count(*) FROM _sqlx_migrations WHERE success" 2>/dev/null || echo 0)
  [ "${n:-0}" -ge "$min" ] && break
  i=$((i + 1))
  [ "$i" -gt "$tunggu" ] && { echo "seed: migrasi backend belum selesai setelah ${tunggu}s (ada ${n:-0}, butuh ${min})" >&2; exit 1; }
  sleep 1
done

psql -v ON_ERROR_STOP=1 -v "jwt_secret=$JWT_SECRET" -qf "$sql"
echo "seed selesai: ceo-uji, analis-uji, layanan-uji (sandi dev), PIN zona petani/vendor"
