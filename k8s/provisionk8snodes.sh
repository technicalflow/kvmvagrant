#!/bin/bash

mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update && apt-get install -y kubelet kubeadm kubectl containerd socat

# Metrics server CNI tools
mkdir -p /usr/lib/cni && ln -s /opt/cni/bin/* /usr/lib/cni/ 2>/dev/null || true

mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \?= \?false/SystemdCgroup = true/g' /etc/containerd/config.toml
sed -i "s|sandbox_image = \".*\"|sandbox_image = \"$(kubeadm config images list | grep pause)\"|g" /etc/containerd/config.toml

systemctl restart containerd.service && systemctl restart kubelet.service

kubeadm config images pull

# Nodes setup
# kubeadm join 192.168.63.2:6443 --token $(cat /vagrant/kubeadm_join) --discovery-token-ca-cert-hash sha256:$(cat /vagrant/ca_cert_hash)
