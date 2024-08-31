# [lancement conteneur : ${NOM_CONTENEUR}] --> Base image utilisée : OpenJDK 21 sur une version légère et performante
FROM openjdk:21-slim

# [lancement conteneur : ${NOM_CONTENEUR}] --> Définition du répertoire de travail dans le conteneur
WORKDIR /minecraft

# [lancement conteneur : ${NOM_CONTENEUR}] --> Commande pour démarrer le serveur Minecraft sans spécifier de limites mémoire
CMD ["java", "-jar", "server.jar", "nogui"]
