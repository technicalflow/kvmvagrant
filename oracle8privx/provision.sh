#!/bin/bash
#!/usr/bin/env bash

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo LANG=en_US.utf-8 >> /etc/environment
echo LC_ALL=en_US.utf-8 >> /etc/environment

timedatectl set-timezone Europe/Warsaw

systemctl enable --now serial-getty@ttyS0.service

#sudo dnf update -y
#sudo dnf install epel-release -y
#sudo dnf install htop -y
# sudo dnf install kernel-devel -y

#Turn swap off
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

swapoff -a

uname -a
hostname

echo DONE
