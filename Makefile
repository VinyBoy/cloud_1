INVENTORY = ansible/inventory.ini
PLAYBOOK = ansible/playbook.yml
HOST = cloud
VPS = root@51.159.155.247
PROJECT_DIR = /opt/cloud-1

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
	ansible -i $(INVENTORY) $(HOST) -m ping

deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

deploy-vault:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --ask-vault-pass

syntax:
	ansible-playbook $(PLAYBOOK) --syntax-check

inventory:
	ansible-inventory -i $(INVENTORY) --list

ssh:
	ssh $(VPS)

ps:
	ssh $(VPS) "cd $(PROJECT_DIR) && docker compose ps"

logs:
	ssh $(VPS) "cd $(PROJECT_DIR) && docker compose logs --tail=100"

restart:
	ssh $(VPS) "cd $(PROJECT_DIR) && docker compose restart"