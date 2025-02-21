#!/bin/bash
# Check required software
apt-get install -y -qq apt-transport-https ca-certificates curl

# Add Docker’s official GPG key
curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | apt-key add -qq

# Set up the stable repo
#add-apt-repository \
#  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#  $(lsb_release -cs) \
#  stable"

echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" >  /etc/apt/sources.list.d/docker.list

# Update the packages
apt-get update

# Install docker-ce
apt-get install --no-install-recommends -y docker-ce
apt-get install -y docker-compose

# Access docker w/o sudo
usermod -aG docker vagrant
systemctl restart docker
service docker restart
docker version
