#!/bin/bash

set -e

# Required config
ROLE="proxy"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
IS_DEV='${IS_DEV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
WAZUH_JOIN_GROUP="Linux_customers"

# Role config
GRAFANA_FULL_METRICS='false'
MANAGER_ADDRESS='${PUBLIC_LB_HOSTNAME}'
REGION_PROXY_DOMAIN_NAME='${REGION_PROXY_DOMAIN_NAME}'
ADDITIONAL_INSTALL_ARGS="-O"

# "Static" config
BASE_SCRIPTS_URL="https://kasm-static-content.s3.amazonaws.com/engineering"
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"

## Override stig script location
KASM_STIG_URL="${KASM_STIG_OVERRIDE}"

# Handle switches
CORE_SWITCHES=()
if [[ "$${GRAFANA_FULL_METRICS,,}" = 'true' ]]; then CORE_SWITCHES+=("-G"); fi
if [ ! -z "$${KASM_STIG_URL}" ]; then CORE_SWITCHES+=("--stig" "$${KASM_STIG_URL}"); fi

## Download necessary scripts
mkdir -p "$${KASM_DOWNLOAD_FOLDER}"
cd "$${KASM_DOWNLOAD_FOLDER}" || exit 1
wget -qO "$${KASM_DOWNLOAD_FOLDER}/core.sh" "$${BASE_SCRIPTS_URL}/startup-scripts/core.sh"

if [[ "$${IS_DEV,,}" = 'true' ]]; then
    sed -i "s|^MASTER_SECRET_ID=.*|MASTER_SECRET_ID='ocid1.vaultsecret.oc1.iad.amaaaaaadulgmtqasyzhavj7q7jvrqanob5ykmgwmnlwi5mo4ufpqi3caskq'|" "$${KASM_DOWNLOAD_FOLDER}/core.sh"
fi

# Run startup script
bash "$${KASM_DOWNLOAD_FOLDER}/core.sh" -r "$${ROLE}" -t "$${DEPLOYMENT_TYPE}" -v "$${KASM_VERSION}" -n "$${CUSTOMER_NAME}" -e "$${CUSTOMER_ENV}" -s "$${BASE_SCRIPTS_URL}" -W "$${WAZUH_JOIN_GROUP}" -k "$${KASM_DOWNLOAD_URL}" -f "$${KASM_DOWNLOAD_FOLDER}" "$${CORE_SWITCHES[@]}"

while ! (curl -k "https://$${MANAGER_ADDRESS}/api/__healthcheck" 2>/dev/null | grep -q "true"); do
    echo "Waiting for API server at $${MANAGER_ADDRESS}..."
    sleep 5
done

# Install Kasm
bash "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh"  -S "$${ROLE}" -e -H -p "$${REGION_PROXY_DOMAIN_NAME}" -n "$${MANAGER_ADDRESS}" "$${ADDITIONAL_INSTALL_ARGS}"

# Hardening script(s)
bash "$${KASM_DOWNLOAD_FOLDER}/firstboot.sh" -f "$${KASM_DOWNLOAD_FOLDER}"

# Update OS
bash "$${KASM_DOWNLOAD_FOLDER}/update_os.sh"