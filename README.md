# Monitoring QG — Centre de monitoring multi-projets

Ce projet est un **QG de monitoring centralisé** capable de surveiller N projets tournant sur le même hôte Docker. Il repose sur une architecture hybride sécurisée (Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma).

## Architecture

```
monitoring/
├── monitoring.yml          # Socle commun (services globaux + exporters)
├── monitoring.local.yml    # Override Local (rétention 2j, ports ouverts, profil léger)
├── monitoring.prod.yml     # Override Prod (Node Exporter, quotas, sécurité ports 127.0.0.1)
├── Makefile                # Commandes rapides (make local, make prod, make reload...)
├── add-project.sh          # Script d'aide pour intégrer un nouveau projet
├── prometheus/
│   ├── prometheus.yml      # Scrape configs avec labels project
│   └── alerts.yml          # Alertes génériques ({{ $labels.project }}) + alertes hôte
├── alertmanager/
│   ├── alertmanager.yml    # Routing email + Slack/Discord par projet
│   └── .env.alertmanager.example
├── promtail/
│   └── promtail.yml        # Logs de TOUS les conteneurs (docker_sd_configs)
├── loki/loki.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/ds.yaml
│   │   └── dashboards/dashboards.yaml
│   └── dashboards/
│       ├── overview.json       # Vue globale tous projets
│       └── per-project.json    # Vue par projet (dropdown)
└── exporters/
    └── koda/
        └── .env.postgres_exporter.example
```

## Services & Ports

| Service | URL | Description |
|---|---|---|
| Grafana | http://localhost:3001 | Dashboards (admin/admin) |
| Prometheus | http://localhost:19090 | Métriques brutes |
| Alertmanager | http://localhost:9093 | Gestion des alertes |
| Loki | http://localhost:3100 | Agrégation de logs |
| Uptime Kuma | http://localhost:3002 | Surveillance uptime endpoints |
| cAdvisor | http://localhost:8081 | Métriques Docker |

> ⚠️ Prometheus est sur le port **19090**.

## Prérequis

- Docker + Docker Compose
- Le réseau `koda_network` doit exister : `docker network create koda_network`

## Démarrage

### 1. Variables d'environnement

```bash
# Credentials exporter Postgres
cp exporters/koda/.env.postgres_exporter.example exporters/koda/.env.postgres_exporter
nano exporters/koda/.env.postgres_exporter

# Credentials alertes (Email, Slack, Discord)
cp alertmanager/.env.alertmanager.example alertmanager/.env.alertmanager
nano alertmanager/.env.alertmanager
```

### 2. Lancement selon l'environnement

Deux variantes optimisées sont disponibles via surcouches Docker Compose :

#### 💻 En Local (Développement — Strict Minimum)
Par défaut, `make local` ne démarre **QUE le strict minimum vital** (Prometheus, Grafana et les exporters applicatifs, soit ~300 Mo de RAM au total).
Les services superflus en dev (Alertmanager, cAdvisor, Loki, Promtail, Uptime Kuma) sont désactivés :

```bash
# Strict minimum (5 conteneurs : Prometheus, Grafana, Exporters)
make local

# Si tu as besoin des logs dans Grafana (+ Loki & Promtail) :
make local-logs

# Si tu veux tester TOUS les services en local :
make local-full
```

#### 🚀 En Production
Version durcie et complète (surveillance matérielle complète avec **Node Exporter**, tous les ports web liés sur `127.0.0.1` pour reverse proxy HTTPS, quotas TSDB 30j/15Go, quotas CPU/RAM) :

```bash
make prod
# Ou manuellement :
# docker compose -f monitoring.yml -f monitoring.prod.yml up -d
```

### Commandes utiles (Makefile)

| Commande | Action | Empreinte RAM |
|---|---|---|
| `make local` | Strict minimum vital (Prometheus, Grafana, Exporters) | **~300 Mo** |
| `make local-logs` | Strict minimum + logs Loki/Promtail | ~550 Mo |
| `make local-full` | Stack locale complète (avec Alertmanager, cAdvisor, Kuma) | ~800 Mo |
| `make prod` | Version de production complète (Node Exporter, quotas) | Durcie |
| `make down` | Arrêter proprement la stack | - |
| `make status` | Voir l'état des conteneurs (`ps`) | - |
| `make logs` | Voir les logs en temps réel | - |
| `make reload` | Recharger la configuration Prometheus à chaud (hot-reload) | - |

## Ajouter un nouveau projet

```bash
# Générer les snippets et la structure pour un nouveau projet
./add-project.sh <nom-projet>

# Exemple
./add-project.sh projetx
```

Le script crée le dossier `exporters/<projet>/`, génère les credentials à remplir, et affiche exactement les blocs YAML à copier dans `monitoring.yml` et `prometheus/prometheus.yml`.

Une fois les blocs ajoutés :

```bash
# Démarrer les exporters du nouveau projet sans toucher aux autres
docker compose -f monitoring.yml up -d --no-deps postgres_exporter_projetx

# Hot-reload Prometheus (sans redémarrage)
curl -X POST http://localhost:19090/-/reload
```

## Note — nginx_status (Koda)

Pour que `nginx_exporter_koda` fonctionne, le Nginx de Koda doit exposer le endpoint `stub_status`. Ajouter dans la config Nginx de Koda :

```nginx
location /nginx_status {
    stub_status;
    allow 127.0.0.1;
    allow 172.0.0.0/8;   # Plage réseau Docker
    deny all;
}
```

## Labels Docker requis (pour Promtail)

Chaque conteneur peut porter un label `project` pour que ses logs soient
automatiquement associés au bon projet dans Loki/Grafana.

Les exporters du QG portent déjà ces labels. Pour les conteneurs applicatifs :

```yaml
# Dans le docker-compose.yml du projet
services:
  api:
    labels:
      project: "koda"
```
