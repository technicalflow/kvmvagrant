#!/bin/bash

# Not for Ubuntu 18.04
curl -fsSL https://get.docker.com | sh

# Access docker w/o sudo
usermod -aG docker vagrant
service docker restart
docker version
