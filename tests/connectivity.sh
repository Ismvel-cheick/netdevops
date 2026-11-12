#!/usr/bin/env bash
# =============================================================================
# Tests de connectivité et de filtrage — utilisés à la main et par Jenkins
# Usage : bash tests/connectivity.sh        (code retour 0 = tous les tests OK)
# =============================================================================
set -u
PASS=0; FAIL=0

ok()   { echo "  [OK]    $1"; PASS=$((PASS+1)); }
ko()   { echo "  [ECHEC] $1"; FAIL=$((FAIL+1)); }

# doit_reussir "description" commande...
doit_reussir() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
# doit_echouer "description" commande...   (vérifie qu'un flux est BLOQUÉ)
doit_echouer() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ko "$d (flux NON bloqué !)"; else ok "$d"; fi; }

echo "== 1. Conteneurs démarrés"
for c in router-fw web-dmz dns-lan client1 client2; do
  doit_reussir "$c est en cours d'exécution" \
    sh -c "[ \"\$(docker inspect -f '{{.State.Running}}' $c)\" = true ]"
done

echo "== 2. DNS (dig)"
doit_reussir "client1 résout www.pme.local -> 172.20.1.10" \
  sh -c "docker exec client1 dig +short @172.20.2.10 www.pme.local | grep -qx 172.20.1.10"
doit_reussir "client1 résout un nom Internet (google.com)" \
  sh -c "docker exec client1 dig +short +time=3 @172.20.2.10 google.com | grep -q ."

echo "== 3. Web (curl)"
doit_reussir "client1 -> web-dmz en HTTPS" \
  docker exec client1 curl -sk --max-time 5 -o /dev/null -w '%{http_code}' https://172.20.1.10
doit_reussir "HTTP redirige vers HTTPS (301)" \
  sh -c "docker exec client1 curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://172.20.1.10 | grep -qx 301"
doit_reussir "Accès depuis l'hôte via le DNAT du pare-feu (https://localhost:8443)" \
  curl -sk --max-time 5 -o /dev/null https://localhost:8443

echo "== 4. Filtrage nftables (flux interdits)"
doit_echouer "DMZ -> LAN : web-dmz ne joint pas dns-lan en DNS" \
  docker exec web-dmz sh -c "nc -z -w 3 172.20.2.10 53"
doit_echouer "DMZ -> LAN : web-dmz ne ping pas client1" \
  docker exec web-dmz ping -c 1 -W 2 172.20.2.100
doit_echouer "LAN -> web-dmz sur un port non autorisé (22)" \
  docker exec client1 nc -z -w 3 172.20.1.10 22

echo "== 5. Scan nmap de la DMZ depuis le LAN"
docker exec client1 nmap -Pn -p 22,53,80,443,8080 172.20.1.10 | grep -E '^[0-9]+/tcp' || true

echo "== 6. Règles nftables actives"
doit_reussir "La politique forward du pare-feu est 'drop'" \
  sh -c "docker exec router-fw nft list chain inet filter forward | grep -q 'policy drop'"

echo
echo "Résultat : $PASS OK, $FAIL échec(s)"
[ "$FAIL" -eq 0 ]
