#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"
echo "[TASK 1] Setting SSH with Root"
printf "qwe123\nqwe123\n" | passwd >/dev/null 2>&1
sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart sshd  >/dev/null 2>&1

echo "[TASK 2] Profile & Bashrc & Change Timezone"
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> .bashrc
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtimew

echo "[TASK 3] Disable ufw & AppArmor"
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1

echo "[TASK 4] Install Packages"
apt update -qq >/dev/null 2>&1
apt-get install prettyping sshpass bridge-utils net-tools jq tree resolvconf wireguard ngrep ipset iputils-arping ipvsadm vim unzip conntrack -y -qq >/dev/null 2>&1
# Install Batcat - https://github.com/sharkdp/bat
apt-get install bat -y >/dev/null 2>&1
echo 'alias cat=batcat' >> /etc/profile
# Install Exa - https://the.exa.website/
#apt-get install exa -y >/dev/null 2>&1
#echo 'alias ls=exa' >> /etc/profile
# Install YAML Highlighter
wget https://github.com/andreazorzetto/yh/releases/download/v0.4.0/yh-linux-amd64.zip
unzip yh-linux-amd64.zip
mv yh /usr/local/bin/

echo "[TASK 5] Change DNS Server IP Address"
echo -e "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

echo "[TASK 6] Setting Local DNS Using Hosts file"
echo "192.168.56.200 k8s-m" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.56.20$i k8s-w$i" >> /etc/hosts; done

echo "[TASK 7] Install containerd.io"
# packets traversing the bridge are processed by iptables for filtering
echo 1 > /proc/sys/net/ipv4/ip_forward
# enable br_filter for iptables 
modprobe br_netfilter
apt-get update >/dev/null 2>&1
apt-get install containerd.io -y >/dev/null 2>&1
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

echo "[TASK 8] Using the systemd cgroup driver"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# avoid WARN&ERRO(default endpoints) when crictl run  
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

systemctl restart containerd && systemctl enable containerd
systemctl enable --now kubelet

echo "[TASK 9] Disable and turn off SWAP"
swapoff -a

echo "[TASK 10] Install Kubernetes components (kubeadm, kubelet and kubectl) - v$2"
# add kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$2/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$2/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# add docker-ce repo with containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
apt update -qq >/dev/null 2>&1
apt-get install -y kubelet kubectl kubeadm >/dev/null 2>&1 && apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1
systemctl enable kubelet && systemctl start kubelet

echo ">>>> Initial Config End <<<<"