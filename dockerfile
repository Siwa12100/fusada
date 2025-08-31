# ============================================
#  Dockerfile Fusada - Serveur Minecraft
# ============================================

ARG BASE_IMAGE=openjdk:21-slim
FROM ${BASE_IMAGE}

WORKDIR /minecraft

# Keep if you like, but not required anymore for CMD
ARG JAVA_OPTS=""
ENV JAVA_OPTS=${JAVA_OPTS}

# Run Java in exec JSON form (no shell; signals handled correctly)
CMD ["java","-jar","server.jar","nogui"]
