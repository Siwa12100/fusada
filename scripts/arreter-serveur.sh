#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
ok="✅"; info="ℹ️"; err="❌"; stop="🛑"; trash="🗑️"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker non installé ou inaccessible.${NC}"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker installé mais daemon injoignable (service/permissions).${NC}"
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if [ -z "${NOM_CONTENEUR:-}" ]; then
        echo -e "${RED}${err} NOM_CONTENEUR n'est pas défini dans ${CONFIG_FILE}${NC}"
        exit 1
    fi

    STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-30}"
    echo -e "${BLUE}${info} Cible: ${NOM_CONTENEUR}, stop-timeout=${STOP_TIMEOUT_SECONDS}s${NC}"

    if docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
        echo -e "${YELLOW}${stop} Arrêt du conteneur : ${NOM_CONTENEUR}${NC}"
        docker stop -t "$STOP_TIMEOUT_SECONDS" "$NOM_CONTENEUR" || true

        echo -e "${YELLOW}${trash} Suppression du conteneur : ${NOM_CONTENEUR}${NC}"
        docker rm "$NOM_CONTENEUR" && \
          echo -e "${GREEN}${ok} Conteneur supprimé avec succès${NC}"
    else
        echo -e "${YELLOW}${info} Aucun conteneur nommé '${NOM_CONTENEUR}' n'existe actuellement.${NC}"
    fi
else
    echo -e "${RED}${err} Fichier de configuration introuvable : ${CONFIG_FILE}${NC}"
    exit 1
fi
