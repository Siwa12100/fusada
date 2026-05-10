#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; stat="📊"; ram="🧠"; cpu="⚙️"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
SERVER_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

NOM_CONTENEUR="${NOM_CONTENEUR:-ostal-neige}"

usage() {
  cat <<EOF
Fusada - Commande unifiee

Usage:
  $0 <commande> [options]

Commandes:
  start                 Lance le serveur (equiv. lancement.sh)
  stop                  Arrete/supprime le conteneur (equiv. arreter-serveur.sh)
  restart               Redemarre completement (equiv. redemarrer-serveur.sh)
  console [opts]        Console live (par defaut attach)
  logs [opts]           Logs historiques/live (mode logs)
  logscan [opts]        Analyse logs par intervalle + filtres
  rcon [opts]           Console RCON / one-shot
  backup [opts]         Backup ZIP (avec arret/restart guide)
  auto [cmd]            Active/desactive les taches automatiques
  watcher [cmd]         Watcher UUID dupliques (start|stop|status|logs)
  cleanup [opts]        Nettoyage maps/level corrompus
  status                Etat serveur + RAM/CPU instantanes
  status-watch [sec]    Status en boucle (defaut: 2s)
  help                  Affiche cette aide

Exemples:
  $0 start
  $0 console
  $0 logs --since 30m
  $0 logscan --since 2h --level warn
  $0 logscan --from "2026-05-09 00:00:00" --to "2026-05-10 23:59:59" --level error terraspread biome
  $0 rcon -c "list"
  $0 rcon --with-console
  $0 backup
  $0 backup -y --no-restart
  $0 auto status
  $0 auto enable
  $0 auto disable
  $0 watcher start
  $0 watcher status
  $0 watcher logs
  $0 status
  $0 status-watch 2
EOF
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}${err} Docker n'est pas installe ou absent du PATH.${NC}"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}${err} Docker est installe mais le daemon est injoignable.${NC}"
    exit 1
  fi
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"
}

print_status() {
  require_docker

  echo -e "${BLUE}${info} Conteneur cible: ${NOM_CONTENEUR}${NC}"

  if ! container_exists; then
    echo -e "${YELLOW}${warn} Conteneur inexistant.${NC}"
  else
    local state status started image restart_policy
    state=$(docker inspect -f '{{.State.Status}}' "${NOM_CONTENEUR}" 2>/dev/null || echo "unknown")
    status=$(docker inspect -f '{{.State.Running}}' "${NOM_CONTENEUR}" 2>/dev/null || echo "false")
    started=$(docker inspect -f '{{.State.StartedAt}}' "${NOM_CONTENEUR}" 2>/dev/null || echo "n/a")
    image=$(docker inspect -f '{{.Config.Image}}' "${NOM_CONTENEUR}" 2>/dev/null || echo "n/a")
    restart_policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "${NOM_CONTENEUR}" 2>/dev/null || echo "n/a")

    echo -e "${stat} Etat       : ${state}"
    echo -e "${stat} Running    : ${status}"
    echo -e "${stat} StartedAt  : ${started}"
    echo -e "${stat} Image      : ${image}"
    echo -e "${stat} Restart    : ${restart_policy}"

    if container_running; then
      local stats_line cpu_perc mem_usage mem_perc pids
      stats_line=$(docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.PIDs}}' "${NOM_CONTENEUR}" 2>/dev/null || true)
      if [[ -n "$stats_line" ]]; then
        IFS='|' read -r cpu_perc mem_usage mem_perc pids <<< "$stats_line"
        echo -e "${cpu} CPU        : ${cpu_perc:-n/a}"
        echo -e "${ram} Memoire    : ${mem_usage:-n/a} (${mem_perc:-n/a})"
        echo -e "${stat} PIDs       : ${pids:-n/a}"
      else
        echo -e "${YELLOW}${warn} Impossible de recuperer docker stats.${NC}"
      fi

      echo -e "${stat} Ports:"
      docker port "${NOM_CONTENEUR}" 2>/dev/null | sed 's/^/  - /' || echo "  - n/a"
    fi
  fi

  local cron_installed="no"
  if command -v crontab >/dev/null 2>&1; then
    if (crontab -l 2>/dev/null || true) | grep -Fq '# >>> fusada-auto-tasks >>>'; then
      cron_installed="yes"
    fi
  fi

  echo ""
  echo -e "${BLUE}${info} Taches automatiques${NC}"
  echo -e "${stat} Crontab installee : ${cron_installed}"
  echo -e "${stat} Backup   : ${AUTO_TASKS_BACKUP_ENABLED:-yes} à $(printf '%02d:%02d' "${AUTO_TASKS_BACKUP_HOUR:-4}" "${AUTO_TASKS_BACKUP_MINUTE:-0}")"
  echo -e "${stat} Cleanup  : ${AUTO_TASKS_CLEANUP_ENABLED:-yes} à $(printf '%02d:%02d' "${AUTO_TASKS_CLEANUP_HOUR:-4}" "${AUTO_TASKS_CLEANUP_MINUTE:-20}")"
  echo -e "${stat} Restart  : ${AUTO_TASKS_RESTART_ENABLED:-yes} à $(printf '%02d:%02d' "${AUTO_TASKS_RESTART_HOUR:-4}" "${AUTO_TASKS_RESTART_MINUTE:-40}")"
  echo -e "${stat} Log file : ${AUTO_TASKS_LOG_FILE:-logs/fusada-auto-tasks.log}"
}

run_script() {
  local script="$1"
  shift || true
  if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
    echo -e "${RED}${err} Script introuvable: $SCRIPTS_DIR/$script${NC}"
    exit 1
  fi
  if [[ ! -r "$SCRIPTS_DIR/$script" ]]; then
    echo -e "${RED}${err} Script illisible: $SCRIPTS_DIR/$script${NC}"
    exit 1
  fi
  exec bash "$SCRIPTS_DIR/$script" "$@"
}

cmd="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$cmd" in
  start)
    run_script "lancement.sh" "$@"
    ;;
  stop)
    run_script "arreter-serveur.sh" "$@"
    ;;
  restart)
    run_script "redemarrer-serveur.sh" "$@"
    ;;
  console)
    run_script "console.sh" "$@"
    ;;
  logs)
    run_script "console.sh" --mode logs "$@"
    ;;
  logscan)
    exec bash "$SCRIPTS_DIR/logscan.sh" "$@"
    ;;
  rcon)
    run_script "cli-rcon.sh" "$@"
    ;;
  backup)
    run_script "backup.sh" "$@"
    ;;
  auto)
    run_script "auto-tasks.sh" "$@"
    ;;
  watcher)
    run_script "watch-entity-duplicates.sh" "$@"
    ;;
  cleanup)
    run_script "mise-au-propre.sh" "$@"
    ;;
  status)
    print_status
    ;;
  status-watch)
    interval="${1:-2}"
    while true; do
      clear || true
      date
      echo ""
      print_status
      sleep "$interval"
    done
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo -e "${RED}${err} Commande inconnue: $cmd${NC}"
    echo ""
    usage
    exit 1
    ;;
esac
