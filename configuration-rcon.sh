#!/bin/bash

# [configuration-rcon] --> Définir les couleurs pour les messages dans la console
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# [configuration-rcon] --> Vérification de l'existence du fichier de configuration
if [ -z "$SCRIPT_DIR" ]; then
    echo -e "${RED}[configuration-rcon] --> ERREUR : SCRIPT_DIR n'est pas défini.${NC}"
    exit 1
fi

CONFIG_FILE="$SCRIPT_DIR/fusada-config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[configuration-rcon] --> ERREUR : Le fichier de configuration ${CONFIG_FILE} est introuvable.${NC}"
    exit 1
fi

# [configuration-rcon] --> Chargement de la configuration
source "$CONFIG_FILE"

# [configuration-rcon] --> Vérification et configuration de RCON dans server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ ! -f "$SERVER_PROPERTIES" ]; then
    echo -e "${RED}[configuration-rcon] --> AVERTISSEMENT : Le fichier server.properties n'existe pas.${NC}"
    exit 1
fi

if grep -q "enable-rcon=false" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}[configuration-rcon] --> Activation de RCON dans server.properties...${NC}"
    sed -i 's/enable-rcon=false/enable-rcon=true/' "$SERVER_PROPERTIES"
    sed -i "s/rcon.password=.*/rcon.password=$RCON_PASSWORD/" "$SERVER_PROPERTIES"
    sed -i "s/rcon.port=.*/rcon.port=$RCON_PORT/" "$SERVER_PROPERTIES"
elif ! grep -q "enable-rcon=" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}[configuration-rcon] --> Ajout de la configuration RCON dans server.properties...${NC}"
    echo "enable-rcon=true" >> "$SERVER_PROPERTIES"
    echo "rcon.password=$RCON_PASSWORD" >> "$SERVER_PROPERTIES"
    echo "rcon.port=$RCON_PORT" >> "$SERVER_PROPERTIES"
else
    echo -e "${GREEN}[configuration-rcon] --> RCON est déjà activé dans server.properties.${NC}"
fi
