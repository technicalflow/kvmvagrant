#!/usr/bin/env bash

set -euo pipefail

# Not for Ubuntu 18.04
curl -fsSL https://get.docker.com | sh

# Access docker w/o sudo
usermod -aG docker vagrant
systemctl restart docker.service
# service docker restart
docker version
