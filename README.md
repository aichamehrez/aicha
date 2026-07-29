# 🤖 aicha — Autonomous Local AI Agent Node

Bienvenue sur le dépôt du nœud d'agent IA local **aicha**. Ce projet propose un environnement d'exécution conteneurisé pour l'automatisation de tests QA, l'analyse visuelle UI/UX et l'orchestration de tâches d'infrastructure.

---

## 🚀 Architecture & Technologies

Le projet s'appuie sur une architecture conteneurisée sous **Docker / WSL2** :

* **Inférence LLM Locale :** Ollama (avec accélération GPU)
* **Mémoire Vectorielle & RAG :** Turbovec
* **Automatisation & QA :** Python (`vector_memory.py`) & Scripts Shell (`scan.sh`)
* **Gestion d'Infrastructure :** Ansible
* **Environnement :** Docker Compose sur WSL2 / Linux

---

## 📁 Structure du Projet

```text
aicha/
├── ansible/               # Playbooks et rôles d'automatisation Ansible
├── Dockerfile             # Fichier de build principal du conteneur
├── Dockerfile.ollama      # Configuration de l'environnement d'inférence Ollama
├── docker-compose.yml     # Orchestration des services (aicha, ollama, turbovec)
├── vector_memory.py       # Script de gestion de la mémoire vectorielle (RAG)
├── scan.sh                # Script d'analyse et d'exécution des scans QA
├── package.json           # Dépendances Node.js (OpenClaw Node)
├── requirements.txt       # Dépendances Python
├── .env.example           # Modèle de variables d'environnement
└── .gitignore             # Exclusion des secrets, logs et données lourdes
```
🛠️ Installation et Démarrage
1. Prérequis
Docker Desktop installé avec le support WSL2 et GPU Pass-through.

Git.

2. Cloner le dépôt
Bash
git clone [https://github.com/aichamehrez/aicha.git](https://github.com/aichamehrez/aicha.git)
cd aicha
3. Configurer l'environnement
Copiez le modèle de configuration et adaptez-le à votre environnement local :

Bash
cp .env.example .env
4. Démarrer les services
Lancez l'ensemble des conteneurs en arrière-plan via Docker Compose :

Bash
docker compose up -d
🔒 Sécurité et Bonnes Pratiques
Les clés d'accès, mots de passe de VM et données temporaires sont entièrement ignorés via le fichier .gitignore.

Aucune donnée confidentielle ou clé API réelle n'est présente sur ce dépôt.
