#!/bin/bash

set -euo pipefail

export NEEDRESTART_MODE=l
export DEBIAN_FRONTEND=noninteractive

##############################################################################
# Tofu-templated variables (rendered by templatefile() in compute.tf)
##############################################################################
ROLE="proxy"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
KASM_STIG_OVERRIDE='${KASM_STIG_OVERRIDE}'
ADDITIONAL_INSTALL_ARGS='${ADDITIONAL_PROXY_INSTALL_ARGS}'
MANAGER_ADDRESS='${PUBLIC_LB_HOSTNAME}'
REGION_PROXY_DOMAIN_NAME='${REGION_PROXY_DOMAIN_NAME}'

##############################################################################
# Static constants
##############################################################################
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"
KASM_DEPLOYMENT_DIR="/opt/kasm/.kasm_deployment"
SWAP_SIZE_GB="8"
INSTALL_PACKAGES="iputils-ping dnsutils netcat-openbsd htop cron vim kmod"

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

function create_nginx_logrotate() {
    cat > /etc/logrotate.d/kasm-nginx <<LOGROTATE
/opt/kasm/current/log/nginx/*.log {
        su root root
        size 10k
        missingok
        rotate 20
        compress
        delaycompress
        notifempty
        create 644 kasm root
        sharedscripts
        postrotate
                if [ "\$(docker ps -a -q -f name=kasm_proxy)" ]; then
                        docker exec kasm_proxy nginx -s reopen
                fi
        endscript
}

LOGROTATE
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
# Role-specific work — proxy
##############################################################################
create_swap
create_nginx_logrotate

# Wait for the manager API to come up before installing
while ! curl -k "https://$${MANAGER_ADDRESS}/api/__healthcheck" 2>/dev/null | grep -q "true"; do
    echo "Waiting for API server at $${MANAGER_ADDRESS}..."
    sleep 5
done

bash "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh" \
    -S "$${ROLE}" -e -H \
    -p "$${REGION_PROXY_DOMAIN_NAME}" \
    -n "$${MANAGER_ADDRESS}" \
    "$${ADDITIONAL_INSTALL_ARGS}"

echo "resolver 127.0.0.11 valid=10s ipv6=off" > /opt/kasm/current/conf/nginx/resolver.conf
docker exec kasm_proxy nginx -s reload

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

echo -e "$${OK}Proxy node bootstrap complete$${NC}"
