#!/bin/sh
# Démarrage du routeur/pare-feu
set -e

echo "[router-fw] Interfaces :"
ip -br -4 addr

# Le routage est activé via 'sysctls' dans docker-compose.yml
echo "[router-fw] ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"

# Chargement des règles (vérification de syntaxe d'abord)
nft -c -f /etc/nftables.conf
nft -f /etc/nftables.conf
echo "[router-fw] Règles nftables chargées"

# Le conteneur reste actif
exec tail -f /dev/null
