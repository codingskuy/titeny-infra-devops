#!/bin/sh
# Membangkitkan k8s/cronjob-insight.yaml dari satu tabel jadwal (TTN-OPS-003).
# Jadwal terkunci v1.0.0 (WIB, CronJob timeZone Asia/Jakarta); sumber: FSD/10-alur.md butir 2, 40-TECHSTACK.md.
# Pemakaian: sh scripts/gen-cronjobs.sh > k8s/cronjob-insight.yaml
# ASUMSI (tandai di PR): image model `titeny-ai-models` dan perintah `python -m titeny_models.jobs <jenis>`
# belum ada di repo model; sesuaikan bila berbeda. Penanda koreksi siang (`koreksi.flag`) ditulis oleh ingest.
set -eu
here=$(cd "$(dirname "$0")" && pwd)

image=${JOB_IMAGE:-ghcr.io/coding-skuy/titeny-ai-models:1.0.0}

cat <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: titeny-job-wrapper
  namespace: titeny
data:
  job-wrapper.sh: |
YAML
sed -e 's/^/    /' -e 's/ *$//' "$here/job-wrapper.sh"
cat <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: titeny-job-state
  namespace: titeny
spec:
  accessModes: ["ReadWriteMany"]   # kunci berkas + log dipakai bersama semua CronJob (butuh StorageClass RWX)
  resources:
    requests:
      storage: 2Gi
YAML

# nama | cron | jenis | opsi wrapper
while IFS='|' read -r nama cron jenis opsi; do
  [ -n "$nama" ] || continue
  cat <<YAML
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: $nama
  namespace: titeny
spec:
  schedule: "$cron"
  timeZone: Asia/Jakarta
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 600
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 1500
      template:
        spec:
          restartPolicy: Never
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            fsGroup: 10001
          containers:
            - name: job
              image: $image
              command: ["sh", "/opt/titeny/job-wrapper.sh", "$nama"$opsi, "--", "python", "-m", "titeny_models.jobs", "$jenis"]
              env:
                - name: DATABASE_URL
                  valueFrom: { secretKeyRef: { name: titeny-secrets, key: DATABASE_URL } }
                - name: TITENY_API_TOKEN
                  valueFrom: { secretKeyRef: { name: titeny-secrets, key: TITENY_API_TOKEN } }
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities: { drop: ["ALL"] }
              volumeMounts:
                - { name: wrapper, mountPath: /opt/titeny, readOnly: true }
                - { name: state, mountPath: /var/lib/titeny-jobs, subPath: state }
                - { name: state, mountPath: /var/log/titeny-jobs, subPath: log }
                - { name: tmp, mountPath: /tmp }
          volumes:
            - name: wrapper
              configMap: { name: titeny-job-wrapper }
            - name: state
              persistentVolumeClaim: { claimName: titeny-job-state }
            - name: tmp
              emptyDir: {}
YAML
done <<'TABEL'
harga-0400|0 4 * * *|harga|
harga-retry-0430|30 4 * * *|harga|, "--only-if-missing"
harga-retry-0500|0 5 * * *|harga|, "--only-if-missing", "--stale-on-fail"
harga-koreksi-1500|0 15 * * *|harga|, "--require-flag", "koreksi"
demand-0430|30 4 * * *|demand|
panen-senin-0300|0 3 * * 1|panen|
mape-minggu-2300|0 23 * * 0|mape|
TABEL
