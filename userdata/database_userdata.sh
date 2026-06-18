#!/bin/bash

set -e
export PATH+=":/root/.local/bin/"

# Required config
BLOCK_DEVICE='${BLOCK_DEVICE}'
ROLE="db"
DEPLOYMENT_TYPE='${DEPLOYMENT_TYPE}'
KASM_VERSION='${KASM_VERSION}'
CUSTOMER_NAME='${CUSTOMER_NAME}'
CUSTOMER_ENV='${CUSTOMER_ENV}'
KASM_DOWNLOAD_URL='${KASM_DOWNLOAD_URL}'
WAZUH_JOIN_GROUP="Linux_customers"

# Role config
GRAFANA_FULL_METRICS='${GRAFANA_FULL_METRICS}'
KASM_DB_PASS='${KASM_DB_PASS}'
KASM_USER_PASS='${KASM_USER_PASS}'
KASM_ADMIN_PASS='${KASM_ADMIN_PASS}'
KASM_MANAGER_TOKEN='${KASM_MANAGER_TOKEN}'
KASM_SERVICE_TOKEN='${KASM_SERVICE_TOKEN}'
ADDITIONAL_INSTALL_ARGS='${ADDITIONAL_DATABASE_INSTALL_ARGS}'
BUCKET_NAME='${BUCKET_NAME}'
BUCKET_NAMESPACE='${BUCKET_NAMESPACE}'
BUCKET_REGION="us-ashburn-1"
BACKUP_BUCKET_DIR_NAME='${BACKUP_BUCKET_DIR_NAME}'
CUSTOM_PROPERTIES_FILENAME='${CUSTOM_PROPERTIES_FILENAME}'
DB_CONNECTIONS='${DB_CONNECTIONS}'
DB_INIT_OVERRIDE='${DB_INIT_OVERRIDE}'

# "Static" config
BASE_SCRIPTS_URL="https://kasm-static-content.s3.amazonaws.com/engineering"
KASM_DOWNLOAD_FOLDER="/opt/kasm/scripts"
VOLUME_MOUNT_PATH="/opt/kasm"

## Override stig script location
KASM_STIG_URL="${KASM_STIG_OVERRIDE}"

# Handle switches
CORE_SWITCHES=()
if [[ "$${GRAFANA_FULL_METRICS,,}" = 'true' ]]; then CORE_SWITCHES+=("-G"); fi
if [ ! -z "$${KASM_STIG_URL}" ]; then CORE_SWITCHES+=("--stig" "$${KASM_STIG_URL}"); fi

while ! test -b "/dev/$${BLOCK_DEVICE}"; do
    echo "Waiting for $${BLOCK_DEVICE} to become available..."
    sleep 5
done

echo -e "Mounting block volume storage to $${VOLUME_MOUNT_PATH}"

if [ -d /opt/kasm/.kasm_deployment/ ]; then cp -a /opt/kasm/.kasm_deployment/ /tmp; fi

## Partition and Mount NFS Block Volume
if [[ $(lsblk -f | grep "$${BLOCK_DEVICE}" | awk -F ' ' '{print $2}') != 'xfs' ]]; then
    mkfs.xfs -f "/dev/$${BLOCK_DEVICE}"
fi

mkdir -p "$${VOLUME_MOUNT_PATH}"
echo "/dev/$${BLOCK_DEVICE} $${VOLUME_MOUNT_PATH} xfs defaults,_netdev,nofail 0 2" >> /etc/fstab
mount -a

if [ -d /tmp/.kasm_deployment ]; then cp -a /tmp/.kasm_deployment /opt/kasm/; fi

if [ $(ls "$${VOLUME_MOUNT_PATH}/db/data" | wc -l) -gt "0" ]; then
  EXISTING_DB='true'
else
  EXISTING_DB='false'
fi

if [[ "$${DB_INIT_OVERRIDE,,}" = 'false' ]] && [[ "$${EXISTING_DB,,}" = 'true' ]]; then
  echo -e "\nExisting database detected. Skipping database initialization....\n"
  DB_ARGS=("-d")
else
  echo -e "\nNo existing database detected. Proceeding with initialization....\n"
  DB_ARGS=("-Q" "$${KASM_DB_PASS}" "-U" "$${KASM_USER_PASS}" "-P" "$${KASM_ADMIN_PASS}" "-M" "$${KASM_MANAGER_TOKEN}" "-k" "$${KASM_SERVICE_TOKEN}")
fi

## Download necessary scripts
mkdir -p "$${KASM_DOWNLOAD_FOLDER}"
cd "$${KASM_DOWNLOAD_FOLDER}" || exit 1
wget -qO "$${KASM_DOWNLOAD_FOLDER}/core.sh" "$${BASE_SCRIPTS_URL}/startup-scripts/core.sh"

# Run startup script
bash "$${KASM_DOWNLOAD_FOLDER}/core.sh" -r "$${ROLE}" -t "$${DEPLOYMENT_TYPE}" -v "$${KASM_VERSION}" -n "$${CUSTOMER_NAME}" -e "$${CUSTOMER_ENV}" -s "$${BASE_SCRIPTS_URL}" -W "$${WAZUH_JOIN_GROUP}" -k "$${KASM_DOWNLOAD_URL}" -f "$${KASM_DOWNLOAD_FOLDER}" -V "$${VOLUME_MOUNT_PATH}" "$${CORE_SWITCHES[@]}"


# Run pre-install role script
bash "$${KASM_DOWNLOAD_FOLDER}/db-pre.sh" -c "$${CUSTOM_PROPERTIES_FILENAME}" -n "$${BUCKET_NAME}" -r "$${BUCKET_REGION}" -s "$${BUCKET_NAMESPACE}" -f "$${KASM_DOWNLOAD_FOLDER}"

# Install kasm
echo "Stopping db_utils script from wiping out docker volume...."
sed -i "/Installing Database Role/a sed -i -e '/volume rm/d; /volume create/d' /opt/kasm/$${KASM_VERSION}/bin/utils/db_init" "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh" 

bash "$${KASM_DOWNLOAD_FOLDER}/kasm_release/install.sh" -S "$${ROLE}" -e -H "$${DB_ARGS[@]}" "$${ADDITIONAL_INSTALL_ARGS}"

# Run post-install role script
bash "$${KASM_DOWNLOAD_FOLDER}/db-post.sh" -b "$${BACKUP_BUCKET_DIR_NAME}" -n "$${BUCKET_NAME}" -r "$${BUCKET_REGION}" -s "$${BUCKET_NAMESPACE}" -c "$${DB_CONNECTIONS}"

# Hardening script(s)
bash "$${KASM_DOWNLOAD_FOLDER}/firstboot.sh" -f "$${KASM_DOWNLOAD_FOLDER}"

# Update OS
bash "$${KASM_DOWNLOAD_FOLDER}/update_os.sh"
