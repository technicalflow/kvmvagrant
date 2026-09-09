### The Packer files are tested and working on RHEL 10 Host with libvirt
### The setup is standard and creates vagrant user with password vagrant and inserts insecure vagrant ssh keys
### Remember there is no RedHat subscription activation - meaning no package updates are possible until activated


### Install Packer image for Ubuntu 24.04
packer validate ./ubuntu/24.04/ubuntu.pkr.hcl

packer init ./ubuntu/24.04/ubuntu.pkr.hcl

packer build ./ubuntu/24.04/ubuntu.pkr.hcl

vagrant box add ownubuntu/2404 ./ubuntu/24.04/output-vagrant/package.box

### Same for RedHat 10
packer validate ./rhel/rhel.pkr.hcl

packer init ./rhel/rhel.pkr.hcl

packer build ./rhel/rhel.pkr.hcl

vagrant box add ownrhel/10 ./rhel/output-vagrant/package.box

### Based on https://github.com/alvistack vagrant packer files