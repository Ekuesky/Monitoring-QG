#!/usr/bin/env bash
# =============================================================================
# add-project.sh — Intégration d'un nouveau projet dans le QG de monitoring
# Usage: ./add-project.sh <nom-projet>
# Exemple: ./add-project.sh projetx
# =============================================================================

set -e

PROJECT="${1}"

if [ -z "$PROJECT" ]; then
  echo "❌  Usage: ./add-project.sh <nom-projet>"
  exit 1
fi

NETWORK="${PROJECT}_network"
EXPORTER_DIR="exporters/${PROJECT}"

echo ""
echo "🚀  Intégration du projet : ${PROJECT}"
echo "=================================================="

# 1. Créer le dossier exporters/<projet>/
echo ""
echo "📁  Création de ${EXPORTER_DIR}/"
mkdir -p "${EXPORTER_DIR}"

# 2. Copier les fichiers .example
cp exporters/koda/.env.postgres_exporter.example "${EXPORTER_DIR}/.env.postgres_exporter.example"
echo "   ✅  ${EXPORTER_DIR}/.env.postgres_exporter.example créé"

# 3. Afficher les snippets YAML à ajouter
echo ""
echo "=================================================="
echo "📋  ÉTAPE MANUELLE 1 — Ajouter dans monitoring.yml :"
echo "=================================================="
cat << YAML

  # -- Exporters — ${PROJECT} --
  postgres_exporter_${PROJECT}:
    image: prometheuscommunity/postgres-exporter:v0.15.0
    container_name: monitoring_postgres_${PROJECT}
    restart: unless-stopped
    env_file:
      - ./exporters/${PROJECT}/.env.postgres_exporter
    ports:
      - "91XX:9187"   # ← choisir un port libre
    networks:
      - ${NETWORK}
      - monitoring_network
    labels:
      project: "${PROJECT}"
      service: "postgres"

YAML

echo "=================================================="
echo "📋  ÉTAPE MANUELLE 2 — Ajouter dans prometheus/prometheus.yml :"
echo "=================================================="
cat << YAML

  # PostgreSQL — ${PROJECT}
  - job_name: "postgres"
    static_configs:
      - targets: ["postgres_exporter_${PROJECT}:9187"]
        labels:
          project: "${PROJECT}"
          service: "postgres"

YAML

echo "=================================================="
echo "📋  ÉTAPE MANUELLE 3 — Ajouter le réseau dans monitoring.yml (section networks) :"
echo "=================================================="
cat << YAML

  ${NETWORK}:
    external: true

YAML

echo "=================================================="
echo "📋  ÉTAPES FINALES :"
echo "=================================================="
echo ""
echo "  1. Remplir les credentials :"
echo "     cp ${EXPORTER_DIR}/.env.postgres_exporter.example ${EXPORTER_DIR}/.env.postgres_exporter"
echo "     nano ${EXPORTER_DIR}/.env.postgres_exporter"
echo ""
echo "  2. Vérifier que le réseau existe :"
echo "     docker network inspect ${NETWORK} || docker network create ${NETWORK}"
echo ""
echo "  3. Démarrer les nouveaux exporters sans toucher aux autres :"
echo "     docker compose -f monitoring.yml up -d --no-deps postgres_exporter_${PROJECT}"
echo ""
echo "  4. Hot-reload Prometheus (sans redémarrage) :"
echo "     curl -X POST http://localhost:19090/-/reload"
echo ""
echo "✅  Prêt ! Le projet ${PROJECT} sera visible dans Grafana sous le label project=\"${PROJECT}\""
echo ""
