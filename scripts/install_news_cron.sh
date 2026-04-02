#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Este script tem de correr dentro de um repositorio git."
  exit 1
fi

schedule="${1:-17 8,13,19 * * *}"
cron_command="cd $repo_root && scripts/collect_news_queue.sh >> /tmp/alface0x19-news-cron.log 2>&1"
begin_marker="# BEGIN alface0x19-news-collector"
end_marker="# END alface0x19-news-collector"
block="$begin_marker
$schedule $cron_command
$end_marker"

existing_crontab="$(crontab -l 2>/dev/null || true)"
cleaned_crontab="$(printf '%s\n' "$existing_crontab" | sed "/$begin_marker/,/$end_marker/d")"

if [[ -n "$cleaned_crontab" && "${cleaned_crontab: -1}" != $'\n' ]]; then
  cleaned_crontab="${cleaned_crontab}"$'\n'
fi

printf '%s\n%s\n' "$cleaned_crontab" "$block" | crontab -

echo "Cron instalado/atualizado."
echo "Horario: $schedule"
echo "Comando: $cron_command"
echo "Log: /tmp/alface0x19-news-cron.log"
