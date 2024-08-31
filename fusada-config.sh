#!/bin/bash

# [lancement conteneur : ${NOM_CONTENEUR}] --> Configuration du serveur Minecraft

# PORT_REEL : Le port sur lequel le serveur Minecraft sera accessible.
PORT_REEL=${PORT_REEL:-25565}  # Valeur par défaut : 25565

# NOM_CONTENEUR : Nom du conteneur Docker pour le serveur Minecraft.
NOM_CONTENEUR=${NOM_CONTENEUR:-"minecraft-serveur"}  # Valeur par défaut : minecraft-server

# LIMITERESSOURCES : Indique si les ressources (CPU, RAM) doivent être limitées. true/false
LIMITERESSOURCES=${LIMITERESSOURCES:-false}  # Valeur par défaut : false (pas de limitation)

# CPU_LIMIT : Limite du nombre de cœurs CPU que le conteneur peut utiliser. Ignoré si LIMITERESSOURCES=false
CPU_LIMIT=${CPU_LIMIT:-"2.0"}  # Valeur par défaut : 2 CPU

# MEMORY_LIMIT : Limite de la mémoire RAM que le conteneur peut utiliser. Ignoré si LIMITERESSOURCES=false
MEMORY_LIMIT=${MEMORY_LIMIT:-"4g"}  # Valeur par défaut : 4 Go

# CPUS_SET : Cœurs CPU spécifiques que le conteneur peut utiliser. Ignoré si LIMITERESSOURCES=false
CPUS_SET=${CPUS_SET:-"0,1"}  # Valeur par défaut : 0,1
