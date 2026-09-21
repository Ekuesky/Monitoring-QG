# 🛸 Monitoring QG — Centre de surveillance multi-projets Docker

Un quartier général de monitoring **clé en main, sécurisé et prêt pour la production**, conçu pour surveiller plusieurs projets indépendants hébergés sur une même machine Docker (serveur dédié, VPS ou machine locale).

Il centralise les **métriques** (Prometheus), les **logs** (Loki + Promtail), les **dashboards** (Grafana préconfiguré) et les **alertes** (Alertmanager) sans alourdir ni modifier les `docker-compose.yml` de vos applications.

---

## ⚡ Pourquoi ce projet ?

Quand on héberge plusieurs applications sur un serveur (ou en local) :
* Installer une stack de monitoring complète par projet gaspille des gigaoctets de RAM.
* Partager le socket Docker avec Prometheus pose un risque critique de sécurité.
* En local, on veut une stack légère qui ne ralentit pas la machine (~300 Mo de RAM), alors qu'en production on veut de la rétention, des alertes réelles et la surveillance du serveur hôte.

**Monitoring QG résout ces problèmes :**
- 💻 **Mode Local (Strict Minimum)** : Ne démarre que l'essentiel (Prometheus, Grafana, exporters) pour seulement **~300 Mo de RAM**.
- 🚀 **Mode Production Durci** : Quotas TSDB (30j / 15 Go max), ports privés liés à `127.0.0.1` (prêt pour reverse proxy SSL), limites de ressources CPU/RAM et métriques matérielles du serveur hôte (**Node Exporter**).
- 🔌 **Architecture Hybride Zero-Trust** : Prometheus ne touche pas au socket Docker. Les métriques transitent via des réseaux Docker isolés (`<projet>_network`).
- 📊 **Dashboards & Alertes Prêts à l'emploi** : Vue d'ensemble de tous les projets + vue détaillée avec menu déroulant par projet.

---

## 📐 Architecture

```text
monitoring/
├── monitoring.yml          # Socle commun (Grafana, Prometheus, Loki, Promtail, etc.)
├── monitoring.local.yml    # Surcouche locale (Strict minimum ~300 Mo, rétention 2j)
├── monitoring.prod.yml     # Surcouche production (Node Exporter, quotas, ports sécurisés)
├── Makefile                # Commandes simples (make local, make prod, make reload...)
├── add-project.sh          # Script CLI interactif pour brancher un nouveau projet
├── prometheus/
│   ├── prometheus.yml      # Configuration du scraping multi-projets
│   └── alerts.yml          # Règles d'alertes génériques et alertes système hôte
├── alertmanager/
│   ├── alertmanager.yml    # Routage des alertes (Email, Slack, Discord)
│   └── .env.alertmanager.example
├── promtail/
│   └── promtail.yml        # Découverte automatique des logs de conteneurs
├── loki/loki.yml           # Stockage et indexation des logs
├── grafana/
│   ├── provisioning/       # Datasources et dashboards provisionnés automatiquement
│   └── dashboards/
│       ├── overview.json    # Dashboard 1 : Santé globale de l'hôte et de tous les projets
│       └── per-project.json # Dashboard 2 : Vue détaillée par projet (sélecteur dynamique)
└── exporters/
    └── koda/               # Exemple d'intégration d'un projet réel (voir ci-dessous)
```

---

## 🔌 Comprendre l'exemple `koda` & brancher vos projets

> 💡 **À propos du dossier `exporters/koda/` :**  
> Le projet nommé **`koda`** présent dans les fichiers de configuration sert d'**exemple concret et complet** (stack Django + PostgreSQL + Redis + Nginx + Celery). Vous pouvez vous en inspirer directement ou le remplacer par vos propres applications.

### Comment brancher votre propre application en 3 étapes :

#### Étape 1 : Assurez-vous d'avoir un réseau Docker pour votre projet
Dans le `docker-compose.yml` de votre projet applicatif, définissez un réseau :
```yaml
networks:
  monprojet_network:
    name: monprojet_network
```
*(Ou créez-le manuellement : `docker network create monprojet_network`)*

#### Étape 2 : Lancez le script d'aide
```bash
./add-project.sh monprojet
```
Le script va :
1. Créer le dossier `exporters/monprojet/` avec les fichiers de credentials d'exemple.
2. Vous afficher les blocs YAML exacts à copier dans `monitoring.yml` et `prometheus/prometheus.yml`.

#### Étape 3 : Activez les logs automatiques (Optionnel mais recommandé)
Dans le `docker-compose.yml` de votre application, ajoutez simplement le label `project` à vos conteneurs :
```yaml
services:
  api:
    image: monprojet_api
    labels:
      project: "monprojet"
```
**Promtail détectera automatiquement ces labels** et catégorisera tous les logs dans Grafana sans aucune configuration supplémentaire !

---

## 🚀 Démarrage rapide

### 1. Prérequis
- Docker et Docker Compose installés.
- Un réseau Docker existant pour le premier projet que vous souhaitez surveiller (par exemple `docker network create koda_network` pour tester avec la configuration d'exemple).

### 2. Configuration des secrets
```bash
# Configuration des identifiants Grafana (optionnel, admin/admin par défaut)
cp grafana/.env.grafana.example grafana/.env.grafana

# Configuration des alertes (Slack, Discord, Email)
cp alertmanager/.env.alertmanager.example alertmanager/.env.alertmanager

# Si vous utilisez l'exemple Koda :
cp exporters/koda/.env.postgres_exporter.example exporters/koda/.env.postgres_exporter
```

---

## 💻 Utilisation au quotidien

Un [Makefile](Makefile) rassemble toutes les commandes usuelles :

### En Développement Local

```bash
# 1. Démarrer en STRICT MINIMUM (~300 Mo de RAM) :
# Démarre uniquement Prometheus, Grafana et les exporters applicatifs
make local

# 2. Si vous voulez également agréger les logs dans Grafana (+ Loki & Promtail) :
make local-logs

# 3. Si vous voulez démarrer TOUS les services en local (Alertmanager, cAdvisor, Uptime Kuma) :
make local-full
```

### En Production

```bash
# Démarre la stack complète durcie avec Node Exporter, quotas TSDB et ressources :
make prod
```

### Commandes utiles

| Commande | Action | Description |
|---|---|---|
| `make local` | Démarrage dev | Strict minimum vital (**~300 Mo RAM**) |
| `make local-logs` | Démarrage dev + logs | Strict minimum + Loki + Promtail (**~550 Mo**) |
| `make local-full` | Démarrage dev complet | Tous les services en local (**~800 Mo**) |
| `make prod` | Démarrage production | Version durcie (**Node Exporter**, quotas, ports privés) |
| `make down` | Arrêt | Éteint proprement l'ensemble des conteneurs |
| `make status` | Vérification | Affiche l'état des conteneurs (`docker compose ps`) |
| `make logs` | Suivi | Affiche les logs en direct |
| `make reload` | Hot-reload | Recharge Prometheus sans couper le service (`curl -X POST /-/reload`) |

---

## 🌐 Services & Ports d'accès

| Service | Port Local | Description | Identifiants par défaut |
|---|---|---|---|
| **Grafana** | `http://localhost:3001` | Tableaux de bord & visualisation | `admin` / `admin` |
| **Prometheus** | `http://localhost:19090` | Métriques brutes & requêtes PromQL | Accès direct |
| **Alertmanager** | `http://localhost:9093` | Interface de gestion des alertes | Accès direct |
| **Uptime Kuma** | `http://localhost:3002` | Statuts de disponibilité & pings HTTP | À configurer au 1er lancement |
| **cAdvisor** | `http://localhost:8081` | Métriques brutes des conteneurs Docker | Accès direct |
| **Loki** | `http://localhost:3100` | API ingestion & requêtes LogQL | Interne |

> 📌 **Pourquoi le port 19090 pour Prometheus ?**  
> Le port standard `9090` est souvent utilisé par des reverse proxies applicatifs (comme Nginx de certains projets). Pour éviter tout conflit sur votre machine hôte, Prometheus a été déplacé sur le port **19090**.

---

## 🛡️ Bonnes pratiques de sécurité en Production

1. **Ne pas exposer les ports bruts sur Internet :**  
   Dans `monitoring.prod.yml`, tous les ports d'administration sont liés à `127.0.0.1`.
   Pour y accéder en toute sécurité depuis l'extérieur :
   * Soit via un **Reverse Proxy sécurisé** (Nginx, Traefik ou Caddy avec HTTPS Let's Encrypt et authentification HTTP ou SSO).
   * Soit via un **tunnel SSH sécurisé** :
     ```bash
     ssh -L 3001:127.0.0.1:3001 user@votre-serveur.com
     ```
     Puis ouvrez `http://localhost:3001` sur votre machine locale.

2. **Changer les identifiants Grafana :**  
   Modifiez impérativement le mot de passe dans `grafana/.env.grafana`.

3. **Exporters étanches :**  
   Aucun exporter applicatif (Postgres, Redis, MySQL...) n'expose de port sur l'extérieur. Seul Prometheus y a accès à l'intérieur du réseau Docker privé `monitoring_network`.

---

## ⚙️ Configuration Nginx (Stub Status)

Si vous surveillez un serveur web Nginx avec `nginx-prometheus-exporter`, Nginx doit exposer la directive `stub_status` aux réseaux Docker :

```nginx
# Dans la configuration Nginx de votre application
location /nginx_status {
    stub_status;
    allow 127.0.0.1;
    allow 172.16.0.0/12;  # Plages IP des réseaux Docker
    allow 10.0.0.0/8;
    deny all;
}
```

---

## 🤝 Licence & Contribution

Projet open-source sous licence [MIT](LICENSE). Les contributions, suggestions et ajouts de nouveaux dashboards ou exporters sont les bienvenus !
