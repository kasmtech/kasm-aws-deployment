#!/bin/bash

set -eux

ROLE="bastion"
DEPLOYMENT_DATE=$(date +"Date: %Y-%m-%d / Time: %T")
DEPLOYMENT_TYPE="${KASM_DEPLOYMENT_TYPE}"
KASM_VERSION="${KASM_DEPLOYMENT_VERSION}"
CUSTOMER="${PROJECT_NAME}"

## Teleport join info
TELEPORT_JOIN_TOKEN="${TELEPORT_TOKEN}"
TELEPORT_DOMAIN="${TELEPORT_DOMAIN_NAME}"
TELEPORT_CA_PIN="${TELEPORT_CA}"
TELEPORT_NODE_NAME="${NODE_NAME}"
TELEPORT_CONFIG_FILE_NAME="/etc/teleport-node.yaml"
PRIVATE_IP=$(hostname -I | cut -d' ' -f1)

## Wazuh join info
WAZUH_JOIN_TOKEN="${WAZUH_TOKEN}"
WAZUH_SERVICE_URL="${WAZUH_URL}"
WAZUH_JOIN_GROUP="${WAZUH_GROUP}"
WAZUH_CONFIG_FILE="/var/ossec/etc/ossec.conf"
WAZUH_PASSWORD_FILE="/var/ossec/etc/authd.pass"

## Resolve a bug in the v. 1.0.0 and v1.0.1 images with the firstboot script
if [ -f /opt/kasm/.kasm_deployment/image_version ]
then
  IMAGE_VERSION=$(cat /opt/kasm/.kasm_deployment/image_version)

  if [[ "$${IMAGE_VERSION}" =~ 1.0.0 ]]
  then
    sed -i '35d;36d' /usr/local/bin/firstboot
    systemctl restart firstboot
  elif [[ "$${IMAGE_VERSION}" =~ 1.0.1 ]]
  then
    sed -i '68 {s/^/#/}' /usr/local/bin/firstboot
    systemctl restart firstboot
  elif [[ "$${IMAGE_VERSION}" =~ 1.1.3 ]]
  then
    sed -i '24i\\n  <auth>\n    <disabled>no</disabled>\n    <use_password>yes</use_password>\n    <force>\n      <enabled>yes</enabled>\n    </force>\n  </auth>' /var/ossec/etc/ossec.conf
  fi
fi

## Provision Teleport so firstboot script finializes setup
if [ -n "$${TELEPORT_JOIN_TOKEN}" ]
then
  echo "$${TELEPORT_JOIN_TOKEN}" > /var/lib/teleport/token
  mkdir -p /etc/teleport.d
  echo "node" > /etc/teleport.d/role.node
  sed -i "s/{{CA_PIN}}/$${TELEPORT_CA_PIN}/" "$${TELEPORT_CONFIG_FILE_NAME}"
  sed -i "s/{{NODE_NAME}}/$${TELEPORT_NODE_NAME}/" "$${TELEPORT_CONFIG_FILE_NAME}"
  sed -i "s/{{PRIVATE_IP}}/$${PRIVATE_IP}/" "$${TELEPORT_CONFIG_FILE_NAME}"

  mv "$${TELEPORT_CONFIG_FILE_NAME}" /etc/teleport.yaml
  systemctl enable teleport.service
  systemctl start teleport.service
fi

if [ -n "$${WAZUH_JOIN_TOKEN}" ]
then
  ## Set Wazuh agent password
  echo "$${WAZUH_JOIN_TOKEN}" > "$${WAZUH_PASSWORD_FILE}"
  chmod 640 "$${WAZUH_PASSWORD_FILE}"
  chown root:wazuh "$${WAZUH_PASSWORD_FILE}"

  ## Configure Wazuh join info
  sed -i "s/{{WAZUH_URL}}/$${WAZUH_SERVICE_URL}/" "$${WAZUH_CONFIG_FILE}"
  sed -i "s/{{NODE_NAME}}/$${TELEPORT_NODE_NAME}/" "$${WAZUH_CONFIG_FILE}"
  sed -i "s/{{WAZUH_GROUP}}/$${WAZUH_JOIN_GROUP}/" "$${WAZUH_CONFIG_FILE}"
fi

function update_ubuntu () {
    apt-get -o DPkg::Lock::Timeout=-1 update
    apt-get -o DPkg::Lock::Timeout=-1 install \
        iputils-ping \
        dnsutils \
        netcat \
        htop \
        iftop \
        nmap -y
    export DEBIAN_FRONTEND=noninteractive ; apt-get upgrade -y -o DPkg::Lock::Timeout=-1 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
}

function update_rhel () {
    dnf update -y && \
    dnf install -y --skip-broken \
        iputils-ping \
        dnsutils \
        netcat \
        htop \
        iftop \
        nmap
}

case "${IMAGE_TYPE}" in
  ubuntu | kasm_ubuntu)
    FOLDER="/home/ubuntu/.ssh"
    USER=ubuntu
    GROUP=ubuntu
    update_ubuntu
    mkdir -p /opt/kasm/.kasm_deployment
    mkdir -p /opt/kasm/"$${KASM_VERSION}"
    ln -sf /opt/kasm/"$${KASM_VERSION}" /opt/kasm/current
    echo "$${ROLE}" >/opt/kasm/.kasm_deployment/kasm_role
    echo "$${CUSTOMER}" >/opt/kasm/.kasm_deployment/customer
    echo "$${DEPLOYMENT_DATE}" >/opt/kasm/.kasm_deployment/deployment_date
    echo "$${DEPLOYMENT_TYPE}" >/opt/kasm/.kasm_deployment/deployment_type
    chmod 755 /var/lib/docker
    chmod 644 /var/log/kern.log
    ;;
  al2 | kasm_al2)
    FOLDER="/home/ec2-user/.ssh"
    USER=ec2-user
    GROUP=ec2-uesr
    update_rhel
    ;;
  oracle | kasm_oracle)
    FOLDER="/home/opc/.ssh"
    USER=opc
    GROUP=opc
    update_rhel
    ;;
esac

mkdir -p "$${FOLDER}"
# Copy Management SSH key to Bastion host
echo "${MANAGEMENT_SSH_PRIVATE_KEY}" | base64 -d > "$${FOLDER}"/id_rsa
chmod 600 "$${FOLDER}"/id_rsa

# Copy Agent SSH key to Bastion host
echo "${AGENT_SSH_PRIVATE_KEY}" | base64 -d > "$${FOLDER}"/agent.key
chmod 600 "$${FOLDER}"/agent.key
chown -R "$${USER}":"$${GROUP}" "$${FOLDER}"/
