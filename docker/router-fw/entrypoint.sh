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

# Le conteneur reste actif
exec tail -f /dev/null
