#!/usr/bin/env bash
set -euo pipefail

required_github_host="${AUTOMATION_GITHUB_HOST:-github.com}"
required_github_account="${AUTOMATION_GITHUB_ACCOUNT:-alface0x19}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

cd "$repo_root"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI nao encontrado no PATH."
  exit 1
fi

gh auth switch --hostname "$required_github_host" --user "$required_github_account" >/dev/null

active_login="$(gh api user --jq '.login')"
if [[ "$active_login" != "$required_github_account" ]]; then
  echo "Conta GitHub ativa inesperada: $active_login"
  echo "Esperava: $required_github_account"
  exit 1
fi

active_id="$(gh api user --jq '.id')"
if [[ -z "$active_id" ]]; then
  echo "Nao foi possivel determinar o id da conta GitHub ativa."
  exit 1
fi

expected_email="${active_id}+${required_github_account}@users.noreply.github.com"
git config --local user.name "$required_github_account"
git config --local user.email "$expected_email"
