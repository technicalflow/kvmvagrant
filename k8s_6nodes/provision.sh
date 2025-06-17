#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

timedatectl set-timezone Europe/Warsaw

apt-get install -y \
    gcc \
    make \
    perl \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    gpg \
    jq

if [ $(systemd-detect-virt) == "kvm" ] ; then apt-get install -y qemu-guest-agent; fi

apt-get purge
apt-get autoremove -y
apt-get clean
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

swapoff -a
systemctl stop swap.target
systemctl disable swap.target

modprobe br_netfilter
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.ipv4.ip_forward=1
touch /etc/sysctl.d/10-kubernetes.conf
tee /etc/sysctl.d/10-kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.ip_unprivileged_port_start=80
vm.swappiness=10
fs.aio-max-nr=524288
kernel.keys.maxbytes=2000000
kernel.keys.maxkeys=2000
vm.max_map_count=262144
EOF

sysctl --system

ip a | grep inet
echo DONE

# Only if communicating from LAN network with VM on Ubuntu 18.04
# cat << EOFroute > /vagrant/50-vagrant.yaml
# ---
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     eth1:
#       addresses:
#       - 192.168.50.238/24
#       routes:
#       - to: 0.0.0.0/0
#         via: 192.168.50.250
#         metric: 10
#         on-link: true
#     eth2:
#       addresses:
#       - 192.168.63.2/24
# EOFroute

# if [ $(hostname) == "k8smaster" ] ; then mv -f /vagrant/50-vagrant.yaml /etc/netplan/50-vagrant.yaml && netplan apply; fi

# For Debian12 to communicate from LAN network with VM
if [ "$(hostname)" == "k8sm1" ] ; then sed -i '/      address 192.168.50.238/a\      gateway 192.168.50.250\n      up ip addr add 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10\n      down ip addr del 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10' /etc/network/interfaces && systemctl restart networking.service && sleep 5; fi
if [ "$(hostname)" == "k8sm2" ] ; then sed -i '/      address 192.168.50.239/a\      gateway 192.168.50.250\n      up ip addr add 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10\n      down ip addr del 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10' /etc/network/interfaces && systemctl restart networking.service && sleep 5; fi
if [ "$(hostname)" == "k8sm3" ] ; then sed -i '/      address 192.168.50.240/a\      gateway 192.168.50.250\n      up ip addr add 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10\n      down ip addr del 192.168.50.0/24 dev $IFACE label $IFACE:0 metric 10' /etc/network/interfaces && systemctl restart networking.service && sleep 5; fi
