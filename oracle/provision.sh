#!/bin/bash
#!/usr/bin/env bash

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

sudo echo LANG=en_US.utf-8 >> /etc/environment
sudo echo LC_ALL=en_US.utf-8 >> /etc/environment

sudo timedatectl set-timezone Europe/Warsaw

sudo dnf update -y
sudo dnf install epel-release -y
sudo dnf install htop -y
# sudo dnf install kernel-devel -y

# Turn swap off
# sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo swapoff -a

uname -a
hostname

echo DONE
