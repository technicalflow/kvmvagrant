#!/bin/bash

#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8 
export LC_ALL=en_US.UTF-8

sudo timedatectl set-timezone Europe/Warsaw

# Install recommended extra packages
sudo apt-get update
sudo apt-get -y upgrade
#sudo apt-get install -y \
#    linux-image-virtual \
#    linux-image-extra-virtual

sudo apt-get install -y \
    gcc \
    make \
    perl \
    curl \
    ntp \
    ca-certificates \
    apt-transport-https

sudo apt-get autoremove
sudo apt-get purge
sudo apt-get clean

# sudo apt-get remove virtualbox-guest-utils -y
# sudo sh /vagrant/VBoxLinuxAdditions.run

ip a | grep inet 
echo DONE

