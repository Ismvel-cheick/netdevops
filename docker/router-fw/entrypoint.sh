#!/bin/sh
# Démarrage du routeur/pare-feu
set -e

# Fichier de règles : monté par Ansible dans /etc/nft/, sinon celui de l'image
NFT_CONF="${NFT_CONF:-/etc/nftables.conf}"

echo "[router-fw] Interfaces :"
ip -br -4 addr

# Le routage est activé via 'sysctls' dans docker-compose.yml
echo "[router-fw] ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"

# Chargement des règles (vérification de syntaxe d'abord)
nft -c -f "$NFT_CONF"
nft -f "$NFT_CONF"
echo "[router-fw] Règles nftables chargées depuis $NFT_CONF"

# Exporteur de métriques (port 9100) : accessible uniquement depuis le réseau MGMT
# grâce à la chaîne input du pare-feu
echo "[router-fw] Démarrage de node_exporter sur :9100"
exec node_exporter --web.listen-address=:9100 \
  --collector.disable-defaults \
  --collector.netdev --collector.netstat --collector.conntrack \
  --collector.cpu --collector.meminfo --collector.loadavg
