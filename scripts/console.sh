#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; logicon="📜"; plug="🔌"

# 🔧 Options
MODE="attach"      # logs | attach
SINCE=""           # ex: "10m", "1h", "2025-08-31T09:00:00"
RAW="auto"         # auto | yes | no

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -m, --mode [logs|attach]   Mode d'affichage (par défaut: attach)
  -s, --since <durée/date>   Limiter les logs depuis (ex: 10m, 1h, 2025-08-31T09:00:00)
      --raw [auto|yes|no]    Forcer l'utilisation de --raw (par défaut: auto)
  -h, --help                 Afficher cette aide

Exemples:
  $0
  $0 --mode attach
  $0 --mode logs --since 30m
EOF
}

# 🧭 Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode) MODE="${2:-}"; shift 2 ;;
    -s|--since) SINCE="${2:-}"; shift 2 ;;
    --raw) RAW="${2:-auto}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo -e "${YELLOW}${warn} Option inconnue: $1${NC}"; usage; exit 1 ;;
  esac
done


# 📁 Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

# 🐳 Docker
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker n'est pas installé ou accessible dans \$PATH${NC}"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker est installé mais le daemon est injoignable (service/permissions).${NC}"
  exit 1
fi

# 🔧 Charger config
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}${err} Fichier de configuration introuvable : ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${NOM_CONTENEUR:?NOM_CONTENEUR manquant dans config.sh}"

# 🔎 Conteneur existe ?
if ! docker ps -a --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  echo -e "${RED}${err} Aucun conteneur nommé '${NOM_CONTENEUR}' n'existe.${NC}"
  exit 1
fi

# 🔌 Conteneur en cours ?
IS_RUNNING="no"
if docker ps --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"; then
  IS_RUNNING="yes"
fi

# 🧰 Build options logs
LOGS_ARGS=(-f)
if [[ -n "$SINCE" ]]; then
  LOGS_ARGS+=( --since "$SINCE" )
fi

# 🧪 Test support --raw
supports_raw() {
  # Docker >= 20.10: --raw dispo. On essaie une commande innocente.
  if docker logs --help 2>&1 | grep -q -- "--raw"; then
    return 0
  else
    return 1
  fi
}

# ▶️ Exécution
case "$MODE" in
  logs)
    echo -e "${BLUE}${info} Mode: logs (avec couleurs si possible) — conteneur: ${NOM_CONTENEUR}${NC}"
    if [[ "$RAW" = "yes" ]] || { [[ "$RAW" = "auto" ]] && supports_raw; }; then
      echo -e "${logicon} ${GREEN}${ok} Utilisation de --raw pour préserver les couleurs ANSI.${NC}"
      exec docker logs "${LOGS_ARGS[@]}" --raw "${NOM_CONTENEUR}"
    else
      if [[ "$RAW" = "yes" ]]; then
        echo -e "${YELLOW}${warn} --raw forcé, mais non supporté par cette version de Docker. Fallback sans --raw.${NC}"
      else
        echo -e "${YELLOW}${warn} --raw non disponible → affichage standard (couleurs possibles selon image/TTY).${NC}"
      fi
      exec docker logs "${LOGS_ARGS[@]}" "${NOM_CONTENEUR}"
    fi
    ;;

  attach)
    echo -e "${BLUE}${info} Mode: attach — conteneur: ${NOM_CONTENEUR}${NC}"
    if [[ "$IS_RUNNING" != "yes" ]]; then
      echo -e "${YELLOW}${warn} Le conteneur n'est pas en cours d'exécution. Les logs 'attach' seront vides.${NC}"
      echo -e "${YELLOW}${warn} Démarre le conteneur ou utilise --mode logs avec --since.${NC}"
    fi
    echo -e "${plug} ${GREEN}${ok} Attachement direct (couleurs garanties). Quitter sans arrêter: Ctrl+C (sig-proxy désactivé).${NC}"
    exec docker attach --sig-proxy=false "${NOM_CONTENEUR}"
    ;;

  *)
    echo -e "${RED}${err} Mode invalide: ${MODE} (attendus: logs|attach)${NC}"
    exit 1
    ;;
esac
