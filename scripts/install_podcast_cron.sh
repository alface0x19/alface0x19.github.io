#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

source "$repo_root/scripts/lib/codex_cli.sh"

schedule="${1:-0 18 * * 4}"
codex_bin="${CODEX_BIN:-}"
if [[ -z "$codex_bin" ]]; then
  codex_bin="$(resolve_codex_cli)"
fi

if [[ -n "$codex_bin" ]]; then
  cron_command="cd $repo_root && CODEX_BIN=$codex_bin bash scripts/run_weekly_podcast_pipeline.sh >> /tmp/alface0x19-podcast-cron.log 2>&1"
else
  cron_command="cd $repo_root && bash scripts/run_weekly_podcast_pipeline.sh >> /tmp/alface0x19-podcast-cron.log 2>&1"
fi

begin_marker="# BEGIN alface0x19-weekly-podcast"
end_marker="# END alface0x19-weekly-podcast"
block="$begin_marker
$schedule $cron_command
$end_marker"

existing_crontab="$(crontab -l 2>/dev/null || true)"
cleaned_crontab="$(printf '%s\n' "$existing_crontab" | sed "/$begin_marker/,/$end_marker/d")"

if [[ -n "$cleaned_crontab" && "${cleaned_crontab: -1}" != $'\n' ]]; then
  cleaned_crontab="${cleaned_crontab}"$'\n'
fi

printf '%s\n%s\n' "$cleaned_crontab" "$block" | crontab -

echo "Cron de podcast instalado/atualizado."
echo "Horario: $schedule"
echo "Comando: $cron_command"
echo "Log: /tmp/alface0x19-podcast-cron.log"
