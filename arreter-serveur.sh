#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok="✅"; info="ℹ️"; err="❌"; stop="🛑"; trash="🗑️"

CONFIG_FILE="./fusada/config.sh"

if [ -f "$CONFIG_FILE" ]; then
    # Charger la config
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    if [ -z "${NOM_CONTENEUR:-}" ]; then
        echo -e "${RED}${err} NOM_CONTENEUR n'est pas défini dans ${CONFIG_FILE}${NC}"
        exit 1
    fi

    # Vérifier si le conteneur existe
    if docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
        echo -e "${YELLOW}${stop} Arrêt du conteneur : ${NOM_CONTENEUR}${NC}"
        docker stop "$NOM_CONTENEUR" || true

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
