.PHONY: help local local-logs local-full prod down logs status reload check-env validate secure

help: ## Affiche l'aide
	@echo "Monitoring QG — Commandes disponibles :"
	@echo ""
	@echo "  make local       Démarre le STRICT MINIMUM en local (Prometheus, Grafana, Exporters ~300 Mo RAM)"
	@echo "  make local-logs  Démarre le strict minimum + agrégation des logs (Loki + Promtail)"
	@echo "  make local-full  Démarre TOUTE la stack locale (Alertmanager, cAdvisor, Uptime Kuma inclus)"
	@echo "  make prod        Démarre la stack de production (Node Exporter, quotas, sécurité)"
	@echo "  make down        Arrête la stack de monitoring"
	@echo "  make status      Affiche l'état des conteneurs"
	@echo "  make logs        Affiche les logs de la stack"
	@echo "  make reload      Recharge la configuration Prometheus sans redémarrer (hot-reload)"
	@echo "  make check-env   Vérifie que les fichiers .env nécessaires existent"
	@echo "  make validate    Valide la syntaxe de tous les fichiers Docker Compose et YAML"
	@echo "  make secure      Génère un mot de passe aléatoire pour Grafana (prod)"
	@echo ""

# =============================================================================
# VÉRIFICATIONS — Pré-requis et validation
# =============================================================================

check-env: ## Vérifie que les fichiers .env nécessaires existent
	@echo "🔍  Vérification des fichiers de configuration..."
	@MISSING=0; \
	if [ ! -f grafana/.env.grafana ]; then \
		echo "  ❌  grafana/.env.grafana manquant (copier depuis grafana/.env.grafana.example)"; \
		MISSING=1; \
	else \
		echo "  ✅  grafana/.env.grafana"; \
	fi; \
	if [ ! -f alertmanager/.env.alertmanager ]; then \
		echo "  ⚠️   alertmanager/.env.alertmanager manquant (copier depuis alertmanager/.env.alertmanager.example)"; \
	else \
		echo "  ✅  alertmanager/.env.alertmanager"; \
	fi; \
	for dir in exporters/*/; do \
		project=$$(basename "$$dir"); \
		if [ ! -f "$$dir/.env.postgres_exporter" ] && [ -f "$$dir/.env.postgres_exporter.example" ]; then \
			echo "  ❌  $$dir.env.postgres_exporter manquant (copier depuis .example)"; \
			MISSING=1; \
		elif [ -f "$$dir/.env.postgres_exporter" ]; then \
			echo "  ✅  $$dir.env.postgres_exporter"; \
		fi; \
	done; \
	if [ "$$MISSING" -eq 1 ]; then \
		echo ""; \
		echo "💡  Conseil : copiez les fichiers .example et éditez-les avec vos credentials."; \
		exit 1; \
	else \
		echo ""; \
		echo "✅  Tous les fichiers de configuration sont en place."; \
	fi

validate: ## Valide la syntaxe des fichiers Docker Compose
	@echo "🔍  Validation de la configuration Docker Compose..."
	@docker compose -f monitoring.yml -f monitoring.local.yml config --quiet 2>&1 && \
		echo "  ✅  monitoring.yml + monitoring.local.yml — OK" || \
		echo "  ❌  monitoring.yml + monitoring.local.yml — ERREUR"
	@docker compose -f monitoring.yml -f monitoring.prod.yml config --quiet 2>&1 && \
		echo "  ✅  monitoring.yml + monitoring.prod.yml — OK" || \
		echo "  ❌  monitoring.yml + monitoring.prod.yml — ERREUR"
	@echo ""
	@echo "✅  Validation terminée."

secure: ## Génère un mot de passe Grafana aléatoire sécurisé
	@NEW_PASS=$$(openssl rand -base64 24 | tr -d '/+=' | head -c 24); \
	if [ -f grafana/.env.grafana ]; then \
		sed -i "s|^GF_SECURITY_ADMIN_PASSWORD=.*|GF_SECURITY_ADMIN_PASSWORD=$$NEW_PASS|" grafana/.env.grafana; \
	else \
		cp grafana/.env.grafana.example grafana/.env.grafana; \
		sed -i "s|^GF_SECURITY_ADMIN_PASSWORD=.*|GF_SECURITY_ADMIN_PASSWORD=$$NEW_PASS|" grafana/.env.grafana; \
	fi; \
	chmod 600 grafana/.env.grafana; \
	echo "🔐  Nouveau mot de passe Grafana généré :"; \
	echo "    $$NEW_PASS"; \
	echo ""; \
	echo "    (Sauvegardé dans grafana/.env.grafana avec permissions 600)"

# =============================================================================
# DÉMARRAGE — Modes local et production
# =============================================================================

local: check-env ## Démarrage en local — STRICT MINIMUM (5 conteneurs : Prometheus, Grafana, Exporters)
	docker compose -f monitoring.yml -f monitoring.local.yml up -d

local-logs: check-env ## Démarrage en local avec Loki & Promtail pour les logs
	docker compose -f monitoring.yml -f monitoring.local.yml --profile logs up -d

local-full: check-env ## Démarrage en local complet (Alertmanager, cAdvisor, Uptime Kuma, Logs)
	docker compose -f monitoring.yml -f monitoring.local.yml --profile full up -d

prod: check-env ## Démarrage en production (Node Exporter, ports sécurisés 127.0.0.1, quotas)
	docker compose -f monitoring.yml -f monitoring.prod.yml up -d

# =============================================================================
# GESTION — Arrêt, statut, logs, reload
# =============================================================================

down: ## Arrêt de la stack
	docker compose -f monitoring.yml -f monitoring.local.yml --profile full down

status: ## État des conteneurs
	docker compose -f monitoring.yml ps

logs: ## Logs en direct
	docker compose -f monitoring.yml logs -f

reload: ## Hot-reload Prometheus
	@curl -s -X POST http://localhost:$${PROMETHEUS_PORT:-19090}/-/reload && echo "✅ Configuration Prometheus rechargée avec succès." || echo "❌ Échec du reload (Prometheus actif sur $${PROMETHEUS_PORT:-19090} ?)"
