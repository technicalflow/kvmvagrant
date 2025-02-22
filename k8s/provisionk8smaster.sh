#!/bin/bash

set -e

INSTALLHELM=true
INSTALLMETALLB=true
INSTALLMETRICS=true
INSTALLINGRESS=true
SAMPLEDEPLOY=true
SAMPLEWEBAPP=false

mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list 
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list 

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update && apt-get install -y kubelet kubeadm kubectl containerd socat

mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd.service && systemctl restart kubelet.service

kubeadm config images pull

# Master Configuration
kubeadm init --pod-network-cidr=172.20.0.0/16 --apiserver-advertise-address=192.168.63.2 --node-name=k8smaster

mkdir -p /home/vagrant/.kube
mkdir -p /root/.kube
cp -r /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp -r /etc/kubernetes/admin.conf /root/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //' > /vagrant/ca_cert_hash
kubeadm token list -o yaml | grep token: | awk '{print $2}' > /vagrant/kubeadm_join

# export KUBECONFIG=/etc/kubernetes/admin.conf
# chmod 755 /etc/kubernetes/admin.conf

# Install Calico
curl -fs https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml > /vagrant/tigera.yaml
kubectl create -f /vagrant/tigera.yaml
sleep 5
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml > /vagrant/calico.yaml
# Insert pod network CIDR in calico.yaml
sed -i 's|cidr:.*|cidr: 172.20.0.0/16|g' /vagrant/calico.yaml
kubectl create -f /vagrant/calico.yaml

# # Install MetalLB
if $INSTALLMETALLB == true; then
    curl -fs https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml > /vagrant/metallb.yaml
    kubectl apply -f /vagrant/metallb.yaml
    # kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
fi

# Install Metrics Server
if $INSTALLMETRICS == true; then
    wget -q -O /vagrant/components.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    sed -i 's| - --secure-port=10250| - --secure-port=10250\n        - --kubelet-insecure-tls|' /vagrant/components.yaml
    kubectl apply -f /vagrant/components.yaml
fi

# # Install Helm
if $INSTALLHELM == true; then
    curl -fsSL -o /vagrant/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 
    chmod 700 /vagrant/get_helm.sh
    /vagrant/get_helm.sh
    # # Install Helm Chart
    helm repo add stable https://charts.helm.sh/stable
    helm repo update
    # helm install nginx-ingress stable/nginx-ingress
fi

if [[ "$INSTALLINGRESS" == true && "$INSTALLMETALLB" == true ]]; then
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm template ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --version 4.11.3 --namespace ingress-nginx > /vagrant/ingress.yaml
    sed -i 's|  type: LoadBalancer|  type: LoadBalancer\n  externalIPs:\n    - 192.168.50.238|' /vagrant/ingress.yaml
    kubectl create ns ingress-nginx
    kubectl apply -f /vagrant/ingress.yaml --namespace ingress-nginx
fi

# Sample with Ingress Configuration
if [[ "$SAMPLEWEBAPP" == true && "$INSTALLINGRESS" == true && "$INSTALLMETALLB" == true]]; then
    kubectl apply -f /vagrant/samplewebappingress.yaml
fi

# Sample Deployment
if [[ "$SAMPLEDEPLOY" == true && "$INSTALLMETALLB" == true ]]; then
    kubectl apply -f /vagrant/samplenginx.yaml
fi

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