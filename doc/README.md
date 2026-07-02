### Ansible

Ansible est un outil d’automatisation DevOps. Il permet de configurer des serveurs, installer des paquets, copier des fichiers, lancer Docker, déployer une application, configurer un firewall, etc., sans faire toutes les commandes à la main en SSH.

Son gros avantage : écrire une fois les étapes dans des fichiers Ansible, puis pouvoir les rejouer automatiquement sur un VPS.

### Inventory.ini

Le fichier inventory.ini sert à dire à Ansible quelles machines il doit contrôler et comment s’y connecter.

Exemple :

[cloud] 
cloud1 ansible_host={IP_Machine} ansible_user={user}ansible_ssh_private_key_file={path_private_key}

[cloud] -> definit un groupe de machines appelé cloud.

cloud1 -> est le nom interne de ton serveur dans Ansible.

ansible_host=5{IP_Machine} -> indique l’IP du VPS.

ansible_user={user} -> indique l’utilisateur SSH utilisé.

ansible_ssh_private_key_file=... -> indique la clé privée locale utilisée pour se connecter au VPS.

### le playbook principal

Permet d'orchestrer tout le déploiement :

curl -I http://51.159.155.247

http://51.159.155.247

### Lancer le playbook de facon securisee avec secrets directement dans Ansible Vault

ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass