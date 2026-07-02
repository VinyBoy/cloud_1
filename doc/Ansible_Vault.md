# Cours complet — Ansible Vault

## 1. Introduction

Ansible Vault est une fonctionnalité d’Ansible qui permet de chiffrer des données sensibles.

Dans un projet d’infrastructure, on manipule souvent des secrets :

* mots de passe de base de données ;
* mots de passe administrateur ;
* tokens API ;
* clés privées ;
* secrets applicatifs ;
* identifiants de services externes.

Sans protection, ces données peuvent se retrouver en clair dans le dépôt Git.

Ansible Vault permet d’éviter cela en chiffrant les fichiers ou variables sensibles.

---

## 2. Pourquoi utiliser Ansible Vault ?

Dans un projet comme Cloud-1, Ansible manipule des secrets pour déployer l’infrastructure.

Exemples :

```yaml
mysql_password: "change_me_wp_db_password"
mysql_root_password: "change_me_root_db_password"
wp_admin_password: "change_me_admin_password"
wp_user_password: "change_me_user_password"
```

Le problème est simple :

* ces valeurs sont visibles ;
* elles peuvent être commit sur GitHub ;
* elles peuvent être lues pendant une correction ;
* elles restent dans l’historique Git ;
* elles compromettent la sécurité du serveur.

Ansible Vault règle ce problème en chiffrant les valeurs sensibles.

---

## 3. Principe général

Ansible Vault chiffre un fichier avec un mot de passe.

Le fichier chiffré reste dans le projet, mais son contenu devient illisible.

Exemple de fichier chiffré :

```text
$ANSIBLE_VAULT;1.1;AES256
6638643965363630343438363562633066326238326431366639613437313932
6133663230303935626266613865336435336337396431323537343233346539
...
```

Sans le mot de passe Vault, il est impossible de lire les secrets.

Avec le mot de passe Vault, Ansible peut déchiffrer temporairement les valeurs pendant l’exécution du playbook.

---

## 4. Ce qu’Ansible Vault protège

Ansible Vault peut protéger :

* des fichiers YAML ;
* des fichiers de variables ;
* des fichiers dans `group_vars` ;
* des fichiers dans `host_vars` ;
* des fichiers utilisés par les rôles ;
* des variables isolées ;
* des secrets utilisés dans les templates ;
* des fichiers complets.

Dans Cloud-1, l’usage le plus propre est de chiffrer un fichier de variables :

```text
ansible/group_vars/cloud/vault.yml
```

---

## 5. Ce qu’Ansible Vault ne protège pas

Ansible Vault ne protège pas tout automatiquement.

Il ne protège pas :

* les secrets déjà copiés sur le VPS ;
* les secrets affichés dans les logs Ansible ;
* le fichier `.vault_pass` si tu l’ajoutes au projet ;
* les secrets déjà commit en clair dans l’historique Git ;
* les variables affichées par erreur avec `debug`;
* les secrets visibles dans des fichiers générés sur le serveur.

Vault protège principalement les secrets **dans ton dépôt local**.

Pour compléter la sécurité, il faut aussi :

* utiliser `no_log: true` ;
* protéger les fichiers secrets sur le VPS avec les bonnes permissions ;
* ne pas exposer les services sensibles ;
* éviter de commit le mot de passe Vault ;
* nettoyer l’historique Git si un secret a déjà été commit.

---

## 6. Différence entre Ansible Vault et Docker secrets

Dans Cloud-1, tu peux utiliser deux mécanismes complémentaires :

```text
Ansible Vault
  → protège les secrets dans le repo Ansible

Docker secrets
  → injecte les secrets dans les conteneurs via /run/secrets
```

Exemple de chaîne complète :

```text
vault.yml chiffré
  ↓
ansible-playbook --ask-vault-pass
  ↓
Ansible déchiffre les variables en mémoire
  ↓
Ansible crée des fichiers dans /opt/cloud-1/secrets/
  ↓
Docker Compose les monte comme secrets
  ↓
MariaDB / WordPress les lisent dans /run/secrets
```

Les deux sont utiles.

Ansible Vault protège la partie **code / dépôt Git**.
Docker secrets protège la partie **runtime / conteneurs**.

---

## 7. Structure recommandée

Au début, tu peux avoir un fichier unique :

```text
ansible/group_vars/cloud.yml
```

Mais pour Vault, une structure plus propre est :

```text
ansible/group_vars/cloud/
├── main.yml
└── vault.yml
```

Rôle de chaque fichier :

```text
main.yml   → variables non sensibles
vault.yml  → variables sensibles chiffrées
```

Exemple :

```text
ansible/
├── group_vars/
│   └── cloud/
│       ├── main.yml
│       └── vault.yml
├── inventory.ini
├── playbook.yml
└── roles/
```

---

## 8. Exemple de main.yml

Le fichier `main.yml` reste lisible.

Il contient les variables non sensibles et référence les secrets Vault.

```yaml
---
project_dir: /opt/cloud-1

domain_name: "cloud-one-vnieto-j.duckdns.org"
letsencrypt_email: "victornieto-juan@live.fr"

mysql_database: "wordpress"
mysql_user: "wp_user"
mysql_password: "{{ vault_mysql_password }}"
mysql_root_password: "{{ vault_mysql_root_password }}"

wp_title: "cloud_1"

wp_admin_user: "admin"
wp_admin_email: "victornieto-juan@live.fr"
wp_admin_password: "{{ vault_wp_admin_password }}"

wp_user: "victor"
wp_user_email: "victornieto-juan+wpuser@live.fr"
wp_user_password: "{{ vault_wp_user_password }}"

wordpress_db_host: "mariadb:3306"
```

Ici, les secrets ne sont pas écrits directement.

On utilise seulement des références :

```yaml
mysql_password: "{{ vault_mysql_password }}"
```

La vraie valeur sera dans `vault.yml`.

---

## 9. Exemple de vault.yml avant chiffrement

Le fichier `vault.yml` contient les vraies valeurs sensibles.

Avant chiffrement, il peut ressembler à ça :

```yaml
---
vault_mysql_password: "un_mot_de_passe_db_solide"
vault_mysql_root_password: "un_mot_de_passe_root_db_solide"

vault_wp_admin_password: "un_mot_de_passe_admin_wp_solide"
vault_wp_user_password: "un_mot_de_passe_user_wp_solide"
```

Ce fichier ne doit pas rester en clair.

Il doit être chiffré avec Ansible Vault.

---

## 10. Créer un fichier Vault

Commande :

```bash
ansible-vault create ansible/group_vars/cloud/vault.yml
```

Ansible demande un mot de passe Vault.

Ensuite, un éditeur s’ouvre.

Tu écris les variables sensibles :

```yaml
---
vault_mysql_password: "un_mot_de_passe_db_solide"
vault_mysql_root_password: "un_mot_de_passe_root_db_solide"

vault_wp_admin_password: "un_mot_de_passe_admin_wp_solide"
vault_wp_user_password: "un_mot_de_passe_user_wp_solide"
```

Quand tu sauvegardes, Ansible chiffre automatiquement le fichier.

---

## 11. Vérifier qu’un fichier est chiffré

Commande :

```bash
cat ansible/group_vars/cloud/vault.yml
```

Résultat attendu :

```text
$ANSIBLE_VAULT;1.1;AES256
6638643965363630343438363562633066326238326431366639613437313932
...
```

Si tu vois encore :

```yaml
vault_mysql_password: "..."
```

alors le fichier n’est pas chiffré.

---

## 12. Lire un fichier Vault

Pour lire un fichier chiffré :

```bash
ansible-vault view ansible/group_vars/cloud/vault.yml
```

Ansible demande le mot de passe Vault.

Si le mot de passe est correct, le contenu s’affiche.

Attention : ne fais pas cette commande pendant un partage d’écran ou dans un terminal visible publiquement.

---

## 13. Modifier un fichier Vault

Pour modifier un fichier Vault :

```bash
ansible-vault edit ansible/group_vars/cloud/vault.yml
```

Ansible :

* demande le mot de passe Vault ;
* déchiffre temporairement le fichier ;
* ouvre l’éditeur ;
* rechiffre le fichier à la sauvegarde.

C’est la méthode normale pour modifier les secrets.

---

## 14. Chiffrer un fichier existant

Si tu as déjà créé `vault.yml` en clair, tu peux le chiffrer avec :

```bash
ansible-vault encrypt ansible/group_vars/cloud/vault.yml
```

Après cette commande, le fichier devient illisible sans mot de passe Vault.

---

## 15. Déchiffrer un fichier

Commande :

```bash
ansible-vault decrypt ansible/group_vars/cloud/vault.yml
```

Attention : cette commande remet le fichier en clair.

Elle est utile pour debug, mais dangereuse avant un commit.

Après debug, il faut rechiffrer :

```bash
ansible-vault encrypt ansible/group_vars/cloud/vault.yml
```

---

## 16. Changer le mot de passe Vault

Pour changer le mot de passe d’un fichier Vault :

```bash
ansible-vault rekey ansible/group_vars/cloud/vault.yml
```

Ansible demande :

* l’ancien mot de passe ;
* le nouveau mot de passe.

C’est utile si :

* le mot de passe Vault a été partagé ;
* tu veux renforcer la sécurité ;
* tu veux faire une rotation des secrets.

---

## 17. Lancer un playbook avec Vault

Si le playbook utilise un fichier chiffré, il faut donner le mot de passe à Ansible.

Méthode interactive :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Ansible demande :

```text
Vault password:
```

Puis il exécute le playbook.

---

## 18. Utiliser un fichier de mot de passe Vault

Tu peux aussi utiliser un fichier local contenant le mot de passe Vault.

Exemple :

```bash
nano .vault_pass
```

Contenu :

```text
mon_mot_de_passe_vault
```

Puis :

```bash
chmod 600 .vault_pass
```

Lancer le playbook :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --vault-password-file .vault_pass
```

Avantage :

* pratique ;
* pas besoin de retaper le mot de passe.

Inconvénient :

* dangereux si le fichier est commit ;
* dangereux si les permissions sont mauvaises ;
* moins adapté à un rendu étudiant public.

Pour Cloud-1, la méthode la plus propre reste :

```bash
--ask-vault-pass
```

---

## 19. Sécuriser .vault_pass

Si tu utilises `.vault_pass`, il doit être protégé.

Permission recommandée :

```bash
chmod 600 .vault_pass
```

Cela signifie :

```text
propriétaire : lecture + écriture
groupe       : aucun droit
autres       : aucun droit
```

Vérification :

```bash
ls -la .vault_pass
```

Résultat attendu :

```text
-rw------- 1 user user ... .vault_pass
```

---

## 20. .gitignore recommandé

Le fichier Vault chiffré peut être commit.

Le mot de passe Vault ne doit jamais être commit.

Exemple de `.gitignore` :

```gitignore
.venv/
.vault_pass
*vault-password*
*.retry
__pycache__/
```

À retenir :

```text
vault.yml chiffré  → peut être commit
.vault_pass        → ne doit jamais être commit
```

---

## 21. Utiliser no_log avec les secrets

Même si les secrets sont chiffrés dans le repo, Ansible peut les manipuler pendant l’exécution.

Exemple :

```yaml
- name: Create db password secret
  ansible.builtin.copy:
    content: "{{ mysql_password }}"
    dest: "{{ project_dir }}/secrets/db_password.txt"
    owner: root
    group: root
    mode: "0600"
```

Cette tâche utilise un secret.

Il faut ajouter :

```yaml
no_log: true
```

Version correcte :

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

Cela évite qu’Ansible affiche des informations sensibles dans les logs.

---

## 22. Exemple complet pour les secrets Cloud-1

Dans le rôle `common`, tu peux avoir :

```yaml
- name: Create secrets directory
  ansible.builtin.file:
    path: "{{ project_dir }}/secrets"
    state: directory
    owner: root
    group: root
    mode: "0700"

- name: Create db root password secret
  ansible.builtin.copy:
    content: "{{ mysql_root_password }}"
    dest: "{{ project_dir }}/secrets/db_root_password.txt"
    owner: root
    group: root
    mode: "0600"
  no_log: true

- name: Create db password secret
  ansible.builtin.copy:
    content: "{{ mysql_password }}"
    dest: "{{ project_dir }}/secrets/db_password.txt"
    owner: root
    group: root
    mode: "0600"
  no_log: true

- name: Create WordPress admin password secret
  ansible.builtin.copy:
    content: "{{ wp_admin_password }}"
    dest: "{{ project_dir }}/secrets/wp_admin_password.txt"
    owner: root
    group: root
    mode: "0600"
  no_log: true

- name: Create WordPress user password secret
  ansible.builtin.copy:
    content: "{{ wp_user_password }}"
    dest: "{{ project_dir }}/secrets/wp_user_password.txt"
    owner: root
    group: root
    mode: "0600"
  no_log: true
```

Ici :

* les secrets sont stockés chiffrés dans `vault.yml` ;
* Ansible les déchiffre pendant le playbook ;
* Ansible crée des fichiers secrets sur le VPS ;
* Docker Compose les injecte ensuite dans les conteneurs.

---

## 23. Exemple avec Docker Compose secrets

Dans `docker-compose.yml.j2` :

```yaml
services:
  mariadb:
    secrets:
      - db_root_password
      - db_password

  wordpress:
    secrets:
      - db_password
      - wp_admin_password
      - wp_user_password

secrets:
  db_root_password:
    file: ./secrets/db_root_password.txt

  db_password:
    file: ./secrets/db_password.txt

  wp_admin_password:
    file: ./secrets/wp_admin_password.txt

  wp_user_password:
    file: ./secrets/wp_user_password.txt
```

Dans les conteneurs, ces secrets deviennent accessibles ici :

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

Exemple dans un entrypoint :

```bash
DB_PWD="$(cat /run/secrets/db_password)"
```

---

## 24. Workflow complet avec Ansible Vault

Flux complet :

```text
1. Créer main.yml avec les variables non sensibles
2. Créer vault.yml avec les variables sensibles
3. Chiffrer vault.yml
4. Référencer les variables Vault dans main.yml
5. Ajouter no_log: true aux tâches sensibles
6. Lancer le playbook avec --ask-vault-pass
7. Vérifier que les secrets sont créés sur le VPS
8. Vérifier que Docker Compose les monte correctement
```

Commande finale :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

---

## 25. Transformation de group_vars/cloud.yml vers Vault

Situation initiale :

```text
ansible/group_vars/cloud.yml
```

Transformation recommandée :

```bash
mkdir -p ansible/group_vars/cloud
mv ansible/group_vars/cloud.yml ansible/group_vars/cloud/main.yml
```

Puis créer :

```bash
ansible-vault create ansible/group_vars/cloud/vault.yml
```

Résultat final :

```text
ansible/group_vars/cloud/
├── main.yml
└── vault.yml
```

---

## 26. Exemple final de main.yml

```yaml
---
project_dir: /opt/cloud-1

domain_name: "cloud-one-vnieto-j.duckdns.org"
letsencrypt_email: "victornieto-juan@live.fr"

mysql_database: "wordpress"
mysql_user: "wp_user"

mysql_password: "{{ vault_mysql_password }}"
mysql_root_password: "{{ vault_mysql_root_password }}"

wp_title: "cloud_1"

wp_admin_user: "admin"
wp_admin_email: "victornieto-juan@live.fr"
wp_admin_password: "{{ vault_wp_admin_password }}"

wp_user: "victor"
wp_user_email: "victornieto-juan+wpuser@live.fr"
wp_user_password: "{{ vault_wp_user_password }}"

wordpress_db_host: "mariadb:3306"
```

Ce fichier peut être lu publiquement.

Il ne contient pas les vraies valeurs sensibles.

---

## 27. Exemple final de vault.yml

Avant chiffrement :

```yaml
---
vault_mysql_password: "db_password_tres_solide"
vault_mysql_root_password: "root_db_password_tres_solide"

vault_wp_admin_password: "admin_wp_password_tres_solide"
vault_wp_user_password: "user_wp_password_tres_solide"
```

Après chiffrement :

```text
$ANSIBLE_VAULT;1.1;AES256
6331386138313734323333366265316235653766343134303936393533343130
6630633863366432393533336437346236383936383731313733396437356531
...
```

---

## 28. Vérifier que les variables sont chargées

Commande :

```bash
ansible-inventory -i ansible/inventory.ini --list --ask-vault-pass
```

Cette commande affiche l’inventory complet avec les variables.

Attention : elle peut afficher des secrets déchiffrés dans le terminal.

À utiliser seulement pour debug.

---

## 29. Erreur fréquente : oubli de --ask-vault-pass

Erreur possible :

```text
Attempting to decrypt but no vault secrets found
```

ou :

```text
Decryption failed
```

Cause :

* tu as un fichier Vault ;
* mais tu n’as pas donné le mot de passe à Ansible.

Solution :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

---

## 30. Erreur fréquente : mauvais mot de passe Vault

Erreur :

```text
Decryption failed
```

Cause :

* le mot de passe entré n’est pas le bon.

Solution :

* vérifier le mot de passe ;
* utiliser `ansible-vault view` pour tester ;
* si nécessaire, recréer le fichier Vault.

---

## 31. Erreur fréquente : variable Vault undefined

Erreur :

```text
'vault_mysql_password' is undefined
```

Causes possibles :

* le fichier `vault.yml` n’est pas au bon endroit ;
* le nom de variable est mal écrit ;
* le groupe `cloud` ne correspond pas au dossier `group_vars/cloud/`;
* le fichier n’est pas chargé automatiquement.

Vérifications :

```bash
tree ansible/group_vars
```

Structure attendue :

```text
ansible/group_vars/
└── cloud/
    ├── main.yml
    └── vault.yml
```

L’inventory doit contenir :

```ini
[cloud]
cloud1 ansible_host=51.159.155.247 ansible_user=root
```

Le nom du dossier `cloud` doit correspondre au nom du groupe `[cloud]`.

---

## 32. Erreur fréquente : secrets affichés dans les logs

Même avec Vault, si une tâche manipule un secret sans `no_log`, certains détails peuvent être visibles.

Mauvaise pratique :

```yaml
- name: Debug password
  ansible.builtin.debug:
    var: mysql_password
```

À éviter absolument.

Bonne pratique :

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

## 33. Erreur fréquente : .vault_pass commit

Erreur grave :

```text
.vault_pass présent dans GitHub
```

Conséquences :

* le chiffrement Vault ne sert plus à rien ;
* toute personne avec le repo peut déchiffrer les secrets.

Solution :

```bash
echo ".vault_pass" >> .gitignore
git rm --cached .vault_pass
```

Puis changer le mot de passe Vault :

```bash
ansible-vault rekey ansible/group_vars/cloud/vault.yml
```

Et changer les secrets compromis.

---

## 34. Vault et Git

Le fichier Vault chiffré peut être versionné :

```text
ansible/group_vars/cloud/vault.yml
```

Mais il faut vérifier son contenu avant commit :

```bash
head ansible/group_vars/cloud/vault.yml
```

Résultat attendu :

```text
$ANSIBLE_VAULT;1.1;AES256
```

Si le fichier commence par :

```yaml
vault_mysql_password:
```

il n’est pas chiffré.

---

## 35. Vault et historique Git

Si un secret a déjà été commit en clair, le supprimer du fichier ne suffit pas.

Il reste dans l’historique Git.

Dans un projet sérieux, il faut :

* changer le secret concerné ;
* nettoyer l’historique Git si nécessaire ;
* éviter de réutiliser ce mot de passe ;
* considérer le secret comme compromis.

Pour Cloud-1, si tu as déjà commit des `change_me`, ce n’est pas dramatique si ce ne sont pas de vrais secrets.

Mais si tu as commit de vrais mots de passe, il faut les changer.

---

## 36. Convention de nommage

Bonne convention :

```yaml
mysql_password: "{{ vault_mysql_password }}"
```

Pourquoi ?

* `mysql_password` est la variable utilisée par le projet ;
* `vault_mysql_password` est la vraie valeur sensible ;
* on comprend immédiatement que la variable vient de Vault.

Exemples :

```yaml
mysql_root_password: "{{ vault_mysql_root_password }}"
wp_admin_password: "{{ vault_wp_admin_password }}"
wp_user_password: "{{ vault_wp_user_password }}"
```

---

## 37. Vault IDs

Ansible permet aussi d’utiliser plusieurs Vault IDs.

Exemple :

```bash
ansible-playbook playbook.yml --vault-id dev@prompt
```

Ou :

```bash
ansible-playbook playbook.yml --vault-id prod@prompt
```

Cette approche est utile quand on a plusieurs environnements :

```text
dev
staging
production
```

Pour Cloud-1, ce n’est pas nécessaire.

Un seul fichier Vault et un seul mot de passe suffisent.

---

## 38. ansible.cfg et Vault

Il est possible de configurer Ansible pour utiliser automatiquement un fichier de mot de passe.

Exemple dans `ansible.cfg` :

```ini
[defaults]
vault_password_file = .vault_pass
```

Avantage :

* plus besoin d’écrire `--vault-password-file`.

Inconvénient :

* si `.vault_pass` est mal protégé, c’est dangereux ;
* si le projet est public, il faut être très strict avec `.gitignore`.

Pour Cloud-1, mieux vaut documenter :

```bash
--ask-vault-pass
```

---

## 39. Commandes essentielles

Créer un fichier Vault :

```bash
ansible-vault create ansible/group_vars/cloud/vault.yml
```

Voir un fichier Vault :

```bash
ansible-vault view ansible/group_vars/cloud/vault.yml
```

Modifier un fichier Vault :

```bash
ansible-vault edit ansible/group_vars/cloud/vault.yml
```

Chiffrer un fichier existant :

```bash
ansible-vault encrypt ansible/group_vars/cloud/vault.yml
```

Déchiffrer un fichier :

```bash
ansible-vault decrypt ansible/group_vars/cloud/vault.yml
```

Changer le mot de passe Vault :

```bash
ansible-vault rekey ansible/group_vars/cloud/vault.yml
```

Lancer le playbook avec demande de mot de passe :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Lancer le playbook avec fichier de mot de passe :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --vault-password-file .vault_pass
```

---

## 40. Exemple complet appliqué à Cloud-1

Structure :

```text
cloud_1/
├── ansible/
│   ├── group_vars/
│   │   └── cloud/
│   │       ├── main.yml
│   │       └── vault.yml
│   ├── inventory.ini
│   ├── playbook.yml
│   └── roles/
├── docker/
├── Makefile
└── README.md
```

Commande de création :

```bash
mkdir -p ansible/group_vars/cloud
mv ansible/group_vars/cloud.yml ansible/group_vars/cloud/main.yml
ansible-vault create ansible/group_vars/cloud/vault.yml
```

Commande de déploiement :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Commande de vérification :

```bash
ssh root@51.159.155.247
cd /opt/cloud-1
docker compose ps
```

Résultat attendu :

```text
cloud1_mariadb     cloud1_mariadb:local
cloud1_wordpress   cloud1_wordpress:local
cloud1_nginx       cloud1_nginx:local
```

---

## 41. Exemple de documentation README

````md
## Gestion des secrets avec Ansible Vault

Le projet utilise Ansible Vault pour protéger les secrets.

Les variables non sensibles sont dans :

```text
ansible/group_vars/cloud/main.yml
````

Les variables sensibles sont dans :

```text
ansible/group_vars/cloud/vault.yml
```

Pour lancer le déploiement :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Pour modifier les secrets :

```bash
ansible-vault edit ansible/group_vars/cloud/vault.yml
```

Le fichier `.vault_pass` ne doit jamais être commit.

````

---

## 42. Bonnes pratiques

- Ne jamais commit un mot de passe en clair.
- Ne jamais commit `.vault_pass`.
- Garder `vault.yml` chiffré.
- Vérifier que `vault.yml` commence par `$ANSIBLE_VAULT`.
- Ajouter `no_log: true` aux tâches sensibles.
- Ne pas utiliser `debug` sur des variables sensibles.
- Séparer les variables sensibles et non sensibles.
- Utiliser un préfixe `vault_` pour les vraies valeurs sensibles.
- Changer les secrets s’ils ont déjà été commit.
- Documenter l’usage de Vault dans le README.
- Utiliser des mots de passe forts.
- Garder le mot de passe Vault hors du repo.

---

## 43. Résumé mental

```text
main.yml
  → configuration lisible
  → pas de secrets en clair

vault.yml
  → secrets réels
  → fichier chiffré

ansible-vault
  → commande pour créer, lire, éditer, chiffrer

--ask-vault-pass
  → demande le mot de passe au lancement

.vault_pass
  → pratique mais dangereux si commit

no_log: true
  → évite d’afficher les secrets dans les logs
````

---

## 44. Résumé appliqué à Cloud-1

Pour Cloud-1, Ansible Vault doit protéger :

```text
mot de passe root MariaDB
mot de passe utilisateur MariaDB
mot de passe admin WordPress
mot de passe utilisateur WordPress
```

Le flux propre est :

```text
1. Les secrets sont écrits dans vault.yml
2. vault.yml est chiffré
3. main.yml référence les variables Vault
4. Ansible déchiffre au lancement
5. Ansible crée les fichiers secrets sur le VPS
6. Docker Compose monte les secrets dans /run/secrets
7. Les conteneurs lisent les secrets au démarrage
```

Commande finale :

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

---

## 45. Conclusion

Ansible Vault est indispensable dès qu’un projet Ansible manipule des secrets.

Il permet de garder un projet versionnable sans exposer les mots de passe.

Dans Cloud-1, Vault rend le déploiement plus propre, plus sécurisé et plus défendable à l’évaluation.

Un bon projet doit montrer que :

* les secrets ne sont pas en clair ;
* les variables sont bien séparées ;
* le playbook reste automatisé ;
* le déploiement fonctionne avec Vault ;
* les secrets sont injectés proprement dans les conteneurs.

Ansible Vault ne rend pas tout automatiquement sécurisé, mais il constitue la base correcte pour gérer les secrets dans un projet d’automatisation.
