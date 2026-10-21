-- Seed data dev lokal (BUKAN produksi). Idempoten; aman dijalankan berulang.
-- Dijalankan setelah backend mengerjakan migrasi (lihat dev-stack/seed.sh).
-- Variabel psql: jwt_secret (wajib, sama dengan JWT_SECRET backend; pepper PIN bawaan = 'pin:' || JWT_SECRET).
-- Akun dev: ceo-uji / analis-uji / layanan-uji, kata sandi dev "sandi-uji-lokal-1" (argon2id, hanya untuk lokal).
-- PIN zona dev: petani 482013, vendor 739204. Nilai sama dengan titeny-web contract/seed.py (PR #16/#17)
-- agar skrip Schemathesis web/app-kmp dapat dipakai terhadap stack ini tanpa perubahan.
\set ON_ERROR_STOP on

INSERT INTO pengguna (id, username, password_hash, peran) VALUES
  (gen_random_uuid(), 'ceo-uji',     '$argon2id$v=19$m=16384,t=2,p=1$dGl0ZW55ZGV2c2FsdDAx$gRG9uH3JNHxdib9AZV9rvbw79jVX63eC4DLd5+labG4', 'ceo'),
  (gen_random_uuid(), 'analis-uji',  '$argon2id$v=19$m=16384,t=2,p=1$dGl0ZW55ZGV2c2FsdDAx$gRG9uH3JNHxdib9AZV9rvbw79jVX63eC4DLd5+labG4', 'analis'),
  (gen_random_uuid(), 'layanan-uji', '$argon2id$v=19$m=16384,t=2,p=1$dGl0ZW55ZGV2c2FsdDAx$gRG9uH3JNHxdib9AZV9rvbw79jVX63eC4DLd5+labG4', 'layanan')
ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash, aktif = TRUE;

INSERT INTO zona_pin (id, zona, peran, pin_digest) VALUES
  (gen_random_uuid(), 'psr_jakarta_timur_01', 'petani',
   encode(sha256(convert_to('pin:' || :'jwt_secret', 'UTF8') || '\x00'::bytea || convert_to('482013', 'UTF8')), 'hex')),
  (gen_random_uuid(), 'psr_jakarta_timur_01', 'vendor',
   encode(sha256(convert_to('pin:' || :'jwt_secret', 'UTF8') || '\x00'::bytea || convert_to('739204', 'UTF8')), 'hex'))
ON CONFLICT (pin_digest) DO NOTHING;

INSERT INTO prediksi_harga
  SELECT 'cmd_cabai_merah', 'psr_jakarta_timur_01', (NOW() AT TIME ZONE 'Asia/Jakarta')::date + n,
         'H+' || GREATEST(n, 1), 42000 + n * 500, 39000, 46000, 'sedang', 'stok_gudang_72%',
         'harga_v1.0.0', NOW()
  FROM generate_series(0, 7) n
ON CONFLICT DO NOTHING;

INSERT INTO prediksi_panen VALUES
  ('cmd_cabai_merah', 'kab_brebes', to_char(NOW(), 'IYYY-"W"IW'), 12500, 11000, 14000, 'tinggi',
   'panen_v1.0.0', NOW())
ON CONFLICT DO NOTHING;

INSERT INTO prediksi_demand VALUES
  ('cmd_cabai_merah', 'psr_jakarta_timur_01', 'H+7_total_kg', (NOW() AT TIME ZONE 'Asia/Jakarta')::date,
   840.0, 700.0, 980.0, 'defisit', '["Amankan pasokan 800 kg"]'::jsonb, 'demand_v1.0.0', NOW())
ON CONFLICT DO NOTHING;

INSERT INTO rekomendasi (id, zona, teks) VALUES
  ('rek_uji_001', 'psr_jakarta_timur_01', '["Amankan pasokan 800 kg"]'::jsonb)
ON CONFLICT DO NOTHING;
