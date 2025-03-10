#!/usr/bin/env bash

echo ">>>> K8S Controlplane config Start <<<<"

echo "[TASK 1] Initial Kubernetes - Pod CIDR 172.30.0.0/16 , Service CIDR 10.200.1.0/24 , API Server 192.168.56.200"
kubeadm init --token 123456.1234567890123456 --token-ttl 0 --pod-network-cidr=172.30.0.0/16 --apiserver-advertise-address=192.168.56.200 --service-cidr=10.200.1.0/24 --cri-socket=unix:///run/containerd/containerd.sock>/dev/null 2>&1

echo "[TASK 2] Setting kube config file"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "[TASK 3] Install cailco CNI"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/custom-resources.yaml  
sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 172\.30\.0\.0\/16/g' custom-resources.yaml
kubectl create -f custom-resources.yaml

echo "[TASK 5] Source the completion"
# source bash-completion for kubectl kubeadm
source <(kubectl completion bash)
source <(kubeadm completion bash)

## Source the completion script in your ~/.bashrc file
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile

echo "[TASK 6] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile

echo "[TASK 7] Install Kubectx & Kubens"
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

echo "[TASK 8] Install Kubeps & Setting PS1"
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1 >/dev/null 2>&1
cat <<"EOT" >> ~/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=false
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT
kubectl config rename-context "kubernetes-admin@kubernetes" "$1" >/dev/null 2>&1

echo "[TASK 9] Install Packages"
apt install kubetail etcd-client -y -qq >/dev/null 2>&1

echo "[TASK 10] Install Helm"
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >/dev/null 2>&1

echo "[TASK 11] Install Metrics server - v0.7"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null 2>&1

echo "[TASK 12] Dynamically provisioning persistent local storage with Kubernetes - v0.0.22"
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml >/dev/null 2>&1
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1

echo ">>>> K8S Controlplane Config End <<<<"