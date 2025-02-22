#!/bin/bash

#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

timedatectl set-timezone Europe/Warsaw

# Install recommended extra packages
# apt-get update
# apt-get -y upgrade
#apt-get install -y \
#    linux-image-virtual \
#    linux-image-extra-virtual

apt-get install -y \
    gcc \
    make \
    perl \
    curl \
    gnupg \
    ntp \
    ca-certificates \
    apt-transport-https

if [ $(systemd-detect-virt) == "kvm" ] ; then apt-get install -y qemu-guest-agent; fi

apt-get autoremove
apt-get purge
apt-get clean

# apt-get remove virtualbox-guest-utils -y
# sh /vagrant/VBoxLinuxAdditions.run

ip a | grep inet
echo DONE

# Only if communicating from LAN network with VM
cat << EOFroute > /vagrant/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
      - 192.168.50.232/24
      routes:
      - to: 0.0.0.0/0
        via: 192.168.50.250
        metric: 10
        on-link: true
    eth2:
      addresses:
      - 192.168.60.2/24
EOFroute

if [ $(hostname) == "dsm" ] ; then mv -f /vagrant/50-vagrant.yaml /etc/netplan/50-vagrant.yaml; fi
netplan apply