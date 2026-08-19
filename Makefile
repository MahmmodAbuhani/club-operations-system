.PHONY: up verify verify-db verify-http verify-image verify-release evidence erd social-preview logs down fixture-snapshot verify-streamlit

up:
	docker compose up --build -d

fixture-snapshot:
	scripts/export_fixture_snapshot.sh
	python3 scripts/validate_fixture_snapshot.py demo/fixture_snapshot.json

verify-streamlit:
	python3 scripts/validate_fixture_snapshot.py demo/fixture_snapshot.json
	python3 -m unittest discover -s tests/python -p 'test_*.py'
	npm run test:streamlit

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
