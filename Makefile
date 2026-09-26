
PWD=$(shell pwd)
BIN_DIR=$(PWD)/bin
DIST_DIR=$(PWD)/dist/release

BUILD_IMAGES_SCRIPT ?= $(PWD)/hack/release/build-images.sh
BUILD_BINARIES_SCRIPT ?= $(PWD)/hack/release/build-binaries.sh
STAGE_ASSETS_SCRIPT ?= $(PWD)/hack/release/stage-assets.sh
WRITE_CHECKSUMS_SCRIPT ?= $(PWD)/hack/release/write-checksums.sh
PUBLISH_IMAGES_SCRIPT ?= $(PWD)/hack/release/retag-and-push-images.sh

PKG_DIR := $(PWD)/pkg
PKG_LIST := release etcd kubernetes kind

.PHONY: all
all: folders
	+$(MAKE) -C $(PKG_DIR)/release all
	+$(MAKE) -C $(PKG_DIR)/etcd all
	+$(MAKE) -C $(PKG_DIR)/kubernetes all
	+$(MAKE) -C $(PKG_DIR)/kind all

.PHONY: $(PKG_LIST)
$(PKG_LIST):
	+$(MAKE) -C $(PKG_DIR)/$@ all

.PHONY: distclean
distclean:
	+$(MAKE) -C $(PKG_DIR)/release distclean
	+$(MAKE) -C $(PKG_DIR)/etcd distclean
	+$(MAKE) -C $(PKG_DIR)/kubernetes distclean
	+$(MAKE) -C $(PKG_DIR)/kind distclean
	rm -rf $(BIN_DIR)

.PHONY: folders
folders:
	mkdir -p $(BIN_DIR)
	mkdir -p $(DIST_DIR)

.PHONY: release-build-images
release-build-images: folders
	@KIND_BUILD_PROFILE=release $(BUILD_IMAGES_SCRIPT)

.PHONY: release-build-binaries
release-build-binaries: folders
	@KIND_BUILD_PROFILE=release $(BUILD_BINARIES_SCRIPT)

.PHONY: dev-build-images
dev-build-images: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(BUILD_IMAGES_SCRIPT)

.PHONY: dev-build-binaries
dev-build-binaries: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(BUILD_BINARIES_SCRIPT)

.PHONY: dev-build
dev-build: folders
	+$(MAKE) dev-build-images
	+$(MAKE) dev-build-binaries

.PHONY: release-stage-assets
release-stage-assets: folders
	@KIND_BUILD_PROFILE=release $(STAGE_ASSETS_SCRIPT)

.PHONY: release-checksums
release-checksums: release-stage-assets
	@KIND_BUILD_PROFILE=release $(WRITE_CHECKSUMS_SCRIPT)

.PHONY: dev-stage-assets
dev-stage-assets: folders
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(STAGE_ASSETS_SCRIPT)

.PHONY: dev-checksums
dev-checksums: dev-stage-assets
	@KIND_BUILD_PROFILE=local RELEASE_TAG= $(WRITE_CHECKSUMS_SCRIPT)

.PHONY: release-retag-images
release-retag-images:
	@KIND_BUILD_PROFILE=release $(PUBLISH_IMAGES_SCRIPT) retag

.PHONY: release-push-images
release-push-images:
	@KIND_BUILD_PROFILE=release $(PUBLISH_IMAGES_SCRIPT) publish

.PHONY: release-artifacts
release-artifacts: folders
	+$(MAKE) release-build-binaries
	+$(MAKE) release-checksums

.PHONY: release-publish
release-publish: folders
	+$(MAKE) release-build-images
	+$(MAKE) release-artifacts
	@KIND_BUILD_PROFILE=release $(PUBLISH_IMAGES_SCRIPT) publish
