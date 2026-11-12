#!/usr/bin/env bash
# =============================================================================
# Tests de connectivité et de filtrage — utilisés à la main et par Jenkins
# Usage :
#   bash tests/connectivity.sh            -> environnement prod (172.20.x, port 8443)
#   bash tests/connectivity.sh test       -> environnement test (172.30.x, port 9443)
# Code retour 0 = tous les tests OK
# =============================================================================
set -u
ENV_NAME="${1:-prod}"

if [ "$ENV_NAME" = "test" ]; then
  P="test-"; NET="172.30"; HTTPS_PORT=9443; PROM_PORT=19090; GRAFANA_PORT=13000
else
  P="";      NET="172.20"; HTTPS_PORT=8443; PROM_PORT=9090;  GRAFANA_PORT=3000
fi
WEB="$NET.1.10"; DNS="$NET.2.10"; CLIENT1="$NET.2.100"

PASS=0; FAIL=0
ok()   { echo "  [OK]    $1"; PASS=$((PASS+1)); }
ko()   { echo "  [ECHEC] $1"; FAIL=$((FAIL+1)); }

# doit_reussir "description" commande...
doit_reussir() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
# doit_echouer "description" commande...   (vérifie qu'un flux est BLOQUÉ)
doit_echouer() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ko "$d (flux NON bloqué !)"; else ok "$d"; fi; }

echo "### Environnement : $ENV_NAME (réseaux $NET.x.0/24)"

echo "== 1. Conteneurs démarrés"
for c in router-fw web-dmz dns-lan client1 client2; do
  doit_reussir "$P$c est en cours d'exécution" \
    sh -c "[ \"\$(docker inspect -f '{{.State.Running}}' $P$c)\" = true ]"
done

echo "== 2. DNS (dig)"
doit_reussir "client1 résout www.pme.local -> $WEB" \
  sh -c "docker exec ${P}client1 dig +short @$DNS www.pme.local | grep -qx $WEB"
doit_reussir "client1 résout un nom Internet (google.com)" \
  sh -c "docker exec ${P}client1 dig +short +time=3 @$DNS google.com | grep -q ."

echo "== 3. Web (curl)"
doit_reussir "client1 -> web-dmz en HTTPS" \
  docker exec "${P}client1" curl -sk --max-time 5 -o /dev/null "https://$WEB"
doit_reussir "HTTP redirige vers HTTPS (301)" \
  sh -c "docker exec ${P}client1 curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://$WEB | grep -qx 301"
doit_reussir "Accès depuis l'hôte via le DNAT du pare-feu (https://localhost:$HTTPS_PORT)" \
  curl -sk --max-time 5 -o /dev/null "https://localhost:$HTTPS_PORT"

echo "== 4. Filtrage nftables (flux interdits)"
doit_echouer "DMZ -> LAN : web-dmz ne joint pas dns-lan en DNS" \
  docker exec "${P}web-dmz" sh -c "nc -z -w 3 $DNS 53"
doit_echouer "DMZ -> LAN : web-dmz ne ping pas client1" \
  docker exec "${P}web-dmz" ping -c 1 -W 2 "$CLIENT1"
doit_echouer "LAN -> web-dmz sur un port non autorisé (22)" \
  docker exec "${P}client1" nc -z -w 3 "$WEB" 22

echo "== 5. Scan nmap de la DMZ depuis le LAN"
docker exec "${P}client1" nmap -Pn -p 22,53,80,443,8080 "$WEB" | grep -E '^[0-9]+/tcp' || true

echo "== 6. Règles nftables actives"
doit_reussir "La politique forward du pare-feu est 'drop'" \
  sh -c "docker exec ${P}router-fw nft list chain inet filter forward | grep -q 'policy drop'"

echo "== 7. Supervision (Prometheus / Grafana)"
# Prometheus a besoin de quelques secondes pour faire son premier relevé
cibles_toutes_up() {
  curl -s --max-time 5 "http://localhost:$PROM_PORT/api/v1/query?query=up" \
    | jq -e '(.data.result | length) >= 4 and all(.data.result[]; .value[1] == "1")'
}
for _ in $(seq 1 12); do cibles_toutes_up >/dev/null 2>&1 && break; sleep 5; done
doit_reussir "Prometheus : toutes les cibles sont UP" cibles_toutes_up
doit_reussir "Sondes Blackbox HTTPS + DNS en succès" \
  sh -c "curl -s 'http://localhost:$PROM_PORT/api/v1/query?query=min(probe_success)' | jq -e '.data.result[0].value[1] == \"1\"'"
# Au premier démarrage, Grafana initialise sa base (jusqu'à ~1 min)
grafana_ok() { curl -s --max-time 5 "http://localhost:$GRAFANA_PORT/api/health" | jq -e '.database == "ok"'; }
for _ in $(seq 1 12); do grafana_ok >/dev/null 2>&1 && break; sleep 5; done
doit_reussir "Grafana répond (api/health)" grafana_ok
doit_echouer "LAN -> MGMT : client1 ne joint pas Prometheus" \
  docker exec "${P}client1" nc -z -w 3 "$NET.3.10" 9090

echo
echo "Résultat ($ENV_NAME) : $PASS OK, $FAIL échec(s)"
[ "$FAIL" -eq 0 ]
