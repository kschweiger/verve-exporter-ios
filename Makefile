PROJECT := VerveExporter.xcodeproj
SCHEME := VerveExporter
CONFIGURATION := Debug
DERIVED_DATA := /private/tmp/VerveExporter-DerivedData
COVERAGE_RESULT_BUNDLE ?=

REQUIRED_FILES := \
	AGENTS.md \
	ARCHITECTURE.md \
	.gitignore \
	.agent-harness/manifest.json \
	.agent-harness/selection.yml \
	docs/README.md \
	docs/PRINCIPLES.md \
	docs/TESTING.md \
	docs/SECURITY.md \
	docs/QUALITY_SCORE.md \
	docs/DECISIONS.md \
	docs/product-specs/README.md \
	docs/design-docs/README.md \
	docs/exec-plans/README.md \
	docs/exec-plans/active/.gitkeep \
	docs/exec-plans/completed/.gitkeep \
	docs/exec-plans/tech-debt-tracker.md

.PHONY: help validate validate-docs validate-lint validate-build test test-coverage xcode-list manual-smoke

help:
	@printf '%s\n' 'Validation targets:'
	@printf '%s\n' '  make validate-docs   Check harness files, metadata syntax, and unresolved template markers.'
	@printf '%s\n' '  make validate-lint   Run pre-commit hooks, including SwiftFormat, SwiftLint, and plutil.'
	@printf '%s\n' '  make xcode-list      Confirm the Xcode project exposes the expected scheme.'
	@printf '%s\n' '  make validate-build  Run a signing-disabled generic iOS build.'
	@printf '%s\n' '  make validate        Run docs, lint, and generic iOS build validation.'
	@printf '%s\n' '  make test TEST_DESTINATION=...   Run XCTest on an iOS simulator.'
	@printf '%s\n' '  make test-coverage TEST_DESTINATION=...   Run XCTest and print target coverage.'
	@printf '%s\n' '  make manual-smoke    Print the real-device HealthKit smoke-test reference.'

validate: validate-docs validate-lint validate-build

validate-lint:
	uvx pre-commit run -a

validate-docs:
	@missing=0; \
	for file in $(REQUIRED_FILES); do \
		if [ ! -f "$$file" ]; then \
			printf 'MISSING %s\n' "$$file"; \
			missing=1; \
		fi; \
	done; \
	exit $$missing
	@ruby -rjson -e 'JSON.parse(File.read(".agent-harness/manifest.json")); puts "manifest.json OK"'
	@ruby -e 'require "yaml"; YAML.load_file(".agent-harness/selection.yml"); puts "selection.yml OK"'
	@if command -v rg >/dev/null 2>&1; then \
		if rg -n '\{\{|TBD|TODO|gitlab|GitLab|https://gitlab' AGENTS.md ARCHITECTURE.md docs .agent-harness; then \
			printf 'Unresolved harness/template text found.\n'; \
			exit 1; \
		fi; \
	else \
		printf 'rg not found; skipped unresolved-template scan.\n'; \
	fi

xcode-list:
	xcodebuild -list -project $(PROJECT)

validate-build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		build

test:
	@test -n "$(TEST_DESTINATION)" || { printf '%s\n' 'Set TEST_DESTINATION to an available iOS simulator destination.'; exit 1; }
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(TEST_DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-parallel-testing-enabled NO \
		CODE_SIGNING_ALLOWED=NO \
		test

test-coverage:
	@test -n "$(TEST_DESTINATION)" || { printf '%s\n' 'Set TEST_DESTINATION to an available iOS simulator destination.'; exit 1; }
	@result_bundle="$(COVERAGE_RESULT_BUNDLE)"; \
	if [ -z "$$result_bundle" ]; then \
		result_bundle="/private/tmp/$(SCHEME)-Coverage-$$(date +%Y%m%d-%H%M%S)-$$$$.xcresult"; \
	fi; \
	printf 'Coverage result bundle: %s\n' "$$result_bundle"; \
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(TEST_DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-resultBundlePath "$$result_bundle" \
		-enableCodeCoverage YES \
		-parallel-testing-enabled NO \
		CODE_SIGNING_ALLOWED=NO \
		test && \
	xcrun xccov view --report --only-targets "$$result_bundle"

manual-smoke:
	@printf '%s\n' 'Manual HealthKit smoke test is documented in docs/TESTING.md.'
	@printf '%s\n' 'Use a real device with Health data; do not commit personal workout exports.'
