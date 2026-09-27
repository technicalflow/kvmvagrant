#!/bin/bash

# ==============================================================================
# FreeIPA Server Installation & Configuration Script for Oracle Linux 10
# ==============================================================================

set -e

IPA_DOMAIN="home.lab"
IPA_REALM="HOME.LAB"
IPA_HOSTNAME="msklaol10fipa01"
IPA_HOSTNAME_FQDN="$IPA_HOSTNAME.$IPA_DOMAIN"
IPA_IP_ADDRESS="192.168.50.50"
DNS_FORWARDER="9.9.9.9"
DIR_MANAGER_PASSWORD="simplepassword1"
ADMIN_PASSWORD="simplepassword1"

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

hostnamectl set-hostname "${IPA_HOSTNAME_FQDN}"

timedatectl set-timezone Europe/Warsaw
timedatectl set-ntp yes

rm -f /etc/resolv.conf
cat << EOF > /etc/resolv.conf
nameserver ${DNS_FORWARDER}
search ${IPA_DOMAIN}
EOF

#Turn swap off
swapoff -a
systemctl stop swap.target
systemctl mask swap.target
sed -i '/swap/s/^/#/' /etc/fstab

# Remove any existing entry for the hostname to avoid conflicts
sed -i "/${IPA_HOSTNAME_FQDN}/d" /etc/hosts
echo "${IPA_IP_ADDRESS} ${IPA_HOSTNAME_FQDN} ${IPA_HOSTNAME}" >> /etc/hosts

systemctl disable --now systemd-resolved || true
rm -f /etc/resolv.conf
cat << EOF > /etc/resolv.conf
nameserver ${DNS_FORWARDER}
search ${IPA_DOMAIN}
EOF

dnf update -y
dnf install -y ipa-server ipa-server-dns bind-dyndb-ldap

systemctl enable firewalld --now

# Add FreeIPA services to the firewall
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=freeipa-ldap
firewall-cmd --permanent --add-service=freeipa-ldaps
firewall-cmd --permanent --add-service=dns
firewall-cmd --permanent --add-service=ntp
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=kerberos
firewall-cmd --permanent --add-service=kadmin

firewall-cmd --reload

ipa-server-install \
    --unattended \
    --realm="${IPA_REALM}" \
    --domain="${IPA_DOMAIN}" \
    --ds-password="${DIR_MANAGER_PASSWORD}" \
    --admin-password="${ADMIN_PASSWORD}" \
    --hostname="${IPA_HOSTNAME_FQDN}" \
    --ip-address="${IPA_IP_ADDRESS}" \
    --setup-dns \
    --auto-forwarders \
    --forwarder="${DNS_FORWARDER}" \
    --auto-reverse \
    --no-host-dns

echo "=============================================================================="
echo "FreeIPA Installation Completed Successfully!"
echo "=============================================================================="
echo "Admin Web UI: https://${IPA_HOSTNAME_FQDN}/ipa/ui"
echo "Username: admin"
echo "Password: ${ADMIN_PASSWORD}"
echo ""
echo "Please remember to obtain a Kerberos ticket before using CLI tools:"
echo "kinit admin"
echo "=============================================================================="
