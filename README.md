# NetDevOps — Automatisation et sécurisation d'une infrastructure réseau segmentée

Projet fil rouge DevOps — M1 ERIS (Expert Réseau & Infrastructure Sécurisée), 2025-2026.
Auteur : Ismvel-cheick (Anzoumana Cissé)

Une PME dispose de trois zones réseau (DMZ, LAN, Management). Ce dépôt contient toute la chaîne
qui les construit, les configure, les teste, les supervise et les déploie automatiquement :
**Git → Jenkins → (lint, SonarQube, build, Trivy) → Ansible → Docker → tests → production**,
supervisé par **Prometheus + Grafana**.

---

## 1. Architecture

```
                      Internet / poste admin (Windows)
                                   │  :8080 / :8443 (HTTP/HTTPS)
┌──────────────────────────── Docker host (VM Ubuntu 26.04) ─────────────────────────────┐
│                                                                                          │
│  Outils DevOps :  Jenkins :8081   SonarQube :9000   Trivy   Ansible (+Vault)   Git       │
│                                                                                          │
│                          ┌──────────────────────────┐                                    │
│                          │ router-fw  (nftables)     │  ← seul point de passage           │
│                          │ .1.1     .2.1     .3.1    │    entre les zones                 │
│                          └───┬────────┬────────┬────┘                                    │
│        dmz-net 172.20.1.0/24 │        │        │ mgmt-net 172.20.3.0/24                  │
│     ┌───────────────────┐    │        │        │   ┌─────────────────────────────────┐   │
│     │ web-dmz  .1.10    │────┘        │        └───│ monitoring .3.10                 │   │
│     │ Nginx 80→443 TLS  │             │            │ Prometheus :9090  Grafana :3000  │   │
│     └───────────────────┘             │            │ node-exporter  nginx-exporter    │   │
│                    lan-net 172.20.2.0/24 (internal)│ blackbox (sondes HTTPS + DNS)    │   │
│     ┌──────────────┐ ┌──────────────┐ ┌──────────┐ └─────────────────────────────────┘   │
│     │ dns-lan .2.10│ │client1 .2.100│ │client2   │                                       │
│     │ dnsmasq :53  │ │              │ │ .2.101   │                                       │
│     └──────────────┘ └──────────────┘ └──────────┘                                       │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

| Service        | Réseau                       | IP (prod)                            | Rôle |
|----------------|------------------------------|--------------------------------------|------|
| `router-fw`    | dmz-net, lan-net, mgmt-net   | 172.20.1.1 / 172.20.2.1 / 172.20.3.1 | Routage inter-zones, pare-feu nftables, DNAT, node-exporter |
| `web-dmz`      | dmz-net                      | 172.20.1.10                          | Nginx, HTTP → HTTPS, en-têtes de sécurité |
| `dns-lan`      | lan-net                      | 172.20.2.10                          | dnsmasq, zone `pme.local` |
| `client1/2`    | lan-net                      | 172.20.2.100 / .101                  | Postes de test (curl, dig, nmap) |
| `monitoring`   | mgmt-net                     | 172.20.3.10                          | Prometheus, Grafana, exporters (même adresse) |

**Deux environnements** générés par Ansible à partir des mêmes rôles :

| Environnement | Réseaux     | Préfixe conteneurs | Web (HTTPS) | Prometheus | Grafana |
|---------------|-------------|--------------------|-------------|------------|---------|
| test          | 172.30.x.0/24 | `test-`          | 9443        | 19090      | 13000   |
| prod          | 172.20.x.0/24 | (aucun)          | 8443        | 9090       | 3000    |

### Matrice des flux (pare-feu)

| Source → Destination | Autorisé | Détail |
|----------------------|----------|--------|
| Internet → web-dmz   | ✅ | TCP 80/443 uniquement, via DNAT sur router-fw |
| LAN → web-dmz        | ✅ | TCP 80/443 |
| LAN → Internet       | ✅ | TCP 80/443 (NAT) |
| dns-lan → Internet   | ✅ | UDP/TCP 53 (résolveurs amont) |
| MGMT → toutes zones  | ✅ | Supervision (scrape, sondes) |
| **DMZ → LAN**        | ❌ | Bloqué et journalisé (`FW-FORWARD-DROP`) |
| **LAN → MGMT**       | ❌ | Bloqué |
| Tout le reste        | ❌ | Politique par défaut `drop` |

---

## 2. Arborescence

```
netdevops/
├── Jenkinsfile                 # Pipeline CI/CD (9 étapes)
├── sonar-project.properties    # Configuration de l'analyse SonarQube
├── docker-compose.yml          # Stack manuelle (étape 3, sans Ansible)
├── docker/                     # Dockerfiles : router-fw, web-dmz, dns-lan, client
├── ansible/
│   ├── site.yml                # Playbook principal
│   ├── inventories/{test,prod} # Variables par environnement
│   ├── group_vars/all/         # main.yml + vault.yml (chiffré Ansible Vault)
│   └── roles/                  # nftables, dnsmasq, nginx, monitoring, stack
├── monitoring/grafana/dashboards/netdevops.json   # Dashboard Grafana exporté
├── jenkins/                    # Image Jenkins + compose Jenkins/SonarQube
├── tests/connectivity.sh       # Tests curl / dig / nmap / nftables / supervision
├── scripts/
│   ├── setup-vm.sh             # Préparation de la VM
│   └── audit_nftables.py       # Audit automatique des règles du pare-feu
└── docs/                       # Rapport d'audit sécurité, rapports, captures
```

## 3. Stratégie de branches

- `main` : branche de production, lue par Jenkins (déploiement automatique).
- `feature/<brique>` : une branche par brique (`feature/ansible`, `feature/jenkins`...), fusionnée dans `main`.

## 4. Pipeline Jenkins

| # | Étape | Outil | Bloquant |
|---|-------|-------|----------|
| 1 | Checkout | Git | oui |
| 2 | Lint | yamllint, ansible-lint, pylint | non (build « instable ») |
| 3 | SonarQube Scan | sonar-scanner | oui |
| 4 | Build Docker | docker build (tag = n° de build) | oui |
| 5 | Trivy Scan | trivy (HIGH/CRITICAL) | CVE critique corrigeable → instable |
| 6 | Déploiement Test | Ansible (inventaire test) | oui |
| 7 | Tests de connectivité | curl, dig, nmap, nftables, audit Python | oui |
| 8 | Déploiement Prod | Ansible (inventaire prod) + tests | oui |
| 9 | Notification | email en cas d'échec | — |

Les rapports (lint, Trivy, tests, audit) sont archivés comme artefacts de chaque build.
Jenkins surveille le dépôt toutes les 2 minutes (`pollSCM`) : un `git commit` sur `main` déclenche le pipeline.

## 5. Mise en route

```bash
# 1. Préparer la VM (une seule fois)
sudo bash scripts/setup-vm.sh

# 2. Créer le coffre Ansible Vault
cd ansible
echo 'MOT_DE_PASSE_DU_COFFRE' > .vault_pass && chmod 600 .vault_pass
cp group_vars/all/vault.yml.example group_vars/all/vault.yml   # puis éditer
ansible-vault encrypt group_vars/all/vault.yml

# 3. Déployer
ansible-playbook site.yml                                 # environnement test
ansible-playbook -i inventories/prod/hosts.yml site.yml   # production

# 4. Tester
bash tests/connectivity.sh test
bash tests/connectivity.sh prod
python3 scripts/audit_nftables.py router-fw 172.20.1.10

# 5. Outils CI/CD
cd jenkins
echo "DOCKER_GID=$(getent group docker | cut -d: -f3)" > .env
echo "REPO_DIR=$HOME/netdevops" >> .env
docker compose up -d --build
```

| Interface  | URL                          |
|------------|------------------------------|
| Site web   | https://IP_VM:8443           |
| Grafana    | http://IP_VM:3000            |
| Prometheus | http://IP_VM:9090            |
| Jenkins    | http://IP_VM:8081            |
| SonarQube  | http://IP_VM:9000            |

## 6. Sécurité (DevSecOps)

Voir [docs/rapport-audit-securite.md](docs/rapport-audit-securite.md) : mesures en place,
vulnérabilités trouvées, corrections et améliorations restantes.
