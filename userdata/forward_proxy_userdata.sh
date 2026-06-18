#!/bin/bash

## Install useful packages
if [[ ${IMAGE_TYPE} =~ "ubuntu" ]]
then
  apt-get -o DPkg::Lock::Timeout=-1 update && \
  apt-get -o DPkg::Lock::Timeout=-1 install -y \
    iputils-ping \
    dnsutils \
    netcat
elif [[ ${IMAGE_TYPE} =~ "al2" ]]
then
  dnf update -y && \
  dnf install -y --skip-broken \
    iputils-ping \
    dnsutils \
    netcat
fi
