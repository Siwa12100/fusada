#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok='[OK]'; info='[INFO]'; warn='[WARN]'; err='[ERR]'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"
DRY_RUN="no"
DELETE_NON_GZIP="no"
ALLOW_RUNNING="no"

usage() {
  cat <<'EOF'
Usage: nettoyer-maps-corrompues.sh [options]

Options:
  --dry-run            Affiche sans supprimer
  --delete-non-gzip    Supprime aussi les map_*.dat non-gzip (non 0 octet)
  --allow-running      Autorise l'execution meme si le conteneur est actif
  -h, --help           Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="yes"; shift ;;
    --delete-non-gzip) DELETE_NON_GZIP="yes"; shift ;;
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

DATA_DIRS=(
  "$SERVER_DIR/world/data"
  "$SERVER_DIR/world_nether/data"
  "$SERVER_DIR/world_the_end/data"
  "$SERVER_DIR/world_the_end/DIM1/data"
)

EXISTING_DATA_DIRS=()
for d in "${DATA_DIRS[@]}"; do
  [[ -d "$d" ]] && EXISTING_DATA_DIRS+=("$d")
done

if [[ ${#EXISTING_DATA_DIRS[@]} -eq 0 ]]; then
  echo -e "${YELLOW}${warn} Aucun dossier data de monde detecte.${NC}"
  exit 0
fi

echo -e "${BLUE}${info} Recherche des map_*.dat corrompus dans:${NC}"
for d in "${EXISTING_DATA_DIRS[@]}"; do
  echo "  - $d"
done

mapfile -t ZERO_MAPS < <(find "${EXISTING_DATA_DIRS[@]}" -type f -name 'map_*.dat' -size 0c | sort)

NON_GZIP_MAPS=()
while IFS= read -r f; do
  if ! gzip -t "$f" >/dev/null 2>&1; then
    NON_GZIP_MAPS+=("$f")
  fi
done < <(find "${EXISTING_DATA_DIRS[@]}" -type f -name 'map_*.dat' ! -size 0c | sort)

echo -e "${BLUE}${info} map_*.dat a 0 octet: ${#ZERO_MAPS[@]}${NC}"
[[ ${#ZERO_MAPS[@]} -gt 0 ]] && printf '  %s\n' "${ZERO_MAPS[@]}"

echo -e "${BLUE}${info} map_*.dat non-gzip (non 0 octet): ${#NON_GZIP_MAPS[@]}${NC}"
[[ ${#NON_GZIP_MAPS[@]} -gt 0 ]] && printf '  %s\n' "${NON_GZIP_MAPS[@]}"

ZERO_BYTES=0
for f in "${ZERO_MAPS[@]}"; do
  [[ -f "$f" ]] && ZERO_BYTES=$((ZERO_BYTES + $(stat -c %s "$f")))
done

NON_GZIP_BYTES=0
for f in "${NON_GZIP_MAPS[@]}"; do
  [[ -f "$f" ]] && NON_GZIP_BYTES=$((NON_GZIP_BYTES + $(stat -c %s "$f")))
done

if [[ "$DRY_RUN" == "yes" ]]; then
  echo -e "${GREEN}${ok} DRY-RUN termine. Aucune suppression effectuee.${NC}"
  echo -e "${BLUE}${info} Taille candidate: zero=${ZERO_BYTES}B, non_gzip=${NON_GZIP_BYTES}B${NC}"
  exit 0
fi

DELETED_ZERO=0
if [[ ${#ZERO_MAPS[@]} -gt 0 ]]; then
  rm -f -- "${ZERO_MAPS[@]}"
  DELETED_ZERO=${#ZERO_MAPS[@]}
fi

DELETED_NON_GZIP=0
if [[ "$DELETE_NON_GZIP" == "yes" && ${#NON_GZIP_MAPS[@]} -gt 0 ]]; then
  rm -f -- "${NON_GZIP_MAPS[@]}"
  DELETED_NON_GZIP=${#NON_GZIP_MAPS[@]}
fi

echo -e "${GREEN}${ok} Suppression terminee: zero=${DELETED_ZERO}, non_gzip=${DELETED_NON_GZIP}${NC}"
TOTAL_FREED="$ZERO_BYTES"
if [[ "$DELETE_NON_GZIP" == "yes" ]]; then
  TOTAL_FREED=$((TOTAL_FREED + NON_GZIP_BYTES))
fi
echo -e "${BLUE}${info} Espace libere estime: ${TOTAL_FREED}B${NC}"
if [[ ${#NON_GZIP_MAPS[@]} -gt 0 && "$DELETE_NON_GZIP" != "yes" ]]; then
  echo -e "${YELLOW}${warn} Des maps non-gzip existent encore. Relance avec --delete-non-gzip si necessaire.${NC}"
fi
