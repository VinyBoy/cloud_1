INVENTORY = ansible/inventory.ini
PLAYBOOK = ansible/playbook.yml
HOST = cloud
VPS = root@212.227.191.77
PROJECT_DIR = /opt/cloud-1
SSH_KEY = /home/viny/.ssh/cloud1_vps_ed25519
SSH_OPTIONS = -o IdentitiesOnly=yes -i $(SSH_KEY)

.PHONY: help ping deploy deploy-vault syntax inventory ssh ps logs restart

help:
	@echo "Available commands:"
	@echo "  make ping          - Test Ansible connection"
	@echo "  make deploy        - Run Ansible playbook without Vault"
	@echo "  make deploy-vault  - Run Ansible playbook with Ansible Vault"
	@echo "  make syntax        - Check Ansible playbook syntax"
	@echo "  make inventory     - Show Ansible inventory"
	@echo "  make ssh           - Connect to VPS"
	@echo "  make ps            - Show Docker Compose containers on VPS"
	@echo "  make logs          - Show Docker Compose logs on VPS"
	@echo "  make restart       - Restart Docker Compose stack on VPS"

ping:
	SSH_AUTH_SOCK= ansible -i $(INVENTORY) $(HOST) -m ping --ask-pass --ask-vault-pass

deploy:
	SSH_AUTH_SOCK= ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --ask-pass --ask-vault-pass

deploy-vault:
	SSH_AUTH_SOCK= ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --ask-pass --ask-vault-pass

syntax:
	ansible-playbook $(PLAYBOOK) --syntax-check

inventory:
	ansible-inventory -i $(INVENTORY) --list --ask-vault-pass

ssh:
	SSH_AUTH_SOCK= ssh $(SSH_OPTIONS) $(VPS)

ps:
	SSH_AUTH_SOCK= ssh $(SSH_OPTIONS) $(VPS) "cd $(PROJECT_DIR) && docker compose ps"

logs:
	SSH_AUTH_SOCK= ssh $(SSH_OPTIONS) $(VPS) "cd $(PROJECT_DIR) && docker compose logs --tail=100"

restart:
	SSH_AUTH_SOCK= ssh $(SSH_OPTIONS) $(VPS) "cd $(PROJECT_DIR) && docker compose restart"