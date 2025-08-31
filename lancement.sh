#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; build="🛠️"; rocket="🚀"; port="🔌"

# 📁 Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$SCRIPT_DIR/config.sh"
DOCKERFILE_PATH="$SCRIPT_DIR/dockerfile"

echo -e "${BLUE}${info} Fusada - Lancement serveur Minecraft${NC}"
echo -e "${BLUE}${info} Script : ${SCRIPT_DIR}${NC}"
echo -e "${BLUE}${info} Dossier serveur (monté en volume) : ${SERVER_DIR}${NC}"

# 🔧 Charger la config
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}${err} Config introuvable : ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"
echo -e "${GREEN}${ok} Config chargée (${CONFIG_FILE})${NC}"

# 🐳 Vérifier Docker
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker n'est pas installé ou non accessible dans \$PATH${NC}"
  exit 1
fi
echo -e "${GREEN}${ok} Docker détecté${NC}"

# 🧾 EULA
EULA_FILE="$SERVER_DIR/eula.txt"
if [ ! -f "$EULA_FILE" ]; then
  echo -e "${YELLOW}${warn} eula.txt absent → création avec eula=true${NC}"
  echo "eula=true" > "$EULA_FILE"
else
  echo -e "${GREEN}${ok} eula.txt présent${NC}"
fi

# 🧰 RCON (si server.properties présent)
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [ -f "$SERVER_PROPERTIES" ]; then
  if [ -x "$SCRIPT_DIR/configuration-rcon.sh" ]; then
    echo -e "${BLUE}${info} Configuration RCON via configuration-rcon.sh${NC}"
    "$SCRIPT_DIR/configuration-rcon.sh" "$SCRIPT_DIR" "$SERVER_DIR"
  else
    echo -e "${YELLOW}${warn} configuration-rcon.sh introuvable ou non exécutable → ignoré${NC}"
  fi
else
  echo -e "${YELLOW}${warn} server.properties absent → skip configuration RCON${NC}"
fi

# 👤 Permissions : chown initial (optionnel)
if [ "${FIX_OWNERSHIP_ON_START}" = "yes" ]; then
  echo -e "${BLUE}${info} Correction des permissions (chown -R $(id -un):$(id -gn)) sur ${SERVER_DIR}${NC}"
  sudo chown -R "$(id -u)":"$(id -g)" "$SERVER_DIR" || {
    echo -e "${YELLOW}${warn} chown a échoué (droits sudo requis ?). Continue quand même.${NC}"
  }
fi

# ☕ Sélection auto de l'image Java selon MC_VERSION
choose_base_image() {
  local v="$1"
  # Normalisation simple : garde "x.y.z" ou "x.y"
  # Règles (mémo) :
  # 1.21.x           → openjdk:21-slim
  # 1.20.5 → 1.20.6  → openjdk:21-slim
  # 1.18 → 1.20.4    → openjdk:17-jdk-slim
  # 1.17.x           → openjdk:16-jdk-slim
  # 1.13 → 1.16.5    → openjdk:11-jre-slim
  # 1.8 → 1.12.2     → openjdk:8-jre-slim
  # 1.7.x (hist.)    → openjdk:8-jre-slim (compat)
  case "$v" in
    1.21|1.21.*)   echo "openjdk:21-slim" ;;
    1.20.5|1.20.5*|1.20.6|1.20.6*) echo "openjdk:21-slim" ;;
    1.18|1.18.*|1.19|1.19.*|1.20|1.20.[0-4]|1.20.[0-4]*) echo "openjdk:17-jdk-slim" ;;
    1.17|1.17.*)   echo "openjdk:16-jdk-slim" ;;
    1.13|1.13.*|1.14|1.14.*|1.15|1.15.*|1.16|1.16.*) echo "openjdk:11-jre-slim" ;;
    1.8|1.8.*|1.9|1.9.*|1.10|1.10.*|1.11|1.11.*|1.12|1.12.*|1.7|1.7.*) echo "openjdk:8-jre-slim" ;;
    *) echo "openjdk:21-slim" ;; # défaut raisonnable pour versions récentes
  esac
}

BASE_IMAGE=$(choose_base_image "${MC_VERSION}")
echo -e "${BLUE}${info} MC_VERSION=${MC_VERSION} → Image Java choisie : ${BASE_IMAGE}${NC}"

# 🧱 Construire l'image Docker avec ARG BASE_IMAGE + JAVA_OPTS
if [ -f "$DOCKERFILE_PATH" ]; then
  echo -e "${build}  Build image locale 'minecraft-server-image' depuis ${DOCKERFILE_PATH}"
  docker build \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg JAVA_OPTS="${JAVA_OPTS}" \
    -t minecraft-server-image \
    -f "$DOCKERFILE_PATH" "$SCRIPT_DIR"
  echo -e "${GREEN}${ok} Image construite${NC}"
else
  echo -e "${YELLOW}${warn} Aucun dockerfile trouvé → j'essaie d'utiliser l'image 'minecraft-server-image' existante${NC}"
fi

# 🛑 Si un conteneur existe déjà avec ce nom → stop & rm
if docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  echo -e "${YELLOW}${warn} Conteneur '${NOM_CONTENEUR}' existe → stop & rm${NC}"
  docker stop "${NOM_CONTENEUR}" || true
  docker rm   "${NOM_CONTENEUR}" || true
fi

# 🧮 Limites CPU/RAM
LIMITS=()
if [ "${USE_RESOURCE_LIMITS}" = "yes" ]; then
  [ -n "${LIMIT_CPU}" ] && LIMITS+=( "--cpus=${LIMIT_CPU}" )
  [ -n "${LIMIT_MEMORY}" ] && LIMITS+=( "--memory=${LIMIT_MEMORY}" )
  echo -e "${BLUE}${info} Limites activées: ${LIMITS[*]:-aucune}${NC}"
else
  echo -e "${BLUE}${info} Limites désactivées${NC}"
fi

# 👤 Exécuter avec l’UID/GID de l’utilisateur hôte
USER_FLAG=()
if [ "${RUN_AS_HOST_USER}" = "yes" ]; then
  USER_FLAG=( -u "$(id -u)":"$(id -g)" )
  echo -e "${BLUE}${info} Le conteneur tournera en UID:GID $(id -u):$(id -g) ($(id -un):$(id -gn))${NC}"
else
  echo -e "${YELLOW}${warn} RUN_AS_HOST_USER=no → les fichiers créés appartiendront probablement à root${NC}"
fi

# 🌐 Bind IP (optionnel)
BIND_PREFIX=""
if [ -n "${BIND_IP}" ]; then
  BIND_PREFIX="${BIND_IP}:"
  echo -e "${BLUE}${info} Les ports seront bind sur ${BIND_IP}${NC}"
fi

# 🔌 Ports à exposer
PORT_FLAGS=()

# — Minecraft (TCP & UDP)
PORT_FLAGS+=( -p "${BIND_PREFIX}${PORT_SERVEUR}:25565/tcp" )
PORT_FLAGS+=( -p "${BIND_PREFIX}${PORT_SERVEUR}:25565/udp" )
echo -e "${port} Minecraft: ${PORT_SERVEUR} (tcp/udp)${NC}"

# — RCON (TCP only)
PORT_FLAGS+=( -p "${BIND_PREFIX}${RCON_PORT}:${RCON_PORT}/tcp" )
echo -e "${port} RCON: ${RCON_PORT} (tcp)${NC}"

# Helpers d’ouverture
open_both () {
  local p="$1"
  [ -n "$p" ] || return 0
  PORT_FLAGS+=( -p "${BIND_PREFIX}${p}:${p}/tcp" )
  PORT_FLAGS+=( -p "${BIND_PREFIX}${p}:${p}/udp" )
  echo -e "${port} Service: ${p} (tcp/udp)${NC}"
}
open_tcp_only () {
  local p="$1"
  [ -n "$p" ] || return 0
  PORT_FLAGS+=( -p "${BIND_PREFIX}${p}:${p}/tcp" )
  echo -e "${port} Service: ${p} (tcp)${NC}"
}
open_udp_only () {
  local p="$1"
  [ -n "$p" ] || return 0
  PORT_FLAGS+=( -p "${BIND_PREFIX}${p}:${p}/udp" )
  echo -e "${port} Service: ${p} (udp)${NC}"
}

# — Services spéciaux (TCP & UDP)
open_both "${VOICECHAT_PORT}"
open_both "${DISCORDSRV_PORT}"
open_both "${BLUEMAP_PORT}"

# — Ports additionnels
for p in ${ADDITIONAL_PORTS_BOTH}; do open_both "${p}"; done
for p in ${ADDITIONAL_PORTS_TCP};  do open_tcp_only "${p}"; done
for p in ${ADDITIONAL_PORTS_UDP};  do open_udp_only "${p}"; done

# 🧷 Volume (persistance)
VOLUME_FLAG=( -v "${SERVER_DIR}:/minecraft" )

# 🔁 Restart policy
RESTART_FLAG=( --restart "${RESTART_POLICY}" )

# 🔤 Variables d'env JVM (auto Xmx si limites actives et pas de JAVA_OPTS défini)
ENV_FLAGS=()

# Si l'admin a défini JAVA_OPTS dans config.sh, on le respecte et on l'injecte tel quel
if [ -n "${JAVA_OPTS:-}" ]; then
  echo -e "${BLUE}${info} JAVA_OPTS défini manuellement → ${JAVA_OPTS}${NC}"
  ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${JAVA_OPTS}" )
else
  # Fonction pour convertir LIMIT_MEMORY en MB (supporte suffixes g/G/m/M)
  to_mb() {
    local v="$1"
    case "$v" in
      *[gG]) echo $(( ${v%[gG]} * 1024 )) ;;
      *[mM]) echo $(( ${v%[mM]} )) ;;
      "")    echo 0 ;;
      *)     echo "$v" ;;  # si déjà en MB ou format numérique brut
    esac
  }

  if [ "${USE_RESOURCE_LIMITS:-no}" = "yes" ] && [ -n "${LIMIT_MEMORY:-}" ]; then
    limit_mb="$(to_mb "$LIMIT_MEMORY")"
    if [ "$limit_mb" -gt 0 ]; then
      # Heuristique: Xmx = 80% de la limite - 1024 MB d'overhead, min 1024 MB
      heap_mb=$(( limit_mb * 80 / 100 - 1024 ))
      [ "$heap_mb" -lt 1024 ] && heap_mb=1024
      xms_mb=$(( heap_mb / 2 ))
      jvm_auto="-Xms${xms_mb}M -Xmx${heap_mb}M -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication"
      echo -e "${BLUE}${info} AUTO-JVM: LIMIT_MEMORY=${LIMIT_MEMORY} → -Xms=${xms_mb}M, -Xmx=${heap_mb}M${NC}"
      ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_auto}" )
    else
      # Limite activée mais valeur non exploitable → fallback en pourcentages
      jvm_pct="-XX:InitialRAMPercentage=35 -XX:MaxRAMPercentage=70 -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication"
      echo -e "${YELLOW}${warn} LIMIT_MEMORY vide ou invalide → fallback pourcentages (35/70%).${NC}"
      ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_pct}" )
    fi
  else
    # Pas de limites Docker → utiliser des pourcentages (respecte la RAM vue par la JVM)
    jvm_pct="-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=70 -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication"
    echo -e "${BLUE}${info} Pas de limites Docker → JVM en pourcentages (Initial 25% / Max 70%).${NC}"
    ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_pct}" )
  fi
fi


# 🚀 Run !
echo -e "${BLUE}${info} Lancement du conteneur '${NOM_CONTENEUR}'...${NC}"
docker run -d \
  "${RESTART_FLAG[@]}" \
  "${USER_FLAG[@]}" \
  "${LIMITS[@]}" \
  "${VOLUME_FLAG[@]}" \
  "${PORT_FLAGS[@]}" \
  "${ENV_FLAGS[@]}" \
  --name "${NOM_CONTENEUR}" \
  minecraft-server-image

echo -e "${GREEN}${ok} Conteneur lancé : ${NOM_CONTENEUR}${NC}"
echo -e "${BLUE}${info} Conseil: assure-toi que Docker démarre au boot :
    sudo systemctl is-enabled docker || sudo systemctl enable docker${NC}"

# 🪵 Logs
if [ "${ATTACH_CONSOLE}" = "yes" ]; then
  echo -e "${rocket} Attache console (Ctrl+C pour quitter, le conteneur reste actif)${NC}"
  exec docker logs -f "${NOM_CONTENEUR}"
else
  echo -e "${rocket} Détaché. Pour voir les logs :
    docker logs -f ${NOM_CONTENEUR}${NC}"
fi
