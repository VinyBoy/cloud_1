# Cloud-1 — Automated Deployment of Inception

## 1. Overview

Cloud-1 is a 42 project focused on the automated deployment of an Inception-like infrastructure on a remote cloud server.

The goal of this project is to deploy a complete web stack on a VPS using automation.
The deployment is handled by **Ansible**, and the application stack is executed with **Docker Compose**.

The infrastructure deployed by this project includes:

* a remote VPS hosted on Scaleway;
* a custom Docker-based web stack;
* one container per process;
* a WordPress application served through Nginx;
* a MariaDB database;
* HTTPS access using Let’s Encrypt;
* firewall configuration with UFW;
* persistent Docker volumes;
* secrets management with Ansible Vault and Docker secrets.

The deployed website is available at:

```text
https://cloud-one-vnieto-j.duckdns.org
```

---

## 2. Project Goals

The main goals of the project are:

* deploy an application on a cloud provider;
* automate the full server setup;
* avoid manual configuration on the remote server;
* run each process in its own container;
* use custom Docker images;
* configure a public domain name;
* serve the application through HTTPS;
* protect sensitive data;
* ensure data persistence;
* provide a reproducible deployment.

The server can be redeployed using a single Ansible command.

---

## 3. Infrastructure Summary

```text
User
  |
  | HTTPS / HTTP
  v
Nginx container
  |
  | FastCGI :9000
  v
WordPress PHP-FPM container
  |
  | TCP :3306
  v
MariaDB container
```

Only the Nginx container is publicly exposed.

MariaDB and WordPress are only accessible inside the Docker network.

---

## 4. Cloud Provider

The project is deployed on a Scaleway VPS.

```text
Provider: Scaleway
OS: Ubuntu 22.04 LTS
Public IP: 51.159.155.247
Domain: cloud-one-vnieto-j.duckdns.org
```

The domain is managed through DuckDNS and points to the VPS public IP.

---

## 5. Services

### Nginx

Nginx is the public entrypoint of the infrastructure.

Responsibilities:

* expose ports `80` and `443`;
* redirect HTTP traffic to HTTPS;
* serve WordPress through PHP-FPM;
* handle TLS certificates;
* serve Certbot challenge files for Let’s Encrypt renewal.

Public ports:

```text
80  -> HTTP
443 -> HTTPS
```

### WordPress

WordPress runs in a dedicated PHP-FPM container.

Responsibilities:

* host the WordPress application;
* connect to MariaDB;
* initialize WordPress during first boot;
* create the admin user;
* create a secondary WordPress user;
* expose PHP-FPM internally on port `9000`.

The WordPress container is not exposed publicly.

### MariaDB

MariaDB runs in its own dedicated container.

Responsibilities:

* store WordPress data;
* store posts, users, comments and settings;
* persist data using a Docker volume.

The MariaDB port is not exposed publicly.

Expected behavior:

```text
3306/tcp
```

There must not be:

```text
0.0.0.0:3306->3306/tcp
```

---

## 6. Docker Images

The project uses custom local Docker images:

```text
cloud1_nginx:local
cloud1_wordpress:local
cloud1_mariadb:local
```

Expected running containers:

```text
cloud1_nginx
cloud1_wordpress
cloud1_mariadb
```

The project does not simply run official images directly.
The Dockerfiles are adapted from the Inception project and integrated into an automated cloud deployment with Ansible, HTTPS, firewall rules, secrets and persistence.

---

## 7. Repository Structure

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
│               ├── .env.j2
│               ├── nginx-http.conf.j2
│               └── nginx-https.conf.j2
├── docker/
│   ├── mariadb/
│   │   ├── Dockerfile
│   │   ├── conf/
│   │   │   └── 50-server.cnf
│   │   └── tools/
│   │       └── entrypoint.sh
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── conf/
│   │   │   └── nginx.conf
│   │   └── tools/
│   │       └── entrypoint.sh
│   └── wordpress/
│       ├── Dockerfile
│       ├── conf/
│       │   └── www.conf
│       └── tools/
│           └── entrypoint.sh
├── Makefile
├── README.md
└── .gitignore
```

---

## 8. Ansible Roles

The deployment is split into four Ansible roles.

### common

The `common` role prepares the base system.

It handles:

* apt cache update;
* installation of basic packages;
* creation of the project directory;
* creation of the secrets directory;
* creation of Docker secret files on the VPS.

### docker

The `docker` role installs Docker and Docker Compose.

It handles:

* removing conflicting Docker packages;
* adding Docker official GPG key;
* adding Docker apt repository;
* installing Docker Engine;
* installing the Docker Compose plugin;
* enabling and starting Docker service;
* checking Docker and Compose versions.

### firewall

The `firewall` role configures UFW.

It handles:

* installing UFW;
* denying incoming traffic by default;
* allowing outgoing traffic;
* allowing SSH;
* allowing HTTP;
* allowing HTTPS;
* enabling the firewall.

Allowed ports:

```text
22/tcp
80/tcp
443/tcp
```

### deploy

The `deploy` role deploys the application.

It handles:

* creating the project directory;
* creating Certbot directories;
* generating `docker-compose.yml`;
* generating `.env`;
* copying Docker build contexts;
* checking if the Let’s Encrypt certificate already exists;
* using a temporary HTTP config when needed;
* using HTTPS config when the certificate exists;
* starting containers with Docker Compose;
* creating the initial certificate when needed;
* restarting Nginx after configuration update;
* adding a cron job for certificate renewal;
* checking running containers.

---

## 9. Ansible Inventory

The inventory defines the target VPS.

Example:

```ini
[cloud]
cloud1 ansible_host=51.159.155.247 ansible_user=root ansible_ssh_private_key_file=/home/vnieto-j/.ssh/id_rsa
```

Test the connection:

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

Expected result:

```text
cloud1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

## 10. Variables

Non-sensitive variables are stored in:

```text
ansible/group_vars/cloud/main.yml
```

Example:

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

Sensitive values are not stored directly in this file.
They are referenced through Vault variables.

---

## 11. Secrets Management

Secrets are managed with two layers:

```text
Ansible Vault
  -> protects secrets in the repository

Docker secrets
  -> injects secrets into containers through /run/secrets
```

Sensitive values are stored in:

```text
ansible/group_vars/cloud/vault.yml
```

This file is encrypted with Ansible Vault.

Example before encryption:

```yaml
---
vault_mysql_password: "change_me_wp_db_password"
vault_mysql_root_password: "change_me_root_db_password"

vault_wp_admin_password: "change_me_admin_password"
vault_wp_user_password: "change_me_user_password"
```

After encryption, the file must look like:

```text
$ANSIBLE_VAULT;1.1;AES256
6638643965363630343438363562633066326238326431366639613437313932
...
```

The Vault password must never be committed.

---

## 12. Ansible Vault Commands

Create a Vault file:

```bash
ansible-vault create ansible/group_vars/cloud/vault.yml
```

View a Vault file:

```bash
ansible-vault view ansible/group_vars/cloud/vault.yml
```

Edit a Vault file:

```bash
ansible-vault edit ansible/group_vars/cloud/vault.yml
```

Encrypt an existing file:

```bash
ansible-vault encrypt ansible/group_vars/cloud/vault.yml
```

Change the Vault password:

```bash
ansible-vault rekey ansible/group_vars/cloud/vault.yml
```

Run the playbook with Vault:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

---

## 13. Docker Secrets

Ansible creates secret files on the VPS:

```text
/opt/cloud-1/secrets/db_root_password.txt
/opt/cloud-1/secrets/db_password.txt
/opt/cloud-1/secrets/wp_admin_password.txt
/opt/cloud-1/secrets/wp_user_password.txt
```

These files are used by Docker Compose as secrets.

Inside containers, they are available at:

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

The containers read these values at startup.

Example:

```bash
DB_PWD="$(cat /run/secrets/db_password)"
```

The secrets directory is protected with restrictive permissions:

```text
/opt/cloud-1/secrets -> 0700
secret files          -> 0600
```

---

## 14. HTTPS and Let’s Encrypt

The project uses Let’s Encrypt certificates.

Certificate files are stored on the VPS in:

```text
/opt/cloud-1/certbot/conf/
```

The HTTP challenge directory is:

```text
/opt/cloud-1/certbot/www/
```

The Nginx container exposes ports `80` and `443`.

HTTP traffic is redirected to HTTPS.

Expected behavior:

```bash
curl -I http://cloud-one-vnieto-j.duckdns.org
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://cloud-one-vnieto-j.duckdns.org/
```

HTTPS test:

```bash
curl -I https://cloud-one-vnieto-j.duckdns.org
```

Expected result:

```text
HTTP/2 200
server: nginx
content-type: text/html; charset=UTF-8
```

---

## 15. Certificate Renewal

A cron job is installed by Ansible for automatic certificate renewal.

The cron job runs every day at 03:00.

It executes Certbot renewal and reloads Nginx.

Example Ansible task:

```yaml
- name: Add cron job for Let's Encrypt renewal
  ansible.builtin.cron:
    name: "Renew Cloud-1 Let's Encrypt certificate"
    minute: "0"
    hour: "3"
    job: "cd {{ project_dir }} && docker run --rm -v {{ project_dir }}/certbot/www:/var/www/certbot -v {{ project_dir }}/certbot/conf:/etc/letsencrypt certbot/certbot renew --quiet && docker compose exec -T nginx nginx -s reload"
```

---

## 16. Deployment

### 16.1 Install Ansible locally

This project uses a Python virtual environment.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install ansible-core
```

### 16.2 Test SSH through Ansible

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

### 16.3 Run the full deployment

Without Vault:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

With Vault:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

The expected final recap must show:

```text
failed=0
unreachable=0
```

---

## 17. Expected Deployment Result

At the end of the deployment, Ansible prints the running containers.

Expected result:

```text
NAME               IMAGE                    SERVICE
cloud1_mariadb     cloud1_mariadb:local     mariadb
cloud1_nginx       cloud1_nginx:local       nginx
cloud1_wordpress   cloud1_wordpress:local   wordpress
```

Expected ports:

```text
cloud1_nginx       0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
cloud1_wordpress   9000/tcp
cloud1_mariadb     3306/tcp
```

MariaDB and WordPress are not publicly exposed.

---

## 18. Manual Verification on the VPS

Connect to the VPS:

```bash
ssh root@51.159.155.247
```

Go to the project directory:

```bash
cd /opt/cloud-1
```

Check running containers:

```bash
docker compose ps
```

Check logs:

```bash
docker compose logs nginx --tail=80
docker compose logs wordpress --tail=80
docker compose logs mariadb --tail=80
```

Check custom images:

```bash
docker image ls | grep cloud1
```

Expected images:

```text
cloud1_nginx
cloud1_wordpress
cloud1_mariadb
```

---

## 19. Public Access Tests

Test DNS:

```bash
dig cloud-one-vnieto-j.duckdns.org A
```

Expected result:

```text
cloud-one-vnieto-j.duckdns.org. A 51.159.155.247
```

Test HTTP redirect:

```bash
curl -I http://cloud-one-vnieto-j.duckdns.org
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://cloud-one-vnieto-j.duckdns.org/
```

Test HTTPS:

```bash
curl -I https://cloud-one-vnieto-j.duckdns.org
```

Expected result:

```text
HTTP/2 200
server: nginx
```

---

## 20. Persistence

The project uses Docker volumes to persist data.

Volumes:

```yaml
volumes:
  mariadb_data:
  wordpress_data:
```

MariaDB data is stored in:

```text
mariadb_data
```

WordPress files are stored in:

```text
wordpress_data
```

WordPress comments, posts and users are stored in the MariaDB database.
Therefore, comments must persist after container restart or recreation as long as volumes are not deleted.

---

## 21. Persistence Test — WordPress Comment

### 21.1 Create a comment

Go to:

```text
https://cloud-one-vnieto-j.duckdns.org
```

Create or open a WordPress post.

Add a comment:

```text
Commentaire de test persistance Cloud-1.
```

Approve the comment if needed from the WordPress admin panel.

### 21.2 Check the comment in MariaDB

On the VPS:

```bash
cd /opt/cloud-1
DB_PWD=$(cat /opt/cloud-1/secrets/db_password.txt)
docker compose exec mariadb mariadb -u wp_user -p"$DB_PWD" wordpress \
-e "SELECT comment_ID, comment_author, comment_content FROM wp_comments ORDER BY comment_ID DESC LIMIT 5;"
```

The comment must appear in the result.

### 21.3 Restart containers

```bash
cd /opt/cloud-1
docker compose restart
```

Check again:

```bash
DB_PWD=$(cat /opt/cloud-1/secrets/db_password.txt)
docker compose exec mariadb mariadb -u wp_user -p"$DB_PWD" wordpress \
-e "SELECT comment_ID, comment_author, comment_content FROM wp_comments ORDER BY comment_ID DESC LIMIT 5;"
```

The comment must still be present.

### 21.4 Recreate containers without deleting volumes

```bash
cd /opt/cloud-1
docker compose down
docker compose up -d
```

Check again:

```bash
DB_PWD=$(cat /opt/cloud-1/secrets/db_password.txt)
docker compose exec mariadb mariadb -u wp_user -p"$DB_PWD" wordpress \
-e "SELECT comment_ID, comment_author, comment_content FROM wp_comments ORDER BY comment_ID DESC LIMIT 5;"
```

The comment must still be present.

### 21.5 Important warning

Do not use:

```bash
docker compose down -v
```

The `-v` option deletes Docker volumes.

This would remove:

```text
mariadb_data
wordpress_data
```

and therefore delete the WordPress database and comments.

---

## 22. Firewall Verification

Check UFW status:

```bash
ufw status verbose
```

Expected result:

```text
Status: active
Default: deny (incoming), allow (outgoing), deny (routed)

22/tcp  ALLOW IN
80/tcp  ALLOW IN
443/tcp ALLOW IN
```

Only SSH, HTTP and HTTPS should be publicly accessible.

---

## 23. Security Notes

This project applies several security principles:

* no public exposure of MariaDB;
* firewall enabled with restrictive defaults;
* HTTPS enabled;
* automatic certificate renewal;
* secrets not stored directly in readable variables;
* Ansible Vault used for sensitive values;
* Docker secrets used inside containers;
* restrictive permissions on secret files;
* custom containers isolated in a Docker network.

Sensitive Ansible tasks should use:

```yaml
no_log: true
```

Example:

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

## 24. Useful Commands

### Run deployment

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

``` bash
source .venv/bin/activate
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

### Test Ansible connection

```bash
ansible -i ansible/inventory.ini cloud -m ping
```

### Check syntax

```bash
ansible-playbook ansible/playbook.yml --syntax-check
```

### Check inventory

```bash
ansible-inventory -i ansible/inventory.ini --list --ask-vault-pass
```

### Check containers

```bash
ssh root@51.159.155.247
cd /opt/cloud-1
docker compose ps
```

### Check logs

```bash
docker compose logs --tail=100
```

### Restart stack

```bash
cd /opt/cloud-1
docker compose restart
```

### Stop stack without deleting data

```bash
cd /opt/cloud-1
docker compose down
```

### Start stack

```bash
cd /opt/cloud-1
docker compose up -d
```

### Rebuild custom images

```bash
cd /opt/cloud-1
docker compose build --no-cache
docker compose up -d
```

### delete project and stop docker

```bash
cd /opt/cloud-1
docker compose down -v --remove-orphans
docker image rm -f cloud1_nginx:local cloud1_wordpress:local cloud1_mariadb:local
docker ps -a
rm -rf /opt/cloud-1
```
---

## 25. Troubleshooting

### no configuration file provided

Error:

```text
no configuration file provided: not found
```

Cause:

Docker Compose was launched outside `/opt/cloud-1`.

Fix:

```bash
cd /opt/cloud-1
docker compose ps
```

or:

```bash
docker compose -f /opt/cloud-1/docker-compose.yml ps
```

### 502 Bad Gateway

Possible causes:

* WordPress PHP-FPM is not running;
* MariaDB is not ready;
* Nginx cannot reach `wordpress:9000`;
* WordPress container is restarting.

Check logs:

```bash
cd /opt/cloud-1
docker compose logs wordpress --tail=100
docker compose logs mariadb --tail=100
docker compose logs nginx --tail=100
```

Check containers:

```bash
docker compose ps
```

### MariaDB permission error

Error:

```text
Can't create/write to file './ddl_recovery.log'
Permission denied
```

Cause:

The MariaDB data directory has incorrect ownership.

Fix in the MariaDB entrypoint:

```bash
mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql
chmod 750 /var/lib/mysql
cd /var/lib/mysql
```

### WordPress email already used

Error:

```text
Error: Sorry, that email address is already used!
```

Cause:

The WordPress admin and WordPress user use the same email.

Fix:

```yaml
wp_admin_email: "victornieto-juan@live.fr"
wp_user_email: "victornieto-juan+wpuser@live.fr"
```

### DNS issue

Test DNS:

```bash
dig cloud-one-vnieto-j.duckdns.org A
```

Expected result:

```text
51.159.155.247
```

If the browser fails but `dig` works, clear the browser DNS cache or disable DNS over HTTPS temporarily.

---

## 26. Compliance With the Subject

This project satisfies the main expectations of Cloud-1:

* deployment on a remote cloud server;
* automated deployment using Ansible;
* Docker infrastructure deployed remotely;
* one container per process;
* custom images for the stack;
* domain name configured;
* HTTPS enabled;
* firewall configured;
* database not publicly exposed;
* persistent volumes used;
* secrets handled securely;
* deployment can be reproduced by running the playbook.

The goal is not to manually configure the server, but to automate the full deployment process.

---

## 27. Final Deployment Command

The final deployment command is:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass
```

Expected final result:

```text
PLAY RECAP
cloud1 : failed=0 unreachable=0
```

Expected public endpoint:

```text
https://cloud-one-vnieto-j.duckdns.org
```

Expected containers:

```text
cloud1_nginx
cloud1_wordpress
cloud1_mariadb
```
