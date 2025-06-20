#!/bin/bash
rpm --import https://product-repository.ssh.com/info.fi-ssh.com-pubkey.asc
curl https://product-repository.ssh.com/rhel8/ssh-products.repo -o /etc/yum.repos.d/ssh-products.repo
dnf update
dnf install -y postgresql PrivX

# /opt/privx/scripts/postinstall.sh