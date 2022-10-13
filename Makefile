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

REPO    := github.com/PingCAP-QE/tiup-bench

GOOS    := $(if $(GOOS),$(GOOS),$(shell go env GOOS))
GOARCH  := $(if $(GOARCH),$(GOARCH),$(shell go env GOARCH))
GOENV   := GO111MODULE=on CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH)
GO      := $(GOENV) go
GOBUILD := $(GO) build $(BUILD_FLAGS)
GOTEST  := GO111MODULE=on CGO_ENABLED=1 go test -p 3
SHELL   := /usr/bin/env bash
TAR     := tar --sort=name --mtime=$(shell git show --no-patch --no-notes --pretty='%aI') --owner=0 --group=0 --numeric-owner

_COMMIT := $(shell git describe --no-match --always --dirty)
_GITREF := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT  := $(if $(COMMIT),$(COMMIT),$(_COMMIT))
GITREF  := $(if $(GITREF),$(GITREF),$(_GITREF))

LDFLAGS := -w -s
LDFLAGS += -X "$(REPO)/pkg/version.GitHash=$(COMMIT)"
LDFLAGS += -X "$(REPO)/pkg/version.GitRef=$(GITREF)"
LDFLAGS += $(EXTRA_LDFLAGS)

FILES   := $$(find . -name "*.go")

ARCH     ?= $(GOOS)-$(GOARCH)
REL_VER  ?= nightly
TPC_URL  ?= https://github.com/pingcap/go-tpc/releases/latest/download/go-tpc_latest_$(GOOS)_$(GOARCH).tar.gz
YCSB_URL ?= https://github.com/pingcap/go-ycsb/releases/latest/download/go-ycsb-$(GOOS)-$(GOARCH).tar.gz

default: check build
	@# Target: run the checks and then build.

# Build components
build: bench
	@# Target: build tiup-bench

package: build
	@# Target: package tiup-bench
	curl -sL $(TPC_URL) | tar -xz -C bin
	curl -sL $(YCSB_URL) | tar -xz -C bin
	$(TAR) -C bin -zcf tiup-bench-$(REL_VER)-$(ARCH).tar.gz tiup-bench go-tpc go-ycsb

bench:
	@# Target: build the tiup-bench component
	$(GOBUILD) -ldflags '$(LDFLAGS)' -o bin/tiup-bench .

check: fmt lint tidy check-static vet
	@# Target: run all checkers. (fmt, lint, tidy, check-static and vet)

check-static: tools/bin/golangci-lint
	@# Target: run the golangci-lint static check tool
	tools/bin/golangci-lint run --config tools/check/golangci.yaml ./... --deadline=3m --fix

lint: tools/bin/revive
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

tools/bin/revive: tools/check/go.mod
	@# Target: build revive utility
	cd tools/check; \
	$(GO) build -o ../bin/revive github.com/mgechev/revive

tools/bin/golangci-lint:
	@# Target: pull in specific version of golangci-lint (v1.42.1)
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b ./tools/bin v1.49.0
