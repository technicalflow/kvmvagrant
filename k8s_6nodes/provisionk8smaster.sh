#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

VIP=192.168.67.200
VIPINTERFACE=eth2
KUBEVIPVERSION=v0.9.0
HOSTIP="192.168.67.2"
PODNETWORK="172.22.0.0/16"

INSTALLHELM=false
INSTALLMETALLB=false
INSTALLMETRICS=false
INSTALLINGRESS=false
# SAMPLEDEPLOY=false
# SAMPLEWEBAPP=false

# Already in provisionk8s.sh
# mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list 
# echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list 

# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# apt-get update && apt-get install -y kubelet kubeadm kubectl containerd socat

# mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
# containerd config default > /etc/containerd/config.toml
# sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
# systemctl restart containerd.service && systemctl restart kubelet.service

# kubeadm config images pull

echo "========================== Kube-VIP Install =========================="
mkdir -p /etc/kubernetes/manifests
# Install Kube-VIP
# alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"
ctr image pull "ghcr.io/kube-vip/kube-vip:$KUBEVIPVERSION"
ctr run --rm --net-host "ghcr.io/kube-vip/kube-vip:$KUBEVIPVERSION" vip /kube-vip manifest pod \
    --interface "$VIPINTERFACE" \
    --address "$VIP" \
    --controlplane \
    --services \
    --arp \
    --leaderElection > /etc/kubernetes/manifests/kube-vip.yaml

# Workaround for kube-vip issue with kubeadm
sed -i 's#path: /etc/kubernetes/admin.conf#path: /etc/kubernetes/super-admin.conf#' \
          /etc/kubernetes/manifests/kube-vip.yaml

# Master Configuration
echo "========================== Kubernetes Master Configuration INIT =========================="
kubeadm init --pod-network-cidr="$PODNETWORK" --apiserver-advertise-address="$HOSTIP" --node-name=k8sm1 --control-plane-endpoint "$VIP:6443"
# kubeadm init --node-name=k8sm1 --config /opt/kubeadm-config.yaml

# Workaround for kube-vip issue with kubeadm 
sed -i 's#path: /etc/kubernetes/super-admin.conf#path: /etc/kubernetes/admin.conf#' \
          /etc/kubernetes/manifests/kube-vip.yaml
cp /etc/kubernetes/manifests/kube-vip.yaml /vagrant/kube-vip.yaml

mkdir -p /home/vagrant/.kube
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp /etc/kubernetes/admin.conf /root/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
chmod 0600 /home/vagrant/.kube/config /root/.kube/config

echo "========================== Export tokens =========================="
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //' > /vagrant/ca_cert_hash
kubeadm token list -o yaml | grep token: | awk '{print $2}' > /vagrant/kubeadm_join

# kubectl -n kube-system get cm kubeadm-config -o json |jq -r '.data.ClusterConfiguration' > /opt/kubeadm-config.yaml
# sed -i '/clusterName: kubernetes/a\controlPlaneEndpoint: k8sm1:6443' /opt/kubeadm-config.yaml
# kubeadm init phase upload-certs --upload-certs --config /opt/kubeadm-config.yaml
kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1 > /vagrant/cert_key
# kubeadm certs certificate-key > /vagrant/cert_key

# export KUBECONFIG=/etc/kubernetes/admin.conf
# chmod 755 /etc/kubernetes/admin.conf
# Wait for kube-apiserver VIP to be ready
echo "========================== Waiting for Kube-VIP IP =========================="
sleep 5
# while [ "$(curl -k -s -o /dev/null -w "%{http_code}" https://$VIP:6443)" != "403" ]; do
#     echo 'sleep 5' && sleep 5
# done

until [ "$(curl -k -s --connect-timeout 2 -o /dev/null -w "%{http_code}" "https://$VIP:6443/healthz" 2>/dev/null || true)" = "200" ]; do
    echo "Waiting for Kube-VIP..."
    sleep 5
done

# Install Calico
echo "========================== Install Calico =========================="
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml > /opt/tigera.yaml
kubectl create -f /opt/tigera.yaml
sleep 5
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml > /opt/calico.yaml
# Insert pod network CIDR in calico.yaml
sed -i "s|cidr:.*|cidr: $PODNETWORK|g" /opt/calico.yaml
sed -i 's|encapsulation:.*|encapsulation: None|g' /opt/calico.yaml
kubectl create -f /opt/calico.yaml

# Install MetalLB
if [[ "$INSTALLMETALLB" == true ]]; then
    curl -fsSL https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml > /opt/metallb.yaml
    kubectl apply -f /opt/metallb.yaml
    # kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
fi

# Install Metrics Server
if [[ "$INSTALLMETRICS" == true ]]; then
    wget -q -O /opt/components.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    sed -i 's| - --secure-port=10250| - --secure-port=10250\n        - --kubelet-insecure-tls|' /opt/components.yaml
    kubectl apply -f /opt/components.yaml
fi

# Install Helm
if [[ "$INSTALLHELM" == true ]]; then
    curl -fsSL -o /opt/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 
    chmod 700 /opt/get_helm.sh
    /opt/get_helm.sh
    # # Install Helm Chart
    helm repo add stable https://charts.helm.sh/stable
    helm repo update
    # helm install nginx-ingress stable/nginx-ingress
fi

if [[ "$INSTALLINGRESS" == true && "$INSTALLMETALLB" == true ]]; then
    helm repo update
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm template ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --version 4.11.3 --namespace ingress-nginx > /opt/ingress.yaml
    sed -i 's|  type: LoadBalancer|  type: LoadBalancer\n  externalIPs:\n    - 192.168.50.238|' /opt/ingress.yaml
    kubectl create ns ingress-nginx
    kubectl apply -f /opt/ingress.yaml --namespace ingress-nginx
fi

# Sample with Ingress Configuration
# if [[ "$SAMPLEWEBAPP" == true && "$INSTALLINGRESS" == true && "$INSTALLMETALLB" == true ]]; then
#     kubectl apply -f /vagrant/samplewebappingress.yaml
# fi

# # Sample Deployment
# if [[ "$SAMPLEDEPLOY" == true && "$INSTALLMETALLB" == true ]]; then
#     kubectl apply -f /vagrant/samplenginx.yaml
# fi

# Dashboard
# helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
# To access Dashboard run:
#   kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
#   kubectl expose service kubernetes-dashboard-kong-proxy --port=443 --target-port=8443 --name=kubedashboard -n kubernetes-dashboard

# curl -LO https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
# kubectl create ns cert-manager
# kubectl apply -f cert-manager.yaml --namespace cert-manager

rm -rf /root/.kube

# Provision pods on control plane nodes
# kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Tigera operator Calico installation
# # .tigera.io/v1. Installation
# apiVersion: operator.tigera.io/v1
# kind: Installation
# metadata:
#   name: default
# spec:
#   # Configures Calico networking.
#   calicoNetwork:
#     ipPools:
#     - name: default-ipv4-ippool
#       blockSize: 26
#       cidr: 10.244.0.0/16
#       encapsulation: None
#       natOutgoing: Enabled
#       nodeSelector: all()

# kubectl get tigerastatus

if [ $(hostname) == "k8sm1" ] ; then sed -i '/address 192.168.50..*/a \      gateway 192.168.50.250' /etc/network/interfaces && systemctl restart networking.service && sleep 1; fi