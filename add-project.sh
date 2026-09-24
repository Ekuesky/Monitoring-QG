#!/usr/bin/env bash
# =============================================================================
# add-project.sh — Intégration d'un nouveau projet dans le QG de monitoring
# Usage: ./add-project.sh <nom-projet>
# Exemple: ./add-project.sh projetx
#
# Ce script :
#   1. Vérifie que le réseau Docker du projet existe (ou le crée)
#   2. Crée le dossier exporters/<projet>/ avec les fichiers .example
#   3. Génère les snippets YAML et propose l'ajout automatique
# =============================================================================

set -euo pipefail

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT="${1:-}"

if [ -z "$PROJECT" ]; then
  echo -e "${RED}❌  Usage: ./add-project.sh <nom-projet>${NC}"
  echo "   Exemple: ./add-project.sh monapp"
  exit 1
fi

# Validation du nom (alphanumérique + tirets/underscores)
if ! [[ "$PROJECT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo -e "${RED}❌  Le nom du projet ne doit contenir que des lettres, chiffres, tirets ou underscores.${NC}"
  exit 1
fi

# Vérification qu'il n'existe pas déjà
if [ -d "exporters/${PROJECT}" ]; then
  echo -e "${YELLOW}⚠️   Le dossier exporters/${PROJECT}/ existe déjà. Vérifiez la configuration existante.${NC}"
fi

NETWORK="${PROJECT}_network"
EXPORTER_DIR="exporters/${PROJECT}"

echo ""
echo -e "${CYAN}🚀  Intégration du projet : ${PROJECT}${NC}"
echo "=================================================="

# -------------------------------------------------------------------------
# 1. Vérifier / Créer le réseau Docker
# -------------------------------------------------------------------------
echo ""
echo -e "${CYAN}🌐  Vérification du réseau Docker ${NETWORK}...${NC}"
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo -e "   ${GREEN}✅  Le réseau ${NETWORK} existe déjà.${NC}"
else
  echo -e "   ${YELLOW}⚠️   Le réseau ${NETWORK} n'existe pas.${NC}"
  read -rp "   Voulez-vous le créer maintenant ? [O/n] " CREATE_NET
  CREATE_NET="${CREATE_NET:-O}"
  if [[ "$CREATE_NET" =~ ^[OoYy]$ ]]; then
    docker network create "$NETWORK"
    echo -e "   ${GREEN}✅  Réseau ${NETWORK} créé.${NC}"
  else
    echo -e "   ${YELLOW}⚠️   Pensez à créer le réseau avant de démarrer : docker network create ${NETWORK}${NC}"
  fi
fi

# -------------------------------------------------------------------------
# 2. Créer le dossier exporters/<projet>/
# -------------------------------------------------------------------------
echo ""
echo -e "${CYAN}📁  Création de ${EXPORTER_DIR}/${NC}"
mkdir -p "${EXPORTER_DIR}"

if [ -f "exporters/koda/.env.postgres_exporter.example" ]; then
  cp "exporters/koda/.env.postgres_exporter.example" "${EXPORTER_DIR}/.env.postgres_exporter.example"
  echo -e "   ${GREEN}✅  ${EXPORTER_DIR}/.env.postgres_exporter.example créé${NC}"
else
  # Créer un fichier d'exemple minimal
  cat > "${EXPORTER_DIR}/.env.postgres_exporter.example" << 'ENV'
# PostgreSQL Exporter — Configuration
# Remplacez les valeurs ci-dessous par les credentials de votre base de données
DATA_SOURCE_NAME=postgresql://user:password@<container_name>:5432/dbname?sslmode=disable
ENV
  echo -e "   ${GREEN}✅  ${EXPORTER_DIR}/.env.postgres_exporter.example créé (modèle générique)${NC}"
fi

# Copier automatiquement le .example vers le fichier réel si absent
if [ ! -f "${EXPORTER_DIR}/.env.postgres_exporter" ]; then
  cp "${EXPORTER_DIR}/.env.postgres_exporter.example" "${EXPORTER_DIR}/.env.postgres_exporter"
  chmod 600 "${EXPORTER_DIR}/.env.postgres_exporter"
  echo -e "   ${GREEN}✅  ${EXPORTER_DIR}/.env.postgres_exporter créé (permissions 600)${NC}"
  echo -e "   ${YELLOW}⚠️   Pensez à éditer ce fichier avec vos vrais credentials !${NC}"
fi

# -------------------------------------------------------------------------
# 3. Afficher les snippets YAML à ajouter
# -------------------------------------------------------------------------
echo ""
echo "=================================================="
echo -e "${CYAN}📋  ÉTAPE MANUELLE 1 — Ajouter dans monitoring.yml (section services) :${NC}"
echo "=================================================="
cat << YAML

  # -- Exporters — ${PROJECT} --
  postgres_exporter_${PROJECT}:
    image: prometheuscommunity/postgres-exporter:v0.15.0
    container_name: monitoring_postgres_${PROJECT}
    restart: unless-stopped
    env_file:
      - ./exporters/${PROJECT}/.env.postgres_exporter
    networks:
      - ${NETWORK}
      - monitoring_network
    labels:
      project: "${PROJECT}"
      service: "postgres"

YAML

echo "=================================================="
echo -e "${CYAN}📋  ÉTAPE MANUELLE 2 — Ajouter dans prometheus/prometheus.yml :${NC}"
echo "=================================================="
cat << YAML

  # PostgreSQL — ${PROJECT}
  - job_name: "postgres_${PROJECT}"
    static_configs:
      - targets: ["postgres_exporter_${PROJECT}:9187"]
        labels:
          project: "${PROJECT}"
          service: "postgres"

YAML

echo "=================================================="
echo -e "${CYAN}📋  ÉTAPE MANUELLE 3 — Ajouter le réseau dans monitoring.yml (section networks) :${NC}"
echo "=================================================="
cat << YAML

  ${NETWORK}:
    external: true

YAML

echo "=================================================="
echo -e "${CYAN}📋  ÉTAPES FINALES :${NC}"
echo "=================================================="
echo ""
echo "  1. Éditer les credentials :"
echo "     nano ${EXPORTER_DIR}/.env.postgres_exporter"
echo ""
echo "  2. (Optionnel) Ajouter le label 'project' à vos conteneurs applicatifs :"
echo "     labels:"
echo "       project: \"${PROJECT}\""
echo ""
echo "  3. Démarrer les nouveaux exporters sans toucher aux autres :"
echo "     docker compose -f monitoring.yml up -d --no-deps postgres_exporter_${PROJECT}"
echo ""
echo "  4. Hot-reload Prometheus (sans redémarrage) :"
echo "     make reload"
echo ""
echo -e "${GREEN}✅  Prêt ! Le projet ${PROJECT} sera visible dans Grafana sous le label project=\"${PROJECT}\"${NC}"
echo ""
