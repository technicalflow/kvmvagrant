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
    curl \
    gnupg \
    git \
    dialog \
    wget \
    ca-certificates \
    apt-transport-https

if [ $(systemd-detect-virt) == "kvm" ] ; then apt-get install -y qemu-guest-agent && systemctl enable --now serial-getty@ttyS0.service; fi

apt-get autoremove
apt-get purge
apt-get clean

if [ $(hostname) == "dsm" ] ; then sed -i '/address 192.168.50..*/a \      gateway 192.168.50.250' /etc/network/interfaces && systemctl restart networking.service; fi

ip a | grep inet
ip r
echo DONE

# For Ubuntu
# if [ $(hostname) == "dsm" ] ; then mv -f /tmp/50-vagrant.yaml /etc/netplan/50-vagrant.yaml && netplan apply; fi

# Only if communicating from LAN network with VM
# if [ "$(hostname)" = "dsm" ]; then
#   cat <<EOFroute >/tmp/50-vagrant.yaml
# ---
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     eth1:
#       addresses:
#       - 192.168.50.232/24
#       routes:
#       - to: 0.0.0.0/0
#         via: 192.168.50.250
#         metric: 100
#         on-link: true
#     eth2:
#       addresses:
#       - 192.168.60.2/24
# EOFroute
# fi

# if [ "$(hostname)" = "dsm" ]; then
#   mv -f /tmp/50-vagrant.yaml /etc/netplan/50-vagrant.yaml
#   netplan apply
# fi