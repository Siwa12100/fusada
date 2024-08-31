#!/bin/bash

# Configuration par défaut pour le serveur Minecraft

# Nom du conteneur Docker pour le serveur Minecraft
NOM_CONTENEUR=${NOM_CONTENEUR:-"minecraft-serveur"}

# Port sur lequel le serveur Minecraft est accessible
PORT_SERVEUR=${PORT_SERVEUR:-25565}

# Port pour RCON
RCON_PORT=${RCON_PORT:-25575}

# Mot de passe pour RCON
RCON_PASSWORD=${RCON_PASSWORD:-"mdpdefaut"}

# Activer ou désactiver l'attachement automatique à la console après le lancement
ATTACH_CONSOLE=${ATTACH_CONSOLE:-"yes"}

# Limitation des ressources (RAM et CPU)
LIMIT_CPU=${LIMIT_CPU:-""}          # Exemple : "2" pour limiter à 2 CPUs, ou laisser vide pour ne pas limiter
LIMIT_MEMORY=${LIMIT_MEMORY:-""}    # Exemple : "2g" pour limiter à 2 Go de RAM, ou laisser vide pour ne pas limiter

# Option pour activer/désactiver la limitation des ressources
USE_RESOURCE_LIMITS=${USE_RESOURCE_LIMITS:-"no"}  # "yes" pour activer les limites de ressources
