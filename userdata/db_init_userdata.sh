#!/bin/bash
#
# One-shot Aurora RDS preseed for Kasm. Designed to run on an ephemeral EC2
# launched with `instance_initiated_shutdown_behavior = terminate`. Exits 0
# without re-seeding if the cluster has already been initialized.
#
# Required template variables (rendered by Terraform):
#   AWS_REGION             - region SM secrets and SSM parameter live in
#   DB_HOSTNAME            - Aurora writer endpoint (or its CNAME)
#   DB_PORT                - Aurora port (5432 for aurora-postgresql)
#   DB_NAME                - initial database name (var.rds_database_name)
#   IMAGE_TYPE             - AMI family ("ubuntu" or "al2")
#   KASM_DOWNLOAD_URL      - Kasm installer tarball URL
#   PRESEED_S3_BUCKET      - bucket holding default_properties.yaml
#   PRESEED_S3_KEY         - object key for default_properties.yaml ("" to skip)
#   RDS_MASTER_USER        - non-sensitive master username (var.rds_master_username)
#   SM_SYSTEM_CRED_ID      - SM secret name with {database, service, manager} payload
#   SM_USER_CRED_ID        - SM secret name with {username, password} for kasm user
#   SM_ADMIN_CRED_ID       - SM secret name with {username, password} for kasm admin
#   SSM_STATUS_PARAM_NAME  - SSM parameter to write success marker into
#   VPC_DNS_IP             - VPC CIDR-based DNS resolver (e.g., 10.0.0.2) — routable
#                            from inside Docker bridge containers (link-local isn't)

FORCE_INIT='${FORCE_DB_INIT}'

set -euo pipefail

INIT_LOG=/var/log/kasm-remote-db-init.log
exec > >(tee -a "$INIT_LOG") 2>&1
echo "[$(date -Iseconds)] remote-db-init starting"

##############################################################################
## Install Docker

apt update
apt install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

##############################################################################
## Install dependencies (psql client + awscli + jq)
##
## Ubuntu 24.04 (noble) dropped the `awscli` and `netcat` apt packages — the
## AWS CLI must come from snap or the v2 binary, and `netcat-openbsd` is the
## drop-in successor (also available on 22.04 jammy, so this works on both).
##############################################################################
if [[ "${IMAGE_TYPE}" =~ "ubuntu" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -o DPkg::Lock::Timeout=-1 update
  apt-get -o DPkg::Lock::Timeout=-1 install -y \
    dnsutils \
    iputils-ping \
    jq \
    netcat-openbsd \
    postgresql-client

  ## AWS CLI v2 via snap. Snap is preinstalled on Ubuntu cloud images and
  ## is already in use by the SSM Agent on 24.04.
  if ! command -v aws >/dev/null 2>&1; then
    snap install aws-cli --classic
  fi
elif [[ "${IMAGE_TYPE}" =~ "al2" ]]; then
  dnf update -y
  dnf install -y --skip-broken \
    awscli \
    dnsutils \
    iputils-ping \
    jq \
    nmap-ncat \
    postgresql15
fi

##############################################################################
## Fetch secrets from AWS Secrets Manager
##############################################################################
echo "[$(date -Iseconds)] fetching credentials from Secrets Manager"

SYSTEM_CREDS=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${SM_SYSTEM_CRED_ID}" \
  --query SecretString --output text)
USER_CREDS=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${SM_USER_CRED_ID}" \
  --query SecretString --output text)
ADMIN_CREDS=$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${SM_ADMIN_CRED_ID}" \
  --query SecretString --output text)

KASM_DB_PASS=$(echo "$SYSTEM_CREDS" | jq -r .database)
KASM_SERVICE_TOKEN=$(echo "$SYSTEM_CREDS" | jq -r .service)
KASM_MANAGER_TOKEN=$(echo "$SYSTEM_CREDS" | jq -r .manager)
KASM_USER_PASS=$(echo "$USER_CREDS" | jq -r .password)
KASM_ADMIN_PASS=$(echo "$ADMIN_CREDS" | jq -r .password)

## Aurora master password equals the Kasm DB password (see local.database_password
## in the AWS repo's kasm_internal.tf).
RDS_MASTER_PASS="$KASM_DB_PASS"

## Make psql pick the master password without echoing it back to logs.
export PGPASSWORD="$RDS_MASTER_PASS"

##############################################################################
## Wait for the writer endpoint to accept TCP, then for psql to authenticate.
## We auth against the default `postgres` database here — the Kasm-specific
## database (${DB_NAME}) is created by the installer itself, so it may not
## exist yet on a fresh cluster.
##############################################################################
echo "[$(date -Iseconds)] waiting for Aurora endpoint ${DB_HOSTNAME}:${DB_PORT}"
for i in $(seq 1 60); do
  if nc -w 2 -z "${DB_HOSTNAME}" "${DB_PORT}"; then break; fi
  sleep 5
done

for i in $(seq 1 30); do
  if psql -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${RDS_MASTER_USER}" -d postgres -c 'SELECT 1' >/dev/null 2>&1; then break; fi
  echo "[$(date -Iseconds)] waiting for Aurora to accept psql auth"
  sleep 5
done

##############################################################################
## DB-side one-shot check.
##   1. Does the Kasm database exist? If not, this is a virgin cluster — fall
##      through to the installer.
##   2. If it does, does the sentinel table exist inside it? If yes, the
##      installer already ran successfully — exit 0 without re-seeding.
##############################################################################
KASM_DB_PRESENT=$(psql -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${RDS_MASTER_USER}" -d postgres -tAc \
  "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}')")

SENTINEL_PRESENT="f"
if [ "$KASM_DB_PRESENT" = "t" ]; then
  SENTINEL_PRESENT=$(psql -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${RDS_MASTER_USER}" -d "${DB_NAME}" -tAc \
    "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'kasm_init_marker')")
fi

if [ "$SENTINEL_PRESENT" = "t" && "$FORCE_INIT" = "false" ]; then
  echo "[$(date -Iseconds)] kasm_init_marker present — skipping installer (already initialized)"
  aws ssm put-parameter \
    --region "${AWS_REGION}" \
    --name "${SSM_STATUS_PARAM_NAME}" \
    --value "skipped:already-initialized:$(date -Iseconds)" \
    --type String \
    --overwrite >/dev/null
  shutdown -h now
  exit 0
fi

##############################################################################
## Fetch the rendered preseed YAML (custom default_properties.yaml).
## Stored under /opt to avoid /tmp noexec mounts on hardened/noble AMIs.
##############################################################################
INSTALL_DIR=/opt/kasm-init
mkdir -p "$INSTALL_DIR"

if [ -n "${PRESEED_S3_KEY}" ]; then
  echo "[$(date -Iseconds)] downloading preseed YAML from s3://${PRESEED_S3_BUCKET}/${PRESEED_S3_KEY}"
  aws s3 cp "s3://${PRESEED_S3_BUCKET}/${PRESEED_S3_KEY}" "$INSTALL_DIR/default_properties.yaml"
fi

##############################################################################
## Download + extract Kasm installer under /opt. The bundled yq/curl/etc
## binaries need an exec-permitted filesystem, which /tmp is not on some
## hardened AMI variants (Ubuntu 24.04 minimal, CIS-hardened, etc).
##############################################################################
cd "$INSTALL_DIR"
wget -q "${KASM_DOWNLOAD_URL}"
tar xf kasm_*.tar.gz
## Defense in depth — tar should preserve exec bits, but re-assert in case
## of umask weirdness on cloud-init's working dir.
find kasm_release/bin -type f -exec chmod +x {} +

## If we pulled a custom preseed YAML, drop it where the installer expects it.
if [ -n "${PRESEED_S3_KEY}" ] && [ -f "$INSTALL_DIR/default_properties.yaml" ]; then
  cp "$INSTALL_DIR/default_properties.yaml" "$INSTALL_DIR/kasm_release/conf/database/seed_data/default_properties.yaml"
fi

##############################################################################
## Pre-stage Docker host so the Kasm installer's containers can route + resolve.
##
## 1. ip_forward — required for container -> host -> RDS routing. Docker
##    normally enables this at daemon start, but on Ubuntu 24.04 we hit a
##    race where psql from a container runs before forwarding is on.
##
## 2. DNS resolver — Ubuntu's /etc/resolv.conf points at 127.0.0.53 (the
##    systemd-resolved stub), a loopback that container netns can't reach.
##    Bypass it by stopping systemd-resolved and writing the VPC CIDR DNS
##    resolver into resolv.conf + docker daemon.json.
##
##    Critical: we use the VPC CIDR-based resolver (e.g., 10.0.0.2), NOT
##    link-local 169.254.169.253. AWS exposes the resolver at both addresses,
##    but link-local doesn't reliably traverse Docker's bridge MASQUERADE —
##    containers can't reach it. The CIDR-based address is a regular routed
##    IP, NATs cleanly, and works from any container in the VPC.
##############################################################################
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-kasm-ip-forward.conf
sysctl -w net.ipv4.ip_forward=1

systemctl disable --now systemd-resolved || true
chattr -i /etc/resolv.conf 2>/dev/null || true
rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<RESOLV
nameserver ${VPC_DNS_IP}
options timeout:2 attempts:3
RESOLV
## Lock the file so nothing downstream — Kasm install_dependencies.sh, a
## systemd-resolved re-enable, networkd, DHCP hooks — can rewrite it during
## the installer run. The EC2 self-terminates within minutes; immutability
## is purely scoped to that window.
chattr +i /etc/resolv.conf
echo "[$(date -Iseconds)] /etc/resolv.conf locked to ${VPC_DNS_IP}"

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<JSON
{
  "dns": ["${VPC_DNS_IP}"]
}
JSON

##############################################################################
## Docker CLI wrapper: force --network host on every `docker run` invocation.
##
## Docker 24.x no longer auto-enables net.ipv4.ip_forward, and our pre-stage
## sysctl write isn't surviving the Kasm installer's install_dependencies.sh.
## With ip_forward=0, the docker bridge can't route container traffic to the
## VPC (we see "Network unreachable" against the RDS IP).
##
## Sidestepping the routing layer entirely is the most reliable fix for a
## one-shot init: host-network containers share the EC2's network namespace,
## skip the bridge + NAT + ip_forward chain, and inherit the host's working
## VPC route to RDS. Kasm's installer doesn't run any long-lived containers
## here (just throwaway psql/migration jobs), so port collisions aren't a
## concern.
##
## /usr/local/bin precedes /usr/bin in $PATH, so this wrapper intercepts
## the installer's `docker run` calls regardless of where Docker installs
## its real binary. Non-`run` subcommands pass through unchanged.
##############################################################################
cat > /usr/local/bin/docker <<'WRAPPER'
#!/bin/bash
# Auto-injected by remote-db-init userdata. Routes all `docker run` calls
# through `--network host` to bypass Docker bridge routing constraints on
# this Ubuntu 24.04 host. Restore by `rm /usr/local/bin/docker`.
REAL=/usr/bin/docker
if [ "$1" = "run" ]; then
  shift
  exec "$REAL" run --network host "$@"
fi
exec "$REAL" "$@"
WRAPPER
chmod +x /usr/local/bin/docker
echo "[$(date -Iseconds)] docker CLI wrapper installed at /usr/local/bin/docker"

##############################################################################
## Resolve the DB hostname to a literal IP on the host (where DNS works) and
## pass the IP — not the hostname — to the Kasm installer. The installer's
## bridge-networked containers then connect to a literal IP and do no DNS
## lookups at all, sidestepping the systemd-resolved/link-local NAT problem
## that breaks in-container resolution on Ubuntu 24.04.
##
## Aurora writer endpoint IPs can change on failover, but this init job
## completes in minutes — the IP is stable for the duration of the run.
##############################################################################
DB_HOST_IP=$(dig +short +timeout=3 +tries=3 "${DB_HOSTNAME}" | grep -E '^[0-9.]+$' | tail -1)
if [ -z "$DB_HOST_IP" ]; then
  echo "[$(date -Iseconds)] FATAL: could not resolve ${DB_HOSTNAME} on the host"
  exit 1
fi
echo "[$(date -Iseconds)] resolved ${DB_HOSTNAME} -> $DB_HOST_IP (passing IP to installer)"

##############################################################################
## Run the Kasm installer with the init_remote_db role.
## Flags reference (matches the original kasm-aws db role wiring):
##   -S init_remote_db   Kasm role
##   -e                  accept EULA
##   -H                  skip swap check
##   -q <host>           DB hostname (Aurora writer endpoint)
##   -g <user>           RDS master username
##   -G <pass>           RDS master password
##   -Q <pass>           Kasm DB password
##   -U <pass>           Kasm user@kasm.local password
##   -P <pass>           Kasm admin@kasm.local password
##   -M <token>          Kasm manager token
##   -k <token>          Kasm service token
##############################################################################
echo "[$(date -Iseconds)] running kasm installer (init_remote_db)"
## Feed "y" to any confirmation prompt. The init_remote_db role prompts
## interactively when it finds existing schema (e.g., from a previous failed
## attempt) before dropping it — our cloud-init shell can't answer prompts, so
## the install would otherwise hang until cloud-init's timeout. Process
## substitution (rather than `yes |`) keeps `set -o pipefail` from treating
## `yes`' inevitable SIGPIPE as a failure once install.sh exits.
bash kasm_release/install.sh \
  -S init_remote_db \
  -e \
  -H \
  -q "$DB_HOST_IP" \
  -g "${RDS_MASTER_USER}" \
  -G "$RDS_MASTER_PASS" \
  -Q "$KASM_DB_PASS" \
  -U "$KASM_USER_PASS" \
  -P "$KASM_ADMIN_PASS" \
  -M "$KASM_MANAGER_TOKEN" \
  -k "$KASM_SERVICE_TOKEN" \
  < <(yes)

##############################################################################
## Mark success in two places:
##   1. kasm_init_marker table — defensive guard against repeat seeding even
##      under TF state loss / taint.
##   2. SSM parameter — visible signal for operators verifying the deploy.
## Only reached if the installer exits 0 (set -e above).
##############################################################################
psql -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${RDS_MASTER_USER}" -d "${DB_NAME}" <<SQL
CREATE TABLE IF NOT EXISTS kasm_init_marker (
  id              SERIAL PRIMARY KEY,
  initialized_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  initializer     TEXT NOT NULL DEFAULT 'kasm-aws-tofu-remote-db-init'
);
INSERT INTO kasm_init_marker DEFAULT VALUES;
SQL

aws ssm put-parameter \
  --region "${AWS_REGION}" \
  --name "${SSM_STATUS_PARAM_NAME}" \
  --value "success:$(date -Iseconds)" \
  --type String \
  --overwrite >/dev/null

echo "[$(date -Iseconds)] remote-db-init succeeded — shutting down for self-termination"
shutdown -h now
