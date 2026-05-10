#!/bin/bash
# ============================================
#  Configuration Fusada
#  Charge d'abord .env (si present), puis applique des defaults.
# ============================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# Core
NOM_CONTENEUR=${NOM_CONTENEUR:-"ostal-neige"}
MC_VERSION=${MC_VERSION:-"1.21.11"}

# Network
PORT_SERVEUR=${PORT_SERVEUR:-23600}
RCON_PORT=${RCON_PORT:-21600}
RCON_PASSWORD=${RCON_PASSWORD:-"CHANGE_ME"}
RCON_HOST=${RCON_HOST:-"127.0.0.1"}

# Runtime behavior
ATTACH_CONSOLE=${ATTACH_CONSOLE:-"yes"}
RESTART_POLICY=${RESTART_POLICY:-"unless-stopped"}
STOP_TIMEOUT_SECONDS=${STOP_TIMEOUT_SECONDS:-30}
CLEANUP_ON_LAUNCH=${CLEANUP_ON_LAUNCH:-"yes"}
AUTO_CREATE_LOG4J2=${AUTO_CREATE_LOG4J2:-"yes"}

# Permissions
RUN_AS_HOST_USER=${RUN_AS_HOST_USER:-"yes"}
FIX_OWNERSHIP_ON_START=${FIX_OWNERSHIP_ON_START:-"yes"}

# Resources
USE_RESOURCE_LIMITS=${USE_RESOURCE_LIMITS:-"yes"}
LIMIT_CPU=${LIMIT_CPU:-""}
LIMIT_MEMORY=${LIMIT_MEMORY:-"36g"}

# Bind
BIND_IP=${BIND_IP:-""}

# Service ports
VOICECHAT_PORT=${VOICECHAT_PORT:-""}
DISCORDSRV_PORT=${DISCORDSRV_PORT:-""}
BLUEMAP_PORT=${BLUEMAP_PORT:-""}
ADDITIONAL_PORTS_BOTH=${ADDITIONAL_PORTS_BOTH:-""}
ADDITIONAL_PORTS_TCP=${ADDITIONAL_PORTS_TCP:-""}
ADDITIONAL_PORTS_UDP=${ADDITIONAL_PORTS_UDP:-""}

# JVM
JAVA_OPTS=${JAVA_OPTS:-""}

# Backup
BACKUP_COMPRESSION_LEVEL=${BACKUP_COMPRESSION_LEVEL:-"3"}
BACKUP_OUTPUT_DIR=${BACKUP_OUTPUT_DIR:-"backups"}
BACKUP_FILE_PREFIX=${BACKUP_FILE_PREFIX:-"ostal-neige-backup"}
BACKUP_INCLUDE_PATHS=${BACKUP_INCLUDE_PATHS:-"world world_nether world_the_end plugins config server.properties bukkit.yml commands.yml help.yml permissions.yml purpur.yml spigot.yml whitelist.json ops.json banned-ips.json banned-players.json wepif.yml"}
BACKUP_EXCLUDE_PATTERNS=${BACKUP_EXCLUDE_PATTERNS:-"backups/* cache/* logs/* debug/* libraries/* versions/* *.tmp"}

# Automatic tasks scheduling (config only, enable/disable via auto-tasks.sh)
AUTO_TASKS_BACKUP_ENABLED=${AUTO_TASKS_BACKUP_ENABLED:-"yes"}
AUTO_TASKS_BACKUP_HOUR=${AUTO_TASKS_BACKUP_HOUR:-4}
AUTO_TASKS_BACKUP_MINUTE=${AUTO_TASKS_BACKUP_MINUTE:-0}

AUTO_TASKS_CLEANUP_ENABLED=${AUTO_TASKS_CLEANUP_ENABLED:-"yes"}
AUTO_TASKS_CLEANUP_HOUR=${AUTO_TASKS_CLEANUP_HOUR:-4}
AUTO_TASKS_CLEANUP_MINUTE=${AUTO_TASKS_CLEANUP_MINUTE:-20}

AUTO_TASKS_RESTART_ENABLED=${AUTO_TASKS_RESTART_ENABLED:-"yes"}
AUTO_TASKS_RESTART_HOUR=${AUTO_TASKS_RESTART_HOUR:-4}
AUTO_TASKS_RESTART_MINUTE=${AUTO_TASKS_RESTART_MINUTE:-40}

AUTO_TASKS_LOG_FILE=${AUTO_TASKS_LOG_FILE:-"logs/fusada-auto-tasks.log"}

# Duplicate entities watcher (Entity uuid already exists)
ENTITY_WATCHER_ENABLED=${ENTITY_WATCHER_ENABLED:-"yes"}
ENTITY_WATCHER_COOLDOWN_SECONDS=${ENTITY_WATCHER_COOLDOWN_SECONDS:-10}
ENTITY_WATCHER_SAVE_DELAY_SECONDS=${ENTITY_WATCHER_SAVE_DELAY_SECONDS:-1}
ENTITY_WATCHER_DOCKER_LOGS_SINCE=${ENTITY_WATCHER_DOCKER_LOGS_SINCE:-"10m"}
ENTITY_WATCHER_LOG_FILE=${ENTITY_WATCHER_LOG_FILE:-"logs/fusada-entity-watcher.log"}
ENTITY_WATCHER_UNKNOWN_LOG_FILE=${ENTITY_WATCHER_UNKNOWN_LOG_FILE:-"logs/fusada-entity-watcher-unknown.log"}
ENTITY_WATCHER_PID_FILE=${ENTITY_WATCHER_PID_FILE:-"fusada/.state/entity-watcher.pid"}

# Known corrupted zones (commands executed via rcon-cli)
ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD=${ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD:-"/execute in minecraft:overworld run kill @e[x=-9627,y=-1,z=7519,dx=32,dy=32,dz=32,type=!player]"}
ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD=${ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD:-"/execute in minecraft:overworld run kill @e[x=-5300,y=75,z=4183,dx=64,dy=32,dz=64,type=!player]"}
ENTITY_WATCHER_ZONE_NETHER_1152_CMD=${ENTITY_WATCHER_ZONE_NETHER_1152_CMD:-"/execute in minecraft:the_nether run kill @e[x=-1152,y=237,z=850,dx=32,dy=16,dz=32,type=!player]"}