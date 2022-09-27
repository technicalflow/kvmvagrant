#!/bin/bash
# Check required software
apt-get install -y -qq apt-transport-https ca-certificates curl

# Add Docker’s official GPG key
curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo apt-key add -qq

# Set up the stable repo
#sudo add-apt-repository \
#  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#  $(lsb_release -cs) \
#  stable"

echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" > /etc/apt/sources.list.d/docker.list

# Update the packages
sudo apt-get update

# Install docker-ce
sudo apt-get install --no-install-recommends -y docker-ce
sudo apt-get install -y docker-compose

# Access docker w/o sudo
sudo usermod -aG docker vagrant
sudo service docker restart
docker version
