#!/bin/bash

mkdir -p /etc/apt/keyrings && touch /etc/apt/sources.list.d/kubernetes.list 
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" > /etc/apt/sources.list.d/kubernetes.list 

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt update && apt install -y kubelet kubeadm kubectl containerd socat

mkdir -p /etc/containerd/ && touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd.service && systemctl restart kubelet.service

kubeadm config images pull

# Master Configuration
kubeadm init --pod-network-cidr=172.20.0.0/16 --apiserver-advertise-address=192.168.63.2 --node-name=k8smaster

mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u):$(id -g) /home/vagrant/.kube/config

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //' > /vagrant/ca_cert_hash
kubeadm token list -o yaml | grep token: | awk '{print $2}' > /vagrant/kubeadm_join

# export KUBECONFIG=/etc/kubernetes/admin.conf
# chmod 755 /etc/kubernetes/admin.conf

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml > /vagrant/calico.yaml
# Insert pod network CIDR in calico.yaml
sed -i 's|cidr:.*|cidr: 172.20.0.0/16|g' /vagrant/calico.yaml
kubectl create -f /vagrant/calico.yaml

# cat << EOFnginx > /vagrant/deployment.yaml
# ---
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: nginx-deployment
# spec:
#   selector:
#     matchLabels:
#       app: nginx
#   replicas: 20 # Update the replicas from 2 to 20
#   template:
#     metadata:
#       labels:
#         app: nginx
#     spec:
#       containers:
#       - name: nginx
#         image: techfellow/webappa:latest
#         ports:
#         - containerPort: 80
# EOFnginx
# kubectl apply -f /vagrant/deployment.yaml

# kubectl get services
# kubectl get namespaces
# kubectl get ns
# kubectl get pods -o wide
# kubectl expose deployment nginx-deployment --type=LoadBalancer --port=8080
# kubectl describe service nginx-deployment
# kubectl patch svc nginx-deployment -n default -p '{"spec": {"type": "LoadBalancer", "externalIPs":["192.168.50.238"]}}'
# kubectl get pods -A

# kubectl expose deployment nginx-deployment --type=LoadBalancer --port=8080

# kubectl expose deployment nginx-deployment --type=LoadBalancer --port=8080 --target-port=80
# kubectl delete service nginx-deployment
# kubectl expose deployment nginx-deployment --port=8080 --target-port=80
# kubectl get services
# kubectl get rp,svc
# while true; do curl 192.168.50.238/ip/ ; done

# Nodes setup
# kubeadm join 192.168.63.2:6443 --token $(cat /vagrant/kubeadm_join) --discovery-token-ca-cert-hash sha256:$(cat /vagrant/ca_cert_hash)

