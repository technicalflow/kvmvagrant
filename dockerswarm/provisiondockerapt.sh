#!/bin/bash

# # For Ubuntu 20.04 and later
# curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | gpg --dearmor -o /usr/share/keyrings/docker-keyring.gpg
# echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list


# Add Docker's official GPG key:
# install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
# Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Update the packages
apt-get update 

# Install Docker Engine, containerd, and Docker Compose
apt-get install --no-install-recommends -y docker-ce docker-buildx-plugin docker-compose-plugin

# Access docker w/o sudo
usermod -aG docker vagrant
usermod -aG docker madmin

systemctl restart docker.service
# service docker restart
docker version
