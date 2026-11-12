# Rapport d'audit sécurité — Projet NetDevOps

Projet fil rouge DevOps — M1 ERIS — 2025-2026
Périmètre : infrastructure segmentée (DMZ / LAN / MGMT), chaîne CI/CD et outils associés.

> Les sections marquées **[à compléter]** reprennent les résultats réels du pipeline Jenkins
> (artefacts `reports/` du dernier build) : SonarQube, Trivy, tests et audit nftables.

---

## 1. Méthode

| Contrôle | Outil | Fréquence |
|----------|-------|-----------|
| Qualité / sécurité du code (Ansible, Python, Dockerfiles) | SonarQube, ansible-lint, yamllint, pylint | à chaque commit |
| Vulnérabilités des images Docker (CVE) | Trivy (HIGH, CRITICAL) | à chaque build |
| Filtrage réseau effectif | `tests/connectivity.sh` (curl, dig, nmap, nc) | à chaque déploiement |
| Conformité des règles du pare-feu | `scripts/audit_nftables.py` | à chaque déploiement |
| Disponibilité des services | Prometheus + Blackbox (sondes HTTPS / DNS) | toutes les 15 s |

## 2. Mesures de sécurité en place

### 2.1 Segmentation et filtrage réseau
- Trois réseaux Docker isolés ; **router-fw est le seul conteneur relié aux trois zones**.
- Pare-feu nftables en **liste blanche** : politique `drop` sur `input` et `forward`,
  seuls les flux nécessaires sont ouverts (voir matrice des flux du README).
- **DMZ → LAN interdit** : un serveur web compromis ne peut pas atteindre le réseau interne.
- **LAN → MGMT interdit** : les postes ne peuvent pas joindre la supervision.
- `lan-net` est un réseau Docker `internal` : aucune sortie directe, uniquement via le pare-feu.
- Paquets refusés **journalisés** (préfixes `FW-INPUT-DROP` / `FW-FORWARD-DROP`, limités en débit).
- Exposition sur Internet réduite à **80/443 de la DMZ** (DNAT) ; nmap depuis le LAN confirme :
  22, 53, 8080 `filtered`, seuls 80/443 `open`.

### 2.2 Durcissement des services
- **Nginx** : redirection HTTP → HTTPS, TLS 1.2/1.3 uniquement, `server_tokens off`,
  en-têtes `Strict-Transport-Security`, `X-Frame-Options DENY`, `X-Content-Type-Options nosniff`,
  `Referrer-Policy no-referrer` ; page de statut réservée au réseau MGMT.
- **dnsmasq** : pas de lecture de `/etc/resolv.conf`, zone `pme.local` jamais transmise à
  l'extérieur, `domain-needed`, `bogus-priv`, **protection contre le DNS rebinding**.
- **Grafana** : inscription désactivée, télémétrie désactivée, mot de passe admin fourni par fichier.
- Images de base minimales (Alpine) et versions **épinglées** (Prometheus, Grafana, exporters).
- Configurations montées en **lecture seule** (`:ro`) dans les conteneurs.

### 2.3 Gestion des secrets
- Secrets chiffrés avec **Ansible Vault** (AES-256) dans `ansible/group_vars/all/vault.yml`.
- Mot de passe du coffre **hors dépôt** (`.vault_pass` dans `.gitignore`).
- Dans Jenkins, le mot de passe Vault et le jeton SonarQube sont des **credentials** ;
  le mot de passe Vault est transmis par variable d'environnement via
  `vault-pass-from-env.sh` et **n'est jamais écrit sur le disque**.
- Tâche Ansible manipulant le secret marquée `no_log: true` (absent des journaux).

### 2.4 Chaîne CI/CD
- Aucun déploiement en production sans passage préalable des tests sur l'environnement de test.
- Images taguées avec le **numéro de build** : traçabilité et retour arrière possible.
- Rapports de lint, Trivy, tests et audit **archivés** à chaque build.

## 3. Vulnérabilités et points faibles identifiés

| # | Constat | Gravité | Statut / correction |
|---|---------|---------|---------------------|
| 1 | Grafana 11.6.0 plantait (code 139) sur le noyau Linux 7.0 : supervision indisponible | Moyenne | **Corrigé** : passage à Grafana 12.0.0, détecté par les tests automatisés |
| 2 | Image Docker en cache réutilisée après modification du Dockerfile (déploiement d'une ancienne configuration) | Moyenne | **Corrigé** : reconstruction systématique (`stack_build: always`) et tag par build en CI |
| 3 | Conflit de port 80 avec un Apache existant sur l'hôte | Faible | **Corrigé** : publication sur 8080/8443 |
| 4 | Certificat TLS **auto-signé** pour www.pme.local | Moyenne | Ouvert : utiliser une PKI interne ou Let's Encrypt en production |
| 5 | `web-dmz`, `dns-lan` et les clients ont la capacité `NET_ADMIN` (pour fixer leur route) | Moyenne | Ouvert : définir la route via la passerelle du réseau Docker et retirer la capacité |
| 6 | Jenkins a accès au **socket Docker** de l'hôte (équivalent root sur l'hôte) | Élevée | Accepté pour le TP ; en production : agent Jenkins dédié ou Docker rootless |
| 7 | Mot de passe Grafana écrit en clair (0644) dans le dossier de déploiement `build/` (non versionné) | Faible | Ouvert : utiliser les `secrets` Docker / permissions 0600 avec l'UID Grafana |
| 8 | SonarQube avec base embarquée H2 | Faible | Ouvert : PostgreSQL en production |
| 9 | Jenkins et SonarQube en HTTP (sans TLS) | Moyenne | Ouvert : reverse proxy HTTPS devant les outils |
| 10 | Le DNAT masque l'IP réelle des clients dans les journaux Nginx | Faible | Ouvert : en-tête `X-Forwarded-For` / proxy protocol |
| 11 | Trivy (build #4) : web-dmz basée sur nginx 1.27 / Alpine 3.21.3 → 1 CVE CRITICAL (brotli) + 51 HIGH (curl, libexpat, libxml2, libpng, pcre2, musl…) ; autres images : 2 HIGH (musl) | Élevée | **Corrigé** : passage à nginx 1.28-alpine et `apk upgrade` dans tous les Dockerfiles, vérifié par un nouveau scan |
| 12 | Remarques SonarQube (bugs, code smells, hotspots) | **[à compléter]** | **[à compléter]** : voir le projet `netdevops` sur SonarQube |

## 4. Résultats des contrôles automatisés [à compléter]

- **Tests de connectivité (prod)** : **18 OK, 0 échec** (rapport `reports/tests-prod.txt`).
- **Audit nftables** : **5 OK, 0 échec** (rapport `reports/audit-nftables-prod.txt`).
- **Trivy** : CVE HIGH / CRITICAL avec correctif disponible, par image :

| Image | Build #4 (avant) CRITICAL | Build #4 HIGH | Après correction CRITICAL | Après correction HIGH |
|-------|---------------------------|---------------|---------------------------|-----------------------|
| netdevops/router-fw | 0 | 2  | [à compléter] | [à compléter] |
| netdevops/web-dmz   | 1 | 51 | [à compléter] | [à compléter] |
| netdevops/dns-lan   | 0 | 2  | [à compléter] | [à compléter] |
| netdevops/client    | 0 | 2  | [à compléter] | [à compléter] |

- **SonarQube** : Quality Gate **Passed** (134 lignes analysées : Dockerfiles, Python, YAML).
- **pylint** : `scripts/audit_nftables.py` noté **10,00 / 10**.
- **Pipeline** : builds #3 et #4 complets jusqu'à la production (Lint et Trivy « instables », non bloquants).

## 5. Recommandations prioritaires

1. Remplacer le certificat auto-signé par un certificat signé (PKI interne).
2. Isoler Jenkins du socket Docker (agent dédié, Docker rootless ou Kaniko pour les builds).
3. Mettre Jenkins, SonarQube et Grafana derrière un reverse proxy HTTPS avec authentification.
4. Retirer `NET_ADMIN` des conteneurs applicatifs.
5. Centraliser les journaux du pare-feu (ELK / Loki) et créer des alertes Prometheus
   (sonde en échec, pic de paquets refusés).
6. Faire échouer le pipeline (et non le rendre instable) sur toute CVE critique corrigeable.
