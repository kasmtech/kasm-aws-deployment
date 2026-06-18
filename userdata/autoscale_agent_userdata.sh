#!/bin/bash

set -e

# Required config
ROLE="agent"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
IS_DEV='${IS_DEV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
WAZUH_JOIN_GROUP="Linux_customers"

# Role config
GRAFANA_FULL_METRICS='false'
GPU_ENABLED='false'
INSTALL_SYSBOX='false'
NFS_ENABLED='${NFS_ENABLED}'
NFS_URL='${NFS_URL}'
NFS_PROFILE_PATH='${NFS_PROFILE_PATH}'
SWAP_SIZE_GB='16'
GIVEN_FQDN='{server_external_fqdn}'
MANAGER_TOKEN='{manager_token}'
MANAGER_ADDRESS='{upstream_auth_address}'
SERVER_ID='{server_id}'
PROVIDER_NAME='{provider_name}'
ADDITIONAL_INSTALL_ARGS="-O"

# "Static" config
PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
BASE_SCRIPTS_URL="https://kasm-static-content.s3.amazonaws.com/engineering"
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"

## Override stig script location
KASM_STIG_URL="${KASM_STIG_OVERRIDE}"

# Handle switches
CORE_SWITCHES=()
if [[ "$${GRAFANA_FULL_METRICS,,}" = 'true' ]]; then CORE_SWITCHES+=("-G"); fi
if [ ! -z "$${KASM_STIG_URL}" ]; then CORE_SWITCHES+=("--stig" "$${KASM_STIG_URL}"); fi

AGENT_SWITCHES=()
if [[ "$${{NFS_ENABLED,,}}" = 'true' ]]; then AGENT_SWITCHES+=("-N"); fi
if [[ "$${{GPU_ENABLED,,}}" = 'true' ]]; then AGENT_SWITCHES+=("-g"); fi
if [[ "$${{INSTALL_SYSBOX,,}}" = 'true' ]]; then AGENT_SWITCHES+=("-y"); fi

## Download necessary scripts
mkdir -p "$${{KASM_DOWNLOAD_FOLDER}}"
cd "$${{KASM_DOWNLOAD_FOLDER}}" || exit 1
wget -qO "$${{KASM_DOWNLOAD_FOLDER}}/core.sh" "$${{BASE_SCRIPTS_URL}}/startup-scripts/core.sh"

if [[ "$${{IS_DEV,,}}" = 'true' ]]; then
    sed -i "s|^MASTER_SECRET_ID=.*|MASTER_SECRET_ID='ocid1.vaultsecret.oc1.iad.amaaaaaadulgmtqasyzhavj7q7jvrqanob5ykmgwmnlwi5mo4ufpqi3caskq'|" "$${{KASM_DOWNLOAD_FOLDER}}/core.sh"
fi

# Run startup script
bash "$${{KASM_DOWNLOAD_FOLDER}}/core.sh" -r "$${{ROLE}}" -t "$${{DEPLOYMENT_TYPE}}" -v "$${{KASM_VERSION}}" -n "$${{CUSTOMER_NAME}}" -e "$${{CUSTOMER_ENV}}" -S "$${{SWAP_SIZE_GB}}" -s "$${{BASE_SCRIPTS_URL}}" -W "$${{WAZUH_JOIN_GROUP}}" -k "$${{KASM_DOWNLOAD_URL}}" -f "$${{KASM_DOWNLOAD_FOLDER}}" "$${{CORE_SWITCHES[@]}}"

# Run role script
if [[ -n "$${{AGENT_SWITCHES[*]}}" ]]; then
    bash "$${{KASM_DOWNLOAD_FOLDER}}/agent.sh" -u "$${{NFS_URL}}" -p "$${{NFS_PROFILE_PATH}}" "$${{AGENT_SWITCHES[@]}}"
fi

## Get Agent IP for Kasm registration
if [[ -z "$${{GIVEN_FQDN}}" ]] || [[ "$${{GIVEN_FQDN,,}}" == "none" ]]; then CONNECT_IP="$${{PRIVATE_IP}}"; else CONNECT_IP="$${{GIVEN_FQDN}}"; fi

while ! (curl -k "https://$${{MANAGER_ADDRESS}}/api/__healthcheck" 2>/dev/null | grep -q "true"); do
    echo "Waiting for API server at $${{MANAGER_ADDRESS}}..."
    sleep 5
done

# Install Kasm
bash "$${{KASM_DOWNLOAD_FOLDER}}/kasm_release/install.sh" -S "$${{ROLE}}" -e -p "$${{CONNECT_IP}}" -M "$${{MANAGER_TOKEN}}" -m "$${{MANAGER_ADDRESS}}" -i "$${{SERVER_ID}}" -r "$${{PROVIDER_NAME}}" "$${{ADDITIONAL_INSTALL_ARGS}}"

# Hardening script(s)
bash "$${{KASM_DOWNLOAD_FOLDER}}/firstboot.sh" -f "$${{KASM_DOWNLOAD_FOLDER}}"

# Update OS
bash "$${{KASM_DOWNLOAD_FOLDER}}/update_os.sh"