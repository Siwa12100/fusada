#!/bin/bash

CONFIG_FILE="./fusada/fusada-config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    docker start $NOM_CONTENEUR
else
    echo "Le fichier de configuration n'a pas été trouvé. Veuillez vérifier le chemin."
fi
