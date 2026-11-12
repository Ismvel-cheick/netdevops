# =============================================================================
# Image Jenkins de la chaîne NetDevOps : Jenkins + tous les outils du pipeline
# (Docker CLI/Compose, Ansible, ansible-lint, yamllint, pylint, Trivy, jq)
# =============================================================================
FROM jenkins/jenkins:lts-jdk21

USER root

# Outils de base, Ansible et linters (paquets Debian)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg jq git \
      python3 python3-requests python3-docker \
      ansible ansible-lint yamllint pylint \
 && rm -rf /var/lib/apt/lists/*

# Docker CLI + plugin Compose (le démon est celui de l'hôte, via le socket)
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
 && curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
      > /etc/apt/sources.list.d/trivy.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin trivy \
 && rm -rf /var/lib/apt/lists/*

# Collections Ansible utilisées par les rôles
RUN ansible-galaxy collection install community.docker community.general -p /usr/share/ansible/collections

# Le dépôt /repo appartient à l'utilisateur de la VM : Git doit l'accepter
RUN git config --system --add safe.directory '*'

USER jenkins

# Plugins Jenkins pré-installés
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
