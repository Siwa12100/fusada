#!/bin/bash

# Définir les couleurs pour les messages dans la console
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Vérification des arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}[configuration-rcon] --> ERREUR : SCRIPT_DIR ou SERVER_DIR n'est pas défini.${NC}"
    exit 1
fi

SCRIPT_DIR="$1"
SERVER_DIR="$2"

# Vérification de l'existence du fichier de configuration
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[configuration-rcon] --> ERREUR : Le fichier de configuration ${CONFIG_FILE} est introuvable.${NC}"
    exit 1
fi

# Chargement de la configuration
source "$CONFIG_FILE"

# Vérification et configuration de RCON dans server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ ! -f "$SERVER_PROPERTIES" ]; then
    echo -e "${RED}[configuration-rcon] --> ERREUR : Le fichier server.properties est introuvable. Configuration de RCON impossible.${NC}"
    exit 1
fi

RESTART_REQUIRED=false

if grep -q "enable-rcon=false" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}[configuration-rcon] --> Activation de RCON dans server.properties...${NC}"
    sed -i 's/enable-rcon=false/enable-rcon=true/' "$SERVER_PROPERTIES"
    sed -i "s/rcon.password=.*/rcon.password=$RCON_PASSWORD/" "$SERVER_PROPERTIES"
    sed -i "s/rcon.port=.*/rcon.port=$RCON_PORT/" "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
elif ! grep -q "enable-rcon=" "$SERVER_PROPERTIES"; then
    echo -e "${BLUE}[configuration-rcon] --> Ajout de la configuration RCON dans server.properties...${NC}"
    echo "enable-rcon=true" >> "$SERVER_PROPERTIES"
    echo "rcon.password=$RCON_PASSWORD" >> "$SERVER_PROPERTIES"
    echo "rcon.port=$RCON_PORT" >> "$SERVER_PROPERTIES"
    RESTART_REQUIRED=true
else
    echo -e "${GREEN}[configuration-rcon] --> RCON est déjà activé dans server.properties.${NC}"
fi

# Redémarrage du serveur si nécessaire
if [ "$RESTART_REQUIRED" = true ]; then
    echo -e "${BLUE}[configuration-rcon] --> Redémarrage du serveur Minecraft pour appliquer les modifications RCON...${NC}"
    docker restart $NOM_CONTENEUR
    echo -e "${GREEN}[configuration-rcon] --> Serveur Minecraft redémarré avec succès.${NC}"
fi
