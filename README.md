# Stack de Monitoring - Koda

Ce projet contient la configuration de la stack de monitoring complète pour le projet **Koda**. Elle repose sur une architecture moderne utilisant Prometheus, Grafana, Loki et plusieurs exportateurs pour assurer une surveillance globale et efficace des services, de l'infrastructure et des logs.

## Prérequis

- Docker
- Docker Compose
- Le réseau externe `koda_network` doit être créé au préalable, car il est partagé avec le projet principal.

## Démarrage

Pour lancer l'ensemble de la stack en arrière-plan, utilisez la commande suivante à la racine du projet :

```bash
docker compose -f monitoring.yml up -d
```

Pour arrêter la stack :

```bash
docker compose -f monitoring.yml down
```

## Architecture et Services

La stack de monitoring est composée des services suivants :

### 📊 Visualisation et Alertes
- **[Grafana](http://localhost:3001)** (`:3001`) : Outil de création de tableaux de bord et de visualisation de données. Il est connecté à Prometheus et Loki pour afficher les métriques et les logs. Les identifiants par défaut sont `admin` / `admin` (il est fortement recommandé de les modifier).
- **[Uptime Kuma](http://localhost:3002)** (`:3002`) : Outil de surveillance de la disponibilité (uptime) des différents endpoints et services.

### 📈 Collecte et Stockage des Métriques
- **[Prometheus](http://localhost:9090)** (`:9090`) : Cœur du système de monitoring. Il collecte et stocke les métriques (time-series data) provenant des différents exportateurs. La rétention des données est configurée pour 30 jours.
- **[Alertmanager](http://localhost:9093)** (`:9093`) : Gère les alertes envoyées par Prometheus et se charge de les router vers les bons canaux de communication (Email, Slack, etc.).

### 📝 Gestion des Logs
- **Loki** (`:3100`) : Système d'agrégation de logs, optimisé pour être utilisé conjointement avec Grafana.
- **Promtail** : Agent déployé pour collecter les logs des conteneurs Docker locaux et les envoyer vers Loki.

### 🔌 Exportateurs (Collecteurs de données)
Les exportateurs exposent les métriques spécifiques de chaque service pour qu'elles puissent être récupérées (scrappées) par Prometheus :
- **[cAdvisor](http://localhost:8081)** (`:8081`) : Collecte les métriques d'utilisation des ressources et de performance des conteneurs Docker en cours d'exécution.
- **Postgres Exporter** (`:9187`) : Exporte les métriques de la base de données PostgreSQL.
- **Redis Exporter** (`:9121`) : Exporte les métriques du cache Redis.
- **Nginx Exporter** (`:9113`) : Exporte les métriques du serveur web Nginx.

## Structure du Projet

```text
.
├── alertmanager/         # Fichiers de configuration d'Alertmanager
├── exporters/            # Variables d'environnement et configurations pour les exportateurs (ex: Postgres)
├── grafana/              # Configuration, dashboards et sources de données pour Grafana
├── loki/                 # Fichiers de configuration de Loki
├── prometheus/           # Fichiers de configuration de Prometheus (règles, alertes, etc.)
├── promtail/             # Fichiers de configuration de Promtail
└── monitoring.yml        # Fichier Docker Compose principal de la stack
```

## Réseaux et Volumes

- **Réseaux** :
  - `monitoring_network` : Réseau interne utilisé pour la communication entre les différents services de monitoring.
  - `koda_network` : Réseau externe partagé avec les services applicatifs Koda (permettant aux exportateurs d'atteindre les bases de données, redis, nginx, etc.).

- **Volumes** :
  Des volumes Docker nommés sont utilisés pour persister les données de Prometheus, Alertmanager, Grafana, Loki et Uptime Kuma afin de ne pas perdre d'historique lors du redémarrage des conteneurs.
