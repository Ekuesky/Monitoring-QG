#!/usr/bin/env bash
# =============================================================================
# add-project.sh — Intégration d'un nouveau projet dans le QG de monitoring
# Usage: ./add-project.sh <nom-projet>
# Exemple: ./add-project.sh projetx
#
# Ce script :
#   1. Vérifie que le réseau Docker du projet existe (ou le crée)
#   2. Crée le dossier autonome exporters/<projet>/
#   3. Génère automatiquement exporters/<projet>/docker-compose.yml
#   4. Génère automatiquement prometheus/targets/<projet>.yml (auto-découverte Prometheus)
#   5. Initialise les credentials .env
# =============================================================================

set -euo pipefail

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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

NETWORK="${PROJECT}_network"
EXPORTER_DIR="exporters/${PROJECT}"
TARGET_FILE="prometheus/targets/${PROJECT}.yml"

echo ""
echo -e "${CYAN}🚀  Intégration du projet : ${BOLD}${PROJECT}${NC}"
echo "=================================================="

# -------------------------------------------------------------------------
# 1. Vérifier / Créer le réseau Docker
# -------------------------------------------------------------------------
echo ""
echo -e "${CYAN}🌐  1. Vérification du réseau Docker ${NETWORK}...${NC}"
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo -e "   ${GREEN}✅  Le réseau ${NETWORK} existe déjà.${NC}"
else
  echo -e "   ${YELLOW}⚠️   Le réseau ${NETWORK} n'existe pas encore.${NC}"
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
echo -e "${CYAN}📁  2. Création de ${EXPORTER_DIR}/${NC}"
mkdir -p "${EXPORTER_DIR}"
mkdir -p "prometheus/targets"

# -------------------------------------------------------------------------
# 3. Créer / Copier les fichiers .env de credentials
# -------------------------------------------------------------------------
if [ -f "exporters/koda/.env.postgres_exporter.example" ]; then
  cp "exporters/koda/.env.postgres_exporter.example" "${EXPORTER_DIR}/.env.postgres_exporter.example"
else
  cat > "${EXPORTER_DIR}/.env.postgres_exporter.example" << 'ENV'
# PostgreSQL Exporter — Configuration
DATA_SOURCE_NAME=postgresql://user:password@postgres:5432/dbname?sslmode=disable
ENV
fi
echo -e "   ${GREEN}✅  ${EXPORTER_DIR}/.env.postgres_exporter.example créé${NC}"

if [ ! -f "${EXPORTER_DIR}/.env.postgres_exporter" ]; then
  cp "${EXPORTER_DIR}/.env.postgres_exporter.example" "${EXPORTER_DIR}/.env.postgres_exporter"
  chmod 600 "${EXPORTER_DIR}/.env.postgres_exporter"
  echo -e "   ${GREEN}✅  ${EXPORTER_DIR}/.env.postgres_exporter initialisé (permissions 600)${NC}"
fi

# -------------------------------------------------------------------------
# 4. Générer automatiquement exporters/<projet>/docker-compose.yml
# -------------------------------------------------------------------------
COMPOSE_FILE="${EXPORTER_DIR}/docker-compose.yml"
if [ -f "${COMPOSE_FILE}" ]; then
  echo -e "   ${YELLOW}⚠️   ${COMPOSE_FILE} existe déjà (non écrasé).${NC}"
else
  cat > "${COMPOSE_FILE}" << YAML
services:
  postgres_exporter_${PROJECT}:
    image: prometheuscommunity/postgres-exporter:v0.20.1
    container_name: monitoring_postgres_${PROJECT}
    restart: unless-stopped
    env_file:
      - ./${EXPORTER_DIR}/.env.postgres_exporter
    networks:
      - ${NETWORK}
      - monitoring_network
    labels:
      project: "${PROJECT}"
      service: "postgres"

  # Pour ajouter Redis ou Nginx, décommentez ci-dessous :
  # redis_exporter_${PROJECT}:
  #   image: oliver006/redis_exporter:v1.92.1
  #   container_name: monitoring_redis_${PROJECT}
  #   restart: unless-stopped
  #   environment:
  #     REDIS_ADDR: "redis://${PROJECT}_redis:6379"
  #   networks:
  #     - ${NETWORK}
  #     - monitoring_network
  #   labels:
  #     project: "${PROJECT}"
  #     service: "redis"

networks:
  ${NETWORK}:
    external: true
  monitoring_network: {}
YAML
  echo -e "   ${GREEN}✅  ${COMPOSE_FILE} généré automatiquement.${NC}"
fi

# -------------------------------------------------------------------------
# 5. Générer automatiquement prometheus/targets/<projet>.yml
# -------------------------------------------------------------------------
if [ -f "${TARGET_FILE}" ]; then
  echo -e "   ${YELLOW}⚠️   ${TARGET_FILE} existe déjà (non écrasé).${NC}"
else
  cat > "${TARGET_FILE}" << YAML
# =============================================================================
# Cibles Prometheus — Projet : ${PROJECT}
# Découverte automatique via file_sd_configs (/etc/prometheus/targets/*.yml)
# =============================================================================

- targets:
    - "postgres_exporter_${PROJECT}:9187"
  labels:
    project: "${PROJECT}"
    service: "postgres"
    job: "postgres"

# Décommenter si un redis_exporter est configuré :
# - targets:
#     - "redis_exporter_${PROJECT}:9121"
#   labels:
#     project: "${PROJECT}"
#     service: "redis"
#     job: "redis"
YAML
  echo -e "   ${GREEN}✅  ${TARGET_FILE} généré automatiquement (auto-découverte Prometheus).${NC}"
fi

# -------------------------------------------------------------------------
# 6. Instructions finales
# -------------------------------------------------------------------------
echo ""
echo "=================================================="
echo -e "${CYAN}🎉  Projet ${BOLD}${PROJECT}${NC}${CYAN} configuré avec succès !${NC}"
echo "=================================================="
echo ""
echo -e "Il ne vous reste que 2 étapes simples :"
echo ""
echo -e "  1. ${BOLD}Éditer les credentials de la base de données :${NC}"
echo "     nano ${EXPORTER_DIR}/.env.postgres_exporter"
echo ""
echo -e "  2. ${BOLD}Démarrer (ou recharger) la stack :${NC}"
echo "     make local    # en local"
echo "     # ou make prod # en production"
echo ""
echo -e "${GREEN}✨ Zéro modification du cœur : ${PROJECT} est auto-détecté par Docker Compose et Prometheus !${NC}"
echo ""
