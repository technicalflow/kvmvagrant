#!/bin/sh

sudo pkg update
sudo pkg upgrade -y
sudo pkg install -y mc htop nano

cat /etc/resolv.conf

echo DONE

