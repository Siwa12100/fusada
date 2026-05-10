#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

NOM_CONTENEUR="${NOM_CONTENEUR:-ostal-neige}"
ENTITY_WATCHER_ENABLED="${ENTITY_WATCHER_ENABLED:-yes}"
ENTITY_WATCHER_COOLDOWN_SECONDS="${ENTITY_WATCHER_COOLDOWN_SECONDS:-10}"
ENTITY_WATCHER_SAVE_DELAY_SECONDS="${ENTITY_WATCHER_SAVE_DELAY_SECONDS:-1}"
ENTITY_WATCHER_DOCKER_LOGS_SINCE="${ENTITY_WATCHER_DOCKER_LOGS_SINCE:-10m}"
ENTITY_WATCHER_LOG_FILE="${ENTITY_WATCHER_LOG_FILE:-logs/fusada-entity-watcher.log}"
ENTITY_WATCHER_UNKNOWN_LOG_FILE="${ENTITY_WATCHER_UNKNOWN_LOG_FILE:-logs/fusada-entity-watcher-unknown.log}"
ENTITY_WATCHER_PID_FILE="${ENTITY_WATCHER_PID_FILE:-fusada/.state/entity-watcher.pid}"
ENTITY_WATCHER_AUTO_CPOS_ENABLED="${ENTITY_WATCHER_AUTO_CPOS_ENABLED:-yes}"
ENTITY_WATCHER_AUTO_Y_PADDING="${ENTITY_WATCHER_AUTO_Y_PADDING:-16}"
ENTITY_WATCHER_AUTO_DY="${ENTITY_WATCHER_AUTO_DY:-48}"

ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD="${ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD:-/execute in minecraft:overworld run kill @e[x=-9627,y=-1,z=7519,dx=32,dy=32,dz=32,type=!player]}"
ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD="${ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD:-/execute in minecraft:overworld run kill @e[x=-5300,y=75,z=4183,dx=64,dy=32,dz=64,type=!player]}"
ENTITY_WATCHER_ZONE_NETHER_1152_CMD="${ENTITY_WATCHER_ZONE_NETHER_1152_CMD:-/execute in minecraft:the_nether run kill @e[x=-1152,y=237,z=850,dx=32,dy=16,dz=32,type=!player]}"

if [[ "$ENTITY_WATCHER_LOG_FILE" = /* ]]; then
  LOG_FILE="$ENTITY_WATCHER_LOG_FILE"
else
  LOG_FILE="$SERVER_DIR/$ENTITY_WATCHER_LOG_FILE"
fi

if [[ "$ENTITY_WATCHER_UNKNOWN_LOG_FILE" = /* ]]; then
  UNKNOWN_LOG_FILE="$ENTITY_WATCHER_UNKNOWN_LOG_FILE"
else
  UNKNOWN_LOG_FILE="$SERVER_DIR/$ENTITY_WATCHER_UNKNOWN_LOG_FILE"
fi

if [[ "$ENTITY_WATCHER_PID_FILE" = /* ]]; then
  PID_FILE="$ENTITY_WATCHER_PID_FILE"
else
  PID_FILE="$SERVER_DIR/$ENTITY_WATCHER_PID_FILE"
fi

STATE_DIR=$(dirname "$PID_FILE")
RCON_MODE=""
MCRCON_BIN=""

RCON_HOST="${RCON_HOST:-127.0.0.1}"
RCON_PORT="${RCON_PORT:-21600}"
RCON_PASSWORD="${RCON_PASSWORD:-CHANGE_ME}"

SERVER_PROPERTIES="$SERVER_DIR/server.properties"

declare -A LAST_KILL=()

usage() {
  cat <<EOF
Usage: $0 <start|stop|status|logs|run|help>

Commandes:
  start    Lance le watcher en arriere-plan (nohup)
  stop     Arrete le watcher
  status   Affiche l'etat du watcher
  logs     Suit les logs d'actions du watcher
  run      Lance le watcher au premier plan
  help     Affiche cette aide
EOF
}

ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  local message="$1"
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "[$(ts)] $message" | tee -a "$LOG_FILE"
}

append_unknown() {
  local line="$1"
  mkdir -p "$(dirname "$UNKNOWN_LOG_FILE")"
  echo "[$(ts)] $line" >> "$UNKNOWN_LOG_FILE"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}${err} Docker n'est pas installe ou absent du PATH.${NC}"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}${err} Docker est installe mais le daemon est injoignable.${NC}"
    exit 1
  fi
}

require_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$NOM_CONTENEUR"; then
    echo -e "${RED}${err} Le conteneur '$NOM_CONTENEUR' n'est pas en cours d'execution.${NC}"
    exit 1
  fi
}

apply_runtime_rcon_settings() {
  if [[ ! -f "$SERVER_PROPERTIES" ]]; then
    return 0
  fi

  local sp_enable_rcon sp_rcon_port sp_rcon_password
  sp_enable_rcon=$(awk -F= '/^[[:space:]]*enable-rcon[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)
  sp_rcon_port=$(awk -F= '/^[[:space:]]*rcon.port[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)
  sp_rcon_password=$(awk -F= '/^[[:space:]]*rcon.password[[:space:]]*=/{sub(/^[[:space:]]*/,"",$2); sub(/[[:space:]]*$/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)

  if [[ "$sp_enable_rcon" != "true" ]]; then
    log "${err} enable-rcon n'est pas a true dans ${SERVER_PROPERTIES}"
    exit 1
  fi

  if [[ "$sp_rcon_port" =~ ^[0-9]+$ ]] && [[ "$sp_rcon_port" != "$RCON_PORT" ]]; then
    log "${warn} RCON_PORT (${RCON_PORT}) differe de server.properties (${sp_rcon_port}) -> utilisation de ${sp_rcon_port}"
    RCON_PORT="$sp_rcon_port"
  fi

  if [[ -n "$sp_rcon_password" ]] && [[ "$sp_rcon_password" != "$RCON_PASSWORD" ]]; then
    log "${warn} RCON_PASSWORD differe de server.properties -> utilisation de la valeur server.properties"
    RCON_PASSWORD="$sp_rcon_password"
  fi
}

resolve_mcrcon_host() {
  if command -v mcrcon >/dev/null 2>&1; then
    command -v mcrcon
    return 0
  fi

  local candidates=(
    "$HOME/mcrcon/mcrcon"
    "$HOME/mcrcon/bin/mcrcon"
    "$SERVER_DIR/mcrcon/mcrcon"
    "$SERVER_DIR/mcrcon/bin/mcrcon"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -f "$c" ]]; then
      echo "$c"
      return 0
    fi
  done

  return 1
}

require_rcon() {
  if docker exec "$NOM_CONTENEUR" sh -lc 'command -v rcon-cli >/dev/null 2>&1' >/dev/null 2>&1; then
    RCON_MODE="container-rcon-cli"
    return 0
  fi

  if docker exec "$NOM_CONTENEUR" sh -lc 'command -v mcrcon >/dev/null 2>&1' >/dev/null 2>&1; then
    RCON_MODE="container-mcrcon"
    return 0
  fi

  if MCRCON_BIN="$(resolve_mcrcon_host)"; then
    RCON_MODE="host-mcrcon"
    return 0
  fi

  echo -e "${RED}${err} Aucun client RCON disponible.${NC}"
  echo -e "${RED}${err} Testés: rcon-cli (conteneur), mcrcon (conteneur), mcrcon (hôte).${NC}"
  echo -e "${YELLOW}${warn} Installe mcrcon sur l'hôte, ou ajoute rcon-cli dans le conteneur.${NC}"
  exit 1
}

watcher_pid() {
  if [[ -f "$PID_FILE" ]]; then
    cat "$PID_FILE"
  fi
}

watcher_running() {
  local pid
  pid="$(watcher_pid || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

zone_from_line() {
  local line="$1"

  # Zones connues basees sur cpos de chunks dupliques observes.
  if [[ "$line" == *"cpos=[-602, 469]"* || "$line" == *"cpos=[-602, 470]"* ]]; then
    echo "overworld_9627"
    return 0
  fi

  if [[ "$line" == *"cpos=[-332, 261]"* || "$line" == *"cpos=[-331, 261]"* ]]; then
    echo "overworld_5300"
    return 0
  fi

  if [[ "$line" == *"cpos=[-73, 53]"* || "$line" == *"cpos=[-72, 53]"* ]]; then
    echo "nether_1152"
    return 0
  fi

  echo ""
}

zone_cmd() {
  local zone="$1"
  case "$zone" in
    overworld_9627) echo "$ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD" ;;
    overworld_5300) echo "$ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD" ;;
    nether_1152)    echo "$ENTITY_WATCHER_ZONE_NETHER_1152_CMD" ;;
    *)              echo "" ;;
  esac
}

dimension_to_minecraft_id() {
  local level_name="$1"
  case "$level_name" in
    world) echo "minecraft:overworld" ;;
    world_nether) echo "minecraft:the_nether" ;;
    world_the_end) echo "minecraft:the_end" ;;
    *) echo "" ;;
  esac
}

build_auto_zone_from_line() {
  local line="$1"
  local pair1 pair2
  local c1x c1z c2x c2z
  local dim_raw dim_id
  local min_cx max_cx min_cz max_cz
  local x_start x_end z_start z_end dx dz
  local y_vals min_y_int y_start dy
  local zone cmd

  pair1=$(echo "$line" | grep -oE "cpos=\[[-0-9]+, [-0-9]+\]" | sed -n '1p' || true)
  pair2=$(echo "$line" | grep -oE "cpos=\[[-0-9]+, [-0-9]+\]" | sed -n '2p' || true)
  if [[ -z "$pair1" || -z "$pair2" ]]; then
    return 1
  fi

  read -r c1x c1z <<< "$(echo "$pair1" | sed -E 's/cpos=\[([-0-9]+), ([-0-9]+)\]/\1 \2/')"
  read -r c2x c2z <<< "$(echo "$pair2" | sed -E 's/cpos=\[([-0-9]+), ([-0-9]+)\]/\1 \2/')"

  dim_raw=$(echo "$line" | sed -n "s/.*l='ServerLevel\[\([^]]*\)\]'.*/\1/p" | head -n 1)
  dim_id="$(dimension_to_minecraft_id "$dim_raw")"
  if [[ -z "$dim_id" ]]; then
    return 1
  fi

  if (( c1x < c2x )); then min_cx=$c1x; max_cx=$c2x; else min_cx=$c2x; max_cx=$c1x; fi
  if (( c1z < c2z )); then min_cz=$c1z; max_cz=$c2z; else min_cz=$c2z; max_cz=$c1z; fi

  x_start=$(( min_cx * 16 ))
  x_end=$(( (max_cx + 1) * 16 - 1 ))
  z_start=$(( min_cz * 16 ))
  z_end=$(( (max_cz + 1) * 16 - 1 ))
  dx=$(( x_end - x_start ))
  dz=$(( z_end - z_start ))

  y_vals=$(echo "$line" | grep -oE "y=-?[0-9]+(\.[0-9]+)?" | head -n 2 | cut -d= -f2 || true)
  if [[ -n "$y_vals" ]]; then
    min_y_int=$(echo "$y_vals" | awk 'NR==1{m=$1} {if($1<m)m=$1} END{printf "%d", m}')
  else
    min_y_int=64
  fi

  dy=${ENTITY_WATCHER_AUTO_DY}
  y_start=$(( min_y_int - ENTITY_WATCHER_AUTO_Y_PADDING ))

  zone="auto_${dim_raw}_${c1x}_${c1z}_${c2x}_${c2z}"
  cmd="/execute in ${dim_id} run kill @e[x=${x_start},y=${y_start},z=${z_start},dx=${dx},dy=${dy},dz=${dz},type=!player]"
  echo "${zone}|${cmd}"
  return 0
}

run_rcon() {
  local cmd="$1"
  local output

  case "$RCON_MODE" in
    container-rcon-cli)
      output=$(docker exec "$NOM_CONTENEUR" rcon-cli "$cmd" 2>&1)
      ;;
    container-mcrcon)
      output=$(docker exec "$NOM_CONTENEUR" mcrcon -H 127.0.0.1 -P "$RCON_PORT" -p "$RCON_PASSWORD" "$cmd" 2>&1)
      ;;
    host-mcrcon)
      output=$("$MCRCON_BIN" -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "$cmd" 2>&1)
      ;;
    *)
      output="RCON mode inconnu: $RCON_MODE"
      ;;
  esac || {
    log "${err} RCON echec pour commande: $cmd"
    log "${err} Sortie RCON: ${output}"
    return 1
  }

  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      log "${info} RCON: ${line}"
    done <<< "$output"
  else
    log "${info} RCON: commande executee (sortie vide)"
  fi

  return 0
}

kill_zone() {
  local zone="$1"
  local cmd="$2"
  local now last

  now=$(date +%s)
  last="${LAST_KILL[$zone]:-0}"

  if (( now - last < ENTITY_WATCHER_COOLDOWN_SECONDS )); then
    log "${warn} Cooldown actif pour ${zone}, action ignoree"
    return 0
  fi

  log "${info} Action: kill de la zone ${zone}"
  log "${info} Commande: ${cmd}"

  run_rcon "$cmd" || return 1

  sleep "$ENTITY_WATCHER_SAVE_DELAY_SECONDS"
  log "${info} Action: save-all apres kill (${zone})"
  run_rcon "save-all" || return 1

  LAST_KILL[$zone]="$now"
  log "${ok} Zone traitee: ${zone}"
  return 0
}

run_watcher() {
  if [[ "$ENTITY_WATCHER_ENABLED" != "yes" ]]; then
    echo -e "${YELLOW}${warn} ENTITY_WATCHER_ENABLED=no dans config.sh, arret.${NC}"
    exit 0
  fi

  require_docker
  require_container_running
  apply_runtime_rcon_settings
  require_rcon

  mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$UNKNOWN_LOG_FILE")"
  echo "$$" > "$PID_FILE"

  trap 'rm -f "$PID_FILE"' EXIT

  log "${ok} Watcher demarre"
  log "${info} Conteneur: ${NOM_CONTENEUR}"
  log "${info} Log actions: ${LOG_FILE}"
  log "${info} Log inconnus: ${UNKNOWN_LOG_FILE}"
  log "${info} Cooldown: ${ENTITY_WATCHER_COOLDOWN_SECONDS}s"
  log "${info} RCON mode: ${RCON_MODE}"
  log "${info} Auto cpos: ${ENTITY_WATCHER_AUTO_CPOS_ENABLED} (paddingY=${ENTITY_WATCHER_AUTO_Y_PADDING}, dy=${ENTITY_WATCHER_AUTO_DY})"

  docker logs --since "$ENTITY_WATCHER_DOCKER_LOGS_SINCE" -f "$NOM_CONTENEUR" 2>&1 | while IFS= read -r line; do
    if [[ "$line" != *"Entity uuid already exists"* ]]; then
      continue
    fi

    log "${warn} Duplication detectee: ${line}"

    zone="$(zone_from_line "$line")"
    if [[ -z "$zone" ]]; then
      if [[ "$ENTITY_WATCHER_AUTO_CPOS_ENABLED" == "yes" ]]; then
        auto_payload="$(build_auto_zone_from_line "$line" || true)"
        if [[ -n "$auto_payload" ]]; then
          zone="${auto_payload%%|*}"
          cmd="${auto_payload#*|}"
          log "${info} Auto-zone detectee via cpos: ${zone}"
          if ! kill_zone "$zone" "$cmd"; then
            log "${err} Echec traitement auto-zone ${zone}"
            append_unknown "$line"
          fi
          continue
        fi
      fi

      log "${warn} Zone inconnue, entree ajoutee a ${UNKNOWN_LOG_FILE}"
      append_unknown "$line"
      continue
    fi

    cmd="$(zone_cmd "$zone")"
    if [[ -z "$cmd" ]]; then
      log "${err} Aucune commande configuree pour la zone ${zone}"
      append_unknown "$line"
      continue
    fi

    if ! kill_zone "$zone" "$cmd"; then
      log "${err} Echec traitement de la zone ${zone}"
      append_unknown "$line"
    fi
  done
}

start_watcher() {
  require_docker
  require_container_running

  if watcher_running; then
    echo -e "${YELLOW}${warn} Watcher deja actif (PID $(watcher_pid)).${NC}"
    exit 0
  fi

  mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$UNKNOWN_LOG_FILE")"
  nohup bash "$0" run >/dev/null 2>&1 &
  local bg_pid=$!

  # Petit delai pour verifier que le process n'a pas crash immediatement.
  sleep 1
  if kill -0 "$bg_pid" 2>/dev/null; then
    echo "$bg_pid" > "$PID_FILE"
    echo -e "${GREEN}${ok} Watcher lance en arriere-plan (PID ${bg_pid}).${NC}"
    echo -e "${BLUE}${info} Logs: ${LOG_FILE}${NC}"
  else
    echo -e "${RED}${err} Echec du demarrage du watcher. Consulte les logs: ${LOG_FILE}${NC}"
    exit 1
  fi
}

stop_watcher() {
  if ! watcher_running; then
    echo -e "${YELLOW}${warn} Watcher deja arrete.${NC}"
    rm -f "$PID_FILE"
    exit 0
  fi

  local pid
  pid="$(watcher_pid)"
  kill "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo -e "${GREEN}${ok} Watcher arrete (PID ${pid}).${NC}"
}

status_watcher() {
  if watcher_running; then
    echo -e "${GREEN}${ok} Watcher actif (PID $(watcher_pid)).${NC}"
  else
    echo -e "${YELLOW}${warn} Watcher inactif.${NC}"
  fi
  echo -e "${BLUE}${info} Log actions : ${LOG_FILE}${NC}"
  echo -e "${BLUE}${info} Log inconnus: ${UNKNOWN_LOG_FILE}${NC}"
}

logs_watcher() {
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  tail -f "$LOG_FILE"
}

cmd="${1:-help}"
case "$cmd" in
  start)
    start_watcher
    ;;
  stop)
    stop_watcher
    ;;
  status)
    status_watcher
    ;;
  logs)
    logs_watcher
    ;;
  run)
    run_watcher
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo -e "${RED}${err} Commande inconnue: $cmd${NC}"
    usage
    exit 1
    ;;
esac
