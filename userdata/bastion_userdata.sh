#!/bin/bash

set -euo pipefail

export NEEDRESTART_MODE=l
export DEBIAN_FRONTEND=noninteractive

##############################################################################
# Tofu-templated variables (rendered by templatefile())
##############################################################################
ROLE="bastion"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
IMAGE_TYPE='${IMAGE_TYPE}'
MANAGEMENT_SSH_PRIVATE_KEY='${MANAGEMENT_SSH_PRIVATE_KEY}'
AGENT_SSH_PRIVATE_KEY='${AGENT_SSH_PRIVATE_KEY}'

##############################################################################
# Static constants
##############################################################################
DEPLOYMENT_DATE=$(date +"Date: %Y-%m-%d / Time: %T")
KASM_DEPLOYMENT_DIR="/opt/kasm/.kasm_deployment"

ERR='\e[0;31m'
OK='\e[0;32m'
NC='\e[0m'

##############################################################################
# Setup
##############################################################################
if [[ "$${EUID}" -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Resolve user / group / .ssh directory based on AMI flavor.
# (Bastion is a jumphost — it does not run Kasm services or join the Kasm cluster.)
case "$${IMAGE_TYPE}" in
    ubuntu | kasm_ubuntu)
        SSH_FOLDER="/home/ubuntu/.ssh"
        SSH_USER="ubuntu"
        SSH_GROUP="ubuntu"
        apt-get -o DPkg::Lock::Timeout=-1 update
        apt-get -o DPkg::Lock::Timeout=-1 \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            install -y iputils-ping dnsutils netcat-openbsd htop iftop nmap nano cron vim
        apt-get -o DPkg::Lock::Timeout=-1 \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            upgrade -y
        ;;
    al2 | kasm_al2)
        SSH_FOLDER="/home/ec2-user/.ssh"
        SSH_USER="ec2-user"
        SSH_GROUP="ec2-user"
        dnf update -y
        dnf install -y --skip-broken iputils-ping bind-utils nmap-ncat htop iftop nmap
        ;;
    oracle | kasm_oracle)
        SSH_FOLDER="/home/opc/.ssh"
        SSH_USER="opc"
        SSH_GROUP="opc"
        dnf update -y
        dnf install -y --skip-broken iputils-ping bind-utils nmap-ncat htop iftop nmap
        ;;
    *)
        echo -e "$${ERR}Unknown IMAGE_TYPE: $${IMAGE_TYPE}$${NC}"
        exit 1
        ;;
esac

# Login banner / role marker files
mkdir -p "$${KASM_DEPLOYMENT_DIR}"
mkdir -p "/opt/kasm/$${KASM_VERSION}"
ln -sf "/opt/kasm/$${KASM_VERSION}" /opt/kasm/current
echo "$${ROLE}"            > "$${KASM_DEPLOYMENT_DIR}/kasm_role"
echo "$${CUSTOMER_NAME}"   > "$${KASM_DEPLOYMENT_DIR}/customer"
echo "$${KASM_VERSION}"    > "$${KASM_DEPLOYMENT_DIR}/kasm_version"
echo "$${CUSTOMER_ENV}"    > "$${KASM_DEPLOYMENT_DIR}/deployment_domain"
echo "$${DEPLOYMENT_DATE}" > "$${KASM_DEPLOYMENT_DIR}/deployment_date"
echo "$${DEPLOYMENT_TYPE}" > "$${KASM_DEPLOYMENT_DIR}/deployment_type"

# Drop SSH private keys for management + agent SSH access from this jumphost
mkdir -p "$${SSH_FOLDER}"
echo "$${MANAGEMENT_SSH_PRIVATE_KEY}" | base64 -d > "$${SSH_FOLDER}/id_rsa"
chmod 600 "$${SSH_FOLDER}/id_rsa"
echo "$${AGENT_SSH_PRIVATE_KEY}" | base64 -d > "$${SSH_FOLDER}/agent.key"
chmod 600 "$${SSH_FOLDER}/agent.key"
chown -R "$${SSH_USER}:$${SSH_GROUP}" "$${SSH_FOLDER}/"

echo -e "$${OK}Bastion node bootstrap complete$${NC}"
