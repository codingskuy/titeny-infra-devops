-- Role baca-saja untuk satu DB sumber (TTN-OPS-004; BR-004, US-006). Dijalankan OLEH PEMILIK DB sumber
-- (bukan oleh repo ini secara otomatis), per sumber S1-S10:
--   psql "$URL_ADMIN_SUMBER" -v ON_ERROR_STOP=1 -v role=titeny_ro_s01 -v dbname=NAMA_DB_SUMBER -v schema=public \
--        -v pw="$PASSWORD_BARU" -f sql/source-readonly-role.sql
-- Password dikirim lewat variabel psql (tidak di berkas, tidak di riwayat git). Idempoten.
-- AWAS: ALTER ROLE ... PASSWORD tercatat di log server bila log_statement=ddl|mod|all. Di server berlog,
-- jalankan sebagai superuser dengan `SET log_statement = 'none'` di sesi yang sama sebelum berkas ini, atau
-- setel sandi lewat `\password <role>` (enkripsi sisi-klien) lalu jalankan berkas ini tanpa langkah sandi.
-- Rotasi: jalankan lagi dengan pw baru (ALTER ROLE), atau pola dua-slot di docs/secrets.md.

SELECT format('CREATE ROLE %I LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 5', :'role')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role')
\gexec

-- Sandi baru + kedaluwarsa 100 hari (rotasi 90 hari + tenggang 10 hari)
SELECT format('ALTER ROLE %I PASSWORD %L VALID UNTIL %L', :'role', :'pw', (now() + interval '100 days')::text)
\gexec

-- Paksa transaksi baca-saja pada level role dan batasi waktu
SELECT format('ALTER ROLE %I SET default_transaction_read_only = on', :'role') \gexec
SELECT format('ALTER ROLE %I SET statement_timeout = %L', :'role', '60s') \gexec

-- Cabut semua hak yang mungkin diwarisi lalu beri SELECT saja
SELECT format('REVOKE ALL ON DATABASE %I FROM %I', :'dbname', :'role') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'dbname', :'role') \gexec
SELECT format('REVOKE ALL ON SCHEMA %I FROM %I', :'schema', :'role') \gexec
SELECT format('GRANT USAGE ON SCHEMA %I TO %I', :'schema', :'role') \gexec
SELECT format('REVOKE ALL ON ALL TABLES IN SCHEMA %I FROM %I', :'schema', :'role') \gexec
SELECT format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA %I FROM %I', :'schema', :'role') \gexec
SELECT format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I', :'schema', :'role') \gexec
-- Tabel baru di masa depan: SELECT otomatis (untuk objek yang dibuat oleh role pemilik yang menjalankan skrip ini)
SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO %I', :'schema', :'role') \gexec
