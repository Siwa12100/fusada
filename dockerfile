# ============================================
#  Dockerfile Fusada - Serveur Minecraft
#  Base Java choisie dynamiquement via --build-arg BASE_IMAGE
# ============================================

ARG BASE_IMAGE=openjdk:21-slim
FROM ${BASE_IMAGE}

WORKDIR /minecraft

# Permet de fournir JAVA_OPTS au build (facultatif) puis de l'avoir en ENV
ARG JAVA_OPTS=""
ENV JAVA_OPTS=${JAVA_OPTS}

# RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

# Lancement: /bin/sh -lc (pas besoin de bash). JSON exec form → OK signaux & pas d’ambiguïtés.
CMD ["/bin/sh","-lc","exec java ${JAVA_OPTS:+$JAVA_OPTS} -jar server.jar nogui"]
