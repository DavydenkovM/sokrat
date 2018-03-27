PROJECT_NAME = netology_sokratbot

start:
	sh script/run_local.sh

build:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose build
up:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose up -d
down:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose down
restart:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose down && docker-compose up -d
logs:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose logs -f

# bash:
# 	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose run bot bash
rc:
	COMPOSE_PROJECT_NAME=$(PROJECT_NAME) docker-compose run bot iex -S mix

# wipe:
# 	docker volume rm $(docker volume ls -q)

wipe:
	docker volume rm netologysokratbot_sokrat_db

