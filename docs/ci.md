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

## Uji kontrak: Pact dan Schemathesis (TTN-OPS-007)

| Job | Di workflow | Pemicu | Sumber (nyata, PR siklus 2) | Memblokir merge |
|---|---|---|---|---|
| `pact-konsumen` | `ci-web.yml` | tiap run ci-web | `bun run test:pact`, `pacts/titeny-web-titeny-backend-service.json` (titeny-web #15); gagal bila `pacts/` berubah setelah uji | ya (bila `test:pact` ada; bila belum, peringatan + lewati) |
| `pact-provider` | `ci-backend.yml` | tiap run ci-backend | mengambil `pacts/*.json` titeny-web (#15) dan titeny-app-kmp (#18, `pacts/titeny-analis-desktop-titeny-backend-service.json`) lalu menjalankan `scripts/verifikasi-pact.sh pacts-konsumen` di backend | ya setelah skrip ada |
| `schemathesis` | `ci-backend.yml` | MANUAL: `workflow_dispatch` ci-backend atau ci-semua dengan `jalankan_schemathesis=true` | `contract/schemathesis.sh` titeny-web (#16/#17) terhadap `docs/api/openapi.yaml` backend, backend + Postgres + `dev-stack/seed.sql` | tidak |

Input reusable: `kontrak_web_ref`, `kontrak_kmp_ref` (default `main`; isi nama cabang PR bila PR konsumen belum merge), `schemathesis_max_examples` (50).
Tanggung jawab per sisi: konsumen menulis kontrak (pact) dan menjalankannya terhadap mock; provider memverifikasi (di backend); Schemathesis menguji properti spec vs implementasi.

**Asumsi (belum ada di repo lain)**: PR backend #7-#10 TIDAK memuat `scripts/verifikasi-pact.sh` maupun state handler Pact (`given` pada kontrak web/kmp). Job `pact-provider` mendeteksi ketiadaannya dan menampilkan `::warning::` "BELUM dijalankan" (tidak lulus diam-diam). Kontrak skrip yang diharapkan: `sh scripts/verifikasi-pact.sh <direktori-pact>` memulai backend + DB (`DATABASE_URL` tersedia) dan keluar non-nol bila ada interaksi gagal. Maestro web (beta) dan alur desktop tetap dijalankan lokal/manual (lihat `docs/testing/` di repo konsumen).

## QA gate (`scripts/qa-gate.sh`)

- QA-002: gagal bila ada `#[ignore]` (Rust), `test.skip/it.skip/xit/...` (web), `pytest.mark.skip/xfail` (Python), `@Ignore/@Disabled` (Kotlin) di berkas uji.
- Gerbang fixture: tepat 11 berkas `*.json` di `tests/fixtures/events/`. **Asumsi**: lokasi dan format fixture belum ditetapkan di dokumen beku; ubah lewat input `fixture_dir` / `jumlah_fixture` bila repo model memakai tata letak lain.
- Uji skrip: `sh scripts/tests/qa-gate-test.sh` (merah-hijau).
- Lockfile wajib: `Cargo.lock`, `bun.lock*` (lewat `--frozen-lockfile`), `gradlew`. Tanpa itu CI merah dengan pesan jelas (build terkunci sesuai AGENTS).

## Prasyarat di repo kode (per repo; status per PR siklus 1-2, diperiksa 2026-10-22)

CI menolak build tanpa lockfile/wrapper (build terkunci, AGENTS). Prasyarat yang harus ter-commit di repo kode, dan statusnya pada cabang PR terbuka:

| Repo | Prasyarat CI | Status |
|---|---|---|
| titeny-backend-service | `Cargo.lock`; Axum 0.8 (`Cargo.toml`); `tests/` yang memakai `#[sqlx::test]` (Postgres di job); `docs/api/openapi.yaml`; opsional `scripts/verifikasi-pact.sh` untuk `pact-provider` | `Cargo.lock`, Axum 0.8.4, `tests/` ada di PR #7-#10. `scripts/verifikasi-pact.sh` BELUM ada (asumsi). |
| titeny-web | `bun.lock` (`bun install --frozen-lockfile`), skrip `check` dan `test` di `package.json`, minimal satu berkas `tests/*.test.ts`; `test:pact` + `pacts/` untuk `pact-konsumen` | `bun.lock`, `check`, `test`, `tests/` ada; `test:pact` + `pacts/` datang di #15. |
| titeny-app-kmp | `gradlew`, `gradle/wrapper/gradle-wrapper.jar` + `.properties` (divalidasi `wrapper-validation`); `packageVersion = "1.0.0"`; modul `:analis-desktop` dengan `desktopTest`; `pacts/` untuk cek sinkron | wrapper + `packageVersion 1.0.0` di #12; `desktopTest` + `pacts/` di #18/#19. |
| titeny-ai-models | `pyproject.toml` (paket dapat di-`pip install -e .`), `tests/test_*.py`; tidak punya fixture event | ada; `ci-semua` memakai `jumlah_fixture: 0`. |
| titeny-data-pipeline | `pyproject.toml`, `tests/`, tepat 11 `tests/fixtures/events/*.json` | ada (11 fixture di PR #9; asumsi lokasi terkonfirmasi). |

### Desktop: hanya `:analis-desktop:*`

- `ci-desktop` menjalankan `./gradlew :analis-desktop:desktopTest` lalu `:analis-desktop:packageMsi`. `./gradlew test` di root TIDAK dipakai karena ikut menarik `:baca-mobile`.
- Android SDK hanya diperlukan untuk modul `:baca-mobile` (`com.android.application`, `compileSdk 34`; target iOS tak dapat dibangun di Windows). Karena CI tidak menyentuh `:baca-mobile`, tidak ada langkah pemasangan Android SDK. Diverifikasi lokal: `env -u ANDROID_HOME ./gradlew --offline :analis-desktop:desktopTest` hijau (cabang `test/ttn-kmp-test-maestro`, 12 berkas hasil uji). Bila kelak `:baca-mobile` dibangun di CI, tambahkan job terpisah di ubuntu-24.04 dengan `android-actions/setup-android`.
- Padanan Maestro untuk desktop: Maestro tidak mendukung Compose Desktop (ADR-0005 app-kmp); padanannya tes Compose UI `AlurUiTest` dalam `:analis-desktop:desktopTest` (sudah tercakup langkah di atas).
- Prasyarat runner: Java 17 (Temurin), WiX 3.14 untuk MSI (dipasang bila tak ada), Windows karena `jpackage` MSI.

## Usulan proteksi `main` (tidak diterapkan; keputusan manusia)

Per repo kode: wajib check `ci / ci` hijau, minimal 1 review, larang force-push, larang merge bila check merah. Pengaturan repo/org tidak diubah oleh PR ini.

## Batas

Workflow hanya membaca repo lain (`contents: read`); tidak menulis ke DB sumber; DB Postgres di job hanya service sementara dengan kredensial sekali pakai.
