.PHONY: build release local packages run test generate
build:
	./scripts/build.sh
release:
	./scripts/build.sh --release
local:
	./scripts/build-local.sh
packages:
	./scripts/package-release.sh
run: local
	open build/iGet.app
test:
	./scripts/test.sh
	./scripts/test-integration.sh
	./scripts/test-services.sh
generate:
	./scripts/generate.sh
