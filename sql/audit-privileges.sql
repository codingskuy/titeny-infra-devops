-- Bukti least-privilege: GAGAL (exit psql != 0 dengan ON_ERROR_STOP) bila role titeny_ro_* punya hak tulis.
-- Jalankan di tiap DB sumber:
--   psql "$URL_ADMIN_SUMBER" -v ON_ERROR_STOP=1 -v role=titeny_ro_s01 -v schema=public -f sql/audit-privileges.sql
-- Keluaran: baris pelanggaran (kosong = lulus) lalu pernyataan akhir.

\echo === pelanggaran hak tulis tabel ===
SELECT c.relname AS tabel, p.priv
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = :'schema'
CROSS JOIN (VALUES ('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) AS p(priv)
WHERE c.relkind IN ('r','p','v','m','f')
  AND has_table_privilege(:'role', c.oid, p.priv)
ORDER BY 1, 2;

\echo === pelanggaran atribut role ===
SELECT rolname FROM pg_roles
WHERE rolname = :'role' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls);

\echo === pelanggaran CREATE pada schema/DB ===
SELECT 'schema:' || :'schema' AS objek WHERE has_schema_privilege(:'role', :'schema', 'CREATE')
UNION ALL
SELECT 'db:' || current_database() WHERE has_database_privilege(:'role', current_database(), 'CREATE');

-- Gagalkan skrip bila ada pelanggaran apa pun (membuat pembagian nol terkontrol).
SELECT 1 / (CASE WHEN
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = :'schema'
    CROSS JOIN (VALUES ('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) AS p(priv)
    WHERE c.relkind IN ('r','p','v','m','f') AND has_table_privilege(:'role', c.oid, p.priv))
  + (SELECT count(*) FROM pg_roles WHERE rolname = :'role' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls))
  + (CASE WHEN has_schema_privilege(:'role', :'schema', 'CREATE') OR has_database_privilege(:'role', current_database(), 'CREATE') THEN 1 ELSE 0 END)
  = 0 THEN 1 ELSE 0 END) AS lulus_read_only;
