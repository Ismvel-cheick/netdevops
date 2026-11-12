# Plan de soutenance — 15 min + démo

| Temps | Partie | Contenu | Support |
|-------|--------|---------|---------|
| 0:00 – 1:30 | Contexte | PME, 3 zones (DMZ / LAN / MGMT), objectif : tout automatiser et sécuriser | Schéma d'architecture (README) |
| 1:30 – 3:30 | Architecture | router-fw seul point de passage, plan d'adressage, matrice des flux | Tableau des flux |
| 3:30 – 5:00 | Git | Dépôt, branches `feature/*` → `main`, historique par étape | `git log --oneline --graph` |
| 5:00 – 7:00 | Ansible | Rôles, templates Jinja2, variables test/prod, handlers, idempotence, Vault | `nftables.conf.j2`, `vault.yml` chiffré |
| 7:00 – 9:00 | Pipeline Jenkins | Les 9 étapes, lint, SonarQube, Trivy, test avant prod | Stage View Jenkins |
| 9:00 – 10:30 | Supervision | Prometheus, sondes Blackbox, dashboard Grafana | Dashboard Grafana |
| 10:30 – 12:30 | Sécurité | Mesures DevSecOps, problèmes rencontrés et corrigés, points faibles | Rapport d'audit |
| 12:30 – 15:00 | Démo + conclusion | Voir scénario ci-dessous, limites et améliorations | VM en direct |

## Scénario de démo (≈ 3 min)

1. **Modifier** la page d'accueil (`docker/web-dmz/index.html`), `git commit` sur `main`.
2. Montrer **Jenkins** qui démarre tout seul (pollSCM) et enchaîne les 9 étapes.
3. Pendant le build : ouvrir **Grafana** (sondes OK, trafic du pare-feu).
4. Montrer un **flux bloqué** en direct :
   ```bash
   docker exec web-dmz ping -c 2 172.20.2.100     # DMZ -> LAN : échec attendu
   docker exec client1 curl -sk https://172.20.1.10 | head -3   # LAN -> DMZ : OK
   ```
5. À la fin du build : ouvrir **https://IP_VM:8443** → la nouvelle page est en production.

## Problèmes rencontrés (à raconter : c'est ce qui montre la démarche DevOps)

- VM sans Internet (réseau Host-only) → passage en NAT.
- Port 80 déjà pris par Apache → publication sur 8080/8443.
- Image Docker en cache réutilisée → reconstruction systématique des images.
- Grafana 11.6.0 qui plante sur le noyau 7.0 → détecté par les tests, passage à 12.0.0.
- Disque de l'hôte plein → nettoyage, surveillance de l'espace disque.
