#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

CRON_BEGIN="# >>> fusada-auto-tasks >>>"
CRON_END="# <<< fusada-auto-tasks <<<"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}${err} Config introuvable: ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

AUTO_TASKS_BACKUP_ENABLED="${AUTO_TASKS_BACKUP_ENABLED:-yes}"
AUTO_TASKS_BACKUP_HOUR="${AUTO_TASKS_BACKUP_HOUR:-4}"
AUTO_TASKS_BACKUP_MINUTE="${AUTO_TASKS_BACKUP_MINUTE:-0}"

AUTO_TASKS_CLEANUP_ENABLED="${AUTO_TASKS_CLEANUP_ENABLED:-yes}"
AUTO_TASKS_CLEANUP_HOUR="${AUTO_TASKS_CLEANUP_HOUR:-4}"
AUTO_TASKS_CLEANUP_MINUTE="${AUTO_TASKS_CLEANUP_MINUTE:-20}"

AUTO_TASKS_RESTART_ENABLED="${AUTO_TASKS_RESTART_ENABLED:-yes}"
AUTO_TASKS_RESTART_HOUR="${AUTO_TASKS_RESTART_HOUR:-4}"
AUTO_TASKS_RESTART_MINUTE="${AUTO_TASKS_RESTART_MINUTE:-40}"

AUTO_TASKS_LOG_FILE="${AUTO_TASKS_LOG_FILE:-logs/fusada-auto-tasks.log}"
if [[ "$AUTO_TASKS_LOG_FILE" = /* ]]; then
  AUTO_TASKS_LOG_FILE_RESOLVED="$AUTO_TASKS_LOG_FILE"
else
  AUTO_TASKS_LOG_FILE_RESOLVED="$SERVER_DIR/$AUTO_TASKS_LOG_FILE"
fi

usage() {
  cat <<EOF
Usage: $0 <enable|disable|status|help>

Ce script active/desactive les taches automatiques via crontab.
Le planning est configure uniquement dans config.sh.

Commandes:
  enable   Installe/maj les taches auto (backup + cleanup + restart selon config)
  disable  Supprime les taches auto Fusada de la crontab
  status   Affiche la config courante et l'etat d'installation
  help     Affiche cette aide
EOF
}

validate_yn() {
  local name="$1"
  local value="$2"
  if [[ "$value" != "yes" && "$value" != "no" ]]; then
    echo -e "${RED}${err} ${name} invalide: '${value}' (attendu: yes|no)${NC}"
    exit 1
  fi
}

validate_time() {
  local name="$1"
  local value="$2"
  local min="$3"
  local max="$4"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < min || value > max )); then
    echo -e "${RED}${err} ${name} invalide: '${value}' (attendu: ${min}-${max})${NC}"
    exit 1
  fi
}

require_crontab() {
  if ! command -v crontab >/dev/null 2>&1; then
    echo -e "${RED}${err} crontab introuvable.${NC}"
    echo -e "${BLUE}${info} Installe cron (ex Debian/Ubuntu): sudo apt update && sudo apt install -y cron${NC}"
    exit 1
  fi
}

cron_is_installed() {
  local current
  current="$(crontab -l 2>/dev/null || true)"
  printf '%s\n' "$current" | grep -Fq "$CRON_BEGIN"
}

strip_managed_block() {
  local current
  current="$(crontab -l 2>/dev/null || true)"
  printf '%s\n' "$current" | awk -v begin="$CRON_BEGIN" -v end="$CRON_END" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  '
}

build_block() {
  cat <<EOF
$CRON_BEGIN
# Fuseau utilise: systeme hote
# Logs: $AUTO_TASKS_LOG_FILE_RESOLVED
EOF

  if [[ "$AUTO_TASKS_BACKUP_ENABLED" == "yes" ]]; then
    echo "${AUTO_TASKS_BACKUP_MINUTE} ${AUTO_TASKS_BACKUP_HOUR} * * * cd '$SCRIPT_DIR' && bash ./backup.sh -y --no-restart >> '$AUTO_TASKS_LOG_FILE_RESOLVED' 2>&1"
  fi
  if [[ "$AUTO_TASKS_CLEANUP_ENABLED" == "yes" ]]; then
    echo "${AUTO_TASKS_CLEANUP_MINUTE} ${AUTO_TASKS_CLEANUP_HOUR} * * * cd '$SCRIPT_DIR' && bash ./mise-au-propre.sh --mode launch --yes >> '$AUTO_TASKS_LOG_FILE_RESOLVED' 2>&1"
  fi
  if [[ "$AUTO_TASKS_RESTART_ENABLED" == "yes" ]]; then
    echo "${AUTO_TASKS_RESTART_MINUTE} ${AUTO_TASKS_RESTART_HOUR} * * * cd '$SCRIPT_DIR' && bash ./redemarrer-serveur.sh >> '$AUTO_TASKS_LOG_FILE_RESOLVED' 2>&1"
  fi

  echo "$CRON_END"
}

validate_config() {
  validate_yn "AUTO_TASKS_BACKUP_ENABLED" "$AUTO_TASKS_BACKUP_ENABLED"
  validate_yn "AUTO_TASKS_CLEANUP_ENABLED" "$AUTO_TASKS_CLEANUP_ENABLED"
  validate_yn "AUTO_TASKS_RESTART_ENABLED" "$AUTO_TASKS_RESTART_ENABLED"

  validate_time "AUTO_TASKS_BACKUP_HOUR" "$AUTO_TASKS_BACKUP_HOUR" 0 23
  validate_time "AUTO_TASKS_BACKUP_MINUTE" "$AUTO_TASKS_BACKUP_MINUTE" 0 59
  validate_time "AUTO_TASKS_CLEANUP_HOUR" "$AUTO_TASKS_CLEANUP_HOUR" 0 23
  validate_time "AUTO_TASKS_CLEANUP_MINUTE" "$AUTO_TASKS_CLEANUP_MINUTE" 0 59
  validate_time "AUTO_TASKS_RESTART_HOUR" "$AUTO_TASKS_RESTART_HOUR" 0 23
  validate_time "AUTO_TASKS_RESTART_MINUTE" "$AUTO_TASKS_RESTART_MINUTE" 0 59
}

print_status() {
  require_crontab
  validate_config

  echo -e "${BLUE}${info} Etat automation Fusada${NC}"
  if cron_is_installed; then
    echo -e "${GREEN}${ok} Crontab Fusada installée${NC}"
  else
    echo -e "${YELLOW}${warn} Crontab Fusada non installée${NC}"
  fi

  echo -e "${BLUE}${info} Planning (config.sh)${NC}"
  echo "  - backup : ${AUTO_TASKS_BACKUP_ENABLED} à $(printf '%02d:%02d' "$AUTO_TASKS_BACKUP_HOUR" "$AUTO_TASKS_BACKUP_MINUTE")"
  echo "  - cleanup: ${AUTO_TASKS_CLEANUP_ENABLED} à $(printf '%02d:%02d' "$AUTO_TASKS_CLEANUP_HOUR" "$AUTO_TASKS_CLEANUP_MINUTE")"
  echo "  - restart: ${AUTO_TASKS_RESTART_ENABLED} à $(printf '%02d:%02d' "$AUTO_TASKS_RESTART_HOUR" "$AUTO_TASKS_RESTART_MINUTE")"
  echo "  - log file: $AUTO_TASKS_LOG_FILE_RESOLVED"

  if pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1; then
    echo -e "${GREEN}${ok} Service cron detecté${NC}"
  else
    echo -e "${YELLOW}${warn} Service cron non detecté (les tâches peuvent ne pas s'exécuter).${NC}"
  fi
}

enable_tasks() {
  require_crontab
  validate_config

  mkdir -p "$(dirname "$AUTO_TASKS_LOG_FILE_RESOLVED")"

  local clean block merged
  clean="$(strip_managed_block)"
  block="$(build_block)"

  merged="$clean"
  if [[ -n "$merged" ]]; then
    merged+=$'\n'
  fi
  merged+="$block"

  printf '%s\n' "$merged" | crontab -
  echo -e "${GREEN}${ok} Taches automatiques activées/mises à jour.${NC}"
  print_status
}

disable_tasks() {
  require_crontab

  local clean
  clean="$(strip_managed_block)"
  printf '%s\n' "$clean" | crontab -
  echo -e "${GREEN}${ok} Taches automatiques desactivées.${NC}"
  print_status
}

cmd="${1:-help}"
case "$cmd" in
  enable) enable_tasks ;;
  disable) disable_tasks ;;
  status) print_status ;;
  help|-h|--help) usage ;;
  *)
    echo -e "${RED}${err} Commande inconnue: $cmd${NC}"
    usage
    exit 1
    ;;
esac
