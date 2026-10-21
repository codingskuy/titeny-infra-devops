# CI 4 repo kode + QA gate (TTN-OPS-002)

Rujukan: QA-001..QA-004 (`SRS/40-acceptance-criteria.md`), "Stack pengikat" (`FSD/30-kontrak.md`), KONTEKS §7.

## Peta workflow

| Repo kode | Workflow reusable | Langkah inti | Runner |
|---|---|---|---|
| titeny-backend-service | `ci-backend.yml` | gerbang skip, `cargo test --locked --all-targets` dengan Postgres 16 (untuk `#[sqlx::test]` idempotensi) | ubuntu-24.04 |
| titeny-web | `ci-web.yml` | gerbang skip, `bun install --frozen-lockfile`, `bun run check`, `bun test` | ubuntu-24.04 |
| titeny-ai-models, titeny-data-pipeline | `ci-model.yml` | gerbang skip, gerbang 11 fixture event, `pytest` (Python 3.12.7) | ubuntu-24.04 |
| titeny-app-kmp | `ci-desktop.yml` | gerbang skip, `./gradlew test`, `:analis-desktop:packageMsi`, `SHA256SUMS.txt`, unggah artefak | windows-2022 (WiX 3.14) |

`ci-semua.yml` (manual + 03.00 WIB) menjalankan kelimanya terhadap `main` masing-masing repo. Templat pemanggil per-PR ada di `ci-templates/`; salin ke `.github/workflows/ci.yml` repo kode (PR terpisah di repo itu, bukan di sini).

## QA gate (`scripts/qa-gate.sh`)

- QA-002: gagal bila ada `#[ignore]` (Rust), `test.skip/it.skip/xit/...` (web), `pytest.mark.skip/xfail` (Python), `@Ignore/@Disabled` (Kotlin) di berkas uji.
- Gerbang fixture: tepat 11 berkas `*.json` di `tests/fixtures/events/`. **Asumsi**: lokasi dan format fixture belum ditetapkan di dokumen beku; ubah lewat input `fixture_dir` / `jumlah_fixture` bila repo model memakai tata letak lain.
- Uji skrip: `sh scripts/tests/qa-gate-test.sh` (merah-hijau).
- Lockfile wajib: `Cargo.lock`, `bun.lock*` (lewat `--frozen-lockfile`), `gradlew`. Tanpa itu CI merah dengan pesan jelas (build terkunci sesuai AGENTS).

## Prasyarat di repo kode (temuan; di luar repo ini)

1. `titeny-backend-service`: belum ada `Cargo.lock`, belum ada test; `Cargo.toml` memakai axum 0.7.9 sedangkan stack terkunci Axum 0.8.
2. `titeny-web`: belum ada `bun.lock`, belum ada skrip/berkas test (`bun test` tanpa test keluar non-nol).
3. `titeny-app-kmp`: belum ada `gradlew`/wrapper; `packageVersion = "0.1.0"` (rilis 1.0.0 butuh `1.0.0`); belum ada test.
4. `titeny-ai-models`: ada `tests/test_harga.py`, belum ada fixture event; `pyproject.toml` tanpa pytest (CI memasang `pytest==8.3.3`).

## Usulan proteksi `main` (tidak diterapkan; keputusan manusia)

Per repo kode: wajib check `ci / ci` hijau, minimal 1 review, larang force-push, larang merge bila check merah. Pengaturan repo/org tidak diubah oleh PR ini.

## Batas

Workflow hanya membaca repo lain (`contents: read`); tidak menulis ke DB sumber; DB Postgres di job hanya service sementara dengan kredensial sekali pakai.
