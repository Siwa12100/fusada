# 📦 Fusada — Gestionnaire Docker pour serveurs Minecraft

Fusada est un ensemble de scripts Bash qui permettent de **lancer, gérer et administrer facilement un serveur Minecraft** dans un conteneur Docker.
Le but est de rendre l’expérience simple et propre, avec des logs lisibles (couleurs, emojis), une configuration centralisée et des outils intégrés pour RCON.

---

## ⚙️ Fonctionnement

* Le serveur Minecraft est exécuté dans un **conteneur Docker**, construit depuis un `dockerfile` minimal basé sur une image OpenJDK adaptée à la version de Minecraft (Java 8 → 21 selon `MC_VERSION`).
* Tous les fichiers du serveur (monde, plugins, configs) sont stockés sur l’hôte et montés en **volume** (`$SERVER_DIR:/minecraft`) → **persistance garantie**.
* Les ports nécessaires (jeu, RCON, services additionnels comme VoiceChat, BlueMap, etc.) sont automatiquement exposés en TCP et UDP.
* Le conteneur est lancé avec :

  * **UID/GID de l’utilisateur hôte** (pas de fichiers root dans tes dossiers ✨)
  * **politique de redémarrage** `--restart unless-stopped` (le serveur revient après crash ou reboot du VPS)
  * **limites CPU/RAM optionnelles**
* La configuration principale est centralisée dans `config.sh`.
  Tous les scripts la chargent et s’adaptent.

---

## 📂 Structure du projet

```
fusada/
├── README.md                # 📖 Documentation
├── config.sh                # ⚙️ Configuration centrale
├── dockerfile               # 🏗️ Image Docker du serveur
├── lancement.sh             # 🚀 Lancer / construire le serveur
├── arreter-serveur.sh       # 🛑 Stop + rm du conteneur
├── redemarrer-serveur.sh    # 🔄 Restart complet (stop + rm + lancement)
├── console.sh               # 📜 Voir les logs (avec couleurs ou attach)
├── cli-rcon.sh              # ⌨️ Console RCON interactive ou one-shot
└── configuration-rcon.sh    # 🔧 Auto-configure RCON dans server.properties
```

---

## ⚙️ Les scripts disponibles

### 1. `config.sh`

**Configuration centrale** du serveur Minecraft.

Variables principales :

* `NOM_CONTENEUR` : nom du conteneur Docker
* `MC_VERSION` : version du serveur (ex: `1.21.6`) → détermine automatiquement l’image Java (`openjdk:XX-slim`)
* `PORT_SERVEUR` : port du serveur Minecraft (TCP/UDP)
* `RCON_PORT`, `RCON_PASSWORD` : config RCON
* `ATTACH_CONSOLE=yes|no` : suivre les logs après lancement ou pas
* `USE_RESOURCE_LIMITS=yes|no`, `LIMIT_CPU`, `LIMIT_MEMORY` : limites CPU/RAM
* `VOICECHAT_PORT`, `DISCORDSRV_PORT`, `BLUEMAP_PORT` : ports spéciaux à ouvrir en TCP/UDP
* `ADDITIONAL_PORTS_BOTH/TCP/UDP` : ports personnalisés
* `JAVA_OPTS` : options Java (ex: `-Xms2G -Xmx6G`)

---

### 2. `dockerfile`

Image Docker de base :

* Utilise l’`ARG BASE_IMAGE` choisi automatiquement en fonction de `MC_VERSION` (Java 8, 11, 16, 17, 21…).
* Dossier de travail `/minecraft`
* Démarre le serveur avec :

  ```bash
  java ${JAVA_OPTS} -jar server.jar nogui
  ```

---

### 3. `lancement.sh`

**Lance le serveur Minecraft dans Docker** 🚀

Fonctionnalités :

* Vérifie Docker, `eula.txt`, `server.properties`.
* Construit l’image avec la bonne base Java.
* Stoppe + supprime un conteneur existant du même nom.
* Monte le volume (`$SERVER_DIR:/minecraft`).
* Expose automatiquement tous les ports configurés (TCP/UDP).
* Lance le conteneur avec `--restart unless-stopped`.
* Option : suivre les logs directement (`ATTACH_CONSOLE=yes`).

Exemple :

```bash
./lancement.sh
```

---

### 4. `arreter-serveur.sh`

**Stoppe et supprime** le conteneur 🛑

```bash
./arreter-serveur.sh
```

---

### 5. `redemarrer-serveur.sh`

**Redémarre complètement** le serveur 🔄
(équivaut à stop + rm + lancement)

```bash
./redemarrer-serveur.sh
```

---

### 6. `console.sh`

Affiche les **logs du conteneur** 📜

Deux modes :

* **Logs (défaut)** → `docker logs -f --raw` (garde les couleurs ANSI)
* **Attach** → `docker attach` (console brute avec couleurs garanties, sortir avec `Ctrl+P` puis `Ctrl+Q`)

Exemples :

```bash
./console.sh              # logs avec couleurs
./console.sh --mode attach  # attach direct à la console
./console.sh --since 10m    # logs des 10 dernières minutes
```

---

### 7. `cli-rcon.sh`

Console **RCON** interactive ou en one-shot ⌨️

* Utilise `mcrcon` (doit être installé).
* Interactive :

  ```bash
  ./cli-rcon.sh
  > say Bonjour !
  > time set day
  > exit
  ```
* One-shot (idéal pour scripts/CI) :

  ```bash
  ./cli-rcon.sh -c "say Hello depuis Fusada"
  ./cli-rcon.sh "whitelist add Siwa"   # alias accepté
  ```

Options :

* `-c "commande"` → envoie une seule commande et sort
* `--no-config` → n’appelle pas `configuration-rcon.sh` (utilise les valeurs actuelles)

---

### 8. `configuration-rcon.sh`

Configure automatiquement **RCON** dans `server.properties` 🔧

* Active `enable-rcon=true` si nécessaire
* Met à jour/ajoute `rcon.password` et `rcon.port`
* Redémarre le conteneur si une modification est appliquée

Exemple :

```bash
./configuration-rcon.sh ./fusada ./serveur
```

---

## ✨ Fonctionnalités principales

* 🔥 **Gestion complète du cycle de vie** du conteneur Minecraft (start/stop/restart).
* 📂 **Persistance des données** via volume hôte.
* 👤 **UID/GID de l’utilisateur hôte** → pas de fichiers root à manipuler.
* 🔁 **Redémarrage auto** après crash/reboot VPS (`--restart unless-stopped`).
* 🧩 **Sélection auto de Java** en fonction de `MC_VERSION`.
* 🔐 **RCON auto-configuré** et utilisable directement (interactive ou one-shot).
* 🎨 **Logs colorés** (support ANSI, attach direct dispo).
* 🔌 **Ports flexibles** : Minecraft, RCON, VoiceChat, BlueMap, DiscordSRV, plus des ports custom TCP/UDP.
* 🧮 **Limites CPU/RAM optionnelles**.
* 💡 **Extensible** (scripts modulaires, facile à intégrer dans CI/CD ou outils de monitoring).

---

## 🚀 Exemples d’utilisation courante

### Lancer le serveur

```bash
./lancement.sh
```

### Voir les logs (avec couleurs)

```bash
./console.sh
```

### Attacher à la console brute

```bash
./console.sh --mode attach
```

### Arrêter proprement

```bash
./arreter-serveur.sh
```

### Redémarrer complètement

```bash
./redemarrer-serveur.sh
```

### Envoyer une commande RCON

```bash
./cli-rcon.sh -c "say Hello World"
```

### Console RCON interactive

```bash
./cli-rcon.sh
> time set day
> op Siwa
> exit
```

---

## 📌 Pré-requis

* Debian/Ubuntu avec `docker` et `docker compose` installés
* `mcrcon` (console RCON) :

  ```bash
  sudo apt update && sudo apt install -y mcrcon
  ```
* Facultatif mais recommandé : `rlwrap` pour l’historique des commandes dans RCON

  ```bash
  sudo apt install -y rlwrap
  ```
