#!/usr/bin/env bash
# =============================================================================
# setup-vm.sh — Préparation de la VM Ubuntu (Docker host) pour le projet NetDevOps
# Usage : sudo bash scripts/setup-vm.sh
# Testé pour Ubuntu Server 22.04 / 24.04 LTS
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Lance ce script avec sudo : sudo bash $0" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"

echo "==> [1/6] Mise à jour du système et outils de base"
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release git vim \
  python3 python3-pip python3-venv pipx \
  nmap dnsutils net-tools iproute2 nftables tree jq unzip

install -m 0755 -d /etc/apt/keyrings

echo "==> [2/6] Installation de Docker + plugin Compose"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
# Le dépôt officiel Docker ne couvre pas toujours la dernière version d'Ubuntu :
# on l'utilise s'il connaît notre version, sinon on prend les paquets Ubuntu.
if curl -fsI "https://download.docker.com/linux/ubuntu/dists/${CODENAME}/Release" >/dev/null 2>&1; then
  echo "    Dépôt officiel Docker disponible pour ${CODENAME}"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "    Pas de dépôt Docker pour ${CODENAME} : paquets Ubuntu (docker.io)"
  rm -f /etc/apt/sources.list.d/docker.list
  apt-get install -y docker.io docker-buildx docker-compose-v2
fi
systemctl enable --now docker
usermod -aG docker "$TARGET_USER"

echo "==> [3/6] Ansible + outils de lint (ansible-lint, yamllint, pylint)"
apt-get install -y ansible
# Outils de lint installés pour l'utilisateur (isolés via pipx)
sudo -u "$TARGET_USER" pipx install ansible-lint || true
sudo -u "$TARGET_USER" pipx install yamllint || true
sudo -u "$TARGET_USER" pipx install pylint || true
sudo -u "$TARGET_USER" pipx ensurepath || true
# Collection Ansible pour piloter Docker
sudo -u "$TARGET_USER" ansible-galaxy collection install community.docker community.general ansible.posix

echo "==> [4/6] Trivy (scanner de vulnérabilités d'images)"
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  > /etc/apt/sources.list.d/trivy.list
apt-get update -y
apt-get install -y trivy

echo "==> [5/6] Paramètres noyau requis"
# SonarQube (Elasticsearch embarqué) exige vm.max_map_count >= 524288
# Le routage IP est nécessaire pour le conteneur router-fw
cat > /etc/sysctl.d/99-netdevops.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

echo "==> [6/6] Vérifications"
docker --version
docker compose version
ansible --version | head -n1
trivy --version | head -n1
git --version

echo
echo "Installation terminée."
echo "IMPORTANT : déconnecte-toi puis reconnecte-toi (ou 'newgrp docker')"
echo "pour pouvoir utiliser docker sans sudo."
