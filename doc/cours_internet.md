# Comprendre HTTPS, Certbot et les autorités de certification

## Objectif du cours

Ce document explique simplement comment fonctionne la certification HTTPS sur Internet, dans le contexte d’un déploiement Cloud-1 avec :

- un VPS Scaleway ;
- un domaine DuckDNS ;
- Nginx ;
- Certbot ;
- Let’s Encrypt ;
- Docker ;
- Ansible.

L’objectif est de comprendre **qui fait quoi** entre le DNS, Certbot, Let’s Encrypt, Nginx et le navigateur.

---

## 1. À quoi sert HTTPS ?

Quand tu vas sur un site en HTTPS, par exemple :

```text
https://cloud-one-vnieto-j.duckdns.org
```

ton navigateur veut deux garanties principales.

### 1.1 Chiffrement

HTTPS chiffre les échanges entre le navigateur et le serveur.

Cela protège notamment :

- les mots de passe ;
- les cookies de session ;
- les formulaires ;
- les données envoyées entre le client et le serveur.

Sans HTTPS, une personne placée entre toi et le serveur pourrait potentiellement lire ou modifier le trafic.

### 1.2 Identité

HTTPS permet aussi au navigateur de vérifier qu’il parle bien au serveur autorisé pour ce domaine :

```text
cloud-one-vnieto-j.duckdns.org
```

Le navigateur veut éviter de parler à un faux serveur qui se ferait passer pour ton site.

---

## 2. C’est quoi un certificat HTTPS ?

Un certificat HTTPS est une sorte de carte d’identité cryptographique pour un domaine.

Il contient notamment :

```text
Domaine concerné : cloud-one-vnieto-j.duckdns.org
Clé publique du serveur
Autorité qui a signé le certificat : Let's Encrypt
Date de début de validité
Date de fin de validité
```

Un certificat HTTPS ne contient pas la clé privée du serveur.

Sur ton serveur, tu retrouves généralement deux fichiers importants :

```text
fullchain.pem  -> certificat + chaîne de certificats
privkey.pem    -> clé privée du serveur
```

Le fichier le plus sensible est :

```text
privkey.pem
```

Il ne doit jamais être exposé publiquement.

---

## 3. C’est quoi une autorité de certification ?

Une autorité de certification, souvent appelée **CA** pour *Certificate Authority*, est une organisation capable de signer des certificats reconnus par les navigateurs.

Exemples d’autorités de certification :

```text
Let's Encrypt
DigiCert
GlobalSign
Sectigo
Google Trust Services
```

Dans ton projet Cloud-1, tu utilises :

```text
Let's Encrypt
```

Let’s Encrypt est une autorité de certification gratuite et automatisée.

---

## 4. Pourquoi le navigateur fait confiance à Let’s Encrypt ?

Ton navigateur ne fait pas confiance à n’importe quel certificat.

Il possède une liste d’autorités racines considérées comme fiables. Cette liste est appelée un **root store**.

Quand ton navigateur reçoit le certificat de ton site, il vérifie la chaîne de confiance :

```text
Ton certificat HTTPS
        ↓ signé par
Certificat intermédiaire Let's Encrypt
        ↓ relié à
Autorité racine de confiance
        ↓ déjà connue par
Navigateur / système d'exploitation
```

Si la chaîne est valide, le navigateur accepte le certificat.

Si elle ne l’est pas, tu obtiens une alerte du type :

```text
Votre connexion n’est pas privée
```

ou :

```text
Invalid certificate
```

---

## 5. Qui décide quelles autorités sont acceptées ?

Il n’existe pas une seule autorité centrale appelée “Internet”.

Plusieurs acteurs participent à la confiance HTTPS :

```text
Navigateurs : Chrome, Firefox, Safari, Edge
Systèmes d’exploitation : Windows, macOS, Linux, Android, iOS
Autorités de certification : Let's Encrypt, DigiCert, etc.
CA/Browser Forum : règles communes du secteur
```

Les autorités de certification doivent respecter des règles strictes. Si une autorité fait n’importe quoi, les navigateurs peuvent décider de ne plus lui faire confiance.

---

## 6. Certbot, c’est quoi ?

Certbot n’est pas l’autorité de certification.

Certbot est un **client ACME**.

ACME est le protocole utilisé pour automatiser la demande, la validation et le renouvellement des certificats.

Dans ton architecture :

```text
Certbot        -> demande le certificat
Let's Encrypt  -> vérifie et signe le certificat
Nginx          -> sert le site et le challenge HTTP
DuckDNS        -> fait pointer le domaine vers le VPS
VPS Scaleway   -> héberge l’infrastructure
```

Quand tu exécutes une commande comme :

```bash
certbot certonly --webroot -w /var/www/certbot -d cloud-one-vnieto-j.duckdns.org
```

Certbot contacte Let’s Encrypt pour demander un certificat.

---

## 7. Comment Let’s Encrypt vérifie que tu contrôles le domaine ?

Let’s Encrypt ne te donne pas un certificat juste parce que tu le demandes.

Il doit d’abord vérifier que tu contrôles réellement le domaine.

Pour cela, il utilise des **challenges ACME**.

Les deux types les plus importants sont :

```text
HTTP-01
DNS-01
```

---

## 8. Le challenge HTTP-01

C’est celui utilisé dans ton projet.

Le principe est simple.

Certbot demande un certificat pour :

```text
cloud-one-vnieto-j.duckdns.org
```

Let’s Encrypt répond :

```text
Prouve-moi que tu contrôles ce domaine.
Place ce fichier temporaire à cette URL.
```

L’URL ressemble à ceci :

```text
http://cloud-one-vnieto-j.duckdns.org/.well-known/acme-challenge/UN_TOKEN
```

Certbot crée alors un fichier temporaire dans ton webroot :

```text
/var/www/certbot/.well-known/acme-challenge/UN_TOKEN
```

Ensuite, Let’s Encrypt essaie d’accéder à cette URL depuis Internet.

Si Let’s Encrypt arrive à lire le bon fichier avec le bon contenu, il considère que tu contrôles le domaine.

Il peut alors émettre le certificat.

---

## 9. Le challenge DNS-01

Le challenge DNS-01 fonctionne autrement.

Au lieu de créer un fichier HTTP, tu dois ajouter un enregistrement DNS de type `TXT`.

Exemple fictif :

```text
_acme-challenge.cloud-one-vnieto-j.duckdns.org TXT "valeur-demandée-par-letsencrypt"
```

Let’s Encrypt vérifie ensuite cet enregistrement DNS.

Si la valeur correspond à ce qui était demandé, le domaine est validé.

Le DNS-01 est utile pour :

- les certificats wildcard ;
- les serveurs qui ne peuvent pas exposer le port 80 ;
- certains cas d’automatisation avancée.

Dans ton cas, tu utilises plutôt HTTP-01, car ton Nginx est accessible sur le port 80.

---

## 10. Pourquoi le DNS est important ?

Avant de vérifier le challenge HTTP, Let’s Encrypt doit savoir où se trouve ton serveur.

Il doit donc résoudre ton domaine :

```text
cloud-one-vnieto-j.duckdns.org
```

Le DNS doit répondre avec l’adresse IP de ton VPS.

Pour l’IPv4, on utilise un enregistrement :

```text
A
```

Dans ton cas :

```text
cloud-one-vnieto-j.duckdns.org -> 51.159.155.247
```

Pour l’IPv6, on utilise un enregistrement :

```text
AAAA
```

Si tu n’as pas d’IPv6, ce n’est pas grave.

La bonne réponse est :

```text
NOERROR
ANSWER: 0
```

Cela veut dire :

```text
Le domaine existe, mais il n’a pas d’adresse IPv6.
```

La mauvaise réponse est :

```text
SERVFAIL
```

Cela veut dire :

```text
Le résolveur DNS a rencontré une erreur.
```

Et cette erreur peut bloquer Let’s Encrypt.

---

## 11. Pourquoi ton certificat échouait ?

Dans ton cas, Certbot échouait avec une erreur de ce type :

```text
DNS problem: SERVFAIL looking up A for cloud-one-vnieto-j.duckdns.org
DNS problem: SERVFAIL looking up AAAA for cloud-one-vnieto-j.duckdns.org
```

Cela signifie que Let’s Encrypt n’arrivait pas à résoudre correctement ton domaine.

Le problème ne venait donc pas forcément de :

```text
Ansible
Docker
Nginx
Certbot
WordPress
```

Le problème venait surtout de la résolution DNS DuckDNS qui était encore instable.

Un domaine propre doit donner :

```text
A     -> 51.159.155.247
AAAA  -> NOERROR avec 0 réponse
```

et surtout pas :

```text
SERVFAIL
```

---

## 12. Est-ce que Certbot teste tous les DNS publics ?

Pas exactement.

Certbot ne fait pas lui-même une validation avec tous les DNS publics.

Le fonctionnement est plutôt :

```text
Certbot demande un certificat
        ↓
Let's Encrypt reçoit la demande
        ↓
Let's Encrypt résout le domaine depuis son infrastructure
        ↓
Let's Encrypt tente d’accéder au challenge HTTP
        ↓
Si tout est correct, le certificat est émis
```

Mais tester avec plusieurs DNS publics comme :

```bash
dig @1.1.1.1 cloud-one-vnieto-j.duckdns.org
dig @8.8.8.8 cloud-one-vnieto-j.duckdns.org
```

est utile pour diagnostiquer si ton domaine est stable.

Si certains DNS publics retournent `SERVFAIL`, Let’s Encrypt peut rencontrer le même problème.

---

## 13. Architecture HTTPS dans ton projet Cloud-1

Ton architecture cible ressemble à ceci :

```text
Utilisateur
    ↓
https://cloud-one-vnieto-j.duckdns.org
    ↓
DuckDNS
    ↓
51.159.155.247
    ↓
VPS Scaleway
    ↓
Docker Nginx : ports 80 / 443
    ↓
WordPress
    ↓
MariaDB interne Docker
```

MariaDB ne doit pas être exposée publiquement.

Dans `docker-compose.yml`, elle ne doit pas avoir :

```yaml
ports:
  - "3306:3306"
```

Elle doit seulement être accessible par WordPress via le réseau Docker interne.

---

## 14. Flux complet de génération du certificat

Dans ton projet, le flux est le suivant :

```text
Ansible lance le rôle deploy
        ↓
Ansible copie docker-compose.yml
        ↓
Ansible copie nginx.conf temporaire en HTTP
        ↓
Docker Compose démarre Nginx
        ↓
Certbot est lancé dans un conteneur Docker
        ↓
Certbot demande un certificat à Let’s Encrypt
        ↓
Let’s Encrypt résout le domaine DuckDNS
        ↓
Let’s Encrypt contacte :
http://cloud-one-vnieto-j.duckdns.org/.well-known/acme-challenge/...
        ↓
Nginx sert le fichier temporaire
        ↓
Let’s Encrypt valide le domaine
        ↓
Certbot reçoit le certificat
        ↓
Ansible remplace la config Nginx HTTP par la config HTTPS
        ↓
Nginx redémarre
        ↓
Le site devient accessible en HTTPS
```

---

## 15. Pourquoi le port 80 reste utile même avec HTTPS ?

Même si l’objectif final est HTTPS, le port 80 reste important.

Il sert à deux choses :

### 15.1 Redirection HTTP vers HTTPS

Quand quelqu’un visite :

```text
http://cloud-one-vnieto-j.duckdns.org
```

Nginx peut rediriger vers :

```text
https://cloud-one-vnieto-j.duckdns.org
```

### 15.2 Renouvellement Let’s Encrypt

Le challenge HTTP-01 utilise le port 80.

Donc pour renouveler automatiquement le certificat, il faut généralement garder le port 80 ouvert.

---

## 16. Renouvellement du certificat

Les certificats Let’s Encrypt ont une durée de vie limitée.

C’est pour cela qu’on ajoute une tâche cron.

Exemple :

```bash
docker run --rm   -v /opt/cloud-1/certbot/www:/var/www/certbot   -v /opt/cloud-1/certbot/conf:/etc/letsencrypt   certbot/certbot renew --quiet
```

Puis on recharge Nginx :

```bash
docker compose exec -T nginx nginx -s reload
```

L’objectif est que le certificat soit renouvelé automatiquement avant son expiration.

---

## 17. HTTPS ne garantit pas que le site est sécurisé applicativement

Un certificat HTTPS ne veut pas dire :

```text
Ce site est honnête
Ce site n’a aucune faille
WordPress est sécurisé
Les mots de passe sont forts
La base de données est bien protégée
```

HTTPS garantit surtout :

```text
Le domaine a été validé
La connexion est chiffrée
Le navigateur peut vérifier la chaîne de confiance
```

Il faut quand même sécuriser l’application derrière :

- mises à jour WordPress ;
- secrets forts ;
- base de données non exposée ;
- firewall ;
- sauvegardes ;
- permissions correctes ;
- logs ;
- monitoring.

---

## 18. Résumé simple à retenir

```text
DNS dit où se trouve le serveur.
Certbot demande un certificat.
Let’s Encrypt vérifie que tu contrôles le domaine.
Nginx sert le challenge HTTP.
Let’s Encrypt signe le certificat.
Le navigateur vérifie la chaîne de confiance.
HTTPS chiffre la connexion.
```

Dans ton cas précis :

```text
DuckDNS doit résoudre proprement le domaine.
Sinon Let’s Encrypt ne peut pas valider.
```

---

## 19. Commandes utiles de diagnostic

### Vérifier l’IPv4

```bash
dig +short @1.1.1.1 A cloud-one-vnieto-j.duckdns.org
dig +short @8.8.8.8 A cloud-one-vnieto-j.duckdns.org
```

Résultat attendu :

```text
51.159.155.247
```

### Vérifier l’IPv6

```bash
dig @1.1.1.1 AAAA cloud-one-vnieto-j.duckdns.org
dig @8.8.8.8 AAAA cloud-one-vnieto-j.duckdns.org
```

Résultat attendu :

```text
status: NOERROR
ANSWER: 0
```

### Tester le challenge HTTP

```bash
curl --resolve cloud-one-vnieto-j.duckdns.org:80:51.159.155.247 http://cloud-one-vnieto-j.duckdns.org/.well-known/acme-challenge/test.txt
```

Résultat attendu :

```text
ok-cloud1
```

### Tester HTTPS

```bash
curl -I https://cloud-one-vnieto-j.duckdns.org
```

Résultat attendu :

```text
HTTP/1.1 200 OK
```

ou :

```text
HTTP/2 200
```

---

## 20. Ce que tu peux dire en évaluation

Tu peux expliquer :

```text
J’utilise DuckDNS pour pointer un sous-domaine vers mon VPS.
Ansible déploie Docker, UFW, Nginx, WordPress et MariaDB.
Nginx expose uniquement les ports 80 et 443.
MariaDB reste privée dans le réseau Docker interne.
Certbot utilise le challenge HTTP-01 pour prouver à Let’s Encrypt que je contrôle le domaine.
Une fois le certificat obtenu, Ansible applique une configuration Nginx HTTPS.
Les certificats sont stockés dans un volume monté dans Nginx.
Un cron renouvelle automatiquement le certificat.
```

C’est une explication claire et défendable pour Cloud-1.

ssh root@51.159.155.247

cd /opt/cloud-1
DB_PWD=$(cat /opt/cloud-1/secrets/db_password.txt)
docker compose exec mariadb mariadb -u wp_user -p"$DB_PWD" wordpress

SELECT comment_ID, comment_author, comment_content
FROM wp_comments
ORDER BY comment_ID DESC
LIMIT 5;