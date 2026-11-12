#!/bin/sh
# Fournit le mot de passe Ansible Vault depuis la variable d'environnement
# VAULT_PASS (injectée par Jenkins depuis ses credentials) : le secret
# n'est jamais écrit sur le disque ni dans le dépôt Git.
if [ -z "$VAULT_PASS" ]; then
  echo "VAULT_PASS non défini" >&2
  exit 1
fi
printf '%s\n' "$VAULT_PASS"
