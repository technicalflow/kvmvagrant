#!/bin/bash

curl -fsSL https://get.docker.com | sh

# Access docker w/o sudo
usermod -aG docker vagrant
service docker restart
docker version
