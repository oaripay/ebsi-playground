COMPOSE_CMD = docker compose \
			  --env-file ../versions.env \
			  --env-file ./local.env \
			  --env-file ../global.env

.PHONY: config

up:
	$(COMPOSE_CMD) up --quiet-pull
upd:
	$(COMPOSE_CMD) up -d --quiet-pull
down:
	$(COMPOSE_CMD) down
kill:
	$(COMPOSE_CMD) kill
config:
	$(COMPOSE_CMD) config
