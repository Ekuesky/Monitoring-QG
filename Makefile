.PHONY: help local local-logs local-full prod down logs status reload

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
	@echo ""

local: ## Démarrage en local — STRICT MINIMUM (5 conteneurs : Prometheus, Grafana, Exporters)
	docker compose -f monitoring.yml -f monitoring.local.yml up -d

local-logs: ## Démarrage en local avec Loki & Promtail pour les logs
	docker compose -f monitoring.yml -f monitoring.local.yml --profile logs up -d

local-full: ## Démarrage en local complet (Alertmanager, cAdvisor, Uptime Kuma, Logs)
	docker compose -f monitoring.yml -f monitoring.local.yml --profile full up -d

prod: ## Démarrage en production (Node Exporter, ports sécurisés 127.0.0.1, quotas)
	docker compose -f monitoring.yml -f monitoring.prod.yml up -d

down: ## Arrêt de la stack
	docker compose -f monitoring.yml -f monitoring.local.yml --profile full down

status: ## État des conteneurs
	docker compose -f monitoring.yml ps

logs: ## Logs en direct
	docker compose -f monitoring.yml logs -f

reload: ## Hot-reload Prometheus
	@curl -s -X POST http://localhost:19090/-/reload && echo "✅ Configuration Prometheus rechargée avec succès." || echo "❌ Échec du reload (Prometheus actif sur 19090 ?)"
