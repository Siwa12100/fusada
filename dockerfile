# [lancement conteneur : ${NOM_CONTENEUR}] --> Base image utilisée : OpenJDK 21 sur Alpine Linux pour un environnement léger et performant
FROM openjdk:21-jre-slim

# [lancement conteneur : ${NOM_CONTENEUR}] --> Définition du répertoire de travail dans le conteneur
WORKDIR /minecraft

# [lancement conteneur : ${NOM_CONTENEUR}] --> Copie du fichier serveur Minecraft depuis le répertoire parent
COPY ../server.jar .

# [lancement conteneur : ${NOM_CONTENEUR}] --> Commande pour démarrer le serveur Minecraft sans spécifier de limites mémoire
CMD ["java", "-jar", "server.jar", "nogui"]
