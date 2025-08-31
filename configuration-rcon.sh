#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; restart="🔄"

# 🔧 Vérification des arguments
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo -e "${RED}${err} [configuration-rcon] SCRIPT_DIR ou SERVER_DIR non défini.${NC}"
    exit 1
fi
SCRIPT_DIR="$1"
SERVER_DIR="$2"

# 🔧 Vérification config
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}${err} [configuration-rcon] Fichier de config introuvable : ${CONFIG_FILE}${NC}"
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# 🔎 Vérif server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ ! -f "$SERVER_PROPERTIES" ]; then
    echo -e "${RED}${err} [configuration-rcon] server.properties introuvable → RCON impossible.${NC}"
    exit 1
fi

RESTART_REQUIRED=false

# ⚙️ Activation ou mise à jour des propriétés RCON
if grep -Eq "^enable-rcon=false" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}${info} [configuration-rcon] Activation de RCON...${NC}"
    sed -i "s/^enable-rcon=false/enable-rcon=true/" "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
elif ! grep -Eq "^enable-rcon=" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}${info} [configuration-rcon] Ajout des entrées RCON...${NC}"
    echo "enable-rcon=true" >> "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
else
    echo -e "${GREEN}${ok} [configuration-rcon] RCON déjà activé.${NC}"
fi

# ⚙️ Màj password & port (toujours les écraser pour cohérence)
if grep -Eq "^rcon.password=" "$SERVER_PROPERTIES"; then
    sed -i "s/^rcon.password=.*/rcon.password=$RCON_PASSWORD/" "$SERVER_PROPERTIES"
else
    echo "rcon.password=$RCON_PASSWORD" >> "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
fi

if grep -Eq "^rcon.port=" "$SERVER_PROPERTIES"; then
    sed -i "s/^rcon.port=.*/rcon.port=$RCON_PORT/" "$SERVER_PROPERTIES"
else
    echo "rcon.port=$RCON_PORT" >> "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
fi

# 🔁 Redémarrage si nécessaire
if [ "$RESTART_REQUIRED" = true ]; then
    echo -e "${BLUE}${restart} [configuration-rcon] Redémarrage du conteneur '${NOM_CONTENEUR}' pour appliquer les modifs...${NC}"
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}${err} Docker non installé → impossible de redémarrer.${NC}"
        exit 1
    fi
    if docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
        docker restart "${NOM_CONTENEUR}" >/dev/null
        echo -e "${GREEN}${ok} [configuration-rcon] Serveur Minecraft redémarré avec succès.${NC}"
    else
        echo -e "${YELLOW}${warn} [configuration-rcon] Conteneur '${NOM_CONTENEUR}' introuvable → pas de restart.${NC}"
    fi
else
    echo -e "${GREEN}${ok} [configuration-rcon] Aucune modif → pas de redémarrage.${NC}"
fi
