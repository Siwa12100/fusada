#!/bin/bash

# Définir les couleurs pour les messages dans la console
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Vérification de la présence de mcrcon
if ! command -v mcrcon &> /dev/null
then
    echo -e "${RED}[fusada-console : non défini] --> ERREUR : mcrcon n'est pas installé ou accessible.${NC}"
    echo -e "${BLUE}[fusada-console : non défini] --> Veuillez installer mcrcon pour utiliser ce script.${NC}"
    exit 1
fi

# Obtenir le chemin du script et le répertoire du serveur
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER_DIR=$(dirname "$SCRIPT_DIR")

# Vérification de l'existence du fichier de configuration
CONFIG_FILE="$SCRIPT_DIR/fusada-config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[fusada-console : non défini] --> ERREUR : Le fichier de configuration ${CONFIG_FILE} est introuvable.${NC}"
    exit 1
else
    echo -e "${BLUE}[fusada-console : non défini] --> Chargement de la configuration depuis ${CONFIG_FILE}...${NC}"
    source "$CONFIG_FILE"
    echo -e "${GREEN}[fusada-console : ${NOM_CONTENEUR}] --> Configuration chargée avec succès.${NC}"
fi

# Vérification de l'existence de server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ ! -f "$SERVER_PROPERTIES" ]; then
    echo -e "${RED}[fusada-console : ${NOM_CONTENEUR}] --> ERREUR : Le fichier server.properties est introuvable. Impossible de se connecter à RCON.${NC}"
    exit 1
fi

# Configuration de RCON
"$SCRIPT_DIR/configuration-rcon.sh" "$SCRIPT_DIR" "$SERVER_DIR"

# Interaction avec la console Minecraft via mcrcon
echo -e "${BLUE}[fusada-console : ${NOM_CONTENEUR}] --> Connexion à la console Minecraft via RCON. Tapez 'exit' pour quitter.${NC}"

while true; do
    echo -n "> "
    read cmd
    if [ "$cmd" = "exit" ]; then
        break
    fi
    mcrcon -H localhost -P "$RCON_PORT" -p "$RCON_PASSWORD" "$cmd"
done

echo -e "${GREEN}[fusada-console : ${NOM_CONTENEUR}] --> Session de commande terminée.${NC}"
