
DEBIAN_SUITE?=trixie
DEBIAN_VERSION?=13
PWD=$(shell pwd)
BIN_DIR=$(PWD)/bin
DIST_DIR=$(PWD)/dist/release
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

PKG_DIR := $(PWD)/pkg
PKG_LIST := $(notdir $(wildcard $(PWD)/pkg/*))
PKG_LIST := release etcd kubernetes kind
OPTIONAL_PKG_LIST := golang protobuf

.PHONY: all
all: folders
	@for folder in $(PKG_LIST); do \
		if [ -d $(PKG_DIR)/"$$folder" ]; then \
			cd $(PKG_DIR)/"$$folder" && make all; \
		fi \
	done

.PHONY: $(PKG_LIST) $(OPTIONAL_PKG_LIST)
$(PKG_LIST) $(OPTIONAL_PKG_LIST):
	@cd $(PKG_DIR)/$@ && make all

.PHONY: distclean
distclean:
	@for folder in $(PKG_LIST); do \
		if [ -d $(PKG_DIR)/"$$folder" ]; then \
			cd $(PKG_DIR)/"$$folder" && make distclean; \
		fi \
	done
	rm -rf $(BIN_DIR)

.PHONY: folders
folders:
	mkdir -p $(BIN_DIR)
	mkdir -p $(DIST_DIR)

.PHONY: release-build-images
release-build-images: folders
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/build-images.sh

.PHONY: release-build-binaries
release-build-binaries: folders
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/build-binaries.sh

.PHONY: dev-build-images
dev-build-images: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(PWD)/hack/release/build-images.sh

.PHONY: dev-build-binaries
dev-build-binaries: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(PWD)/hack/release/build-binaries.sh

.PHONY: dev-build
dev-build: dev-build-images dev-build-binaries

.PHONY: release-stage-assets
release-stage-assets: folders
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/stage-assets.sh

.PHONY: release-checksums
release-checksums: release-stage-assets
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/write-checksums.sh

.PHONY: dev-stage-assets
dev-stage-assets: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(PWD)/hack/release/stage-assets.sh

.PHONY: dev-checksums
dev-checksums: dev-stage-assets
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(PWD)/hack/release/write-checksums.sh

.PHONY: release-retag-images
release-retag-images:
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/retag-and-push-images.sh retag

.PHONY: release-push-images
release-push-images:
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/retag-and-push-images.sh publish

.PHONY: release-artifacts
release-artifacts: release-build-binaries release-checksums

.PHONY: release-publish
release-publish: release-build-images release-artifacts
	@KIND_BUILD_PROFILE=release $(PWD)/hack/release/retag-and-push-images.sh publish

.PHONY: verify-ci-baseline-optimization
verify-ci-baseline-optimization:
	@$(PWD)/hack/ci/verify-ci-baseline-optimization.sh

####################################################
# kind cluster and app deployment			 	   #
####################################################
.PHONY: kind-cluster
kind-cluster:
	# build kind cluster
	$(BIN_DIR)/kind create cluster --retain --config config/kind.yaml --image kindest/node:latest
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-helper:riscv64
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-provisioner:riscv64

.PHONY: app-deploy
app-deploy:
	# deploy alpine echo server, client and service
	$(BIN_DIR)/kubectl apply -f config/alpine.yaml

.PHONY: kind-cluster-delete
kind-cluster-delete:
	$(BIN_DIR)/kind delete cluster
