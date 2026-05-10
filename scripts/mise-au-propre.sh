#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok='[OK]'; info='[INFO]'; warn='[WARN]'; err='[ERR]'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"
MODE="manual"   # manual | launch
ASSUME_YES="no"

usage() {
  cat <<'EOF'
Usage: mise-au-propre.sh [options]

Options:
  --mode <manual|launch>  Mode manual (interactif) ou launch (non-interactif)
  --yes                   Repond oui automatiquement aux confirmations
  -h, --help              Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"; shift 2 ;;
    --yes)
      ASSUME_YES="yes"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo -e "${YELLOW}${warn} Option inconnue: $1${NC}"; usage; exit 1 ;;
  esac
done

if [[ "$MODE" != "manual" && "$MODE" != "launch" ]]; then
  echo -e "${RED}${err} --mode invalide: ${MODE}${NC}"
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}${err} Config introuvable: ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${NOM_CONTENEUR:?NOM_CONTENEUR manquant dans config.sh}"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-30}"

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker non disponible dans le PATH.${NC}"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker installé mais daemon injoignable (service/permissions).${NC}"
  exit 1
fi

MAP_SCRIPT="$SCRIPT_DIR/nettoyer-maps-corrompues.sh"
LEVEL_SCRIPT="$SCRIPT_DIR/nettoyer-level-temp.sh"

if [[ ! -x "$MAP_SCRIPT" || ! -x "$LEVEL_SCRIPT" ]]; then
  echo -e "${RED}${err} Scripts de nettoyage introuvables ou non executables.${NC}"
  echo "  - $MAP_SCRIPT"
  echo "  - $LEVEL_SCRIPT"
  exit 1
fi

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$NOM_CONTENEUR"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$NOM_CONTENEUR"
}

ask_yes_no() {
  local prompt="$1"
  local default_yes="${2:-yes}"
  local answer=""

  if [[ "$ASSUME_YES" == "yes" ]]; then
    return 0
  fi

  if [[ "$default_yes" == "yes" ]]; then
    read -r -p "$prompt [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
  fi
}

echo -e "${BLUE}${info} Debut de la mise au propre (mode=${MODE})${NC}"

WAS_RUNNING="no"
if container_exists && container_running; then
  WAS_RUNNING="yes"
  if [[ "$MODE" == "manual" ]]; then
    if ! ask_yes_no "Le serveur est allume. L'arreter pour la mise au propre ?" "yes"; then
      echo -e "${YELLOW}${warn} Operation annulee par l'utilisateur.${NC}"
      exit 0
    fi
  fi

  echo -e "${BLUE}${info} Arret du conteneur ${NOM_CONTENEUR} (timeout=${STOP_TIMEOUT_SECONDS}s)...${NC}"
  docker stop -t "$STOP_TIMEOUT_SECONDS" "$NOM_CONTENEUR" >/dev/null || true
  echo -e "${GREEN}${ok} Conteneur arrete.${NC}"
else
  echo -e "${BLUE}${info} Serveur deja arrete (ou conteneur absent).${NC}"
fi

echo -e "${BLUE}${info} Nettoyage des maps corrompues...${NC}"
"$MAP_SCRIPT"
echo -e "${GREEN}${ok} Nettoyage maps termine.${NC}"

echo -e "${BLUE}${info} Nettoyage des level temporaires corrompus...${NC}"
"$LEVEL_SCRIPT"
echo -e "${GREEN}${ok} Nettoyage level termine.${NC}"

if [[ "$MODE" == "manual" && "$WAS_RUNNING" == "yes" ]]; then
  if ask_yes_no "Le serveur etait allume. Redemarrer maintenant ?" "yes"; then
    LAUNCH_SCRIPT="$SCRIPT_DIR/lancement.sh"
    if [[ -x "$LAUNCH_SCRIPT" ]]; then
      echo -e "${BLUE}${info} Redemarrage via lancement.sh...${NC}"
      exec "$LAUNCH_SCRIPT"
    else
      echo -e "${RED}${err} Script de lancement introuvable/non executable: ${LAUNCH_SCRIPT}${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}${warn} Le serveur reste arrete (choix utilisateur).${NC}"
  fi
fi

echo -e "${GREEN}${ok} Mise au propre terminee.${NC}"
