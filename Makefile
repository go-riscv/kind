
DEBIAN_VERSION=sid
PWD=$(shell pwd)
BIN_DIR=$(PWD)/bin
DIST_DIR=$(PWD)/dist/release
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

PKG_DIR := $(PWD)/pkg
PKG_LIST := $(notdir $(wildcard $(PWD)/pkg/*))
PKG_LIST := release etcd kubernetes kind
OPTIONAL_PKG_LIST := golang protobuf
RELEASE_ASSETS := kind-linux-riscv64 kubectl-linux-riscv64 kubeadm-linux-riscv64 SHA256SUMS

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
	@$(PWD)/hack/release/build-images.sh

.PHONY: release-build-binaries
release-build-binaries: folders
	@$(PWD)/hack/release/build-binaries.sh

.PHONY: release-stage-assets
release-stage-assets: folders
	@$(PWD)/hack/release/stage-assets.sh

.PHONY: release-checksums
release-checksums: release-stage-assets
	@$(PWD)/hack/release/write-checksums.sh

.PHONY: release-retag-images
release-retag-images:
	@$(PWD)/hack/release/retag-and-push-images.sh retag

.PHONY: release-push-images
release-push-images:
	@$(PWD)/hack/release/retag-and-push-images.sh publish

.PHONY: release-artifacts
release-artifacts: release-build-binaries release-checksums

.PHONY: release-publish
release-publish: release-build-images release-artifacts
	@$(PWD)/hack/release/retag-and-push-images.sh publish

####################################################
# kind cluster and app deployment			 	   #
####################################################
.PHONY: kind-cluster
kind-cluster:
	# build kind cluster
	$(BIN_DIR)/kind create cluster --retain --config config/kind.yaml
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-helper:riscv64
	$(BIN_DIR)/kind load docker-image $(REGISTRY)/local-path-provisioner:riscv64

.PHONY: app-deploy
app-deploy:
	# deploy alpine echo server, client and service
	$(BIN_DIR)/kubectl apply -f config/alpine.yaml

.PHONY: kind-cluster-delete
kind-cluster-delete:
	$(BIN_DIR)/kind delete cluster
