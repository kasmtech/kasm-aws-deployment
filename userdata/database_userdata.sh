#!/bin/bash

set -euo pipefail

export NEEDRESTART_MODE=l
export DEBIAN_FRONTEND=noninteractive

##############################################################################
# Tofu-templated variables (rendered by templatefile() in database.tf)
##############################################################################
ROLE="db"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
KASM_STIG_OVERRIDE='${KASM_STIG_OVERRIDE}'
ADDITIONAL_INSTALL_ARGS='${ADDITIONAL_DATABASE_INSTALL_ARGS}'

# Block volume mount target (e.g. nvme2n1)
BLOCK_DEVICE='${BLOCK_DEVICE}'

# Kasm bootstrap credentials (used only on fresh DB init)
KASM_DB_PASS='${KASM_DB_PASS}'
KASM_USER_PASS='${KASM_USER_PASS}'
KASM_ADMIN_PASS='${KASM_ADMIN_PASS}'
KASM_MANAGER_TOKEN='${KASM_MANAGER_TOKEN}'
KASM_SERVICE_TOKEN='${KASM_SERVICE_TOKEN}'
DB_INIT_OVERRIDE='${DB_INIT_OVERRIDE}'

# Custom default_properties.yaml (optional — empty string to skip)
BUCKET_NAME='${BUCKET_NAME}'
BUCKET_REGION='${BUCKET_REGION}'
CUSTOM_PROPERTIES_FILENAME='${CUSTOM_PROPERTIES_FILENAME}'

# Backup cron (optional — empty BACKUP_BUCKET_DIR_NAME skips cron creation)
BACKUP_BUCKET_DIR_NAME='${BACKUP_BUCKET_DIR_NAME}'

# Postgres tuning via pgconfigctl (optional — empty PGCONFIGCTL_SECRET_ID skips this entirely).
# When set, must be an AWS Secrets Manager ARN holding {"username": "...", "key": "..."} credentials for
# registry.gitlab.com/kasm-technologies/engineering/ci-cd-core/docker/pgconfig-api/pgconfigctl.
PGCONFIGCTL_SECRET_ID='${PGCONFIGCTL_SECRET_ID}'
DB_CONNECTIONS='${DB_CONNECTIONS}'

# Enhanced DB monitoring (optional — creates a read-only db-o11y account)
ENHANCED_DB_MONITORING='${ENHANCED_DB_MONITORING}'
DB_O11Y_PASSWORD='${DB_O11Y_PASSWORD}'

##############################################################################
# Static constants
##############################################################################
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"
KASM_DEPLOYMENT_DIR="/opt/kasm/.kasm_deployment"
VOLUME_MOUNT_PATH="/opt/kasm"
SWAP_SIZE_GB="8"
INSTALL_PACKAGES="iputils-ping dnsutils netcat-openbsd htop cron vim kmod"

# pgconfigctl tuning constants (Kasm-internal GitLab CR image, gated on PGCONFIGCTL_SECRET_ID)
AWS_VAULT_REGION="us-east-1"
PGTUNE_IMAGE="registry.gitlab.com/kasm-technologies/engineering/ci-cd-core/docker/pgconfig-api/pgconfigctl:latest"
PG_VERSION="14"
DB_SETTINGS_PATH="/opt/kasm/current/conf/database"
SETTINGS_FILENAME="postgres_optimization"
DB_CONFIG_FILENAME="postgresql.conf"

CMD='\e[0;34m'
WRN='\e[0;33m'
ERR='\e[0;31m'
OK='\e[0;32m'
NC='\e[0m'

##############################################################################
# Helper functions
##############################################################################
function create_swap() {
    if [[ -f "/var/lib/docker/swap/kasm.swap" ]]; then
        echo "Swap file already present, skipping create"
    else
        echo "Creating Swap partition"
        mkdir -p /var/lib/docker/swap
        fallocate -l "$${SWAP_SIZE_GB}"g /var/lib/docker/swap/kasm.swap
        chmod 600 /var/lib/docker/swap/kasm.swap
        mkswap /var/lib/docker/swap/kasm.swap
        swapon /var/lib/docker/swap/kasm.swap
        echo '/var/lib/docker/swap/kasm.swap swap swap defaults 0 0' | tee -a /etc/fstab
    fi
}

function create_db_volume() {
    mkdir -p "$${VOLUME_MOUNT_PATH}/db/data"
    chown -R 70:70 "$${VOLUME_MOUNT_PATH}/db/data"
    local volume_name="kasm_db_$${KASM_VERSION}"
    docker volume create "$${volume_name}" \
        --driver "local" \
        --opt "type=none" \
        --opt "device=$${VOLUME_MOUNT_PATH}/db/data" \
        --opt "o=bind"
}

function mount_block_volume() {
    while ! test -b "/dev/$${BLOCK_DEVICE}"; do
        echo "Waiting for /dev/$${BLOCK_DEVICE} to become available..."
        sleep 5
    done

    # Preserve any existing role/banner state across the mount
    if [[ -d "$${KASM_DEPLOYMENT_DIR}/" ]]; then
        cp -a "$${KASM_DEPLOYMENT_DIR}/" /tmp/
    fi

    # Format if not already XFS
    if [[ "$(lsblk -f | grep "$${BLOCK_DEVICE}" | awk -F ' ' '{print $2}')" != "xfs" ]]; then
        mkfs.xfs -f "/dev/$${BLOCK_DEVICE}"
    fi

    mkdir -p "$${VOLUME_MOUNT_PATH}"
    echo "/dev/$${BLOCK_DEVICE} $${VOLUME_MOUNT_PATH} xfs defaults,_netdev,nofail 0 2" >> /etc/fstab
    mount -a

    if [[ -d /tmp/.kasm_deployment ]]; then
        cp -a /tmp/.kasm_deployment "$${VOLUME_MOUNT_PATH}/"
    fi
}

function install_packages() {
    local PACKAGES
    IFS=" " read -r -a PACKAGES <<< "$${1}"
    echo "Installing Packages: $${PACKAGES[*]}"
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        install "$${PACKAGES[@]}" -y
}

function download_kasm() {
    local tarball
    wget -qP "$${KASM_DOWNLOAD_FOLDER}" "$${KASM_DOWNLOAD_URL}"
    tarball=$(awk -F '/' '{print $NF}' <<< "$${KASM_DOWNLOAD_URL}")
    tar xvf "$${KASM_DOWNLOAD_FOLDER}/$${tarball}" -C "$${KASM_DOWNLOAD_FOLDER}"
}

function install_prereqs() {
    bash "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install_dependencies.sh" "true" "false" "false" "$${ROLE}" \
        && echo -e "$${OK}Kasm pre-reqs successfully installed$${NC}"
}

##############################################################################
# AWS prep
##############################################################################
if [[ "$${EUID}" -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Mount the dedicated block volume at /opt/kasm BEFORE anything writes there
mount_block_volume

# Stop background APT activity for the duration of bootstrap
sed -i 's|APT::Periodic::Unattended-Upgrade "1";|APT::Periodic::Unattended-Upgrade "0";|' /etc/apt/apt.conf.d/20auto-upgrades
systemctl disable apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer --now --no-block || :
systemctl mask apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer || :
systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || :

# Verify AWS instance metadata reachability (IMDSv2)
AWS_IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
METADATA_CHECK_AWS=$(curl -s -o /dev/null -w "%%{http_code}" -H "X-aws-ec2-metadata-token: $${AWS_IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/)
if [[ "$${METADATA_CHECK_AWS}" != "200" ]]; then
    echo -e "$${ERR}AWS instance metadata not reachable$${NC}"
    exit 1
fi

# Stage scripts directory
if [[ -d "$${KASM_DOWNLOAD_FOLDER}" ]]; then
    rm -f "$${KASM_DOWNLOAD_FOLDER}"/kasm_*.tar.gz
    rm -rf "$${KASM_DOWNLOAD_FOLDER}/kasm_release"
else
    mkdir -p "$${KASM_DOWNLOAD_FOLDER}"
fi

# Install AWS CLI on first boot (skipped if instance is already provisioned from a Kasm-prepped image)
if [[ ! -f "$${KASM_DEPLOYMENT_DIR}/image_version" ]]; then
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 install -y unzip jq
    curl -so "$${KASM_DOWNLOAD_FOLDER}/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
    unzip -q "$${KASM_DOWNLOAD_FOLDER}/awscliv2.zip" -d "$${KASM_DOWNLOAD_FOLDER}"
    bash "$${KASM_DOWNLOAD_FOLDER}/aws/install" --update
    rm -f "$${KASM_DOWNLOAD_FOLDER}/awscliv2.zip"
    rm -rf "$${KASM_DOWNLOAD_FOLDER}/aws"
fi

# Wait for any in-flight apt to clear
if pgrep apt > /dev/null; then
    echo -e "$${CMD}apt is already running, waiting 30s for the lock to clear$${NC}"
    pgrep -a apt
    sleep 30
fi

##############################################################################
# Kasm install prep
##############################################################################
SCRIPT_PATH=$(mktemp -d)
cd "$${SCRIPT_PATH}"

# Resolve STIG branch: explicit override > release branch matching version > develop
if [[ -n "$${KASM_STIG_OVERRIDE}" ]]; then
    KASM_STIG_URL="$${KASM_STIG_OVERRIDE}"
elif curl -sfL https://api.github.com/repos/kasmtech/workspaces-stigs/branches \
        | jq -e ".[].name | select(. == \"release/$${KASM_VERSION}\")" &> /dev/null; then
    KASM_STIG_URL="https://raw.githubusercontent.com/kasmtech/workspaces-stigs/refs/heads/release/$${KASM_VERSION}"
else
    KASM_STIG_URL="https://raw.githubusercontent.com/kasmtech/workspaces-stigs/refs/heads/develop"
fi

wget -q "$${KASM_STIG_URL}/apply_docker_stigs.sh" \
    || echo -e "$${ERR}Failed to download apply_docker_stigs.sh$${NC}"
wget -qO "$${KASM_DOWNLOAD_FOLDER}/apply_kasm_stigs.sh" "$${KASM_STIG_URL}/apply_kasm_stigs.sh" \
    || echo -e "$${ERR}Failed to download apply_kasm_stigs.sh$${NC}"
sed -i "s/^KASM_VERSION=.*/KASM_VERSION=$${KASM_VERSION}/" "$${KASM_DOWNLOAD_FOLDER}/apply_kasm_stigs.sh"

if [[ ! -f "$${KASM_DEPLOYMENT_DIR}/image_version" ]]; then
    install_packages "$${INSTALL_PACKAGES}"
fi

# Hotfix CVE-2026-31431 — block algif_aead module loading
echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif.conf
if [[ -f /usr/sbin/rmmod ]]; then
    /usr/sbin/rmmod algif_aead 2>/dev/null || true
else
    echo "WARNING: rmmod not found, cannot remove algif_aead if it has already been loaded"
fi

download_kasm
install_prereqs

# Increase Docker restart burst tolerance (systemd >= 229)
mkdir -p /etc/systemd/system/docker.service.d/
if [[ ! -f /etc/systemd/system/docker.service.d/override.conf ]]; then
    cat >/etc/systemd/system/docker.service.d/override.conf <<EOL
[Unit]
StartLimitBurst=12
EOL
elif grep -q '\[Unit\]' /etc/systemd/system/docker.service.d/override.conf; then
    sed -i '/[Unit]/a StartLimitBurst=12' /etc/systemd/system/docker.service.d/override.conf
else
    echo -e '[Unit]\nStartLimitBurst=12' >> /etc/systemd/system/docker.service.d/override.conf
fi
systemctl daemon-reload

echo 'y' | bash "$${SCRIPT_PATH}/apply_docker_stigs.sh" \
    || echo -e "$${CMD}Stig script exited with errors$${NC}"


##############################################################################
# Role-specific work — db
##############################################################################

# Detect whether the block volume already has a db payload. If so we won't
# re-init the database — we'll attach to the existing one.
if [[ -d "$${VOLUME_MOUNT_PATH}/db/data" ]] && [[ "$(ls -A "$${VOLUME_MOUNT_PATH}/db/data" 2>/dev/null | wc -l)" -gt 0 ]]; then
    EXISTING_DB="true"
else
    EXISTING_DB="false"
fi

if [[ "$${DB_INIT_OVERRIDE,,}" == "false" ]] && [[ "$${EXISTING_DB,,}" == "true" ]]; then
    echo -e "$${OK}Existing database detected. Skipping initialization.$${NC}"
    DB_ARGS=("-d")
else
    echo -e "$${OK}No existing database detected. Proceeding with initialization.$${NC}"
    DB_ARGS=(
        "-Q" "$${KASM_DB_PASS}"
        "-U" "$${KASM_USER_PASS}"
        "-P" "$${KASM_ADMIN_PASS}"
        "-M" "$${KASM_MANAGER_TOKEN}"
        "-k" "$${KASM_SERVICE_TOKEN}"
    )
fi

# Optional: fetch a customer-supplied default_properties.yaml from S3 before install
if [[ -n "$${CUSTOM_PROPERTIES_FILENAME}" ]] && [[ -n "$${BUCKET_NAME}" ]]; then
    echo "Waiting for s3://$${BUCKET_NAME}/$${CUSTOM_PROPERTIES_FILENAME} to be available..."
    while [[ -z "$(aws s3 ls "s3://$${BUCKET_NAME}/$${CUSTOM_PROPERTIES_FILENAME}" 2>/dev/null)" ]]; do
        sleep 10
    done

    DEFAULT_PROPERTIES_PATH="$${KASM_DOWNLOAD_FOLDER}/kasm_release/conf/database/seed_data"
    mv "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml" \
       "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml.bak"
    aws s3 cp "s3://$${BUCKET_NAME}/$${CUSTOM_PROPERTIES_FILENAME}" \
              "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml" \
              --region "$${BUCKET_REGION}"

    if [[ "$(wc -l < "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml")" -eq 0 ]]; then
        mv "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml.bak" \
           "$${DEFAULT_PROPERTIES_PATH}/default_properties.yaml"
    fi
fi

create_swap
create_db_volume

# Stop install.sh's db_init helper from wiping the docker volume we just created
sed -i "/Installing Database Role/a sed -i -e '/volume rm/d; /volume create/d' /opt/kasm/$${KASM_VERSION}/bin/utils/db_init" \
    "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh"

# Install Kasm DB role
bash "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh" \
    -S "$${ROLE}" -e -H \
    "$${DB_ARGS[@]}" \
    "$${ADDITIONAL_INSTALL_ARGS}"

##############################################################################
# Postgres tuning via pgconfigctl (optional — gated on PGCONFIGCTL_SECRET_ID)
##############################################################################
if [[ -n "$${PGCONFIGCTL_SECRET_ID}" ]]; then
    DB_MEMORY=$(free -h | grep -i mem | awk '{print $2}' | cut -d'G' -f1)
    DB_CPUS=$(nproc)

    PGCONFIGCTL_CREDS="$(aws secretsmanager get-secret-value \
        --secret-id "$${PGCONFIGCTL_SECRET_ID}" \
        --region "$${AWS_VAULT_REGION}" \
        --output json | jq -r '.SecretString')"
    PGCONFIGCTL_USER=$(jq -r .username <<< "$${PGCONFIGCTL_CREDS}")
    PGCONFIGCTL_KEY=$(jq -r .key       <<< "$${PGCONFIGCTL_CREDS}")

    if [[ -n "$${PGCONFIGCTL_USER}" ]] && [[ -n "$${PGCONFIGCTL_KEY}" ]]; then
        echo "Authenticating to GitLab Container Registry"
        echo "$${PGCONFIGCTL_KEY}" | docker login "registry.gitlab.com" \
            -u "$${PGCONFIGCTL_USER}" --password-stdin

        docker run --rm "$${PGTUNE_IMAGE}" \
            tune --version "$${PG_VERSION}" \
                 --cpus "$${DB_CPUS}" \
                 --max-connections "$${DB_CONNECTIONS}" \
                 --ram "$${DB_MEMORY}GB" \
                 --profile WEB --os linux --format conf \
            | grep -v '#' | grep -v -e '^$' \
            > "$${DB_SETTINGS_PATH}/$${SETTINGS_FILENAME}"

        # Scrub the GitLab CR credentials out of /root/.docker/config.json
        jq 'del(.auths."registry.gitlab.com")' < /root/.docker/config.json \
            > /root/.docker/config.json.tmp \
            && mv /root/.docker/config.json.tmp /root/.docker/config.json

        # Back up the original postgresql.conf, then merge tuned values in
        cp "$${DB_SETTINGS_PATH}/$${DB_CONFIG_FILENAME}" \
           "$${DB_SETTINGS_PATH}/$${DB_CONFIG_FILENAME}.$(date +"%Y%m%d%H%S")"

        while IFS= read -r line; do
            PARAM=$(echo "$${line}" | cut -d'=' -f1)
            sed -i "/$${PARAM}=.*/s/^#//" "$${DB_SETTINGS_PATH}/$${DB_CONFIG_FILENAME}"
            sed -i "s/$${PARAM}=.*/$${line}/" "$${DB_SETTINGS_PATH}/$${DB_CONFIG_FILENAME}"
        done < "$${DB_SETTINGS_PATH}/$${SETTINGS_FILENAME}"

        chown kasm_db:70 "$${DB_SETTINGS_PATH}/$${DB_CONFIG_FILENAME}"

        echo "Restarting Kasm services to pick up tuned Postgres config..."
        /opt/kasm/bin/stop && /opt/kasm/bin/start
    else
        echo -e "$${WRN}PGCONFIGCTL secret payload missing username/key — skipping Postgres tuning$${NC}"
    fi
fi

##############################################################################
# Backup cron job (optional — gated on BACKUP_BUCKET_DIR_NAME)
##############################################################################
if [[ -n "$${BACKUP_BUCKET_DIR_NAME}" ]] && [[ -n "$${BUCKET_NAME}" ]]; then
    echo "Installing daily backup_db cron job"
    cat > /opt/kasm/scripts/backup_db <<BACKUP
#!/bin/bash
set -e

BACKUP_BUCKET_DIR="\$${1}"
mkdir -p /opt/kasm/backups
DATE="\$(date +'%Y%m%d')"
BACKUP_FILE_NAME="kasm_db_backup-\$${DATE}.tar.gz"

docker exec kasm_db /bin/bash -c "pg_dump -U kasmapp -w -Ft --exclude-table-data=logs kasm | gzip > /tmp/db_backup.tar.gz"
docker cp kasm_db:/tmp/db_backup.tar.gz "/opt/kasm/backups/\$${BACKUP_FILE_NAME}"

aws s3 cp "/opt/kasm/backups/\$${BACKUP_FILE_NAME}" \\
    "s3://$${BUCKET_NAME}/\$${BACKUP_BUCKET_DIR}/\$${BACKUP_FILE_NAME}" \\
    --region "$${BUCKET_REGION}"

# Retain backups locally for 3 days as a safety net
find /opt/kasm/backups/ -mindepth 1 -mtime +3 -delete
BACKUP

    chmod +x /opt/kasm/scripts/backup_db
    (crontab -l 2>/dev/null; echo "0 1 * * * /opt/kasm/scripts/backup_db $${BACKUP_BUCKET_DIR_NAME}") \
        | awk '!x[$0]++' | crontab -
fi

##############################################################################
# Enhanced DB monitoring user (optional — read-only db-o11y account)
##############################################################################
if [[ "$${ENHANCED_DB_MONITORING,,}" == "true" ]] && [[ -n "$${DB_O11Y_PASSWORD}" ]]; then
    echo "Configuring enhanced DB monitoring"

    while ! docker inspect --format='{{.State.Health.Status}}' kasm_db 2>/dev/null | grep -qi 'healthy'; do
        sleep 5
    done

    docker exec kasm_db psql -U kasmapp -d kasm -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    docker exec kasm_db psql -U kasmapp -d kasm -c "CREATE USER \"db-o11y\" WITH PASSWORD '$${DB_O11Y_PASSWORD}';"
    docker exec kasm_db psql -U kasmapp -d kasm -c "GRANT pg_monitor TO \"db-o11y\";"
    docker exec kasm_db psql -U kasmapp -d kasm -c "GRANT pg_read_all_stats TO \"db-o11y\";"
    docker exec kasm_db psql -U kasmapp -d kasm -c "ALTER ROLE \"db-o11y\" SET pg_stat_statements.track = 'none';"
    docker exec kasm_db psql -U kasmapp -d kasm -c "GRANT pg_read_all_data TO \"db-o11y\";"

    echo -e "$${OK}Enhanced DB monitoring configured$${NC}"
fi

##############################################################################
# Firstboot hardening
##############################################################################
SSH_NETWORK_FILE="$${KASM_DEPLOYMENT_DIR}/ssh_network"
IPSET_DIR="/etc/iptables"

# Only run network hardening on Kasm base images (gated by docker_set ipset existence)
if ipset list docker_set > /dev/null 2>&1; then
    KASM_NETWORK=$(docker network inspect kasm_default_network | jq -r .[].IPAM.Config[].Subnet)
    KASM_SIDECAR_NETWORK=$(docker network inspect kasm_sidecar_network 2>/dev/null | jq -r .[].IPAM.Config[].Subnet || true)
    DOCKER_NETWORK=$(docker network inspect bridge | jq -r .[].IPAM.Config[].Subnet)

    for net in "$${KASM_NETWORK}" "$${KASM_SIDECAR_NETWORK}" "$${DOCKER_NETWORK}"; do
        if [[ -n "$${net}" ]] && ! grep -q "$${net}" "$${IPSET_DIR}/ipset_docker"; then
            echo "add docker_set $${net}" >> "$${IPSET_DIR}/ipset_docker"
            sed -i "\|$${net}|d" "$${KASM_DEPLOYMENT_DIR}/docker_networks" 2>/dev/null || true
        fi
    done

    if [[ -f "$${KASM_DEPLOYMENT_DIR}/docker_networks" ]]; then
        iprange --merge "$${KASM_DEPLOYMENT_DIR}/docker_networks" 2>/dev/null \
            | while read -r ip; do
                echo "add workspaces_set $${ip}" >> "$${IPSET_DIR}/ipset_workspaces"
            done
    fi

    if [[ -f "$${SSH_NETWORK_FILE}" ]]; then
        while IFS= read -r line; do
            echo "add ssh_set $${line}" >> "$${IPSET_DIR}/ipset_ssh"
        done < "$${SSH_NETWORK_FILE}"
        ipset restore -f "$${IPSET_DIR}/ipset_ssh"
    fi

    ipset restore -f "$${IPSET_DIR}/ipset_docker"
    ipset restore -f "$${IPSET_DIR}/ipset_workspaces"
    netfilter-persistent save

    /usr/local/bin/cleanup_creds || true
fi

##############################################################################
# OS update
##############################################################################
function update_ubuntu() {
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Waiting for other apt-get instances to exit"
        sleep 5
    done

    dpkg --configure -a
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" upgrade -y
    apt-get -o DPkg::Lock::Timeout=-1 autoremove -y
    apt-get -o DPkg::Lock::Timeout=-1 autoclean -y
}

if [[ ! -f "$${KASM_DEPLOYMENT_DIR}/image_version" ]]; then
    update_ubuntu
fi

# Re-enable unattended upgrades
sed -i 's|APT::Periodic::Unattended-Upgrade "0";|APT::Periodic::Unattended-Upgrade "1";|' /etc/apt/apt.conf.d/20auto-upgrades
systemctl unmask apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer || :
systemctl enable apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer --no-block --now || :

echo -e "$${OK}Database node bootstrap complete$${NC}"
