#!/bin/bash

sudo curl -fsSL https://get.docker.com | sudo sh

# Access docker w/o sudo

sudo usermod -aG docker vagrant
sudo service docker restart
docker version
