#!/bin/bash
#!/usr/bin/env bash

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

timedatectl set-timezone Europe/Warsaw

systemctl enable --now serial-getty@ttyS0.service
swapoff -a

#Turn swap off
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo DONE

echo "Install PrivX"
rpm --import https://product-repository.ssh.com/info.fi-ssh.com-pubkey.asc
curl https://product-repository.ssh.com/rhel9/ssh-products.repo -o /etc/yum.repos.d/ssh-products.repo
dnf update
dnf install -y postgresql PrivX

# cat << EOFinstall > /opt/privx/scripts/postinstall_env
# # Variables for postinstall.sh automation.
# export SKIP_POSTINSTALL=TRUE

# # Space-separated DNS names
# # DNS name is mandatory.
# export PRIVX_DNS_NAMES="msksioel9prix01.local"
# # Space-separated IP addresses
# # IP address is optional. Set to " " to disable interactive IP address prompt.
# export PRIVX_IP_ADDRESSES="192.168.50.228"

# # Superuser name
# export PRIVX_SUPERUSER=madmin
# # Superuser password
# export PRIVX_SUPERUSER_PASSWORD=pass
# # Superuser email address
# export PRIVX_SUPERUSER_EMAIL=vadmin@localhost
# # Set to any non-null value to require superuser-password change on first login
# export PRIVX_SUPERUSER_CHANGE_PASSWORD=""

# # Set PrivX to use local database
# export PRIVX_USE_EXTERNAL_DATABASE=0
# # Database name
# export PRIVX_DATABASE_NAME=privxdb100
# # Database-user name
# export PRIVX_DATABASE_USERNAME=privxadmin
# # Database-user password
# export PRIVX_DATABASE_PASSWORD=privxpass

# # Set to 1 to enable pkcs11 keyvault
# export PRIVX_KEYVAULT_PKCS11_ENABLE=0
# # pkcs11 provider type: one of the following types
# #    amazon-cloud-hsm, safenet-network-hsm, softhsm, generic-pkcs11
# export PRIVX_KEYVAULT_PKCS11_TYPE=""
# # pkcs11 provider library file path
# export PRIVX_KEYVAULT_PKCS11_PROVIDER=""
# # pkcs11 slot
# export PRIVX_KEYVAULT_PKCS11_SLOT=0
# # pkcs11 user pin
# export PRIVX_KEYVAULT_PKCS11_PIN=0000
# # pkcs11 features: comma separated list of following keywords
# #   aes-gcm-zero-iv         Supply zero IV for aes gcm encrypt
# #   aes-gcm-luna-random-iv  Use SafeNet Luna AES-GCM random IV
# #   aes-gcm-padding         Pad aes-gcm input to aes blocksize
# #   fips-mode               Restrict supported algorithms and key sizes
# #                           according to FIPS 140-2 level 3 requirements
# #   serialize-ops           Serialize all pkcs#11 operations
# #   disable-object-cache    Disable object handle caching
# export PRIVX_KEYVAULT_PKCS11_FEATURES=""
# # fsvault.encryption_algorithm
# export PRIVX_KEYVAULT_ENCRYPTION_ALG=""

# # Other
# export PRIVX_NTP_SERVER=pool.ntp.org
# EOFinstall

# source /opt/privx/scripts/postinstall_env
# /opt/privx/scripts/postinstall.sh