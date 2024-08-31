#!/bin/bash

# [fusada-lancement : non défini] --> Définir les couleurs pour les messages dans la console
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# [fusada-lancement : non défini] --> Obtenir le chemin du script et le répertoire du serveur
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER_DIR=$(dirname "$SCRIPT_DIR")

# [fusada-lancement : non défini] --> Vérification de l'existence du fichier de configuration
CONFIG_FILE="$SCRIPT_DIR/fusada-config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[fusada-lancement : non défini] --> ERREUR : Le fichier de configuration ${CONFIG_FILE} est introuvable.${NC}"
    exit 1
else
    echo -e "${BLUE}[fusada-lancement : non défini] --> Chargement de la configuration depuis ${CONFIG_FILE}...${NC}"
    source "$CONFIG_FILE"
    echo -e "${GREEN}[fusada-lancement : ${NOM_CONTENEUR}] --> Configuration chargée avec succès.${NC}"
fi

# [fusada-lancement : ${NOM_CONTENEUR}] --> Vérification de l'installation de Docker
if ! command -v docker &> /dev/null
then
    echo -e "${RED}[fusada-lancement : ${NOM_CONTENEUR}] --> ERREUR : Docker n'est pas installé ou accessible.${NC}"
    exit 1
fi

# [fusada-lancement : ${NOM_CONTENEUR}] --> Vérification de l'existence de server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ -f "$SERVER_PROPERTIES" ]; then
    echo -e "${BLUE}[fusada-lancement : ${NOM_CONTENEUR}] --> Le fichier server.properties existe. Configuration de RCON...${NC}"
    "$SCRIPT_DIR/configuration-rcon.sh"
else
    echo -e "${RED}[fusada-lancement : ${NOM_CONTENEUR}] --> AVERTISSEMENT : Le fichier server.properties est introuvable. Configuration de RCON ignorée.${NC}"
fi

# [fusada-lancement : ${NOM_CONTENEUR}] --> Construction de l'image Docker
docker build -t minecraft-server-image -f "$SCRIPT_DIR/dockerfile" "$SCRIPT_DIR"

# [fusada-lancement : ${NOM_CONTENEUR}] --> Vérification si un conteneur existant porte le même nom
if [ "$(docker ps -aq -f name=$NOM_CONTENEUR)" ]; then
    echo -e "${RED}[fusada-lancement : ${NOM_CONTENEUR}] --> Un conteneur avec le nom $NOM_CONTENEUR existe déjà. Arrêt et suppression...${NC}"
    docker stop $NOM_CONTENEUR
    docker rm $NOM_CONTENEUR
fi

# [fusada-lancement : ${NOM_CONTENEUR}] --> Construction de l'option de limitation des ressources
LIMITS=""
if [ "$USE_RESOURCE_LIMITS" = "yes" ]; then
    if [ -n "$LIMIT_CPU" ]; alors
        LIMITS="$LIMITS --cpus=$LIMIT_CPU"
    fi
    if [ -n "$LIMIT_MEMORY" ]; alors
        LIMITS="$LIMITS --memory=$LIMIT_MEMORY"
    fi
fi

# [fusada-lancement : ${NOM_CONTENEUR}] --> Lancement du conteneur Docker avec ou sans limite de ressources et en montant un volume
if [ -n "$LIMITS" ]; then
    echo -e "${BLUE}[fusada-lancement : ${NOM_CONTENEUR}] --> Lancement du conteneur avec limites de ressources : $LIMITS...${NC}"
    docker run -d $LIMITS -v "$SERVER_DIR:/minecraft" -p $PORT_SERVEUR:25565 -p $RCON_PORT:$RCON_PORT --name $NOM_CONTENEUR minecraft-server-image
else
    echo -e "${BLUE}[fusada-lancement : ${NOM_CONTENEUR}] --> Lancement du conteneur sans limite de ressources...${NC}"
    docker run -d -v "$SERVER_DIR:/minecraft" -p $PORT_SERVEUR:25565 -p $RCON_PORT:$RCON_PORT --name $NOM_CONTENEUR minecraft-server-image
fi

echo -e "${GREEN}[fusada-lancement : ${NOM_CONTENEUR}] --> Le serveur Minecraft est maintenant en cours d'exécution dans le conteneur Docker.${NC}"

docker attach ${NOM_CONTENEUR}
