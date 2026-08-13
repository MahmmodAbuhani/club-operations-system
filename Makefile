.PHONY: up verify verify-db verify-http verify-image verify-release evidence erd social-preview logs down

up:
	docker compose up --build -d

verify:
	scripts/verify.sh

verify-db:
	tests/sql/invariants.sh
	tests/sql/concurrency.sh

verify-http:
	tests/http/fulfillment.sh
	tests/http/security.sh
	tests/http/roles.sh
	tests/http/accessibility.sh

verify-image:
	scripts/verify_image_manifest.sh

verify-release:
	npm run test:release
	tests/release/public_surface.sh

evidence:
	scripts/capture_evidence.sh

erd:
	npm run erd

social-preview:
	npm run social-preview

logs:
	docker compose logs -f --tail=100

down:
	docker compose down
