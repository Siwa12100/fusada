# Fusada - Documentation complete

Fusada est la couche d'exploitation du serveur Minecraft Docker.
L'objectif est d'avoir une seule experience operateur, avec des commandes claires, une console lisible, et des garde-fous.

Cette documentation decrit:
- la commande unifiee
- les scripts internes
- les metriques RAM/CPU
- les modes console et RCON
- les cas d'usage quotidiens

## Vue d'ensemble

Le repertoire fusada contient:
- scripts de cycle de vie (start/stop/restart)
- scripts de console et logs
- script RCON
- scripts de nettoyage pre/post incident
- une commande unifiee qui orchestre tout

## Commande unifiee (recommandee)

Script principal:
- ./cli.sh

Aide rapide:

```bash
./cli.sh help
```

Commandes disponibles:
- start: lancement complet du serveur
- stop: arret propre + suppression du conteneur
- restart: restart complet
- console: console live (attach)
- logs: logs historiques/live (docker logs)
- logscan: analyse des logs locaux par intervalle, niveau et termes
- rcon: RCON interactif ou one-shot
- backup: backup ZIP avec stop/restart guide
- auto: active/desactive les taches automatiques (planning via config.sh)
- watcher: surveillance des WARN "Entity uuid already exists" + correction auto
- cleanup: nettoyage maps/level corrompus
- status: etat instantane + RAM/CPU
- status-watch [sec]: status en boucle toutes les N secondes

Exemples:

```bash
./cli.sh start
./cli.sh console
./cli.sh logs --since 30m
./cli.sh logscan --since 2h --level warn
./cli.sh logscan --from "2026-05-09 00:00:00" --to "2026-05-10 23:59:59" --level error terraspread biome
./cli.sh rcon -c "list"
./cli.sh rcon --with-console
./cli.sh backup
./cli.sh backup -y --no-restart
./cli.sh auto status
./cli.sh auto enable
./cli.sh auto disable
./cli.sh watcher start
./cli.sh watcher status
./cli.sh watcher logs
./cli.sh cleanup --dry-run
./cli.sh status
./cli.sh status-watch 2
```

## Status RAM/CPU

La commande status affiche:
- etat conteneur (running/exited)
- image et restart policy
- date de demarrage
- CPU percent instantane
- memoire utilisee / limite
- memoire percent
- nombre de processus (PIDs)
- ports publies

Source des metriques:
- docker stats --no-stream

Commande:

```bash
./cli.sh status
```

Mode surveillance:

```bash
./cli.sh status-watch 2
```

## Console et logs

Difference importante:
- console (attach): flux live interactif, couleurs, comportement terminal proche de l'hebergeur
- logs (docker logs): historique et suivi, utile pour forensics et fenetre temporelle

Commandes:

```bash
./cli.sh console
./cli.sh logs --since 10m
```

Raccourci de sortie console:
- dans cette stack, la sortie est configuee pour quitter avec Ctrl+C sans stopper le serveur

## RCON

Script:
- ./scripts/cli-rcon.sh

Modes:
- one-shot: envoi d'une commande puis sortie
- interactif: prompt > avec historique si rlwrap est present
- interactif + console en fond: prompt RCON avec flux console simultane

Detection mcrcon:
- PATH
- ~/mcrcon/mcrcon
- ~/mcrcon/bin/mcrcon
- <server>/mcrcon/mcrcon
- <server>/mcrcon/bin/mcrcon

Exemples:

```bash
./cli.sh rcon -c "say Bonjour"
./cli.sh rcon
./cli.sh rcon --without-console
./cli.sh rcon --with-console --console-since 2m
```

Notes sur le mode --with-console:
- le flux console est affiche en arriere-plan avec prefixe [CONSOLE] (actif par defaut)
- le prompt RCON reste utilisable
- selon le terminal, les sorties peuvent se melanger visuellement (normal)

## Analyse des logs par intervalle

Commande:

```bash
./cli.sh logscan [options] [termes...]
```

Fonctionnalites:
- filtre temporel relatif (`--since 30m`, `--since 4h`, `--since 2d`)
- filtre temporel absolu (`--from` / `--to`)
- filtre de niveau (`--level all|error|warn|info|debug|trace|fatal`)
- liste variable de termes en fin de commande (optionnelle)
- limite d'affichage (`--limit`)

Exemples:

```bash
./cli.sh logscan --since 6h --level error
./cli.sh logscan --since 1d --level warn Connection refused
./cli.sh logscan --from "2026-05-09 00:00:00" --to "2026-05-10 23:59:59" --level error terraspread biome
./cli.sh logscan --since 2d --level all --limit 200
```

Notes:
- Si aucun terme n'est fourni, aucun filtrage par mot-cle n'est applique.
- Les termes sont compares en insensible a la casse.

## Backup ZIP

Script:
- ./scripts/backup.sh

Point d'entree recommande:
- ./cli.sh backup

Comportement:
- si le serveur est en cours d'execution, le script demande d'abord l'autorisation de l'arreter
- il cree une archive ZIP datee/horodatee dans le dossier backups
- s'il etait allume avant backup, le script propose de le redemarrer en fin de traitement

Exemples:

```bash
./cli.sh backup
./cli.sh backup -y
./cli.sh backup -y --no-restart
./cli.sh backup --level 9
```

Variables de configuration (config.sh):
- BACKUP_COMPRESSION_LEVEL: niveau ZIP 0..9
- BACKUP_OUTPUT_DIR: dossier de sortie (ex: backups)
- BACKUP_FILE_PREFIX: prefixe du nom de fichier
- BACKUP_INCLUDE_PATHS: liste des chemins a inclure
- BACKUP_EXCLUDE_PATTERNS: motifs a exclure

Format du nom d'archive:
- <prefixe>-YYYY-MM-DD_HH-MM-SS.zip

## Taches automatiques

Script:
- ./scripts/auto-tasks.sh

Point d'entree recommande:
- ./cli.sh auto <enable|disable|status>

Important:
- Le script sert uniquement a activer/desactiver les taches auto.
- Le planning (heure/minute + actions activees) se configure uniquement dans config.sh.

Actions supportees:
- backup
- cleanup (mise-au-propre)
- restart

Par defaut:
- backup journalier
- cleanup journalier
- restart journalier

Variables de planning (config.sh):
- AUTO_TASKS_BACKUP_ENABLED, AUTO_TASKS_BACKUP_HOUR, AUTO_TASKS_BACKUP_MINUTE
- AUTO_TASKS_CLEANUP_ENABLED, AUTO_TASKS_CLEANUP_HOUR, AUTO_TASKS_CLEANUP_MINUTE
- AUTO_TASKS_RESTART_ENABLED, AUTO_TASKS_RESTART_HOUR, AUTO_TASKS_RESTART_MINUTE
- AUTO_TASKS_LOG_FILE

Exemples:

```bash
./cli.sh auto status
./cli.sh auto enable
./cli.sh auto disable
```

Notes d'execution:
- L'automatisation est basee sur crontab utilisateur.
- Les executions sont logguees dans AUTO_TASKS_LOG_FILE.
- Le service cron/crond doit etre actif sur l'hote.

## Watcher des UUID dupliques

Script:
- ./scripts/watch-entity-duplicates.sh

Point d'entree recommande:
- ./cli.sh watcher <start|stop|status|logs>

Fonctionnement:
- suit `docker logs -f` et detecte les lignes `Entity uuid already exists`
- identifie les zones connues via les `cpos=[x, z]`
- execute une commande kill ciblee via `rcon-cli`
- enchaine un `save-all` immediat pour persister la correction
- applique un cooldown par zone pour eviter le spam

Logs:
- actions et commandes executees: `ENTITY_WATCHER_LOG_FILE` (defaut `logs/fusada-entity-watcher.log`)
- evenements inconnus/non mappes: `ENTITY_WATCHER_UNKNOWN_LOG_FILE` (defaut `logs/fusada-entity-watcher-unknown.log`)

Configuration (config.sh):
- `ENTITY_WATCHER_ENABLED`
- `ENTITY_WATCHER_COOLDOWN_SECONDS`
- `ENTITY_WATCHER_SAVE_DELAY_SECONDS`
- `ENTITY_WATCHER_DOCKER_LOGS_SINCE`
- `ENTITY_WATCHER_LOG_FILE`
- `ENTITY_WATCHER_UNKNOWN_LOG_FILE`
- `ENTITY_WATCHER_PID_FILE`
- `ENTITY_WATCHER_ZONE_OVERWORLD_9627_CMD`
- `ENTITY_WATCHER_ZONE_OVERWORLD_5300_CMD`
- `ENTITY_WATCHER_ZONE_NETHER_1152_CMD`

## Scripts internes (backend)

La commande unifiee orchestre ces scripts:
- lancement.sh
- arreter-serveur.sh
- redemarrer-serveur.sh
- console.sh
- cli-rcon.sh
- mise-au-propre.sh

La configuration centrale est dans:
- config.sh

## Workflow operateur recommande

Demarrage:

```bash
./cli.sh start
```

Observation live:

```bash
./cli.sh console
```

Commande admin:

```bash
./cli.sh rcon -c "save-all"
```

Diagnostic ressources:

```bash
./cli.sh status
```

Surveillance continue:

```bash
./cli.sh status-watch 2
```

Nettoyage manuel:

```bash
./cli.sh cleanup --dry-run
./cli.sh cleanup
```

Arret/restart:

```bash
./cli.sh stop
./cli.sh restart
```

## Prerequis

Obligatoires:
- docker
- daemon docker joignable

Recommandes:
- mcrcon
- rlwrap

Installation rapide Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y docker.io mcrcon rlwrap
```

## FAQ rapide

Pourquoi une commande unifiee alors que les scripts existent deja?
- pour reduire la charge mentale: une seule entree, backend conserve

Pourquoi status et status-watch?
- status: photo instantanee
- status-watch: monitoring court pendant les operations

Pourquoi un mode RCON avec console en fond?
- pour administrer sans perdre le contexte live du serveur

## Annexes

Le point d'entree conseille est:
- ./cli.sh

Les scripts historiques restent utilisables directement si besoin.
