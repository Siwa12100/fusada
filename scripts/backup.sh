#!/bin/bash
set -euo pipefail

# 🎨 Couleurs & emojis
BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="✅"; info="ℹ️"; warn="⚠️"; err="❌"; stat="📊"; box="📦"

# 📁 Chemins
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")
CONFIG_FILE="$FUSADA_DIR/config.sh"

# 🔧 Arguments
STOP_SERVER="yes"
RESTART_SERVER="yes"
ASSUME_YES="no"

usage() {
  cat <<'EOF'
Usage: backup.sh [options]

Backup du serveur Minecraft

Options:
  --no-stop       Ne pas arrêter le serveur avant backup
  --no-restart    Ne pas redémarrer le serveur après backup
  -y              Répondre oui automatiquement aux prompts
  -h, --help      Affiche cette aide

Exemples:
  backup.sh                 # Arrête, backup, redémarre
  backup.sh --no-stop       # Backup sans arrêter
  backup.sh --no-restart    # Arrête, backup, ne redémarre pas
  backup.sh -y --no-restart # Non-interactif : arrête et backup
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-stop) STOP_SERVER="no"; shift ;;
    --no-restart) RESTART_SERVER="no"; shift ;;
    -y) ASSUME_YES="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo -e "${RED}${err} Option inconnue: $1${NC}"; usage; exit 1 ;;
  esac
done

# 🔧 Charger la config
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}${err} Config introuvable: ${CONFIG_FILE}${NC}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${NOM_CONTENEUR:?NOM_CONTENEUR manquant dans config.sh}"
: "${BACKUP_OUTPUT_DIR:?BACKUP_OUTPUT_DIR manquant dans config.sh}"
: "${BACKUP_FILE_PREFIX:?BACKUP_FILE_PREFIX manquant dans config.sh}"
: "${BACKUP_INCLUDE_PATHS:?BACKUP_INCLUDE_PATHS manquant dans config.sh}"
: "${BACKUP_COMPRESSION_LEVEL:?BACKUP_COMPRESSION_LEVEL manquant dans config.sh}"

BACKUP_EXCLUDE_PATTERNS="${BACKUP_EXCLUDE_PATTERNS:-}"
STOP_TIMEOUT_SECONDS="${STOP_TIMEOUT_SECONDS:-30}"

# Créer le répertoire de backup s'il n'existe pas
BACKUP_FULL_DIR="$SERVER_DIR/$BACKUP_OUTPUT_DIR"
mkdir -p "$BACKUP_FULL_DIR"

# 🐳 Vérifier Docker
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}${err} Docker n'est pas installé.${NC}"
  exit 1
fi

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "${NOM_CONTENEUR}"
}

# 📊 Affichage initial
echo -e "${BLUE}${info} Backup Minecraft - $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${stat} Conteneur: ${NOM_CONTENEUR}"
echo -e "${stat} Répertoire serveur: ${SERVER_DIR}"
echo -e "${stat} Répertoire backup: ${BACKUP_FULL_DIR}"
echo ""

# ⏹️ Arrêter le serveur (optionnel)
if [[ "$STOP_SERVER" == "yes" ]]; then
  if container_running; then
    echo -e "${BLUE}${info} Arrêt du serveur...${NC}"
    
    if [[ "$ASSUME_YES" != "yes" ]]; then
      read -p "Êtes-vous sûr ? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}${warn} Backup annulée.${NC}"
        exit 0
      fi
    fi
    
    docker stop --time "$STOP_TIMEOUT_SECONDS" "${NOM_CONTENEUR}" >/dev/null 2>&1 || true
    echo -e "${GREEN}${ok} Serveur arrêté${NC}"
    sleep 2
  else
    echo -e "${YELLOW}${warn} Serveur déjà arrêté${NC}"
  fi
fi

# 📦 Créer le timestamp pour le nom du backup
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="${BACKUP_FULL_DIR}/${BACKUP_FILE_PREFIX}-${TIMESTAMP}.zip"

echo -e "${BLUE}${info} Création du backup ZIP...${NC}"
echo -e "${stat} Fichier: ${BACKUP_FILE}"
echo ""

# Construire la ligne de commande zip
ZIP_ARGS=(-r -q "-${BACKUP_COMPRESSION_LEVEL}")

# Ajouter les patterns d'exclusion
if [[ -n "$BACKUP_EXCLUDE_PATTERNS" ]]; then
  for pattern in $BACKUP_EXCLUDE_PATTERNS; do
    ZIP_ARGS+=(-x "$pattern")
  done
fi

# Aller au répertoire serveur et créer le ZIP
cd "$SERVER_DIR" || exit 1

# Créer l'archive
if zip "${ZIP_ARGS[@]}" "$BACKUP_FILE" $BACKUP_INCLUDE_PATHS >/dev/null 2>&1; then
  BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
  echo -e "${GREEN}${ok} Backup créé avec succès${NC}"
  echo -e "${stat} Taille: ${BACKUP_SIZE}"
else
  echo -e "${RED}${err} Erreur lors de la création du backup${NC}"
  exit 1
fi

echo ""

# 🚀 Redémarrer le serveur (optionnel)
if [[ "$RESTART_SERVER" == "yes" && "$STOP_SERVER" == "yes" ]]; then
  echo -e "${BLUE}${info} Redémarrage du serveur...${NC}"
  
  if ! docker start "${NOM_CONTENEUR}" >/dev/null 2>&1; then
    echo -e "${RED}${err} Impossible de redémarrer le conteneur${NC}"
    exit 1
  fi
  
  sleep 5
  echo -e "${GREEN}${ok} Serveur redémarré${NC}"
fi

echo ""
echo -e "${GREEN}${ok} Backup terminé : ${BACKUP_FILE}${NC}"
