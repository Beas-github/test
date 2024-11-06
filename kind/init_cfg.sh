#!/usr/bin/env bash

# [TASK 0] SSH 설정을 통해 root 계정으로 SSH 접속 가능하게 설정
echo "[TASK 0] Setting SSH with Root"
# root 계정 비밀번호를 'qwe123'로 설정하고 출력 내용을 숨깁니다.
printf "qwe123\nqwe123\n" | passwd >/dev/null 2>&1

# SSH에서 root 로그인 허용을 설정합니다.
sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config

# SSH 비밀번호 인증을 활성화합니다.
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# SSH 서비스를 재시작하여 변경된 설정을 적용합니다.
systemctl restart sshd  >/dev/null 2>&1

# [TASK 1] 프로필과 Bash 설정
echo "[TASK 1] Profile & Bashrc"
# vi 명령어를 vim으로 대체하는 alias 설정을 /etc/profile에 추가.
echo 'alias vi=vim' >> /etc/profile

# root 계정 로그인 시 자동으로 su - 명령어 실행
echo "sudo su -" >> .bashrc

# 시스템의 시간대를 아시아/서울 시간대로 설정합니다.
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# [TASK 2] AppArmor 비활성화
echo "[TASK 2] Disable AppArmor"
# UFW (Ubuntu 방화벽)와 AppArmor를 중지하고 비활성화합니다.
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1

# [TASK 3] 필수 패키지 설치
echo "[TASK 3] Install Packages"
# 시스템 패키지 목록을 업데이트하고 필요한 패키지들을 설치합니다.
apt update -qq >/dev/null 2>&1
apt-get install bridge-utils net-tools jq tree unzip kubecolor -y -qq >/dev/null 2>&1

# [TASK 4] Kind 설치
echo "[TASK 4] Install Kind"
# Kind (Kubernetes in Docker)를 다운로드하여 실행 권한을 부여하고 /usr/bin으로 이동합니다.
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64 >/dev/null 2>&1
chmod +x ./kind
mv ./kind /usr/bin

# [TASK 5] Docker 엔진 설치
echo "[TASK 5] Install Docker Engine"
# Docker 엔진을 자동으로 설치하는 스크립트를 실행합니다.
curl -fsSL https://get.docker.com | sh >/dev/null 2>&1

# [TASK 6] kubectl 설치
echo "[TASK 6] Install kubectl"
# kubectl 최신 릴리스를 다운로드하고 실행 가능하게 설정한 후 /usr/local/bin으로 이동.
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >/dev/null 2>&1
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# [TASK 7] Helm 설치
echo "[TASK 7] Install Helm"
# Helm 설치 스크립트를 실행하여 Helm 3을 설치.
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >/dev/null 2>&1

# [TASK 8] kubectl 자동 완성 설정
echo "[TASK 8] Source the completion"
# kubectl 자동 완성을 활성화하고, 이를 /etc/profile에 추가하여 모든 사용자가 사용 가능하도록 설정.
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> /etc/profile

# [TASK 9] kubectl에 대한 alias 설정
echo "[TASK 9] Alias kubectl to k"
# kubectl 명령어를 'k'로 줄여서 사용할 수 있도록 alias 추가.
echo 'alias k=kubectl' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile
# kubectl을 kubecolor로 대체하여 컬러 출력을 활성화.
echo 'alias kubectl=kubecolor' >> /etc/profile

# [TASK 10] Kubectx와 Kubens 설치
echo "[TASK 10] Install Kubectx & Kubens"
# kubectx와 kubens 도구를 설치하고 /usr/local/bin으로 심볼릭 링크 생성.
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

# [TASK 11] Kubeps 설치 및 PS1 설정
echo "[TASK 11] Install Kubeps & Setting PS1"
# kube-ps1을 설치하여 프롬프트에 클러스터 정보를 표시하도록 설정.
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1 >/dev/null 2>&1
cat <<"EOT" >> ~/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=true
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT

# [TASK 12] 리소스 제한값 증가
echo "[TASK 12] To increase Resource limits"
# inotify 사용자 워치 및 인스턴스 최대값을 설정하여 시스템 리소스 사용량을 조정.
sysctl fs.inotify.max_user_watches=524288 >/dev/null 2>&1
sysctl fs.inotify.max_user_instances=512 >/dev/null 2>&1
# 이 설정을 영구적으로 유지하기 위해 sysctl 설정 파일에 저장.
echo 'fs.inotify.max_user_watches=524288' > /etc/sysctl.d/99-kind.conf
echo 'fs.inotify.max_user_instances=512'  > /etc/sysctl.d/99-kind.conf
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
