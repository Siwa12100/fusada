#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; plug="🔌"; keyb="⌨️"

# 🧭 Options: -c "commande" (one-shot), --no-config (ne pas (re)configurer RCON)
ONE_SHOT=""
DO_CONFIG=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--command) ONE_SHOT="${2:-}"; shift 2 ;;
    --no-config)  DO_CONFIG=0; shift ;;
    -h|--help)
      echo "Usage: $0 [-c \"commande\"] [--no-config]"
      exit 0;;
    *) echo -e "${YELLOW}${warn} Option inconnue: $1${NC}"; shift ;;
  esac
done

# 🗺️ Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVER_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# 🧩 Dépendance mcrcon
if ! command -v mcrcon >/dev/null 2>&1; then
  echo -e "${RED}${err} mcrcon n'est pas installé ou accessible.${NC}"
  echo -e "${BLUE}${info} Installe-le (ex: Debian/Ubuntu) : sudo apt update && sudo apt install -y mcrcon${NC}"
  exit 1
fi

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
  if [[ -x "$SCRIPT_DIR/configuration-rcon.sh" ]]; then
    echo -e "${BLUE}${info} Configuration RCON via configuration-rcon.sh${NC}"
    "$SCRIPT_DIR/configuration-rcon.sh" "$SCRIPT_DIR" "$SERVER_DIR" || {
      echo -e "${YELLOW}${warn} configuration-rcon.sh a retourné une erreur. On continue quand même.${NC}"
    }
  else
    echo -e "${YELLOW}${warn} configuration-rcon.sh absent/non exécutable → ignoré (utilisation des valeurs actuelles)${NC}"
  fi
fi

# 🧾 Vérifier server.properties
SERVER_PROPERTIES="$SERVER_DIR/server.properties"
if [[ ! -f "$SERVER_PROPERTIES" ]]; then
  echo -e "${RED}${err} ${SERVER_PROPERTIES} introuvable → RCON impossible.${NC}"
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
  mcrcon -H "${RCON_HOST}" -P "${RCON_PORT}" -p "${RCON_PASSWORD}" "${ONE_SHOT}"
  exit 0
fi

# 🧑‍💻 Console interactive
if command -v rlwrap >/dev/null 2>&1; then
  echo -e "${GREEN}${ok} rlwrap détecté → historique & édition de ligne activés.${NC}"
  READ_CMD=(rlwrap bash -c 'while IFS= read -r -p "> " cmd; do [[ -z "$cmd" ]] && continue; [[ "$cmd" = "exit" ]] && break; mcrcon -H "'"${RCON_HOST}"'" -P "'"${RCON_PORT}"'" -p "'"${RCON_PASSWORD}"'" "$cmd"; done')
else
  READ_CMD=(bash -c 'trap "echo; exit 0" INT; while IFS= read -r -p "> " cmd; do [[ -z "$cmd" ]] && continue; [[ "$cmd" = "exit" ]] && break; mcrcon -H "'"${RCON_HOST}"'" -P "'"${RCON_PORT}"'" -p "'"${RCON_PASSWORD}"'" "$cmd"; done')
fi

echo -e "${BLUE}${keyb} Connecté. Tape 'exit' pour quitter.${NC}"
"${READ_CMD[@]}"

echo -e "${GREEN}${ok} Session RCON terminée.${NC}"
