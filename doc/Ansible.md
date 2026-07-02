# Cours complet — Ansible

## 1. Introduction

Ansible est un outil d’automatisation d’infrastructure.
Il permet de configurer des serveurs, installer des logiciels, déployer des applications, gérer des fichiers, créer des utilisateurs, configurer un firewall ou encore lancer des conteneurs Docker.

Dans un projet comme **Cloud-1**, Ansible sert à transformer un VPS vide en serveur prêt à héberger une application complète.

Exemple d’objectif :

```text
VPS vide
  ↓
Ansible
  ↓
Docker installé
Firewall configuré
Fichiers copiés
Secrets créés
Conteneurs lancés
Site accessible en HTTPS
```

L’intérêt principal d’Ansible est de rendre le déploiement **reproductible**.
Au lieu de configurer un serveur à la main, on écrit des fichiers qui décrivent ce que le serveur doit devenir.

---

## 2. À quoi sert Ansible ?

Ansible peut automatiser :

* l’installation de paquets système ;
* la configuration de services ;
* la création de dossiers ;
* la copie de fichiers ;
* la génération de fichiers de configuration ;
* la gestion des permissions ;
* la configuration SSH ;
* la configuration firewall ;
* le déploiement Docker ;
* le lancement de commandes ;
* la gestion de tâches cron ;
* le déploiement complet d’une application.

Dans Cloud-1, Ansible peut par exemple :

* installer Docker ;
* installer Docker Compose ;
* configurer UFW ;
* ouvrir les ports `22`, `80`, `443` ;
* créer `/opt/cloud-1` ;
* copier les Dockerfiles ;
* générer le `docker-compose.yml` ;
* créer les fichiers secrets ;
* obtenir ou réutiliser un certificat Let’s Encrypt ;
* lancer les conteneurs.

---

## 3. Le principe général

Ansible fonctionne avec une logique simple :

```text
Machine locale
  ↓ SSH
Serveur distant
```

La machine locale est appelée **Ansible Controller**.
C’est la machine depuis laquelle on lance les commandes Ansible.

Le serveur distant est appelé **Managed Node**.
C’est la machine qu’Ansible configure.

Dans ton cas :

```text
Ansible Controller : ta machine locale à 42
Managed Node       : ton VPS Scaleway
```

Ansible se connecte généralement au serveur distant avec SSH.

---

## 4. Les grands concepts d’Ansible

Ansible repose principalement sur ces éléments :

* **Inventory** : liste des serveurs à gérer ;
* **Playbook** : fichier principal qui décrit les actions à effectuer ;
* **Play** : ensemble d’actions appliquées à un groupe de serveurs ;
* **Task** : action individuelle ;
* **Module** : outil Ansible utilisé dans une tâche ;
* **Role** : dossier organisé contenant des tâches, fichiers, templates et variables ;
* **Variables** : valeurs dynamiques utilisées dans les playbooks ;
* **Templates** : fichiers générés dynamiquement avec Jinja2 ;
* **Handlers** : actions déclenchées seulement si une tâche change quelque chose ;
* **Facts** : informations récupérées automatiquement sur le serveur cible.

---

## 5. Inventory

L’inventory est le fichier qui indique à Ansible quelles machines il doit gérer.

Exemple :

```ini
[cloud]
cloud1 ansible_host=51.159.155.247 ansible_user=root ansible_ssh_private_key_file=/home/vnieto-j/.ssh/id_rsa
```

Explication :

```text
[cloud]                         → groupe de serveurs
cloud1                          → nom logique du serveur
ansible_host=51.159.155.247     → IP réelle du serveur
ansible_user=root               → utilisateur SSH
ansible_ssh_private_key_file    → clé privée utilisée pour SSH
```

Le nom `cloud1` est un alias local à Ansible.
Il ne correspond pas forcément au hostname réel du VPS.

Commande pour tester l’inventory :

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

Résultat attendu :

```json
cloud1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Si cette commande fonctionne, Ansible peut joindre ton serveur.

---

## 6. Playbook

Un playbook est un fichier YAML qui décrit ce qu’Ansible doit faire.

Exemple :

```yaml
---
- name: Deploy Cloud-1 infrastructure
  hosts: cloud
  become: true

  roles:
    - common
    - docker
    - firewall
    - deploy
```

Explication :

```text
name        → nom du playbook ou du play
hosts       → groupe de machines ciblé
become      → permet d’exécuter avec privilèges élevés
roles       → liste des rôles à appliquer
```

Dans cet exemple, Ansible applique les rôles suivants :

```text
common
docker
firewall
deploy
```

dans cet ordre.

Commande pour lancer le playbook :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

---

## 7. YAML dans Ansible

Ansible utilise beaucoup le format YAML.

Un fichier YAML commence souvent par :

```yaml
---
```

Ce marqueur indique le début du document.

Exemple simple :

```yaml
project_dir: /opt/cloud-1
domain_name: cloud-one-vnieto-j.duckdns.org
mysql_database: wordpress
```

Les espaces sont importants.
YAML fonctionne avec l’indentation.

Mauvais exemple :

```yaml
- name: Install packages
ansible.builtin.apt:
name:
- curl
```

Bon exemple :

```yaml
- name: Install packages
  ansible.builtin.apt:
    name:
      - curl
      - git
    state: present
```

---

## 8. Tasks

Une task est une action précise.

Exemple :

```yaml
- name: Install base packages
  ansible.builtin.apt:
    name:
      - curl
      - git
      - unzip
    state: present
```

Cette tâche signifie :

* installer `curl` ;
* installer `git` ;
* installer `unzip` ;
* ne rien faire s’ils sont déjà installés.

Une tâche Ansible doit idéalement avoir un nom clair.

Bon nom :

```yaml
- name: Install Docker Engine and Compose plugin
```

Mauvais nom :

```yaml
- name: Run command
```

Le nom de la tâche doit permettre de comprendre ce qu’elle fait dans les logs.

---

## 9. Modules

Les modules sont les outils qu’Ansible utilise pour agir sur le serveur.

Exemples de modules courants :

### apt

Utilisé pour gérer les paquets sur Debian/Ubuntu.

```yaml
- name: Install curl
  ansible.builtin.apt:
    name: curl
    state: present
```

### file

Utilisé pour créer des fichiers, dossiers ou gérer les permissions.

```yaml
- name: Create project directory
  ansible.builtin.file:
    path: /opt/cloud-1
    state: directory
    owner: root
    group: root
    mode: "0755"
```

### copy

Utilisé pour copier un fichier depuis la machine locale vers le serveur.

```yaml
- name: Copy Docker build contexts
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../docker/"
    dest: "{{ project_dir }}/docker/"
    owner: root
    group: root
    mode: preserve
```

### template

Utilisé pour générer un fichier à partir d’un template Jinja2.

```yaml
- name: Copy docker-compose.yml from template
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: "{{ project_dir }}/docker-compose.yml"
    owner: root
    group: root
    mode: "0644"
```

### command

Utilisé pour lancer une commande.

```yaml
- name: Start containers with Docker Compose
  ansible.builtin.command: docker compose up -d --build --remove-orphans
  args:
    chdir: "{{ project_dir }}"
```

### service

Utilisé pour gérer un service système.

```yaml
- name: Ensure Docker service is started
  ansible.builtin.service:
    name: docker
    state: started
    enabled: true
```

### cron

Utilisé pour créer une tâche cron.

```yaml
- name: Add cron job for Let's Encrypt renewal
  ansible.builtin.cron:
    name: "Renew certificates"
    minute: "0"
    hour: "3"
    job: "docker run --rm certbot/certbot renew --quiet"
```

---

## 10. Idempotence

L’idempotence est une notion centrale dans Ansible.

Une tâche idempotente peut être lancée plusieurs fois sans produire de changement inutile.

Exemple :

```yaml
- name: Install curl
  ansible.builtin.apt:
    name: curl
    state: present
```

Premier lancement :

```text
changed
```

Deuxième lancement :

```text
ok
```

Cela signifie que le paquet est déjà installé.

L’objectif d’un bon playbook est qu’il puisse être relancé plusieurs fois sans casser le serveur.

Dans Cloud-1, c’est très important.
Tu dois pouvoir relancer :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

sans devoir reconstruire ton VPS à chaque fois.

---

## 11. Lecture du résultat Ansible

À la fin d’un playbook, Ansible affiche un résumé :

```text
PLAY RECAP
cloud1 : ok=44 changed=5 unreachable=0 failed=0 skipped=3 rescued=0 ignored=0
```

Signification :

```text
ok          → tâche réussie sans changement
changed     → tâche réussie avec modification
unreachable → serveur inaccessible
failed      → tâche échouée
skipped     → tâche ignorée à cause d’une condition
rescued     → tâche récupérée par un bloc rescue
ignored     → erreur ignorée volontairement
```

Le résultat idéal :

```text
failed=0
unreachable=0
```

Cela signifie que le déploiement n’a pas échoué.

---

## 12. Variables

Les variables permettent d’éviter les valeurs codées en dur.

Mauvais exemple :

```yaml
path: /opt/cloud-1
```

Meilleur exemple :

```yaml
path: "{{ project_dir }}"
```

Puis dans un fichier de variables :

```yaml
project_dir: /opt/cloud-1
```

Avantages :

* le projet est plus propre ;
* les valeurs sont centralisées ;
* le playbook est plus facile à modifier ;
* le projet devient plus réutilisable.

Exemple de variables pour Cloud-1 :

```yaml
project_dir: /opt/cloud-1

domain_name: cloud-one-vnieto-j.duckdns.org
letsencrypt_email: victornieto-juan@live.fr

mysql_database: wordpress
mysql_user: wp_user

wp_title: cloud_1
wp_admin_user: admin
wp_admin_email: victornieto-juan@live.fr
wp_user: victor
wp_user_email: victornieto-juan+wpuser@live.fr

wordpress_db_host: mariadb:3306
```

Les variables sont appelées avec cette syntaxe :

```yaml
{{ variable_name }}
```

Exemple :

```yaml
dest: "{{ project_dir }}/docker-compose.yml"
```

---

## 13. group_vars

`group_vars` permet de définir des variables pour un groupe de serveurs.

Si ton inventory contient :

```ini
[cloud]
cloud1 ansible_host=51.159.155.247 ansible_user=root
```

Alors Ansible peut charger automatiquement :

```text
ansible/group_vars/cloud.yml
```

ou :

```text
ansible/group_vars/cloud/main.yml
```

Exemple :

```yaml
---
project_dir: /opt/cloud-1
domain_name: cloud-one-vnieto-j.duckdns.org
mysql_database: wordpress
mysql_user: wp_user
```

Cela permet d’avoir un playbook générique, mais des valeurs spécifiques à ton groupe `cloud`.

---

## 14. Templates Jinja2

Les templates permettent de générer des fichiers dynamiques.

Un template Ansible utilise généralement l’extension :

```text
.j2
```

Exemple :

```text
docker-compose.yml.j2
```

Dans un template, on peut utiliser des variables :

```yaml
services:
  nginx:
    environment:
      DOMAIN_NAME: "{{ domain_name }}"
```

Si dans `group_vars` on a :

```yaml
domain_name: cloud-one-vnieto-j.duckdns.org
```

Alors Ansible génère :

```yaml
services:
  nginx:
    environment:
      DOMAIN_NAME: "cloud-one-vnieto-j.duckdns.org"
```

Dans Cloud-1, les templates sont utiles pour :

* `docker-compose.yml` ;
* `.env` ;
* configuration Nginx HTTP ;
* configuration Nginx HTTPS ;
* fichiers de configuration dynamiques.

---

## 15. Conditions avec when

Ansible permet d’exécuter une tâche seulement si une condition est vraie.

Exemple :

```yaml
- name: Copy temporary HTTP nginx config before first certificate
  ansible.builtin.template:
    src: nginx-http.conf.j2
    dest: "{{ project_dir }}/nginx.conf"
  when: not letsencrypt_cert.stat.exists
```

Cette tâche est exécutée seulement si le certificat Let’s Encrypt n’existe pas encore.

Autre exemple :

```yaml
- name: Copy HTTPS nginx config if certificate already exists
  ansible.builtin.template:
    src: nginx-https.conf.j2
    dest: "{{ project_dir }}/nginx.conf"
  when: letsencrypt_cert.stat.exists
```

Cette tâche est exécutée seulement si le certificat existe déjà.

Les conditions sont très utiles pour gérer plusieurs états possibles :

```text
premier déploiement
renouvellement
redéploiement
certificat déjà existant
certificat absent
```

---

## 16. Register

`register` permet de stocker le résultat d’une tâche dans une variable.

Exemple :

```yaml
- name: Check Docker version
  ansible.builtin.command: docker --version
  register: docker_version
  changed_when: false
```

Puis on peut afficher le résultat :

```yaml
- name: Show Docker version
  ansible.builtin.debug:
    var: docker_version.stdout
```

Résultat :

```text
Docker version 29.6.1, build 8900f1d
```

`register` est utile pour :

* récupérer la sortie d’une commande ;
* utiliser le résultat dans une condition ;
* debugger ;
* afficher une information importante.

---

## 17. changed_when

Certaines commandes ne sont pas naturellement idempotentes.

Exemple :

```yaml
- name: Check Docker version
  ansible.builtin.command: docker --version
```

Ansible peut considérer cette commande comme `changed`, même si elle ne modifie rien.

On corrige avec :

```yaml
changed_when: false
```

Exemple :

```yaml
- name: Check Docker version
  ansible.builtin.command: docker --version
  register: docker_version
  changed_when: false
```

Pour une commande comme Docker Compose :

```yaml
- name: Start containers with Docker Compose
  ansible.builtin.command: docker compose up -d --build --remove-orphans
  args:
    chdir: "{{ project_dir }}"
  register: compose_up
  changed_when: >
    'Started' in compose_up.stdout or
    'Created' in compose_up.stdout or
    'Recreated' in compose_up.stdout or
    'Building' in compose_up.stdout
```

Cela permet d’indiquer à Ansible quand la tâche a réellement changé quelque chose.

---

## 18. Roles

Les rôles permettent d’organiser un projet Ansible proprement.

Au lieu d’avoir un seul gros playbook, on sépare les responsabilités.

Exemple :

```text
ansible/roles/
├── common/
├── docker/
├── firewall/
└── deploy/
```

### common

Rôle pour les tâches système de base :

* mise à jour du cache apt ;
* installation des paquets de base ;
* création du dossier projet ;
* création du dossier secrets.

### docker

Rôle pour installer Docker :

* suppression des vieux paquets Docker ;
* ajout de la clé GPG officielle ;
* ajout du dépôt Docker ;
* installation de Docker Engine ;
* installation du plugin Docker Compose ;
* activation du service Docker.

### firewall

Rôle pour sécuriser le VPS :

* installation UFW ;
* politique par défaut ;
* ouverture SSH ;
* ouverture HTTP ;
* ouverture HTTPS ;
* activation du firewall.

### deploy

Rôle pour déployer l’application :

* création des dossiers Certbot ;
* génération du `docker-compose.yml` ;
* copie des contextes Docker ;
* démarrage des conteneurs ;
* configuration Nginx ;
* gestion du certificat ;
* cron de renouvellement.

---

## 19. Structure recommandée pour Cloud-1

Structure propre :

```text
cloud_1/
├── ansible/
│   ├── group_vars/
│   │   └── cloud.yml
│   ├── inventory.ini
│   ├── playbook.yml
│   └── roles/
│       ├── common/
│       │   └── tasks/
│       │       └── main.yml
│       ├── docker/
│       │   └── tasks/
│       │       └── main.yml
│       ├── firewall/
│       │   └── tasks/
│       │       └── main.yml
│       └── deploy/
│           ├── tasks/
│           │   └── main.yml
│           └── templates/
│               ├── docker-compose.yml.j2
│               ├── nginx-http.conf.j2
│               └── nginx-https.conf.j2
├── docker/
│   ├── mariadb/
│   │   ├── Dockerfile
│   │   ├── conf/
│   │   └── tools/
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── conf/
│   │   └── tools/
│   └── wordpress/
│       ├── Dockerfile
│       ├── conf/
│       └── tools/
├── Makefile
└── README.md
```

Il faut éviter de mélanger :

```text
ansible/roles/docker
```

et :

```text
docker/nginx
docker/wordpress
docker/mariadb
```

Le premier est un rôle Ansible.
Le second contient les Dockerfiles de l’application.

---

## 20. Exemple de rôle common

```yaml
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600

- name: Install base packages
  ansible.builtin.apt:
    name:
      - curl
      - git
      - unzip
      - ca-certificates
      - gnupg
      - lsb-release
    state: present

- name: Create project directory
  ansible.builtin.file:
    path: "{{ project_dir }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Create secrets directory
  ansible.builtin.file:
    path: "{{ project_dir }}/secrets"
    state: directory
    owner: root
    group: root
    mode: "0700"
```

Ce rôle prépare le serveur.

---

## 21. Exemple de rôle deploy

```yaml
---
- name: Create project directory
  ansible.builtin.file:
    path: "{{ project_dir }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Create Certbot directories
  ansible.builtin.file:
    path: "{{ project_dir }}/certbot/{{ item }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
  loop:
    - www
    - conf

- name: Copy docker-compose.yml from template
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: "{{ project_dir }}/docker-compose.yml"
    owner: root
    group: root
    mode: "0644"

- name: Copy Docker build contexts
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../docker/"
    dest: "{{ project_dir }}/docker/"
    owner: root
    group: root
    mode: preserve

- name: Start containers with Docker Compose
  ansible.builtin.command: docker compose up -d --build --remove-orphans
  args:
    chdir: "{{ project_dir }}"
  register: compose_up
  changed_when: >
    'Started' in compose_up.stdout or
    'Created' in compose_up.stdout or
    'Recreated' in compose_up.stdout or
    'Building' in compose_up.stdout
```

Ce rôle déploie l’application sur le VPS.

---

## 22. Loops

Les boucles permettent d’éviter de répéter une tâche.

Exemple :

```yaml
- name: Create Certbot directories
  ansible.builtin.file:
    path: "{{ project_dir }}/certbot/{{ item }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
  loop:
    - www
    - conf
```

Ansible va créer :

```text
/opt/cloud-1/certbot/www
/opt/cloud-1/certbot/conf
```

`item` représente chaque élément de la boucle.

---

## 23. Handlers

Un handler est une tâche spéciale déclenchée seulement si une autre tâche a changé quelque chose.

Exemple :

```yaml
- name: Copy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx
```

Handler :

```yaml
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

Le handler `Restart nginx` ne s’exécute que si la configuration Nginx a changé.

Dans un projet Docker Compose, on peut aussi utiliser des handlers pour :

* redémarrer un conteneur ;
* recharger Nginx ;
* relancer Docker Compose.

---

## 24. Facts

Ansible récupère automatiquement des informations sur le serveur cible.

Exemples de facts :

```text
ansible_facts["distribution"]
ansible_facts["distribution_release"]
ansible_facts["architecture"]
ansible_facts["default_ipv4"]
```

Ces facts permettent d’adapter le playbook au système.

Exemple :

```yaml
Suites: {{ ansible_facts["distribution_release"] }}
```

Sur Ubuntu 22.04, cela peut donner :

```text
jammy
```

Les facts sont collectés au début du playbook pendant la tâche :

```text
Gathering Facts
```

---

## 25. Sécurité avec Ansible

Ansible peut manipuler des secrets.
Il faut donc être prudent.

Bonnes pratiques :

* ne pas mettre de mots de passe en clair dans Git ;
* utiliser Ansible Vault ;
* ajouter `no_log: true` sur les tâches sensibles ;
* limiter les ports ouverts ;
* ne pas exposer MariaDB publiquement ;
* utiliser des permissions restrictives ;
* ne pas commit de clé privée SSH ;
* ne pas commit de fichier `.vault_pass`.

Exemple avec `no_log` :

```yaml
- name: Create db password secret
  ansible.builtin.copy:
    content: "{{ mysql_password }}"
    dest: "{{ project_dir }}/secrets/db_password.txt"
    owner: root
    group: root
    mode: "0600"
  no_log: true
```

---

## 26. Ansible et Docker Compose

Dans Cloud-1, Ansible ne remplace pas Docker Compose.

Les rôles sont complémentaires :

```text
Ansible
  → prépare le serveur
  → installe Docker
  → génère les fichiers
  → lance Docker Compose

Docker Compose
  → construit les images
  → crée les réseaux
  → crée les volumes
  → lance les conteneurs
```

Ansible agit donc au-dessus de Docker Compose.

Commande typique dans Ansible :

```yaml
- name: Start containers with Docker Compose
  ansible.builtin.command: docker compose up -d --build --remove-orphans
  args:
    chdir: "{{ project_dir }}"
```

Le `chdir` est important.
Sans lui, Docker Compose cherche le fichier `docker-compose.yml` dans le mauvais dossier.

---

## 27. Debug Ansible

Commandes utiles :

### Tester la connexion

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

### Lancer le playbook

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### Mode verbose

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -v
```

Plus détaillé :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -vvv
```

### Voir l’inventory complet

```bash
ansible-inventory -i ansible/inventory.ini --list
```

### Limiter à une machine

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --limit cloud1
```

### Commencer à une tâche précise

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --start-at-task "Start containers with Docker Compose"
```

### Vérifier la syntaxe

```bash
ansible-playbook ansible/playbook.yml --syntax-check
```

---

## 28. Erreurs fréquentes

### Permission denied SSH

Erreur :

```text
Permission denied (publickey)
```

Causes possibles :

* mauvaise clé privée ;
* clé publique absente du serveur ;
* mauvais utilisateur SSH ;
* mauvais chemin dans l’inventory.

À vérifier :

```bash
ssh -i ~/.ssh/id_rsa root@51.159.155.247
```

### Inventory introuvable

Erreur :

```text
Unable to parse inventory
```

Cause fréquente :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

lancé depuis le mauvais dossier.

Solution :

```bash
cd ~/cloud_1
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### Variable undefined

Erreur :

```text
'wp_admin_user' is undefined
```

Cause :

* variable manquante dans `group_vars`.

Solution :

```yaml
wp_admin_user: "admin"
```

### Fichier local introuvable

Erreur :

```text
Could not find or access '/path/docker/' on the Ansible Controller
```

Cause :

* le chemin `src` de `copy` pointe vers un dossier qui n’existe pas localement.

Solution :

* vérifier l’architecture du repo ;
* corriger le chemin `src`.

### Docker Compose lancé au mauvais endroit

Erreur :

```text
no configuration file provided: not found
```

Cause :

* commande lancée hors du dossier contenant `docker-compose.yml`.

Solution :

```bash
cd /opt/cloud-1
docker compose up -d
```

ou dans Ansible :

```yaml
args:
  chdir: "{{ project_dir }}"
```

---

## 29. Bonnes pratiques de projet

Un projet Ansible propre doit :

* avoir une structure claire ;
* utiliser des rôles ;
* utiliser des variables ;
* éviter les valeurs codées en dur ;
* être relançable ;
* ne pas exposer de secrets ;
* documenter les commandes ;
* avoir un README clair ;
* utiliser un `.gitignore` propre ;
* séparer les rôles Ansible des Dockerfiles applicatifs ;
* afficher les informations utiles en fin de déploiement.

Exemple de `.gitignore` :

```gitignore
.venv/
.vault_pass
*.retry
__pycache__/
```

---

## 30. Commandes essentielles à retenir

Tester SSH via Ansible :

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

Lancer le déploiement :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Lancer avec Vault :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Voir les variables chargées :

```bash
ansible-inventory -i ansible/inventory.ini --list
```

Vérifier la syntaxe :

```bash
ansible-playbook ansible/playbook.yml --syntax-check
```

Lancer en verbose :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -vvv
```

---

## 31. Résumé mental

```text
Inventory  → quelles machines ?
Playbook   → quelles actions globales ?
Role       → quelle responsabilité ?
Task       → quelle action précise ?
Module     → quel outil Ansible ?
Variable   → quelle valeur dynamique ?
Template   → quel fichier généré ?
Handler    → quelle action déclenchée après changement ?
Facts      → quelles infos récupérées sur le serveur ?
Vault      → comment protéger les secrets ?
```

---

## 32. Résumé appliqué à Cloud-1

Dans Cloud-1, Ansible sert à automatiser tout le déploiement.

Le flux est :

```text
1. Connexion SSH au VPS
2. Installation des paquets de base
3. Installation de Docker
4. Configuration du firewall
5. Création du dossier /opt/cloud-1
6. Création des secrets
7. Copie des Dockerfiles
8. Génération du docker-compose.yml
9. Lancement des conteneurs
10. Configuration HTTPS
11. Ajout du renouvellement automatique
12. Vérification des conteneurs
```

Le résultat attendu est :

```text
cloud1_mariadb     cloud1_mariadb:local
cloud1_wordpress   cloud1_wordpress:local
cloud1_nginx       cloud1_nginx:local
```

Avec :

```text
MariaDB   → non exposé publiquement
WordPress → accessible seulement par Nginx
Nginx     → expose 80 et 443
```

Et le site accessible via :

```text
https://cloud-one-vnieto-j.duckdns.org
```

---

## 33. Conclusion

Ansible est un outil d’automatisation qui permet de rendre un déploiement propre, reproductible et maintenable.

Dans un projet comme Cloud-1, il permet de prouver que l’infrastructure n’a pas été configurée manuellement, mais déployée automatiquement à partir du code.

Un bon usage d’Ansible repose sur :

* une structure claire ;
* des rôles bien séparés ;
* des variables propres ;
* des templates ;
* des tâches idempotentes ;
* une bonne gestion des secrets ;
* une documentation précise.

La commande finale doit permettre de reconstruire l’infrastructure :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

ou avec Vault :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```
