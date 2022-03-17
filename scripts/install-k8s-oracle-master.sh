#!/bin/bash

# update apt package index
sudo apt update

# upgrade the packages
sudo apt upgrade -y

# install dependencies for kubernetes
sudo apt install -y apt-transport-https ca-certificates curl

# install docker
curl -fsSL https://get.docker.com | bash

# add the current user to the docker group
sudo usermod -aG docker $USER

# create necessary folder to config docker with systemd
sudo mkdir -p /etc/systemd/system/docker.service.d

# create config file daemon.json to use docker with systemd
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# start docker services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker

# download the google cloud public signing key
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

# add the kubernetes apt repository
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# update apt package index, install kubelet, kubeadm and kubectl, and pin their version
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# disable swap
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# config sysctl
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

# check if br_netfilter module is loaded
lsmod | grep br_netfilter

# enable kubelet service
sudo systemctl start kubelet
sudo systemctl enable kubelet

# pull container images
# sudo kubeadm config images pull

# start kubertenetes cluster
sudo kubeadm init --apiserver-advertise-address <PRIVATE_IP> --apiserver-cert-extra-sans <PUBLIC_IP> --ignore-preflight-errors=NumCPU

# config kubectl using kubeadm init output
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# install network plugin
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# check cluster status
kubectl cluster-info
kubctl get nodes

# enable access permission in the iptables
sudo iptables -L
sudo iptables-save > ~/iptables-rules
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -F
sudo iptables --flush
