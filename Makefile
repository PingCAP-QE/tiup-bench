.DEFAULT_GOAL := default

LANG=C
MAKEOVERRIDES =
targets:
	@printf "%-30s %s\n" "Target" "Description"
	@printf "%-30s %s\n" "------" "-----------"
	@make -pqR : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
	| egrep -v -e '^[^[:alnum:]]' -e '^$@$$' \
	| sort \
	| xargs -I _ sh -c 'printf "%-30s " _; make _ -nB | (grep "^# Target:" || echo "") | tail -1 | sed "s/^# Target: //g"'

REPO    := github.com/pingcap/tiup

GOOS    := $(if $(GOOS),$(GOOS),$(shell go env GOOS))
GOARCH  := $(if $(GOARCH),$(GOARCH),$(shell go env GOARCH))
GOENV   := GO111MODULE=on CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH)
GO      := $(GOENV) go
GOBUILD := $(GO) build $(BUILD_FLAGS)
GOTEST  := GO111MODULE=on CGO_ENABLED=1 go test -p 3
SHELL   := /usr/bin/env bash

_COMMIT := $(shell git describe --no-match --always --dirty)
_GITREF := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT  := $(if $(COMMIT),$(COMMIT),$(_COMMIT))
GITREF  := $(if $(GITREF),$(GITREF),$(_GITREF))

LDFLAGS := -w -s
LDFLAGS += -X "$(REPO)/pkg/version.GitHash=$(COMMIT)"
LDFLAGS += -X "$(REPO)/pkg/version.GitRef=$(GITREF)"
LDFLAGS += $(EXTRA_LDFLAGS)

FILES   := $$(find . -name "*.go")

default: check build
	@# Target: run the checks and then build.

# Build components
build: components
	@# Target: build tiup and all it's components

components: bench
	@# Target: build the playground, client, cluster, dm, bench and server components

bench:
	@# Target: build the tiup-bench component
	$(GOBUILD) -ldflags '$(LDFLAGS)' -o bin/tiup-bench .

check: fmt lint tidy check-static vet
	@# Target: run all checkers. (fmt, lint, tidy, check-static and vet)

check-static:
	@# Target: run the golangci-lint static check tool
	tools/bin/golangci-lint run --config tools/check/golangci.yaml ./... --deadline=3m --fix

lint:
	@# Target: run the lint checker revive
	@echo "linting"
	tools/check/check-lint.sh
	@tools/bin/revive -formatter friendly -config tools/check/revive.toml $(FILES)

vet:
	@# Target: run the go vet tool
	$(GO) vet ./...

tidy:
	@# Target: run tidy check
	@echo "go mod tidy"
	tools/check/check-tidy.sh

clean:
	@# Target: run the build cleanup steps
	@rm -rf bin

fmt:
	@# Target: run the go formatter utility
	@echo "gofmt (simplify)"
	@gofmt -s -l -w $(FILES) 2>&1
	@echo "goimports (if installed)"
	$(shell goimports -w $(FILES) 2>/dev/null)

