#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list 
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list 

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update && apt-get install -y kubelet kubeadm kubectl containerd socat

mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd.service && systemctl restart kubelet.service

kubeadm config images pull

# mkdir -p /home/vagrant/.kube
# mkdir -p /root/.kube
# cp -r /etc/kubernetes/admin.conf /home/vagrant/.kube/config
# cp -r /etc/kubernetes/admin.conf /root/.kube/config
# chown vagrant:vagrant /home/vagrant/.kube/config

# On Master
# kubectl -n kube-system get cm kubeadm-config -o json |jq -r '.data.ClusterConfiguration' > /vagrant/kubeadm-config.yaml
# sed -i '/clusterName: kubernetes/a\controlPlaneEndpoint: k8sm1:6443' /vagrant/kubeadm-config.yaml
# kubeadm init phase upload-certs --upload-certs --config /vagrant/kubeadm-config.yaml

# Generate Certificate for control plane
# kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1 > /vagrant/cert_key
# kubeadm certs certificate-key > /vagrant/cert_key

# kubeadm token create --print-join-command
# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
# kubectl cluster-info

# On Mains
# kubeadm join 192.168.63.2:6443 --token e67wkq.m061amvpt7e0pdgm --discovery-token-ca-cert-hash sha256:eb2e51edc3c31100d33ed2fe38a72109f3fc203585918cdd97f7f10684acc1c0  --control-plane --certificate-key 956ffffb8c244efbcb075c03ddf679247e5416e2123bd60b7bf6b026a596885e --apiserver-advertise-address 192.168.63.3 --apiserver-bind-port 6443

# Get Certs
# kubectl -n kube-system get secret kubeadm-certs -o jsonpath='{ .metadata.ownerReferences[0].name }'
# kubeadm init phase upload-certs --upload-certs | sed -n '3p'

# Get config
# kubectl -n kube-system get cm kubeadm-config -o json |jq -r '.data.ClusterConfiguration' > /tmp/kubeadm-config.yaml
# kubeadm init phase upload-certs --upload-certs --config /tmp/kubeadm-config.yaml -v 5

# Edit Kubconfig
# kubectl -n kube-system edit cm kubeadm-config
# kubectl -n kube-system get cm kubeadm-config -oyaml

# Nodes setup
# kubeadm join 192.168.63.2:6443 --token $(cat /vagrant/kubeadm_join) --discovery-token-ca-cert-hash sha256:$(cat /vagrant/ca_cert_hash)

# if [[ $(hostname) == *k8sm* ]] ; then echo "Master node"; else echo "Not Master node" ; fi
