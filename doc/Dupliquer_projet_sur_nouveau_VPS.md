# Dupliquer Cloud-1 sur un nouveau VPS

Ce document explique comment redéployer le projet Cloud-1 sur un nouveau VPS et modifier l'adresse IP associee a un domaine DuckDNS.

Le deploiement est realise depuis la machine locale avec Ansible. Ansible n'a pas besoin d'etre installe sur le VPS.

## 1. Choisir le type de duplication

### Nouveau deploiement vierge

Le nouveau VPS contient une installation propre. Le playbook installe Docker, UFW et les conteneurs. Les volumes MariaDB et WordPress sont nouveaux.

Les utilisateurs, articles, commentaires et reglages de l'ancien serveur ne sont pas recuperes automatiquement.

### Migration avec conservation des donnees

Il faut sauvegarder puis restaurer les volumes ou la base MariaDB et les fichiers WordPress. Ne lancez pas `docker compose down -v` sur l'ancien serveur : cette commande supprime les volumes.

Le playbook seul automatise le deploiement, mais ne migre pas les donnees applicatives.

## 2. Preparer le nouveau VPS

Utiliser de preference une installation Ubuntu LTS fraiche avec :

- une IP publique fixe ;
- les ports 22, 80 et 443 disponibles ;
- un acces SSH root temporaire ou un utilisateur administrateur ;
- aucun autre service utilisant les ports 80 ou 443.

Depuis la machine locale, tester l'acces fourni par le fournisseur :

```bash
ssh root@NEW_IP
```

Ne pas activer manuellement un pare-feu avant le premier test Ansible. Le role `firewall` autorise SSH avant d'activer UFW.

## 3. Creer une cle SSH dediee

Ne pas ecraser une cle existante. Creer une nouvelle cle avec un nom distinct :

```bash
ssh-keygen -t ed25519 \
  -C "cloud-1-new-vps" \
  -f ~/.ssh/cloud1_new_vps_ed25519
```

Copier la cle publique sur le nouveau serveur :

```bash
ssh-copy-id \
  -i ~/.ssh/cloud1_new_vps_ed25519.pub \
  root@NEW_IP
```

Tester la cle :

```bash
ssh -o IdentitiesOnly=yes \
  -i ~/.ssh/cloud1_new_vps_ed25519 \
  root@NEW_IP
```

Si la cle est protegee par une passphrase, utiliser `ssh-agent` ou saisir la passphrase lorsque SSH la demande. Ne jamais mettre cette passphrase dans le depot.

## 4. Mettre a jour l'inventaire Ansible

Modifier `ansible/inventory.ini` :

```ini
[cloud]
cloud1 ansible_host=NEW_IP ansible_user=root ansible_ssh_private_key_file=/home/LOCAL_USER/.ssh/cloud1_new_vps_ed25519 ansible_ssh_common_args='-o IdentitiesOnly=yes'
```

Remplacer :

- `NEW_IP` par l'adresse IP du nouveau VPS ;
- `/home/LOCAL_USER` par le chemin reel de la machine locale.

Le `Makefile` contient aussi l'adresse du VPS et le chemin de la cle. Mettre a jour :

```makefile
VPS = root@NEW_IP
SSH_KEY = /home/LOCAL_USER/.ssh/cloud1_new_vps_ed25519
```

Tester l'inventaire et Ansible depuis la racine du projet :

```bash
source .venv/bin/activate
ansible-inventory -i ansible/inventory.ini --graph
ansible -i ansible/inventory.ini cloud -m ping --ask-pass --ask-vault-pass
```

Les deux mots de passe demandes sont differents :

- `SSH password` : mot de passe SSH du VPS ;
- `Vault password` : mot de passe qui dechiffre `ansible/group_vars/cloud/vault.yml`.

Avec une cle SSH fonctionnelle, `--ask-pass` pourra etre retire du Makefile et des commandes Ansible.

## 5. Configurer DuckDNS avec la nouvelle IP

Le domaine doit pointer vers le nouveau VPS avant de demander le certificat Let's Encrypt.

### Mise a jour manuelle

Sur DuckDNS, ouvrir le domaine concerne et remplacer l'ancienne IP par `NEW_IP`.

### Mise a jour avec l'API DuckDNS

DuckDNS fournit une URL de mise a jour de la forme :

```text
https://www.duckdns.org/update?domains=SUBDOMAIN&token=DUCKDNS_TOKEN&ip=NEW_IP
```

Exemple depuis la machine locale :

```bash
curl "https://www.duckdns.org/update?domains=SUBDOMAIN&token=DUCKDNS_TOKEN&ip=NEW_IP"
```

La reponse attendue est :

```text
OK
```

Ne pas enregistrer l'URL complete avec le token dans Git, dans le README ou dans un fichier partage.

Verifier la propagation DNS :

```bash
dig +short SUBDOMAIN.duckdns.org
```

La sortie doit contenir `NEW_IP`. Attendre la propagation avant de lancer Certbot.

## 6. Verifier les variables du projet

Modifier `ansible/group_vars/cloud/main.yml` si necessaire :

```yaml
project_dir: /opt/cloud-1
domain_name: "SUBDOMAIN.duckdns.org"
letsencrypt_email: "EMAIL@example.com"
```

Verifier aussi :

- `wp_title` ;
- `wp_admin_user` ;
- `wp_admin_email` ;
- `wp_user` ;
- `wp_user_email` ;
- `wordpress_db_host`.

Le domaine de `domain_name` doit correspondre exactement au domaine DuckDNS.

## 7. Verifier Ansible Vault

Le fichier des secrets doit rester chiffre :

```bash
head -n 1 ansible/group_vars/cloud/vault.yml
```

La premiere ligne doit commencer par :

```text
$ANSIBLE_VAULT;
```

Tester le mot de passe Vault :

```bash
ansible-vault view ansible/group_vars/cloud/vault.yml
```

Pour changer les secrets applicatifs :

```bash
ansible-vault edit ansible/group_vars/cloud/vault.yml
```

Ne jamais committer :

- un fichier Vault dechiffre ;
- un mot de passe SSH ;
- un token DuckDNS ;
- une cle privee SSH ;
- un fichier contenant les secrets Docker.

## 8. Lancer les verifications avant deploiement

Depuis la racine du depot :

```bash
source .venv/bin/activate
ansible-playbook ansible/playbook.yml --syntax-check
ansible-inventory -i ansible/inventory.ini --list --ask-vault-pass
ansible -i ansible/inventory.ini cloud -m ping --ask-pass --ask-vault-pass
```

Verifier que le domaine resout vers la nouvelle IP :

```bash
dig +short SUBDOMAIN.duckdns.org
```

## 9. Lancer le deploiement

Avec le Makefile :

```bash
make deploy-vault
```

Ou directement :

```bash
ansible-playbook \
  -i ansible/inventory.ini \
  ansible/playbook.yml \
  --ask-pass \
  --ask-vault-pass
```

Le playbook effectue notamment les operations suivantes :

1. installation des paquets de base ;
2. creation des secrets Docker ;
3. installation de Docker et Docker Compose ;
4. configuration d'UFW ;
5. copie des Dockerfiles et des templates ;
6. demarrage de MariaDB, WordPress et Nginx ;
7. demande du certificat Let's Encrypt ;
8. activation de la configuration HTTPS ;
9. installation du renouvellement cron.

Le recapitulatif attendu est :

```text
unreachable=0
failed=0
```

## 10. Verifier le nouveau serveur

Verifier les conteneurs :

```bash
make ps
```

Ou directement :

```bash
ssh root@NEW_IP "cd /opt/cloud-1 && docker compose ps"
```

Les conteneurs attendus sont :

```text
cloud1_mariadb
cloud1_wordpress
cloud1_nginx
```

MariaDB et WordPress ne doivent pas avoir de port public :

```text
mariadb    3306/tcp
wordpress  9000/tcp
```

Seul Nginx doit exposer :

```text
0.0.0.0:80->80/tcp
0.0.0.0:443->443/tcp
```

Verifier UFW :

```bash
ssh root@NEW_IP "ufw status verbose"
```

Les ports entrants autorises doivent etre limites a :

```text
22/tcp
80/tcp
443/tcp
```

Verifier HTTP et HTTPS :

```bash
curl -I http://SUBDOMAIN.duckdns.org
curl -I https://SUBDOMAIN.duckdns.org
```

HTTP doit rediriger vers HTTPS. HTTPS doit repondre sans erreur de certificat.

Verifier l'emetteur et les dates du certificat :

```bash
openssl s_client \
  -connect SUBDOMAIN.duckdns.org:443 \
  -servername SUBDOMAIN.duckdns.org \
  </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates
```

L'emetteur attendu est Let's Encrypt.

## 11. Migration des donnees depuis l'ancien VPS

Pour une migration complete, sauvegarder au minimum :

- la base MariaDB ;
- les fichiers WordPress ;
- les secrets necessaires ;
- eventuellement les certificats, bien qu'ils puissent etre regeneres.

Exemple de sauvegarde SQL sur l'ancien VPS :

```bash
cd /opt/cloud-1
DB_PWD=$(cat secrets/db_password.txt)
docker compose exec -T mariadb mariadb-dump \
  -u wp_user -p"$DB_PWD" wordpress > wordpress.sql
```

Copier la sauvegarde vers le nouveau VPS avec un canal securise :

```bash
scp wordpress.sql root@NEW_IP:/root/
```

Restaurer uniquement apres le premier deploiement, et apres avoir verifie que MariaDB est demarre. La restauration doit etre adaptee a l'etat des volumes et aux secrets utilises.

Ne pas executer :

```bash
docker compose down -v
```

sauf si la suppression definitive des donnees est voulue.

## 12. Apres la migration

Executer les controles suivants :

```bash
make ps
make logs
curl -I https://SUBDOMAIN.duckdns.org
```

Verifier dans WordPress :

- la page d'accueil ;
- la connexion administrateur ;
- les articles ;
- les commentaires ;
- les fichiers media ;
- les permaliens.

Verifier le renouvellement planifie :

```bash
ssh root@NEW_IP "crontab -l"
```

## 13. Securite finale

Une fois le deploiement valide :

- remplacer le mot de passe root temporaire ;
- preferer un utilisateur administrateur avec `become: true` ;
- desactiver la connexion SSH root par mot de passe apres validation de la cle ;
- supprimer les fichiers locaux contenant des mots de passe ;
- ajouter ces fichiers au `.gitignore` ;
- renouveler tout secret qui a ete expose ;
- conserver une sauvegarde hors du VPS ;
- ne jamais utiliser `docker compose down -v` pour un simple redemarrage.

## 14. Commandes rapides

```bash
source .venv/bin/activate
ansible-playbook ansible/playbook.yml --syntax-check
ansible -i ansible/inventory.ini cloud -m ping --ask-pass --ask-vault-pass
make deploy-vault
make ps
make logs
```
