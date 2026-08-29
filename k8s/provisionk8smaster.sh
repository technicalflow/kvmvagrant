#!/bin/bash

set -e

INSTALLHELM=true
INSTALLMETALLB=true
INSTALLMETRICS=true
INSTALLINGRESS=false
SAMPLEDEPLOY=false
SAMPLEWEBAPP=false
HOSTIP="192.168.63.2"
PODNETWORK="172.20.0.0/16"
K8S_VERSION="v1.37"

mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update && apt-get install -y kubelet kubeadm kubectl containerd socat

# Metrics server CNI tools
# mkdir -p /usr/lib/cni && ln -s /opt/cni/bin/* /usr/lib/cni/ 2>/dev/null || true
ln -sfn /opt/cni/bin /usr/lib/cni

# [ -e /usr/lib/cni ] || ln -s /opt/cni/bin /usr/lib/cni

mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \?= \?false/SystemdCgroup = true/g' /etc/containerd/config.toml
sed -i "s|sandbox_image = \".*\"|sandbox_image = \"$(kubeadm config images list | grep pause)\"|g" /etc/containerd/config.toml
systemctl restart containerd.service && systemctl restart kubelet.service

echo " Images pull for kubeadm"
kubeadm config images pull

# Master Configuration
echo " Kubernetes Master Configuration INIT"
kubeadm init --pod-network-cidr=$PODNETWORK --apiserver-advertise-address=$HOSTIP --node-name=k8smaster

echo " Copy kubeconfig to vagrant user"
mkdir -p /home/vagrant/.kube
mkdir -p /root/.kube
cp -r /etc/kubernetes/admin.conf /home/vagrant/.kube/config
cp -r /etc/kubernetes/admin.conf /root/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo " Generate CA certificate hash"
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //' > /vagrant/ca_cert_hash
kubeadm token list -o yaml | grep token: | awk '{print $2}' > /vagrant/kubeadm_join

# export KUBECONFIG=/etc/kubernetes/admin.conf
# chmod 755 /etc/kubernetes/admin.conf

echo " Install Tigera Calico"
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml > /vagrant/tigera.yaml
kubectl create -f /vagrant/tigera.yaml
sleep 30

echo " Install Calico"
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml > /vagrant/calico.yaml
# Insert pod network CIDR in calico.yaml
sed -i "s|cidr:.*|cidr: $PODNETWORK|g" /vagrant/calico.yaml
kubectl create -f /vagrant/calico.yaml

echo " Install MetalLB"
if [[ "$INSTALLMETALLB" == true ]]; then
    curl -fsSL https://raw.githubusercontent.com/metallb/metallb/v0.16/config/manifests/metallb-native.yaml > /vagrant/metallb.yaml
    kubectl apply -f /vagrant/metallb.yaml
    kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
fi

echo " Install Metrics Server"
if [[ "$INSTALLMETRICS" == true ]]; then
    curl -fsSL https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml > /vagrant/components.yaml
    sed -i 's| - --secure-port=10250| - --secure-port=10250\n        - --kubelet-insecure-tls|' /vagrant/components.yaml
    kubectl apply -f /vagrant/components.yaml
fi

echo " Install Helm"
if [[ "$INSTALLHELM" == true ]]; then
    curl -fsSL -o /vagrant/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
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
    sed -i 's|  type: LoadBalancer|  type: LoadBalancer\n  externalIPs:\n    - 192.168.50.237|' /vagrant/ingress.yaml
    kubectl create ns ingress-nginx
    kubectl apply -f /vagrant/ingress.yaml --namespace ingress-nginx
fi

echo " Sample with Ingress Configuration"
if [[ "$SAMPLEWEBAPP" == true && "$INSTALLINGRESS" == true && "$INSTALLMETALLB" == true ]]; then
    kubectl apply -f /vagrant/samplewebappingress.yaml
fi

echo " Sample Deployment"
if [[ "$SAMPLEDEPLOY" == true && "$INSTALLMETALLB" == true ]]; then
    kubectl apply -f /vagrant/samplenginx.yaml
fi

rm -rf /root/.kube

# Dashboard
# helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
# To access Dashboard run:
#   kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
#   kubectl expose service kubernetes-dashboard-kong-proxy --port=443 --target-port=8443 --name=kubedashboard -n kubernetes-dashboard

# curl -LO https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
# kubectl create ns cert-manager
# kubectl apply -f cert-manager.yaml --namespace cert-manager
