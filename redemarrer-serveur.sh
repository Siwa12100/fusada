#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok="✅"; err="❌"; restart="🔄"

CONFIG_FILE="./fusada/config.sh"
LAUNCHER="./fusada/lancement.sh"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if [ -z "${NOM_CONTENEUR:-}" ]; then
        echo -e "${RED}${err} NOM_CONTENEUR non défini dans config.sh${NC}"
        exit 1
    fi

    echo -e "${restart} Redémarrage complet du serveur : ${NOM_CONTENEUR}${NC}"
    docker stop "$NOM_CONTENEUR" || true
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
