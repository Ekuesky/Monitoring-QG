.PHONY: help local local-full prod down logs status reload

help: ## Affiche l'aide
	@echo "Monitoring QG — Commandes disponibles :"
	@echo ""
	@echo "  make local       Démarre la stack optimisée pour le développement local"
	@echo "  make local-full  Démarre la stack locale AVEC Uptime Kuma (--profile optional)"
	@echo "  make prod        Démarre la stack optimisée pour la production (Node Exporter, quotas, sécurité)"
	@echo "  make down        Arrête la stack de monitoring"
	@echo "  make status      Affiche l'état des conteneurs"
	@echo "  make logs        Affiche les logs de la stack"
	@echo "  make reload      Recharge la configuration Prometheus sans redémarrer (hot-reload)"
	@echo ""

local: ## Démarrage en local (léger, rétention 2j, ports ouverts)
	docker compose -f monitoring.yml -f monitoring.local.yml up -d

local-full: ## Démarrage en local avec Uptime Kuma inclus
	docker compose -f monitoring.yml -f monitoring.local.yml --profile optional up -d

prod: ## Démarrage en production (Node Exporter, ports sécurisés, quotas TSDB et ressources)
	docker compose -f monitoring.yml -f monitoring.prod.yml up -d

down: ## Arrêt de la stack
	docker compose -f monitoring.yml -f monitoring.local.yml -f monitoring.prod.yml down

status: ## État des conteneurs
	docker compose -f monitoring.yml ps

logs: ## Logs en direct
	docker compose -f monitoring.yml logs -f

reload: ## Hot-reload Prometheus
	@curl -s -X POST http://localhost:19090/-/reload && echo "✅ Configuration Prometheus rechargée avec succès." || echo "❌ Échec du reload (Prometheus actif sur 19090 ?)"
