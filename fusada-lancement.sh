#!/bin/bash

# [lancement conteneur : ${NOM_CONTENEUR}] --> Définir les couleurs pour les messages dans la console
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# [lancement conteneur : ${NOM_CONTENEUR}] --> Vérification de l'existence du fichier de configuration
CONFIG_FILE="./fusada/fusada-config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[lancement conteneur : non défini] --> ERREUR : Le fichier de configuration ${CONFIG_FILE} est introuvable.${NC}"
    exit 1
else
    echo -e "${BLUE}[lancement conteneur : non défini] --> Chargement de la configuration depuis ${CONFIG_FILE}...${NC}"
    source "$CONFIG_FILE"
    echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Configuration chargée avec succès.${NC}"
fi

# [lancement conteneur : ${NOM_CONTENEUR}] --> Vérification si Docker est installé
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Vérification de l'installation de Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : Docker n'est pas installé. Veuillez installer Docker et réessayer.${NC}"
    exit 1
else
    echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Docker est installé.${NC}"
fi

# [lancement conteneur : ${NOM_CONTENEUR}] --> Construction de l'image Docker
DOCKERFILE_PATH="./fusada/Dockerfile"
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Construction de l'image Docker pour le serveur Minecraft...${NC}"
if docker build -t minecraft-server-image -f "$DOCKERFILE_PATH" .; then
    echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Image Docker construite avec succès.${NC}"
else
    echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : La construction de l'image Docker a échoué.${NC}"
    exit 1
fi

# [lancement conteneur : ${NOM_CONTENEUR}] --> Vérification si un conteneur avec le même nom existe déjà
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Vérification si un conteneur existant porte le même nom...${NC}"
if [ "$(docker ps -aq -f name=${NOM_CONTENEUR})" ]; then
    echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : Un conteneur avec le nom ${NOM_CONTENEUR} existe déjà.${NC}"
    echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Arrêt et suppression du conteneur existant...${NC}"
    if docker stop ${NOM_CONTENEUR} && docker rm ${NOM_CONTENEUR}; then
        echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Conteneur existant arrêté et supprimé.${NC}"
    else
        echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : Impossible de supprimer le conteneur existant.${NC}"
        exit 1
    fi
fi

# [lancement conteneur : ${NOM_CONTENEUR}] --> Construction de la commande Docker avec ou sans limite de ressources
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Lancement du conteneur Docker...${NC}"
if [ "$LIMITERESSOURCES" = true ] ; then
    echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Lancement du serveur Minecraft avec des limites de ressources...${NC}"
    if docker run -d -p $PORT_REEL:25565 \
        -v "$(pwd)":/minecraft \
        --name $NOM_CONTENEUR \
        --cpus="$CPU_LIMIT" \
        -m "$MEMORY_LIMIT" \
        minecraft-server-image; then
        echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Conteneur lancé avec succès avec des limites de ressources.${NC}"
    else
        echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : Le lancement du conteneur avec des limites de ressources a échoué.${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Lancement du serveur Minecraft sans limite de ressources...${NC}"
    if docker run -d -p $PORT_REEL:25565 \
        -v "$(pwd)":/minecraft \
        --name $NOM_CONTENEUR \
        minecraft-server-image; then
        echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Conteneur lancé avec succès sans limite de ressources.${NC}"
    else
        echo -e "${RED}[lancement conteneur : ${NOM_CONTENEUR}] --> ERREUR : Le lancement du conteneur sans limite de ressources a échoué.${NC}"
        exit 1
    fi
fi

# [lancement conteneur : ${NOM_CONTENEUR}] --> Instructions d'accès au serveur
echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Le serveur Minecraft est maintenant en cours d'exécution dans le conteneur Docker.${NC}"
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Pour accéder au serveur, utilisez l'adresse suivante : localhost:$PORT_REEL${NC}"
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Pour arrêter le serveur, utilisez la commande : docker stop $NOM_CONTENEUR${NC}"
echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Pour redémarrer le serveur, utilisez la commande : docker start $NOM_CONTENEUR${NC}"

# [lancement conteneur : ${NOM_CONTENEUR}] --> Attacher la console Docker si configuré
if [ "$ATTACH_CONSOLE" = "yes" ]; then
    echo -e "${BLUE}[lancement conteneur : ${NOM_CONTENEUR}] --> Attachement à la console du serveur Minecraft...${NC}"
    docker attach $NOM_CONTENEUR
else
    echo -e "${GREEN}[lancement conteneur : ${NOM_CONTENEUR}] --> Lancement terminé sans attachement à la console.${NC}"
fi
