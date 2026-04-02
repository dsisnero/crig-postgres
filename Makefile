.PHONY: install update format lint test test-integration docker-up docker-down clean

install:
	shards install

update:
	shards update

format:
	crystal tool format src spec

lint:
	crystal tool format --check src spec
	ameba src spec

test:
	crystal spec

test-integration:
	./scripts/run-integration-tests.sh

docker-up:
	docker-compose up -d
	@echo "Waiting for PostgreSQL..."
	@until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL ready at postgresql://postgres:postgres@localhost:5432/crig_test"

docker-down:
	docker-compose down

clean:
	rm -rf .crystal-cache lib bin
