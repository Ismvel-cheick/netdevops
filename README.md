# NetDevOps — Automatisation et sécurisation d'une infrastructure réseau segmentée

Projet fil rouge DevOps — M1 ERIS (Expert Réseau & Infrastructure Sécurisée), 2025-2026.

## Architecture

| Service      | Réseau(x)               | IP                         | Ports        |
|--------------|-------------------------|----------------------------|--------------|
| `router-fw`  | dmz-net, lan-net, mgmt-net | 172.20.1.1 / 172.20.2.1 / 172.20.3.1 | — |
| `web-dmz`    | dmz-net                 | 172.20.1.10                | 80, 443      |
| `dns-lan`    | lan-net                 | 172.20.2.10                | 53/udp, 53/tcp |
| `client1`    | lan-net                 | 172.20.2.100               | —            |
| `client2`    | lan-net                 | 172.20.2.101               | —            |
| `monitoring` | mgmt-net                | 172.20.3.10                | 9090, 3000   |

Réseaux Docker isolés : `dmz-net` 172.20.1.0/24, `lan-net` 172.20.2.0/24, `mgmt-net` 172.20.3.0/24.

## Arborescence

```
netdevops/
├── ansible/            # Playbooks, inventaires, rôles (nftables, dnsmasq, nginx), Vault
├── docker/             # Dockerfiles par service
├── monitoring/         # Prometheus + Grafana (provisioning, dashboards JSON)
├── jenkins/            # Conteneurs Jenkins / SonarQube (outils CI)
├── tests/              # Tests de connectivité (curl, dig, nmap, nftables)
├── scripts/            # Scripts utilitaires (setup de la VM)
├── docs/               # Schémas, rapports SonarQube / Trivy / audit sécurité
├── docker-compose.yml  # Services déployés
└── Jenkinsfile         # Pipeline CI/CD
```

## Stratégie de branches

- `main` : production (déploiement prod uniquement depuis cette branche)
- `dev` : intégration
- `feature/<brique>` : une branche par brique (docker, ansible, monitoring, jenkins…), fusionnée dans `dev` via merge

## Démarrage rapide

```bash
sudo bash scripts/setup-vm.sh   # une seule fois, sur la VM Ubuntu
docker compose up -d --build
```

_(Sections à compléter au fil des étapes.)_
