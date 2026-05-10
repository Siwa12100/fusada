#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
ok="✅"; err="❌"; restart="🔄"; info="ℹ️"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"
LAUNCHER="$SCRIPT_DIR/lancement.sh"

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
        echo -e "${RED}${err} NOM_CONTENEUR non défini dans config.sh${NC}"
        exit 1
    fi

    STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-30}"
    echo -e "${restart} Redémarrage complet du serveur : ${NOM_CONTENEUR}${NC}"
    echo -e "${BLUE}${info} Stop timeout: ${STOP_TIMEOUT_SECONDS}s${NC}"
    docker stop -t "$STOP_TIMEOUT_SECONDS" "$NOM_CONTENEUR" || true
    docker rm "$NOM_CONTENEUR" || true

    if [ -x "$LAUNCHER" ]; then
        "$LAUNCHER"
    else
        echo -e "${RED}${err} Script de lancement introuvable : $LAUNCHER${NC}"
        exit 1
    fi

    echo -e "${GREEN}${ok} Serveur redémarré avec succès${NC}"
else
    echo -e "${RED}${err} Fichier de configuration introuvable : ${CONFIG_FILE}${NC}"
    exit 1
fi
