#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; build="🛠️"; rocket="🚀"; port="🔌"

# 📁 Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"
DOCKERFILE_PATH="$SCRIPT_DIR/dockerfile"

echo -e "${BLUE}${info} Fusada - Lancement serveur Minecraft${NC}"
echo -e "${BLUE}${info} Script : ${SCRIPT_DIR}${NC}"
echo -e "${BLUE}${info} Dossier serveur (monté en volume) : ${SERVER_DIR}${NC}"

# 🧾 Log4j2: créer une config par défaut si absente
ensure_log4j2_config() {
  local log4j2_file="$SERVER_DIR/log4j2.xml"

  if [ "${AUTO_CREATE_LOG4J2:-yes}" != "yes" ]; then
    echo -e "${YELLOW}${warn} AUTO_CREATE_LOG4J2=no → génération auto de log4j2.xml ignorée${NC}"
    return 0
  fi

  if [ -f "$log4j2_file" ]; then
    echo -e "${GREEN}${ok} log4j2.xml présent (${log4j2_file})${NC}"
    return 0
  fi

  cat > "$log4j2_file" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="warn" monitorInterval="5" packages="net.minecrell.terminalconsole,org.fusesource.jansi">
  <Appenders>
    <TerminalConsole name="Console">
      <PatternLayout pattern="%d{HH:mm:ss} %highlight{%-5level}{FATAL=red blink, ERROR=red, WARN=yellow, INFO=green, DEBUG=blue, TRACE=black} %c{1}: %msg%n" disableAnsi="false"/>
    </TerminalConsole>
  </Appenders>
  <Loggers>
    <Root level="info">
      <AppenderRef ref="Console"/>
    </Root>
  </Loggers>
</Configuration>
EOF

  echo -e "${GREEN}${ok} log4j2.xml créé automatiquement (${log4j2_file})${NC}"
}

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
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker est installé mais le daemon est injoignable (service down ou permissions).${NC}"
  exit 1
fi
echo -e "${GREEN}${ok} Docker détecté et daemon joignable${NC}"

# 🔐 Avertissement mot de passe RCON faible/par défaut
if [ "${RCON_PASSWORD:-}" = "" ] || [ "${RCON_PASSWORD:-}" = "CHANGE_ME" ] || [ "${RCON_PASSWORD:-}" = "mdpdefaut" ]; then
  echo -e "${YELLOW}${warn} RCON_PASSWORD est vide ou par défaut. Change-le dans config.sh.${NC}"
fi

# 🧹 Mise au propre pre-lancement (non interactive)
if [ "${CLEANUP_ON_LAUNCH:-yes}" = "yes" ]; then
  if [ -x "$SCRIPT_DIR/mise-au-propre.sh" ]; then
    echo -e "${BLUE}${info} Exécution de mise-au-propre (mode launch)${NC}"
    "$SCRIPT_DIR/mise-au-propre.sh" --mode launch
  else
    echo -e "${YELLOW}${warn} mise-au-propre.sh introuvable ou non exécutable → skip${NC}"
  fi
else
  echo -e "${YELLOW}${warn} CLEANUP_ON_LAUNCH=no → nettoyage automatique ignoré${NC}"
fi

ensure_log4j2_config

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
  echo -e "${BLUE}${info} Vérification des permissions sur ${SERVER_DIR}${NC}"
  if find "$SERVER_DIR" -xdev \( ! -user "$(id -u)" -o ! -group "$(id -g)" \) -print -quit | grep -q .; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      echo -e "${BLUE}${info} Correction des permissions (chown -R $(id -un):$(id -gn))${NC}"
      sudo chown -R "$(id -u)":"$(id -g)" "$SERVER_DIR"
      echo -e "${GREEN}${ok} Permissions corrigées.${NC}"
    else
      echo -e "${YELLOW}${warn} Permissions incohérentes détectées mais sudo non disponible sans mot de passe. Skip chown.${NC}"
    fi
  else
    echo -e "${GREEN}${ok} Permissions déjà cohérentes, chown inutile.${NC}"
  fi
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
    1.21|1.21.*)   echo "amazoncorretto:21-alpine" ;;
    1.20.5|1.20.5*|1.20.6|1.20.6*) echo "amazoncorretto:21-alpine" ;;
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
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-30}"
if docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  echo -e "${YELLOW}${warn} Conteneur '${NOM_CONTENEUR}' existe → arrêt (${STOP_TIMEOUT_SECONDS}s) puis suppression${NC}"
  docker stop -t "${STOP_TIMEOUT_SECONDS}" "${NOM_CONTENEUR}" || true
  docker rm "${NOM_CONTENEUR}" || true
  echo -e "${GREEN}${ok} Ancien conteneur nettoyé.${NC}"
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
else
  echo -e "${YELLOW}${warn} BIND_IP vide: les ports non explicitement localhost seront publiés sur toutes les interfaces.${NC}"
fi

# 🔌 Ports à exposer
PORT_FLAGS=()

# — Minecraft (TCP & UDP)
PORT_FLAGS+=( -p "${BIND_PREFIX}${PORT_SERVEUR}:25565/tcp" )
PORT_FLAGS+=( -p "${BIND_PREFIX}${PORT_SERVEUR}:25565/udp" )
echo -e "${port} Minecraft: ${PORT_SERVEUR} (tcp/udp)${NC}"

# — RCON (TCP only, bind seulement sur localhost)
PORT_FLAGS+=( -p "127.0.0.1:${RCON_PORT}:${RCON_PORT}/tcp" )
echo -e "${port} RCON: ${RCON_PORT} (tcp, localhost only)${NC}"

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

ensure_java_color_opts() {
  local opts="$1"
  if [[ "$opts" != *"-Dlog4j.configurationFile="* ]]; then
    opts="$opts -Dlog4j.configurationFile=/minecraft/log4j2.xml"
  fi
  if [[ "$opts" != *"-Djansi.force="* ]]; then
    opts="$opts -Djansi.force=true"
  fi
  echo "$opts"
}

# Si l'admin a défini JAVA_OPTS dans config.sh, on le respecte et on l'injecte tel quel
if [ -n "${JAVA_OPTS:-}" ]; then
  jvm_manual="$(ensure_java_color_opts "${JAVA_OPTS}")"
  echo -e "${BLUE}${info} JAVA_OPTS défini manuellement → ${jvm_manual}${NC}"
  ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_manual}" )
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
      jvm_auto="-Xms${xms_mb}M -Xmx${heap_mb}M -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication -Dlog4j.configurationFile=/minecraft/log4j2.xml -Djansi.force=true"
      echo -e "${BLUE}${info} AUTO-JVM: LIMIT_MEMORY=${LIMIT_MEMORY} → -Xms=${xms_mb}M, -Xmx=${heap_mb}M${NC}"
      ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_auto}" )
    else
      # Limite activée mais valeur non exploitable → fallback en pourcentages
      jvm_pct="-XX:InitialRAMPercentage=35 -XX:MaxRAMPercentage=70 -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication -Dlog4j.configurationFile=/minecraft/log4j2.xml -Djansi.force=true"
      echo -e "${YELLOW}${warn} LIMIT_MEMORY vide ou invalide → fallback pourcentages (35/70%).${NC}"
      ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_pct}" )
    fi
  else
    # Pas de limites Docker → utiliser des pourcentages (respecte la RAM vue par la JVM)
    jvm_pct="-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=70 -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication -Dlog4j.configurationFile=/minecraft/log4j2.xml -Djansi.force=true"
    echo -e "${BLUE}${info} Pas de limites Docker → JVM en pourcentages (Initial 25% / Max 70%).${NC}"
    ENV_FLAGS+=( -e "JAVA_TOOL_OPTIONS=${jvm_pct}" )
  fi
fi

# 🚀 Run !
echo -e "${BLUE}${info} Lancement du conteneur '${NOM_CONTENEUR}'...${NC}"
docker run -dt \
  --init \
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
  echo -e "${rocket} Attache console interactive (couleurs). Quitter sans arrêter: Ctrl+C (sig-proxy désactivé)${NC}"
  exec docker attach --sig-proxy=false "${NOM_CONTENEUR}"
else
  echo -e "${rocket} Détaché. Pour la console live (couleurs):
    $SCRIPT_DIR/console.sh --mode attach
  Pour l'historique:
    docker logs -f ${NOM_CONTENEUR}${NC}"
fi
