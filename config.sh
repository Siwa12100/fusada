#!/bin/bash
# ============================================
#  Configuration Fusada - Serveur Minecraft
#  (sourcée par lancement.sh)
# ============================================

# 🔤 Nom du conteneur Docker
NOM_CONTENEUR=${NOM_CONTENEUR:-"minecraft-serveur"}

# 🧩 Version Minecraft (ex: 1.21.6, 1.20.4, 1.17.1, 1.12.2, ...)
# Sert à choisir automatiquement la version de Java dans l'image Docker.
MC_VERSION=${MC_VERSION:-"1.21.6"}

# 🌐 Port public côté hôte pour le jeu
PORT_SERVEUR=${PORT_SERVEUR:-25565}

# 🔐 RCON (TCP uniquement)
RCON_PORT=${RCON_PORT:-25575}
RCON_PASSWORD=${RCON_PASSWORD:-"mdpdefaut"}

# 🖥️ Attacher la console après le lancement ? (yes/no)
ATTACH_CONSOLE=${ATTACH_CONSOLE:-"yes"}

# 🔁 Politique de restart Docker (reboot/crash)
RESTART_POLICY=${RESTART_POLICY:-"unless-stopped"}

# 👤 Faire tourner le process dans le conteneur avec l’UID/GID de l’utilisateur hôte
RUN_AS_HOST_USER=${RUN_AS_HOST_USER:-"yes"}

# 🧹 Corriger les permissions (chown -R) au démarrage ?
FIX_OWNERSHIP_ON_START=${FIX_OWNERSHIP_ON_START:-"no"}

# 🧮 Limites de ressources
USE_RESOURCE_LIMITS=${USE_RESOURCE_LIMITS:-"no"}
LIMIT_CPU=${LIMIT_CPU:-""}         # ex: "2"
LIMIT_MEMORY=${LIMIT_MEMORY:-""}   # ex: "6g"

# 📦 (Avancé) Bind sur une IP précise de l’hôte (sinon vide)
BIND_IP=${BIND_IP:-""}

# ============================
#  Ports services “spéciaux”
# ============================
# Ouvrir TCP **et** UDP pour ces services si définis (non vides)
VOICECHAT_PORT=${VOICECHAT_PORT:-""}     # ex: 24454 (Simple Voice Chat)
DISCORDSRV_PORT=${DISCORDSRV_PORT:-""}   # ex: 24654 (si besoin)
BLUEMAP_PORT=${BLUEMAP_PORT:-""}         # ex: 8100 (web server BlueMap)

# Ports additionnels
ADDITIONAL_PORTS_BOTH=${ADDITIONAL_PORTS_BOTH:-""}  # "24753 30000 30001"
ADDITIONAL_PORTS_TCP=${ADDITIONAL_PORTS_TCP:-""}    # "27015 27016"
ADDITIONAL_PORTS_UDP=${ADDITIONAL_PORTS_UDP:-""}    # "19132"

# 🧪 Options Java supplémentaires (facultatif), ex: "-Xms2G -Xmx6G"
JAVA_OPTS=${JAVA_OPTS:-""}
