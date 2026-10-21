#!/bin/sh
# shellcheck disable=SC2015,SC2329
# Uji nyata sql/source-readonly-role.sql dan sql/audit-privileges.sql pada Postgres sementara (initdb di folder temp).
# Dilewati (kode 0, pesan "lewati") bila initdb/pg_ctl/psql tidak ada. Tidak menyentuh DB mana pun selain instance sementara.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
for b in initdb pg_ctl psql; do
  command -v "$b" >/dev/null 2>&1 || { echo "lewati: $b tidak terpasang"; exit 0; }
done
t=$(mktemp -d)
port=$((55000 + $$ % 1000))
cleanup() { pg_ctl -D "$t/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$t"; }
trap cleanup EXIT
gagal=0
ok() { echo "lulus: $1"; }
no() { echo "GAGAL: $1"; gagal=1; }

initdb -D "$t/data" -U admin --auth=trust >/dev/null
pg_ctl -D "$t/data" -o "-p $port -k $t -c listen_addresses=''" -l "$t/pg.log" -w start >/dev/null
P="psql -h $t -p $port -U admin -v ON_ERROR_STOP=1 -X -q"

$P -d postgres -c "CREATE DATABASE db_sumber" >/dev/null
$P -d db_sumber -c "CREATE TABLE harga (id int primary key, nilai int); INSERT INTO harga VALUES (1, 100); CREATE VIEW v_harga AS SELECT * FROM harga" >/dev/null

$P -d db_sumber -v role=titeny_ro_s01 -v dbname=db_sumber -v schema=public -v pw=sandi-uji-palsu -f "$root/sql/source-readonly-role.sql" >/dev/null && ok "pembuatan role berjalan" || no "pembuatan role gagal"
$P -d db_sumber -v role=titeny_ro_s01 -v dbname=db_sumber -v schema=public -v pw=sandi-uji-palsu-2 -f "$root/sql/source-readonly-role.sql" >/dev/null && ok "idempoten (jalankan kedua kali)" || no "tidak idempoten"

# Perilaku nyata sebagai role baca-saja
R="psql -h $t -p $port -U titeny_ro_s01 -X -q -d db_sumber"
[ "$($R -tA -c 'SELECT nilai FROM harga')" = "100" ] && ok "SELECT berhasil" || no "SELECT gagal"
for sql in "INSERT INTO harga VALUES (2, 1)" "UPDATE harga SET nilai = 1" "DELETE FROM harga" "TRUNCATE harga" "CREATE TABLE z (a int)"; do
  if $R -c "$sql" >/dev/null 2>&1; then no "tulis lolos: $sql"; else ok "ditolak: $sql"; fi
done
if $R -c "BEGIN READ WRITE; INSERT INTO harga VALUES (3, 1); COMMIT" >/dev/null 2>&1; then no "READ WRITE lolos"; else ok "READ WRITE ditolak"; fi

# Audit hak: harus lulus
if $P -d db_sumber -v role=titeny_ro_s01 -v schema=public -f "$root/sql/audit-privileges.sql" >/dev/null 2>&1; then ok "audit-privileges lulus untuk role benar"; else no "audit-privileges gagal pada role benar"; fi

# Tabel baru setelah role dibuat: SELECT otomatis, tetap tanpa tulis
$P -d db_sumber -c "CREATE TABLE baru (a int); INSERT INTO baru VALUES (1)" >/dev/null
[ "$($R -tA -c 'SELECT a FROM baru')" = "1" ] && ok "tabel baru terbaca (default privileges)" || no "tabel baru tidak terbaca"

# Merah: beri INSERT -> audit harus gagal
$P -d db_sumber -c "GRANT INSERT ON harga TO titeny_ro_s01" >/dev/null
if $P -d db_sumber -v role=titeny_ro_s01 -v schema=public -f "$root/sql/audit-privileges.sql" >/dev/null 2>&1; then no "audit meloloskan hak INSERT"; else ok "audit menolak role dengan INSERT"; fi
$P -d db_sumber -c "REVOKE INSERT ON harga FROM titeny_ro_s01; ALTER ROLE titeny_ro_s01 CREATEDB" >/dev/null
if $P -d db_sumber -v role=titeny_ro_s01 -v schema=public -f "$root/sql/audit-privileges.sql" >/dev/null 2>&1; then no "audit meloloskan CREATEDB"; else ok "audit menolak atribut CREATEDB"; fi
exit $gagal
