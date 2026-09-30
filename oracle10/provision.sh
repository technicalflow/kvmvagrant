#!/bin/bash

# ==============================================================================
# FreeIPA Server Installation & Configuration Script for Oracle Linux 10
# ==============================================================================

set -e

IPA_DOMAIN="home.lab"
IPA_REALM="HOME.LAB"
# IPA_HOSTNAME=""
IPA_HOSTNAME_FQDN="$IPA_HOSTNAME.$IPA_DOMAIN"
# IPA_IP_ADDRESS=""
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

# ipa user-add brian --password - -homedir=/home/brian --shell=/bin/bash
# ipa host-add testvm.home.lab -force -ip-address=10.127.0.211 -password=simplepassword1

# On Ubuntu join to FreeIPA server:
# sudo apt update && sudo apt install freeipa-client
# sudo ipa-client-install --mkhomedir 

# Or automated on host with OTP:
# ipa host-add testvm.home.lab -force -ip-address=10.127.0.211 -password=simplepassword1
# and on the client machine:
# sudo ipa-client-install --password=simplepassword1 --mkhomedir

# ipa help topics
# ipa user-show user1 --all --raw

# Add FreeIPA Replica
# ipa-client-install --domain=corp.internal --realm=CORP.INTERNAL
# first
# kinit admin
# ipa-replica-install --setup-ca --setup-dns --auto-forwarders

# Check:
# ipa server-find
# ipa topologysuffix-show domain
# ipa topologysegment-find domain
# ipa topologysegment-add domain ipal-to-ipa3 ipa1.corp.internal ipa3.corp.internal
# ipa topologysuffix-verify domain

# Unbound configuration for FreeIPA DNS 
# server:
#     # internal is unsigned; without this, DNSSEC validation marks it bogus
#     domain-insecure: "corp.internal"
#     domain-insecure: "10.in-addr.arpa"
#     # allow private IPs in answers for these domains (rebind protection)
#     private-domain: "corp.internal"


# forward-zone:
#     name: "corp.internal."
#     # forward to the FreeIPA servers
#     forward-addr: 10.0.0.11 #FreeIPA server IP address
#     forward-addr: 10.0.0.12 #FreeIPA 2nd server IP address

# forward-zone:
#     name: "0.0.10.in-addr.arpa." #match your actual reverse zone(s)
#     forward-addr: 10.0.0.11
#     forward-addr: 10.0.0.12

# # The FreeBSD mail host isn't an IPA client, so nothing registers it automatically:
# ipa dnsrecord-add corp.internal mail --a-rec=10.0.0.25 --a-create-reverse
# ipa dnsrecord-add corp.internal @ --mx-rec="10 mail.corp.internal."
# # Optional but useful: RFC 6186 SRV records so mail clients can autoconfigure.
# ipa dnsrecord-add corp.internal _imaps._tcp --srv-rec="0 1 993 mail.corp.internal."
# ipa dnsrecord-add corp. internal _submission._top --srv-rec="0 1 587 mail.corp.internal."