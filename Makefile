SHELL := /bin/bash

BESU_NETWORK_NAME = ebsi-besu-network
BESU_NETWORK_SUBNET_PREFIX = 192.168.50
NODE_NETWORK_NAME_PREFIX = ebsi-node
NODE_NETWORK_SUBNET_PREFIX = 192.168
INFRA_NETWORK_NAME = ebsi-infra
INFRA_NETWORK_SUBNET_PREFIX = 192.168.51

setup: keys/bootnode.env besu_bootnode_perms docker_networks

keys/bootnode.env:
	./scripts/generate_keys.sh

deploy_smart_contracts:
	./scripts/deploy_box.sh
	./scripts/populate_contract_addr.sh
	echo "restart apis with new configs"

besu_bootnode_key: volumes/node1/besu/secret/key volumes/node1/besu/secret/key.pub besu_bootnode_perms

besu_bootnode_perms:
	for n in 1 2 3 4; do \
		for d in \
				besu/data \
				blockscout-redis-db \
				blockscout-db \
				blockscout-backend-logs \
				blockscout-stats-db \
			; do \
			mkdir -p  volumes/node$$n/$$d; \
			chmod 777 volumes/node$$n/$$d; \
		done; \
	done
	mkdir -p volumes/infra/prometheus volumes/infra/grafana
	chmod 777 volumes/infra/prometheus volumes/infra/grafana

docker_networks:
	docker network inspect $(BESU_NETWORK_NAME) >/dev/null 2>&1 || \
		docker network create \
		--internal \
		--label eu.ebsi=true \
		--subnet   $(BESU_NETWORK_SUBNET_PREFIX).0/24 \
		--gateway  $(BESU_NETWORK_SUBNET_PREFIX).1 \
		--ip-range $(BESU_NETWORK_SUBNET_PREFIX).128/25 \
		$(BESU_NETWORK_NAME)
	for i in \
			$(INFRA_NETWORK_NAME),$(INFRA_NETWORK_SUBNET_PREFIX) \
			$(NODE_NETWORK_NAME_PREFIX)1,$(NODE_NETWORK_SUBNET_PREFIX).55 \
			$(NODE_NETWORK_NAME_PREFIX)2,$(NODE_NETWORK_SUBNET_PREFIX).56 \
			$(NODE_NETWORK_NAME_PREFIX)3,$(NODE_NETWORK_SUBNET_PREFIX).57 \
			$(NODE_NETWORK_NAME_PREFIX)4,$(NODE_NETWORK_SUBNET_PREFIX).58 \
		; do \
		IFS=',' read -r name subnet <<< "$$i"; \
		docker network inspect $$name >/dev/null 2>&1 || \
			docker network create \
			--label eu.ebsi=true \
			--subnet   $$subnet.0/24 \
			--gateway  $$subnet.1 \
			--ip-range $$subnet.128/25 \
			$$name; \
	done
	@echo "Created docker networks:"
	docker network ls --filter label=eu.ebsi=true

clean_docker_networks:
	for network in \
			$(BESU_NETWORK_NAME) \
			$(INFRA_NETWORK_NAME) \
			$(NODE_NETWORK_NAME_PREFIX)1 \
			$(NODE_NETWORK_NAME_PREFIX)2 \
			$(NODE_NETWORK_NAME_PREFIX)3 \
			$(NODE_NETWORK_NAME_PREFIX)4 \
		; do \
		docker network rm $$network >/dev/null 2>&1 || true; \
	done

clean: clean_docker_networks
	[ "$(shell id -u)" -eq 0 ] && rm -rf volumes/ keys/ || sudo rm -rf volumes/ keys/

clean_images:
	docker images --filter label=eu.ebsi -q | xargs -r docker rmi

clean_all: clean clean_images

nuke: clean_all
	docker system prune -af

reset: clean setup

pull:
	for i in sources/*; do git -C $$i pull; done

ssl-setup:
	sudo mkdir -p volumes/node1/node-reverse-proxy/config/certs
	make -C ./nodes/node1 ssl-setup

ssl-status:
	make -C ./nodes/node1 ssl-status

build:
	make -C ./nodes/node1 build
	@echo "Node container images build complete:"
	docker images --filter label=eu.ebsi

all: setup up

up: docker_networks
	make -C ./infra upd
	make -C ./nodes/node1 upd
	make -C ./nodes/node2 upd
	make -C ./nodes/node3 upd
	make -C ./nodes/node4 upd

up-light: docker_networks
	make -C ./infra upd
	make -C ./nodes/node1 upd
	make -C ./nodes/node2 upd-besu
	make -C ./nodes/node3 upd-besu
	make -C ./nodes/node4 upd-besu

besu: docker_networks
	for n in 1 2 3 4; do make -C ./nodes/node$$n upd-besu; done

down:
	make -C ./nodes/node4 down
	make -C ./nodes/node3 down
	make -C ./nodes/node2 down
	make -C ./nodes/node1 down
	make -C ./infra down

restart: down up

health:
	curl -s http://192.168.55.1:9009/health | jq .

log:
	docker logs node1-besu-1 --tail 100 -f

clone_repos:
	[ -e sources/core-services ] || git clone --branch main     https://github.com/oaripay/ebsi-core-services sources/core-services
	[ -e sources/besu-plugins ]  || git clone --branch develop  https://code.europa.eu/ebsi/public/besu-plugins  sources/besu-plugins
	[ -e sources/healthcheck ]   || git clone --branch develop  https://code.europa.eu/ebsi/public/healthcheck   sources/healthcheck
	[ -e sources/validator-smart-contract ] || git clone --branch main https://code.europa.eu/ebsi/public/validator-smart-contract sources/validator-smart-contract
