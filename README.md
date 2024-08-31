# Fusada

## 1. Objectif du Projet

Le projet **Fusada** consiste en une série de scripts Bash et un Dockerfile destinés à faciliter le déploiement et la gestion d'un serveur Minecraft dans un environnement Docker. Ce projet permet de gérer facilement la configuration, le déploiement, et la gestion d'un serveur Minecraft en utilisant Docker pour isoler l'environnement d'exécution, garantissant ainsi une stabilité et une portabilité optimales.

Le projet se compose de trois scripts principaux :
- **`fusada-config.sh`** : Un script de configuration où toutes les variables nécessaires au déploiement du serveur sont définies, avec des valeurs par défaut adaptées à la plupart des environnements.
- **`fusada-lancement.sh`** : Le script principal qui utilise les paramètres définis dans le script de configuration pour lancer le serveur Minecraft dans un conteneur Docker.
- **`fusada-console.sh`** : Un script permettant d'interagir avec la console du serveur Minecraft via RCON.

Un **Dockerfile** est également inclus pour créer une image Docker légère et performante, basée sur OpenJDK 21, optimisée pour exécuter un serveur Minecraft.

## 2. Utilisation des Scripts

### 2.1. Pré-requis

Avant de commencer, il est impératif que les conditions suivantes soient respectées :

- **Docker** doit être installé et correctement configuré sur le système où le serveur Minecraft sera déployé.
- Le fichier **`server.jar`** (le fichier exécutable du serveur Minecraft) doit être présent à la racine du projet, c'est-à-dire au même niveau que le dossier `fusada` qui contient les scripts et le Dockerfile.
- Le dossier **`fusada`** doit contenir les scripts `fusada-config.sh`, `fusada-lancement.sh`, `fusada-console.sh`, `configuration-rcon.sh` ainsi que le Dockerfile.

### 2.2. Installation de MCRCON

MCRCON est nécessaire pour interagir avec la console du serveur Minecraft via RCON. Pour l'installer, suivez ces étapes :

```bash
git clone https://github.com/Tiiffi/mcrcon.git
cd mcrcon
make
sudo make install
```

### 2.3. Clonage du Projet

1. **Cloner le dépôt du projet** : Le projet doit être cloné dans un répertoire nommé `fusada`, qui doit être placé au même niveau que le fichier `server.jar`.

   ```bash
   git clone <url-du-dépôt-git> fusada
   ```

   Assurez-vous que le dépôt est cloné dans le répertoire `fusada`, qui doit être situé au même endroit que le `server.jar`.

### 2.4. Configuration Initiale

1. **Vérifier la présence du fichier de configuration** : Le script `fusada-config.sh` doit être présent dans le dossier `fusada`. Ce fichier contient les paramètres de configuration nécessaires pour le déploiement du serveur.

   - Si ce fichier n'existe pas, il est nécessaire de le créer en se basant sur l'exemple fourni dans la documentation.
   - Les valeurs par défaut définies dans `fusada-config.sh` sont adéquates pour une configuration standard, mais peuvent être modifiées en fonction des besoins spécifiques.

2. **Éditer le fichier de configuration (optionnel)** : Si des modifications sont nécessaires, ouvrez `fusada-config.sh` dans un éditeur de texte et ajustez les paramètres tels que le port du serveur, le nom du conteneur, et les limites de ressources.

### 2.5. Lancement du Serveur Minecraft

1. **Rendre les scripts exécutables** : Avant de lancer le script principal, il est nécessaire de rendre les scripts exécutables :

   ```bash
   chmod +x fusada/fusada-config.sh
   chmod +x fusada/fusada-lancement.sh
   chmod +x fusada/fusada-console.sh
   chmod +x fusada/configuration-rcon.sh
   ```

2. **Exécuter le script principal** : Le script `fusada-lancement.sh` doit être exécuté pour lancer le serveur Minecraft dans un conteneur Docker :

   ```bash
   ./fusada/fusada-lancement.sh
   ```

3. **Suivre les messages affichés** : Le script affichera des messages en temps réel indiquant le statut des différentes étapes, telles que la construction de l'image Docker, la gestion des conteneurs existants, et le lancement du serveur Minecraft. Les messages colorés aideront à identifier les succès (en vert), les informations (en bleu), et les erreurs potentielles (en rouge).

### 2.6. Interaction avec la Console du Serveur Minecraft

1. **Afficher la console du serveur Minecraft** : Pour interagir avec la console du serveur via RCON, utilisez le script `fusada-console.sh` :

   ```bash
   ./fusada/fusada-console.sh
   ```

   Tapez vos commandes dans la console et appuyez sur `Entrée`. Pour quitter la session de console, tapez `exit`.

### 2.7. Gestion du Serveur Minecraft

- **Arrêt du serveur** : Pour arrêter le serveur Minecraft en cours d'exécution, utilisez le script suivant :

  ```bash
  ./fusada/arreter-serveur.sh
  ```

- **Redémarrage du serveur** : Pour redémarrer le serveur sans avoir à reconstruire l'image Docker, utilisez le script suivant :

  ```bash
  ./fusada/redemarrer-serveur.sh
  ```

- **Démarrage du serveur** : Pour démarrer le serveur si le conteneur existe mais est arrêté, utilisez le script suivant :

  ```bash
  ./fusada/demarrer-serveur.sh
  ```

- **Affichage des logs du serveur** : Pour suivre les logs du serveur en temps réel, utilisez le script suivant :

  ```bash
  ./fusada/afficher-console.sh
  ```

## 3. Avertissements et Précautions

- **Compatibilité avec Minecraft** : Toujours vérifier que la version de Java utilisée (OpenJDK 21) est compatible avec la version de Minecraft en cours d'exécution. Certaines versions de Minecraft peuvent nécessiter des versions spécifiques de Java pour fonctionner correctement.

- **Gestion des ressources** : Si les ressources sont limitées sur le système hôte, il est recommandé de définir les limites de CPU et de mémoire dans le fichier de configuration (`fusada-config.sh`). Cela évitera que le serveur Minecraft n'utilise trop de ressources, ce qui pourrait impacter les autres services en cours d'exécution sur le même système.

- **Test dans un environnement de développement** : Avant de déployer en production, il est conseillé de tester le script et la configuration dans un environnement de développement pour s'assurer que tout fonctionne comme prévu.

- **Sauvegardes régulières** : Avant d'apporter des modifications significatives ou de mettre à jour l'environnement, il est crucial de réaliser des sauvegardes complètes des données du serveur Minecraft pour éviter toute perte de données.
