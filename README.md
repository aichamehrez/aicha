\# 🤖 aicha — Autonomous Local AI Agent Node



Bienvenue sur le dépôt du nœud d'agent IA local \*\*aicha\*\*. Ce projet propose un environnement d'exécution conteneurisé pour l'automatisation de tests QA, l'analyse visuelle UI/UX et l'orchestration de tâches d'infrastructure.



\---



\## 🚀 Architecture \& Technologies



Le projet s'appuie sur une architecture conteneurisée sous \*\*Docker / WSL2\*\* :



\* \*\*Inférence LLM Locale :\*\* Ollama (avec accélération GPU)

\* \*\*Mémoire Vectorielle \& RAG :\*\* Turbovec

\* \*\*Automatisation \& QA :\*\* Python (`vector\_memory.py`) \& Scripts Shell (`scan.sh`)

\* \*\*Gestion d'Infrastructure :\*\* Ansible

\* \*\*Environnement :\*\* Docker Compose sur WSL2 / Linux



\---



\## 📁 Structure du Projet



```text

aicha/

├── ansible/               # Playbooks et rôles d'automatisation Ansible

├── Dockerfile             # Fichier de build principal du conteneur

├── Dockerfile.ollama      # Configuration de l'environnement d'inférence Ollama

├── docker-compose.yml     # Orchestration des services (aicha, ollama, turbovec)

├── vector\_memory.py       # Script de gestion de la mémoire vectorielle (RAG)

├── scan.sh                # Script d'analyse et d'exécution des scans QA

├── package.json           # Dépendances Node.js (OpenClaw Node)

├── requirements.txt       # Dépendances Python

├── .env.example           # Modèle de variables d'environnement

└── .gitignore             # Exclusion des secrets, logs et données lourdes

