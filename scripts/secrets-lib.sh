# shellcheck shell=sh disable=SC2034
# Daftar nama secret wajib Titeny (TTN-OPS-004). Di-source oleh setup-secrets.sh dan audit-koneksi.sh.
# Tidak pernah mencetak nilai.
PLACEHOLDER='GANTI_DARI_SECRET_MANAGER'
NAMA_WAJIB='DATABASE_URL JWT_ED25519_PRIVATE JWT_ED25519_PUBLIC TITENY_API_TOKEN GHCR_TOKEN'
NAMA_SUMBER='SRC_S1_DATABASE_URL SRC_S2_DATABASE_URL SRC_S3_DATABASE_URL SRC_S4_DATABASE_URL SRC_S5_DATABASE_URL SRC_S6_DATABASE_URL SRC_S7_DATABASE_URL SRC_S8_DATABASE_URL SRC_S9_DATABASE_URL SRC_S10_DATABASE_URL'

nilai_env() { # nilai_env <NAMA>  -> isi variabel (kosong bila tidak ada)
  printenv "$1" 2>/dev/null || true
}
