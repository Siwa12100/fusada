# ============================================
#  Dockerfile Fusada - Serveur Minecraft
#  Base Java choisie dynamiquement via --build-arg BASE_IMAGE
# ============================================

# 🧱 Image de base passée par build-arg (défaut: openjdk:21-slim)
ARG BASE_IMAGE=openjdk:21-slim
FROM ${BASE_IMAGE}

# 📁 Dossier de travail dans le conteneur
WORKDIR /minecraft

# 🔧 Variables (optionnelles) passées au build
ARG JAVA_OPTS=""

# ⛏️ (Optionnel) tu peux installer utilitaires si besoin :
# RUN apt-get update && apt-get install -y bash curl jq && rm -rf /var/lib/apt/lists/*

# 🏁 Commande de lancement
# - JAVA_OPTS permet d’injecter Xms/Xmx ou autres options GC si défini
# - server.jar doit être présent sur le volume /minecraft (monté par lancement.sh)
CMD [ "bash", "-lc", 'exec java ${JAVA_OPTS:+$JAVA_OPTS} -jar server.jar nogui' ]
