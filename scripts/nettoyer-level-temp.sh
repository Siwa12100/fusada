#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok='[OK]'; info='[INFO]'; warn='[WARN]'; err='[ERR]'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"
DRY_RUN="no"
DELETE_NON_ZERO="no"
ALLOW_RUNNING="no"

usage() {
  cat <<'EOF'
Usage: nettoyer-level-temp.sh [options]

Options:
  --dry-run          Affiche sans supprimer
  --delete-non-zero  Supprime aussi les level*.dat temporaires non vides
  --allow-running    Autorise l'execution meme si le conteneur est actif
  -h, --help         Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="yes"; shift ;;
    --delete-non-zero) DELETE_NON_ZERO="yes"; shift ;;
    --allow-running) ALLOW_RUNNING="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo -e "${YELLOW}${warn} Option inconnue: $1${NC}"; usage; exit 1 ;;
  esac
done

if [[ -f "$CONFIG_FILE" ]] && command -v docker >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  if [[ "${ALLOW_RUNNING}" != "yes" ]] && docker ps --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR:-}"; then
    echo -e "${RED}${err} Conteneur '${NOM_CONTENEUR}' en cours d'execution. Arrete le serveur ou utilise --allow-running.${NC}"
    exit 1
  fi
fi

WORLD_DIRS=(
  "$SERVER_DIR/world"
  "$SERVER_DIR/world_nether"
  "$SERVER_DIR/world_the_end"
)

EXISTING_WORLD_DIRS=()
for d in "${WORLD_DIRS[@]}"; do
  [[ -d "$d" ]] && EXISTING_WORLD_DIRS+=("$d")
done

if [[ ${#EXISTING_WORLD_DIRS[@]} -eq 0 ]]; then
  echo -e "${YELLOW}${warn} Aucun dossier de monde detecte.${NC}"
  exit 0
fi

echo -e "${BLUE}${info} Analyse des level*.dat temporaires dans:${NC}"
for d in "${EXISTING_WORLD_DIRS[@]}"; do
  echo "  - $d"
done

mapfile -t TEMP_ZERO < <(find "${EXISTING_WORLD_DIRS[@]}" -maxdepth 1 -type f -name 'level*.dat' ! -name 'level.dat' ! -name 'level.dat_old' -size 0c | sort)
mapfile -t TEMP_NON_ZERO < <(find "${EXISTING_WORLD_DIRS[@]}" -maxdepth 1 -type f -name 'level*.dat' ! -name 'level.dat' ! -name 'level.dat_old' ! -size 0c | sort)

echo -e "${BLUE}${info} level*.dat temporaires a 0 octet: ${#TEMP_ZERO[@]}${NC}"
[[ ${#TEMP_ZERO[@]} -gt 0 ]] && printf '  %s\n' "${TEMP_ZERO[@]}"

echo -e "${BLUE}${info} level*.dat temporaires non vides: ${#TEMP_NON_ZERO[@]}${NC}"
[[ ${#TEMP_NON_ZERO[@]} -gt 0 ]] && printf '  %s\n' "${TEMP_NON_ZERO[@]}"

ZERO_BYTES=0
for f in "${TEMP_ZERO[@]}"; do
  [[ -f "$f" ]] && ZERO_BYTES=$((ZERO_BYTES + $(stat -c %s "$f")))
done

NON_ZERO_BYTES=0
for f in "${TEMP_NON_ZERO[@]}"; do
  [[ -f "$f" ]] && NON_ZERO_BYTES=$((NON_ZERO_BYTES + $(stat -c %s "$f")))
done

if [[ "$DRY_RUN" == "yes" ]]; then
  echo -e "${GREEN}${ok} DRY-RUN termine. Aucune suppression effectuee.${NC}"
  echo -e "${BLUE}${info} Taille candidate: zero=${ZERO_BYTES}B, non_zero=${NON_ZERO_BYTES}B${NC}"
  exit 0
fi

DELETED_ZERO=0
if [[ ${#TEMP_ZERO[@]} -gt 0 ]]; then
  rm -f -- "${TEMP_ZERO[@]}"
  DELETED_ZERO=${#TEMP_ZERO[@]}
fi

DELETED_NON_ZERO=0
if [[ "$DELETE_NON_ZERO" == "yes" && ${#TEMP_NON_ZERO[@]} -gt 0 ]]; then
  rm -f -- "${TEMP_NON_ZERO[@]}"
  DELETED_NON_ZERO=${#TEMP_NON_ZERO[@]}
fi

echo -e "${GREEN}${ok} Suppression terminee: zero=${DELETED_ZERO}, non_zero=${DELETED_NON_ZERO}${NC}"
TOTAL_FREED="$ZERO_BYTES"
if [[ "$DELETE_NON_ZERO" == "yes" ]]; then
  TOTAL_FREED=$((TOTAL_FREED + NON_ZERO_BYTES))
fi
echo -e "${BLUE}${info} Espace libere estime: ${TOTAL_FREED}B${NC}"
if [[ ${#TEMP_NON_ZERO[@]} -gt 0 && "$DELETE_NON_ZERO" != "yes" ]]; then
  echo -e "${YELLOW}${warn} Des level temporaires non vides existent encore. Relance avec --delete-non-zero si necessaire.${NC}"
fi
