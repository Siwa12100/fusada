#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; plug="🔌"; keyb="⌨️"

# 🧭 Options: -c "commande" (one-shot), --no-config (ne pas (re)configurer RCON)
ONE_SHOT=""
DO_CONFIG=1
WITH_CONSOLE=1
CONSOLE_SINCE="30s"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--command) ONE_SHOT="${2:-}"; shift 2 ;;
    --no-config)  DO_CONFIG=0; shift ;;
    --with-console) WITH_CONSOLE=1; shift ;;
    --without-console|--no-console) WITH_CONSOLE=0; shift ;;
    --console-since) CONSOLE_SINCE="${2:-30s}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-c \"commande\"] [--no-config] [--with-console|--without-console] [--console-since <durée/date>]"
      echo ""
      echo "Options utiles:"
      echo "  --with-console          Active explicitement la console en fond (active par defaut)"
      echo "  --without-console       Desactive la console en fond"
      echo "  --console-since <val>   Historique initial pour le flux console (défaut: 30s)"
      exit 0;;
    *) echo -e "${YELLOW}${warn} Option inconnue: $1${NC}"; shift ;;
  esac
done

# 🗺️ Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

# 🧩 Dépendance mcrcon (PATH + emplacements usuels)
MCRCON_BIN=""
resolve_mcrcon() {
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

if ! MCRCON_BIN="$(resolve_mcrcon)"; then
  echo -e "${RED}${err} mcrcon n'est pas installé ou accessible.${NC}"
  echo -e "${BLUE}${info} J'ai cherché dans PATH et aussi :${NC}"
  echo -e "${BLUE}${info}  - ~/mcrcon/mcrcon${NC}"
  echo -e "${BLUE}${info}  - ~/mcrcon/bin/mcrcon${NC}"
  echo -e "${BLUE}${info} Installe-le (ex: Debian/Ubuntu) : sudo apt update && sudo apt install -y mcrcon${NC}"
  exit 1
fi

echo -e "${GREEN}${ok} mcrcon détecté : ${MCRCON_BIN}${NC}"

# 🔧 Config
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}${err} Config introuvable : ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${NOM_CONTENEUR:?NOM_CONTENEUR manquant dans config.sh}"
: "${RCON_PORT:?RCON_PORT manquant dans config.sh}"
: "${RCON_PASSWORD:?RCON_PASSWORD manquant dans config.sh}"

# 🔒 Hôte RCON (par défaut localhost)
RCON_HOST="${RCON_HOST:-127.0.0.1}"

echo -e "${BLUE}${info} Console RCON sur ${RCON_HOST}:${RCON_PORT} (container: ${NOM_CONTENEUR})${NC}"

# 🧰 (Re)config RCON si demandé et si script dispo
if [[ $DO_CONFIG -eq 1 ]]; then
  if [[ -f "$SCRIPT_DIR/configuration-rcon.sh" ]]; then
    echo -e "${BLUE}${info} Configuration RCON via configuration-rcon.sh${NC}"
    bash "$SCRIPT_DIR/configuration-rcon.sh" "$SCRIPT_DIR" "$SERVER_DIR" || {
      echo -e "${YELLOW}${warn} configuration-rcon.sh a retourné une erreur. On continue quand même.${NC}"
    }
  else
    echo -e "${YELLOW}${warn} configuration-rcon.sh absent → ignoré (utilisation des valeurs actuelles)${NC}"
  fi
fi

# 🧾 Vérifier server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [[ ! -f "$SERVER_PROPERTIES" ]]; then
  echo -e "${RED}${err} ${SERVER_PROPERTIES} introuvable → RCON impossible.${NC}"
  exit 1
fi

# Source de vérité runtime: server.properties
sp_enable_rcon=$(awk -F= '/^[[:space:]]*enable-rcon[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)
sp_rcon_port=$(awk -F= '/^[[:space:]]*rcon.port[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)
sp_rcon_password=$(awk -F= '/^[[:space:]]*rcon.password[[:space:]]*=/{sub(/^[[:space:]]*/,"",$2); sub(/[[:space:]]*$/,"",$2); print $2; exit}' "$SERVER_PROPERTIES" 2>/dev/null || true)

if [[ "$sp_enable_rcon" != "true" ]]; then
  echo -e "${RED}${err} enable-rcon n'est pas a true dans ${SERVER_PROPERTIES}.${NC}"
  exit 1
fi

if [[ "$sp_rcon_port" =~ ^[0-9]+$ ]] && [[ "$sp_rcon_port" != "$RCON_PORT" ]]; then
  echo -e "${YELLOW}${warn} RCON_PORT (${RCON_PORT}) differe de server.properties (${sp_rcon_port}) → utilisation de ${sp_rcon_port}.${NC}"
  RCON_PORT="$sp_rcon_port"
fi

if [[ -n "$sp_rcon_password" ]] && [[ "$sp_rcon_password" != "$RCON_PASSWORD" ]]; then
  echo -e "${YELLOW}${warn} RCON_PASSWORD differe de server.properties → utilisation de la valeur server.properties.${NC}"
  RCON_PASSWORD="$sp_rcon_password"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker non disponible dans le PATH.${NC}"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker installé mais daemon injoignable (service/permissions).${NC}"
  exit 1
fi

# 🧪 Le conteneur est-il là / en route ?
if ! docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  echo -e "${RED}${err} Aucun conteneur nommé '${NOM_CONTENEUR}'. Lance d'abord ton serveur.${NC}"
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  echo -e "${YELLOW}${warn} Le conteneur '${NOM_CONTENEUR}' n'est pas en cours d'exécution.${NC}"
fi

# 🔍 Test de reachability du port (si nc ou timeout présents)
if command -v nc >/dev/null 2>&1; then
  if ! nc -z -w 2 "${RCON_HOST}" "${RCON_PORT}"; then
    echo -e "${YELLOW}${warn} Port ${RCON_HOST}:${RCON_PORT} non joignable (RCON peut ne pas être prêt).${NC}"
  fi
elif command -v timeout >/dev/null 2>&1; then
  (timeout 2 bash -lc "</dev/tcp/${RCON_HOST}/${RCON_PORT}") 2>/dev/null || \
    echo -e "${YELLOW}${warn} Port ${RCON_HOST}:${RCON_PORT} non joignable (RCON peut ne pas être prêt).${NC}"
fi

# 🚀 One-shot command ?
if [[ -n "$ONE_SHOT" ]]; then
  echo -e "${plug} Envoi: ${ONE_SHOT}${NC}"
  "$MCRCON_BIN" -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "${ONE_SHOT}"
  exit 0
fi

CONSOLE_PID=""
cleanup_bg_console() {
  if [[ -n "${CONSOLE_PID}" ]] && kill -0 "${CONSOLE_PID}" 2>/dev/null; then
    kill "${CONSOLE_PID}" 2>/dev/null || true
    wait "${CONSOLE_PID}" 2>/dev/null || true
  fi
}

if [[ "$WITH_CONSOLE" -eq 1 ]]; then
  echo -e "${BLUE}${info} Flux console activé en arrière-plan (since=${CONSOLE_SINCE}).${NC}"
  echo -e "${YELLOW}${warn} Astuce: la sortie console et ton prompt peuvent se mélanger, c'est normal.${NC}"
  if docker logs --help 2>&1 | grep -q -- "--raw"; then
    (docker logs -f --raw --since "${CONSOLE_SINCE}" "${NOM_CONTENEUR}" 2>&1 | sed -u 's/^/[CONSOLE] /') &
  else
    (docker logs -f --since "${CONSOLE_SINCE}" "${NOM_CONTENEUR}" 2>&1 | sed -u 's/^/[CONSOLE] /') &
  fi
  CONSOLE_PID=$!
  trap 'cleanup_bg_console; echo; exit 0' INT TERM EXIT
fi

# 🧑‍💻 Console interactive
if command -v rlwrap >/dev/null 2>&1; then
  echo -e "${GREEN}${ok} rlwrap détecté → historique & édition de ligne activés.${NC}"
  READ_CMD=(rlwrap bash -c 'while true; do printf "\n\n\n"; IFS= read -r -p "[RCON] > " cmd || break; [[ -z "$cmd" ]] && continue; [[ "$cmd" = "exit" ]] && break; "'"${MCRCON_BIN}"'" -H "'"${RCON_HOST}"'" -P "'"${RCON_PORT}"'" -p "'"${RCON_PASSWORD}"'" "$cmd"; done')
else
  READ_CMD=(bash -c 'trap "echo; exit 0" INT; while true; do printf "\n\n\n"; IFS= read -r -p "[RCON] > " cmd || break; [[ -z "$cmd" ]] && continue; [[ "$cmd" = "exit" ]] && break; "'"${MCRCON_BIN}"'" -H "'"${RCON_HOST}"'" -P "'"${RCON_PORT}"'" -p "'"${RCON_PASSWORD}"'" "$cmd"; done')
fi

echo -e "${BLUE}${keyb} Connecté. Tape 'exit' pour quitter.${NC}"
"${READ_CMD[@]}"

cleanup_bg_console

echo -e "${GREEN}${ok} Session RCON terminée.${NC}"
