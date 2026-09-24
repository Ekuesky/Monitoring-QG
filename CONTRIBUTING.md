# 🤝 Contribuer à Monitoring QG

Merci de l'intérêt que vous portez à ce projet ! Voici quelques lignes directrices pour contribuer efficacement.

---

## 📋 Comment contribuer

### 1. Signaler un bug ou proposer une amélioration

- Ouvrez une **issue** sur GitHub avec un titre clair.
- Décrivez le problème ou l'amélioration souhaitée.
- Si c'est un bug, incluez les logs pertinents et votre configuration (versions Docker, OS…).

### 2. Soumettre une Pull Request

1. **Forkez** le dépôt et créez une branche descriptive :
   ```bash
   git checkout -b feat/ajout-mysql-exporter
   ```
2. **Validez** vos modifications avant de soumettre :
   ```bash
   make validate   # Vérifie la syntaxe Docker Compose
   make check-env  # Vérifie les fichiers .env nécessaires
   ```
3. **Testez localement** :
   ```bash
   make local      # ou make local-full pour tester tous les services
   ```
4. **Commitez** avec des messages clairs (en français ou en anglais) :
   ```bash
   git commit -m "feat: ajout du support MySQL exporter"
   ```
5. Ouvrez une **Pull Request** vers la branche `main`.

---

## 🏗️ Structure du projet

Avant de modifier quoi que ce soit, familiarisez-vous avec l'architecture :

| Fichier / Dossier | Rôle |
|---|---|
| `monitoring.yml` | Socle commun Docker Compose |
| `monitoring.local.yml` | Surcouche développement local |
| `monitoring.prod.yml` | Surcouche production durcie |
| `prometheus/prometheus.yml` | Configuration du scraping |
| `prometheus/alerts.yml` | Règles d'alertes |
| `alertmanager/alertmanager.yml` | Routage des alertes |
| `grafana/dashboards/` | Dashboards Grafana (JSON) |
| `exporters/<projet>/` | Configuration par projet |
| `.env.example` | Variables d'environnement (ports, etc.) |

---

## ✅ Conventions

- **Pas de secrets dans le dépôt** : utilisez des fichiers `.env` (ignorés par `.gitignore`) et fournissez toujours un `.example`.
- **Labels Docker** : tout exporter doit porter les labels `project` et `service` pour la segmentation dans Grafana.
- **Commentaires** : les fichiers YAML doivent être commentés avec des en-têtes clairs (voir les fichiers existants).
- **Ports** : utilisez les variables d'environnement (`${PROMETHEUS_PORT:-19090}`) plutôt que des valeurs hardcodées.

---

## 🧪 Checklist avant PR

- [ ] `make validate` passe sans erreur
- [ ] `make check-env` signale tous les fichiers nécessaires
- [ ] Les nouveaux services ont des labels `project` et `service`
- [ ] Les fichiers `.env.*.example` sont fournis pour tout nouveau secret
- [ ] Le `README.md` est mis à jour si nécessaire
- [ ] Les dashboards Grafana modifiés sont exportés en JSON dans `grafana/dashboards/`

---

## 📜 Licence

En contribuant, vous acceptez que vos contributions soient publiées sous la licence [MIT](LICENSE).
