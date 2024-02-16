#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

#!/usr/bin/env bash

# disabled becouse of ansible provisioning
# sudo apt-get update
# sudo apt-get -y upgrade

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
sudo apt-get install -y \
    gcc \
    make \
    curl \

if [ $(systemd-detect-virt) == "kvm" ] ; then sudo apt install -y qemu-guest-agent; fi

# Turn swap off
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo swapoff -a
sudo systemctl stop swap.target
sudo systemctl disable swap.target

uname -a
hostname

echo DONE
