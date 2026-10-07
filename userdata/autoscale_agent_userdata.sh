#!/bin/bash
#
# NOTE ON BRACES - this file is intentionally NOT valid Bash as written.
#
# It is rendered twice before it runs on an agent:
#   1. OpenTofu templatefile() in compute.tf substitutes the Tofu variables and
#      collapses the Tofu escapes: a doubled dollar sign becomes a single one,
#      and a doubled percent sign (the curl write-out lines) becomes a single
#      one.
#   2. Kasm AutoScale, at instance-launch time, substitutes the single-brace
#      Kasm placeholders (manager_token, upstream_auth_address, server_id,
#      provider_name, server_external_fqdn) using Python str.format semantics,
#      which collapses every doubled brace into a single brace.
#
# Kasm therefore requires every brace that is NOT a Kasm placeholder to be
# doubled. Upstream wording (kasmtech/workspaces-autoscale-startup-scripts,
# docker_agents/README.md, "Escaping Brackets"): "If your script uses curly
# brackets, aside from Kasm variables, you must escape them by doubling them
# up." Combined with the Tofu dollar escape, that is why shell expansions in
# this file look like dollar-dollar-brace-brace-NAME-brace-brace and function
# bodies open and close with doubled braces.
#
# Do not "fix" the doubled braces, and do not run bash -n on this file
# directly. To validate: render with templatefile(), apply Python .format()
# with dummy values for the Kasm placeholders, then run bash -n on the result.
#
set -euo pipefail

export NEEDRESTART_MODE=l
export DEBIAN_FRONTEND=noninteractive

##############################################################################
# Tofu-templated variables (rendered by templatefile() in compute.tf)
##############################################################################
ROLE="agent"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
KASM_STIG_OVERRIDE='${KASM_STIG_OVERRIDE}'
ADDITIONAL_INSTALL_ARGS='${ADDITIONAL_AGENT_INSTALL_ARGS}'
NFS_ENABLED='${NFS_ENABLED}'
NFS_URL='${NFS_URL}'
NFS_PROFILE_PATH='${NFS_PROFILE_PATH}'

# Kasm runtime placeholders — substituted by Kasm at agent-launch time, not by Tofu.
# Tofu passes these single-brace tokens through unchanged.
GIVEN_FQDN='{server_external_fqdn}'
MANAGER_TOKEN='{manager_token}'
MANAGER_ADDRESS='{upstream_auth_address}'
SERVER_ID='{server_id}'
PROVIDER_NAME='{provider_name}'

# Optional agent capabilities — flip these to 'true' in the rendered template
# (or wire through Tofu vars in compute.tf) to enable.
GPU_ENABLED='false'
INSTALL_SYSBOX='false'

##############################################################################
# Static constants
##############################################################################
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"
KASM_DEPLOYMENT_DIR="/opt/kasm/.kasm_deployment"
SWAP_SIZE_GB="16"
INSTALL_PACKAGES="iputils-ping dnsutils netcat-openbsd htop cron vim kmod nfs-common"

CMD='\e[0;34m'
WRN='\e[0;33m'
ERR='\e[0;31m'
OK='\e[0;32m'
NC='\e[0m'

##############################################################################
# Helper functions
##############################################################################
function create_swap() {{
    if [[ -f "/var/lib/docker/swap/kasm.swap" ]]; then
        echo "Swap file already present, skipping create"
    else
        echo "Creating Swap partition"
        mkdir -p /var/lib/docker/swap
        fallocate -l "$${{SWAP_SIZE_GB}}"g /var/lib/docker/swap/kasm.swap
        chmod 600 /var/lib/docker/swap/kasm.swap
        mkswap /var/lib/docker/swap/kasm.swap
        swapon /var/lib/docker/swap/kasm.swap
        echo '/var/lib/docker/swap/kasm.swap swap swap defaults 0 0' | tee -a /etc/fstab
    fi
}}

function install_packages() {{
    local PACKAGES
    IFS=" " read -r -a PACKAGES <<< "$${{1}}"
    echo "Installing Packages: $${{PACKAGES[*]}}"
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        install "$${{PACKAGES[@]}}" -y
}}

function download_kasm() {{
    local tarball
    wget -qP "$${{KASM_DOWNLOAD_FOLDER}}" "$${{KASM_DOWNLOAD_URL}}"
    tarball=$(awk -F '/' '{{print $NF}}' <<< "$${{KASM_DOWNLOAD_URL}}")
    tar xvf "$${{KASM_DOWNLOAD_FOLDER}}/$${{tarball}}" -C "$${{KASM_DOWNLOAD_FOLDER}}"
}}

function install_agent_prereqs() {{
    # Agent base images ship with Docker already installed — first arg "false"
    # tells install_dependencies.sh to skip the Docker install step.
    bash "$${{KASM_DOWNLOAD_FOLDER}}/kasm_release/install_dependencies.sh" "false" "false" "false" "$${{ROLE}}" \
        && echo -e "$${{OK}}Kasm pre-reqs successfully installed$${{NC}}"
}}

##############################################################################
# AWS prep
##############################################################################
if [[ "$${{EUID}}" -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Stop background APT activity for the duration of bootstrap
sed -i 's|APT::Periodic::Unattended-Upgrade "1";|APT::Periodic::Unattended-Upgrade "0";|' /etc/apt/apt.conf.d/20auto-upgrades
systemctl disable apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer --now --no-block || :
systemctl mask apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer || :
systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || :

# Verify instance metadata reachability — supports AWS IMDSv2 and OCI IMDS v2.
# Same link-local IP (169.254.169.254) on both clouds; differs in token/auth scheme and path.
AWS_IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
METADATA_CHECK_AWS=$(curl -s -o /dev/null -w "%%{{http_code}}" -H "X-aws-ec2-metadata-token: $${{AWS_IMDS_TOKEN}}" http://169.254.169.254/latest/meta-data/ 2>/dev/null || echo "000")
if [[ "$${{METADATA_CHECK_AWS}}" != "200" ]]; then
    METADATA_CHECK_OCI=$(curl -s -o /dev/null -w "%%{{http_code}}" -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ 2>/dev/null || echo "000")
    if [[ "$${{METADATA_CHECK_OCI}}" != "200" ]]; then
        echo -e "$${{ERR}}Cloud instance metadata not reachable (tried AWS IMDSv2 and OCI IMDS v2)$${{NC}}"
        exit 1
    fi
fi

# Stage scripts directory
if [[ -d "$${{KASM_DOWNLOAD_FOLDER}}" ]]; then
    rm -f "$${{KASM_DOWNLOAD_FOLDER}}"/kasm_*.tar.gz
    rm -rf "$${{KASM_DOWNLOAD_FOLDER}}/kasm_release"
else
    mkdir -p "$${{KASM_DOWNLOAD_FOLDER}}"
fi

# Install AWS CLI on first boot (skipped if instance is already provisioned from a Kasm-prepped image)
if [[ ! -f "$${{KASM_DEPLOYMENT_DIR}}/image_version" ]]; then
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 install -y unzip jq
    curl -so "$${{KASM_DOWNLOAD_FOLDER}}/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
    unzip -q "$${{KASM_DOWNLOAD_FOLDER}}/awscliv2.zip" -d "$${{KASM_DOWNLOAD_FOLDER}}"
    bash "$${{KASM_DOWNLOAD_FOLDER}}/aws/install" --update
    rm -f "$${{KASM_DOWNLOAD_FOLDER}}/awscliv2.zip"
    rm -rf "$${{KASM_DOWNLOAD_FOLDER}}/aws"
fi

# Wait for any in-flight apt to clear
if pgrep apt > /dev/null; then
    echo -e "$${{CMD}}apt is already running, waiting 30s for the lock to clear$${{NC}}"
    pgrep -a apt
    sleep 30
fi

##############################################################################
# Kasm install prep
##############################################################################
SCRIPT_PATH=$(mktemp -d)
cd "$${{SCRIPT_PATH}}"

# Resolve STIG branch: explicit override > release branch matching version > develop
if [[ -n "$${{KASM_STIG_OVERRIDE}}" ]]; then
    KASM_STIG_URL="$${{KASM_STIG_OVERRIDE}}"
elif curl -sfL https://api.github.com/repos/kasmtech/workspaces-stigs/branches \
        | jq -e ".[].name | select(. == \"release/$${{KASM_VERSION}}\")" &> /dev/null; then
    KASM_STIG_URL="https://raw.githubusercontent.com/kasmtech/workspaces-stigs/refs/heads/release/$${{KASM_VERSION}}"
else
    KASM_STIG_URL="https://raw.githubusercontent.com/kasmtech/workspaces-stigs/refs/heads/develop"
fi

wget -q "$${{KASM_STIG_URL}}/apply_docker_stigs.sh" \
    || echo -e "$${{ERR}}Failed to download apply_docker_stigs.sh$${{NC}}"
wget -qO "$${{KASM_DOWNLOAD_FOLDER}}/apply_kasm_stigs.sh" "$${{KASM_STIG_URL}}/apply_kasm_stigs.sh" \
    || echo -e "$${{ERR}}Failed to download apply_kasm_stigs.sh$${{NC}}"
sed -i "s/^KASM_VERSION=.*/KASM_VERSION=$${{KASM_VERSION}}/" "$${{KASM_DOWNLOAD_FOLDER}}/apply_kasm_stigs.sh"

if [[ ! -f "$${{KASM_DEPLOYMENT_DIR}}/image_version" ]]; then
    install_packages "$${{INSTALL_PACKAGES}}"
fi

# Hotfix CVE-2026-31431 — block algif_aead module loading
echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif.conf
if [[ -f /usr/sbin/rmmod ]]; then
    /usr/sbin/rmmod algif_aead 2>/dev/null || true
else
    echo "WARNING: rmmod not found, cannot remove algif_aead if it has already been loaded"
fi

download_kasm

# Workaround a bug in the rclone Docker plugin where the config/cache dirs
# are not auto-created on agent startup
mkdir -p /var/lib/docker-plugins/rclone/{{config,cache}}

install_agent_prereqs

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

echo 'y' | bash "$${{SCRIPT_PATH}}/apply_docker_stigs.sh" \
    || echo -e "$${{CMD}}Stig script exited with errors$${{NC}}"


##############################################################################
# Role-specific work — agent
##############################################################################
create_swap

# Optional: mount a shared NFS profile store (EFS on AWS, exposed as NFSv4)
if [[ "$${{NFS_ENABLED,,}}" == "true" ]]; then
    mkdir -p "$${{NFS_PROFILE_PATH}}"
    chown 1000:1000 "$${{NFS_PROFILE_PATH}}"
    chmod 777 "$${{NFS_PROFILE_PATH}}"

    while ! nc -w 1 -z "$${{NFS_URL}}" 2049; do
        echo "Waiting for NFS to be available..."
        sleep 5
    done

    echo "Mounting NFS server..."
    mount -t nfs -o vers=4,port=2049,async "$${{NFS_URL}}":/ "$${{NFS_PROFILE_PATH}}"
fi

# Optional: install Sysbox runtime for nested-container workspaces
if [[ "$${{INSTALL_SYSBOX,,}}" == "true" ]]; then
    echo "Installing sysbox"
    mv /etc/docker/daemon.json /etc/docker/daemon.json.old
    SYSBOX_VERSION=$(curl -s https://api.github.com/repos/nestybox/sysbox/releases/latest | awk '/tag_name/{{print $4;exit}}' FS='[""]')
    wget -q "https://downloads.nestybox.com/sysbox/releases/$${{SYSBOX_VERSION}}/sysbox-ce_$${{SYSBOX_VERSION#v}}-0.linux_amd64.deb"
    apt-get install "./sysbox-ce_$${{SYSBOX_VERSION#v}}-0.linux_amd64.deb" -y
    echo -e "$${{OK}}Installed Sysbox version $${{SYSBOX_VERSION}}$${{NC}}"

    sed -i 's|^ExecStart=/usr/bin/sysbox-mgr$|ExecStart=/usr/bin/sysbox-mgr --data-root /var/lib/docker/sysbox|' /lib/systemd/system/sysbox-mgr.service
    systemctl daemon-reload
    systemctl restart sysbox-mgr

    jq '.runtimes += {{"sysbox-runc":{{"path":"/usr/bin/sysbox-runc"}}}}' /etc/docker/daemon.json.old > /etc/docker/daemon.json
    systemctl restart docker

    while ! systemctl is-active --quiet docker; do
        echo "Waiting for docker to restart"
        sleep 2
    done
fi

# Enable redroid (Android-in-container) kernel modules
if ! dpkg -l | grep -q "linux-modules-extra-$(uname -r)"; then
    apt-get update
    apt-get install -y "linux-modules-extra-$(uname -r)"
fi
modprobe binder_linux devices="binder,hwbinder,vndbinder" || true

# Optional: install NVIDIA GPU drivers + container toolkit
if [[ "$${{GPU_ENABLED,,}}" == "true" ]]; then
    echo "Installing GPU utilities"
    # shellcheck source=/dev/null
    wget "https://developer.download.nvidia.com/compute/cuda/repos/$(source /etc/os-release; echo "$${{ID}}$${{VERSION_ID}}" | tr -d '.')/x86_64/cuda-keyring_1.1-1_all.deb"
    dpkg -i cuda-keyring_1.1-1_all.deb
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get -o DPkg::Lock::Timeout=-1 install -y gcc make "linux-headers-$(uname -r)"
    cat <<EOF | tee --append /etc/modprobe.d/blacklist.conf
blacklist vga16fb
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
EOF
    echo 'GRUB_CMDLINE_LINUX="rdblacklist=nouveau"' | tee --append /etc/default/grub
    update-grub
    apt-get -o DPkg::Lock::Timeout=-1 install -y cuda-drivers
    apt-get -o DPkg::Lock::Timeout=-1 install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# Resolve the IP/FQDN to register this agent with the manager
PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
if [[ -z "$${{GIVEN_FQDN}}" ]] || [[ "$${{GIVEN_FQDN,,}}" == "none" ]]; then
    CONNECT_IP="$${{PRIVATE_IP}}"
else
    CONNECT_IP="$${{GIVEN_FQDN}}"
fi

# Wait for manager API healthcheck before registering
while ! curl -k "https://$${{MANAGER_ADDRESS}}/api/__healthcheck" 2>/dev/null | grep -q "true"; do
    echo "Waiting for API server at $${{MANAGER_ADDRESS}}..."
    sleep 5
done

bash "$${{KASM_DOWNLOAD_FOLDER}}/kasm_release/install.sh" \
    -S "$${{ROLE}}" -e \
    -p "$${{CONNECT_IP}}" \
    -M "$${{MANAGER_TOKEN}}" \
    -m "$${{MANAGER_ADDRESS}}" \
    -i "$${{SERVER_ID}}" \
    -r "$${{PROVIDER_NAME}}" \
    "$${{ADDITIONAL_INSTALL_ARGS}}"

##############################################################################
# Firstboot hardening
##############################################################################
SSH_NETWORK_FILE="$${{KASM_DEPLOYMENT_DIR}}/ssh_network"
IPSET_DIR="/etc/iptables"

# Only run network hardening on Kasm base images (gated by docker_set ipset existence)
if ipset list docker_set > /dev/null 2>&1; then
    KASM_NETWORK=$(docker network inspect kasm_default_network | jq -r .[].IPAM.Config[].Subnet)
    KASM_SIDECAR_NETWORK=$(docker network inspect kasm_sidecar_network 2>/dev/null | jq -r .[].IPAM.Config[].Subnet || true)
    DOCKER_NETWORK=$(docker network inspect bridge | jq -r .[].IPAM.Config[].Subnet)

    for net in "$${{KASM_NETWORK}}" "$${{KASM_SIDECAR_NETWORK}}" "$${{DOCKER_NETWORK}}"; do
        if [[ -n "$${{net}}" ]] && ! grep -q "$${{net}}" "$${{IPSET_DIR}}/ipset_docker"; then
            echo "add docker_set $${{net}}" >> "$${{IPSET_DIR}}/ipset_docker"
            sed -i "\|$${{net}}|d" "$${{KASM_DEPLOYMENT_DIR}}/docker_networks" 2>/dev/null || true
        fi
    done

    if [[ -f "$${{KASM_DEPLOYMENT_DIR}}/docker_networks" ]]; then
        iprange --merge "$${{KASM_DEPLOYMENT_DIR}}/docker_networks" 2>/dev/null \
            | while read -r ip; do
                echo "add workspaces_set $${{ip}}" >> "$${{IPSET_DIR}}/ipset_workspaces"
            done
    fi

    if [[ -f "$${{SSH_NETWORK_FILE}}" ]]; then
        while IFS= read -r line; do
            echo "add ssh_set $${{line}}" >> "$${{IPSET_DIR}}/ipset_ssh"
        done < "$${{SSH_NETWORK_FILE}}"
        ipset restore -f "$${{IPSET_DIR}}/ipset_ssh"
    fi

    ipset restore -f "$${{IPSET_DIR}}/ipset_docker"
    ipset restore -f "$${{IPSET_DIR}}/ipset_workspaces"
    netfilter-persistent save

    # Allow the Kasm agent to reach the Docker daemon socket on TCP/2375
    if ! iptables -L INPUT | grep -q "2375"; then
        LOCAL_NET=$(hostname -I | awk '{{print $1}}')
        iptables -I INPUT 2 -p tcp --dport 2375 \
            -m set --match-set docker_set src \
            -d "$${{LOCAL_NET}}"/32 \
            -m comment --comment "Allow Kasm Agent to connect to Docker service" \
            -j ACCEPT
    fi

    /usr/local/bin/cleanup_creds || true
fi

##############################################################################
# OS update
##############################################################################
function update_ubuntu() {{
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
}}

if [[ ! -f "$${{KASM_DEPLOYMENT_DIR}}/image_version" ]]; then
    update_ubuntu
fi

# Re-enable unattended upgrades
sed -i 's|APT::Periodic::Unattended-Upgrade "0";|APT::Periodic::Unattended-Upgrade "1";|' /etc/apt/apt.conf.d/20auto-upgrades
systemctl unmask apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer || :
systemctl enable apt-daily-upgrade apt-daily apt-daily.timer apt-daily-upgrade.timer --no-block --now || :

echo -e "$${{OK}}Agent node bootstrap complete$${{NC}}"
