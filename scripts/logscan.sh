#!/bin/bash
set -euo pipefail

BLUE='\033[1;34m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
ok="[OK]"; info="[INFO]"; warn="[WARN]"; err="[ERR]"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FUSADA_DIR=$(dirname "$SCRIPT_DIR")
SERVER_DIR=$(dirname "$FUSADA_DIR")

LOGS_DIR="$SERVER_DIR/logs"
LEVEL="all"
SINCE=""
FROM=""
TO=""
LIMIT=0
declare -a TERMS=()

usage() {
  cat <<EOF
Usage: $0 [options] [termes...]

Analyse les logs sur un intervalle de temps et filtre par niveau/eventuels termes.

Options:
  --since <duree>         Intervalle relatif (ex: 30m, 4h, 2d). Defaut: 24h
  --from "YYYY-MM-DD HH:MM:SS"
                          Debut absolu (inclus)
  --to "YYYY-MM-DD HH:MM:SS"
                          Fin absolue (incluse). Defaut: maintenant
  --level <niveau>        all|error|warn|info|debug|trace|fatal (defaut: all)
  --limit <n>             Limite le nombre de lignes affichees (0 = pas de limite)
  --logs-dir <path>       Dossier de logs (defaut: <server>/logs)
  -h, --help              Affiche cette aide

Termes optionnels:
  Ajoute en fin de commande une liste variable de termes.
  Seules les lignes contenant AU MOINS un terme sont remontees.
  Aucun terme par defaut.

Exemples:
  $0 --since 2h --level warn
  $0 --from "2026-05-09 00:00:00" --to "2026-05-10 23:59:59" --level error
  $0 --since 3d --level error terraspread biome
  $0 --since 1d --level warn --limit 100 Connection refused
EOF
}

die() {
  echo -e "${RED}${err} $*${NC}" >&2
  exit 1
}

duration_to_seconds() {
  local raw="$1"
  if [[ ! "$raw" =~ ^([0-9]+)([smhdw])$ ]]; then
    return 1
  fi
  local n="${BASH_REMATCH[1]}"
  local u="${BASH_REMATCH[2]}"
  case "$u" in
    s) echo "$n" ;;
    m) echo $(( n * 60 )) ;;
    h) echo $(( n * 3600 )) ;;
    d) echo $(( n * 86400 )) ;;
    w) echo $(( n * 604800 )) ;;
    *) return 1 ;;
  esac
}

normalize_level() {
  local v
  v=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$v" in
    all) echo "all" ;;
    error|err) echo "error" ;;
    warn|warning) echo "warn" ;;
    info) echo "info" ;;
    debug) echo "debug" ;;
    trace) echo "trace" ;;
    fatal) echo "fatal" ;;
    *) return 1 ;;
  esac
}

to_epoch() {
  local ts="$1"
  date -d "$ts" +%s 2>/dev/null || return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      [[ $# -ge 2 ]] || die "--since attend une valeur"
      SINCE="$2"
      shift 2
      ;;
    --from)
      [[ $# -ge 2 ]] || die "--from attend une valeur"
      FROM="$2"
      shift 2
      ;;
    --to)
      [[ $# -ge 2 ]] || die "--to attend une valeur"
      TO="$2"
      shift 2
      ;;
    --level)
      [[ $# -ge 2 ]] || die "--level attend une valeur"
      LEVEL=$(normalize_level "$2") || die "niveau invalide: $2"
      shift 2
      ;;
    --limit)
      [[ $# -ge 2 ]] || die "--limit attend une valeur"
      [[ "$2" =~ ^[0-9]+$ ]] || die "--limit attend un entier >= 0"
      LIMIT="$2"
      shift 2
      ;;
    --logs-dir)
      [[ $# -ge 2 ]] || die "--logs-dir attend un chemin"
      LOGS_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      TERMS+=("$@")
      break
      ;;
    *)
      TERMS+=("$1")
      shift
      ;;
  esac
done

[[ -d "$LOGS_DIR" ]] || die "dossier de logs introuvable: $LOGS_DIR"

if [[ -n "$SINCE" && ( -n "$FROM" || -n "$TO" ) ]]; then
  die "utilise soit --since, soit --from/--to"
fi

NOW_EPOCH=$(date +%s)
if [[ -n "$SINCE" ]]; then
  SECONDS=$(duration_to_seconds "$SINCE") || die "duree invalide pour --since: $SINCE (ex: 30m, 4h, 2d)"
  START_EPOCH=$(( NOW_EPOCH - SECONDS ))
  END_EPOCH=$NOW_EPOCH
else
  if [[ -n "$FROM" ]]; then
    START_EPOCH=$(to_epoch "$FROM") || die "date --from invalide: $FROM"
  else
    START_EPOCH=$(( NOW_EPOCH - 86400 ))
  fi

  if [[ -n "$TO" ]]; then
    END_EPOCH=$(to_epoch "$TO") || die "date --to invalide: $TO"
  else
    END_EPOCH=$NOW_EPOCH
  fi
fi

if (( START_EPOCH > END_EPOCH )); then
  die "intervalle invalide: start > end"
fi

mapfile -t LOG_FILES < <(find "$LOGS_DIR" -maxdepth 1 -type f \( -name '*.log' -o -name '*.log.gz' \) | sort)
(( ${#LOG_FILES[@]} > 0 )) || die "aucun fichier .log/.log.gz trouve dans $LOGS_DIR"

declare -a LOWER_TERMS=()
for t in "${TERMS[@]}"; do
  LOWER_TERMS+=("$(echo "$t" | tr '[:upper:]' '[:lower:]')")
done

line_matches_terms() {
  local line="$1"
  local line_lc
  local term

  if (( ${#LOWER_TERMS[@]} == 0 )); then
    return 0
  fi

  line_lc=$(echo "$line" | tr '[:upper:]' '[:lower:]')
  for term in "${LOWER_TERMS[@]}"; do
    if [[ "$line_lc" == *"$term"* ]]; then
      return 0
    fi
  done
  return 1
}

line_matches_level() {
  local wanted="$1"
  local line_level="$2"

  case "$wanted" in
    all) return 0 ;;
    error) [[ "$line_level" == "ERROR" ]] && return 0 || return 1 ;;
    warn)  [[ "$line_level" == "WARN" ]] && return 0 || return 1 ;;
    info)  [[ "$line_level" == "INFO" ]] && return 0 || return 1 ;;
    debug) [[ "$line_level" == "DEBUG" ]] && return 0 || return 1 ;;
    trace) [[ "$line_level" == "TRACE" ]] && return 0 || return 1 ;;
    fatal) [[ "$line_level" == "FATAL" ]] && return 0 || return 1 ;;
    *) return 1 ;;
  esac
}

tmp_out=$(mktemp)
trap 'rm -f "$tmp_out"' EXIT

for file in "${LOG_FILES[@]}"; do
  base=$(basename "$file")

  file_date=""
  if [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-[0-9]+\.log(\.gz)?$ ]]; then
    file_date="${BASH_REMATCH[1]}"
  elif [[ "$base" == "latest.log" ]]; then
    file_date="$(date +%F)"
  else
    mtime_epoch=$(stat -c %Y "$file" 2>/dev/null || echo "$NOW_EPOCH")
    file_date=$(date -d "@$mtime_epoch" +%F)
  fi

  day_start=$(date -d "$file_date 00:00:00" +%s)
  day_end=$(date -d "$file_date 23:59:59" +%s)
  if (( day_end < START_EPOCH || day_start > END_EPOCH )); then
    continue
  fi

  if [[ "$file" == *.gz ]]; then
    reader=(gzip -cd -- "$file")
  else
    reader=(cat -- "$file")
  fi

  "${reader[@]}" | while IFS= read -r line; do
    local_time=""
    if [[ "$line" =~ ^\[([0-9]{2}:[0-9]{2}:[0-9]{2})\] ]]; then
      local_time="${BASH_REMATCH[1]}"
    else
      continue
    fi

    line_epoch=$(date -d "$file_date $local_time" +%s 2>/dev/null || echo "")
    if [[ -z "$line_epoch" ]]; then
      continue
    fi
    if (( line_epoch < START_EPOCH || line_epoch > END_EPOCH )); then
      continue
    fi

    line_level="OTHER"
    if [[ "$line" =~ \[[^]]*/([A-Z]+)\] ]]; then
      line_level="${BASH_REMATCH[1]}"
    fi

    if ! line_matches_level "$LEVEL" "$line_level"; then
      continue
    fi
    if ! line_matches_terms "$line"; then
      continue
    fi

    printf "%s\t[%s %s] (%s) %s\n" "$line_level" "$file_date" "$local_time" "$base" "$line"
  done >> "$tmp_out"
done

echo -e "${BLUE}${info} Analyse logs${NC}"
echo "  - Dossier : $LOGS_DIR"
echo "  - Niveau  : $LEVEL"
echo "  - Debut   : $(date -d "@$START_EPOCH" '+%Y-%m-%d %H:%M:%S')"
echo "  - Fin     : $(date -d "@$END_EPOCH" '+%Y-%m-%d %H:%M:%S')"
if (( ${#TERMS[@]} > 0 )); then
  echo "  - Termes  : ${TERMS[*]}"
else
  echo "  - Termes  : (aucun)"
fi
echo ""

if [[ ! -s "$tmp_out" ]]; then
  echo -e "${YELLOW}${warn} Aucun resultat pour ce filtre.${NC}"
  exit 0
fi

declare -A COUNT_BY_LEVEL=()
total=0

if (( LIMIT > 0 )); then
  mapfile -t lines < <(head -n "$LIMIT" "$tmp_out")
  for row in "${lines[@]}"; do
    level="${row%%$'\t'*}"
    line="${row#*$'\t'}"
    echo "$line"
    COUNT_BY_LEVEL["$level"]=$(( ${COUNT_BY_LEVEL["$level"]:-0} + 1 ))
    total=$(( total + 1 ))
  done

  all_lines=$(wc -l < "$tmp_out")
  if (( all_lines > LIMIT )); then
    echo ""
    echo -e "${YELLOW}${warn} Sortie tronquee: ${LIMIT}/${all_lines} lignes affichees (utilise --limit 0 pour tout voir).${NC}"
  fi
else
  while IFS= read -r row; do
    level="${row%%$'\t'*}"
    line="${row#*$'\t'}"
    echo "$line"
    COUNT_BY_LEVEL["$level"]=$(( ${COUNT_BY_LEVEL["$level"]:-0} + 1 ))
    total=$(( total + 1 ))
  done < "$tmp_out"
fi

echo ""
echo -e "${GREEN}${ok} Resume${NC}"
echo "  - Lignes retenues : $total"
for lv in ERROR WARN FATAL INFO DEBUG TRACE OTHER; do
  c=${COUNT_BY_LEVEL[$lv]:-0}
  if (( c > 0 )); then
    echo "  - $lv: $c"
  fi
done
