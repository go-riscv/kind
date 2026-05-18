include ../common.mk

BRANCH=master
SHA=0d55e3269177e9084168bfe19ebde15469252e52

all: release

.PHONY: release
release: folders cross debian-base go-runner setcap distroless-iptables
	@echo "Release done"

.PHONY: $(BUILD_DIR)/release
$(BUILD_DIR)/release:
	docker buildx use default
	cd $(BUILD_DIR) && \
		rm -rf release && \
		git clone --branch $(BRANCH) https://github.com/kubernetes/release.git && \
		cd release && \
		git reset --hard $(SHA) && \
		for patch in $(PATCH_FOLDER)/*; do \
			patch -p1 < $$patch; \
		done


.PHONY: cross
cross: $(BUILD_DIR)/release
	# Build cross
	echo "Building release image: [cross]" && \
	mkdir -p $(BUILD_DIR)/release/images/build/cross/precompiled && \
	if [ -f $(BIN_DIR)/$(PROTOC_ZIP) ]; then cp $(BIN_DIR)/$(PROTOC_ZIP) $(BUILD_DIR)/release/images/build/cross/precompiled/; fi && \
	cd $(BUILD_DIR)/release/images/build/cross && \
	PLATFORMS=linux/riscv64 KUBERNETES_VERSION=v$(KUBERNETES_VERSION).0 GO_VERSION=1.25.10 GO_MAJOR_VERSION=1.25 OS_CODENAME=trixie REGISTRY=$(REGISTRY) make container

.PHONY: debian-base
debian-base: $(BUILD_DIR)/release
	# Build debian-base
	echo "Building release image: [debian-base]" && \
	cd $(BUILD_DIR)/release/images/build/debian-base && \
	ARCH=riscv64 CONFIG=bookworm BASEIMAGE=debian:trixie-slim IMAGE_VERSION=$(DEBIAN_BASE_VERSION) REGISTRY=$(REGISTRY) make build

.PHONY: go-runner
go-runner: $(BUILD_DIR)/release
	# Build go-runner
	echo "Building release image: [go-runner]" && \
	cd $(BUILD_DIR)/release/images/build/go-runner && \
	PLATFORMS=linux/riscv64 GO_VERSION=1.25.10 GO_MAJOR_VERSION=1.25 OS_CODENAME=trixie DISTROLESS_REGISTRY=$(DISTROLESS_REGISTRY) DISTROLESS_IMAGE=$(DISTROLESS_IMAGE) REGISTRY=$(REGISTRY) make container

.PHONY: setcap
setcap: $(BUILD_DIR)/release
	echo "Building release image: [setcap]" && \
	cd $(BUILD_DIR)/release/images/build/setcap && \
	ARCH=riscv64 CONFIG=trixie IMAGE_VERSION=$(KUBE_SETCAP_VERSION) DEBIAN_BASE_VERSION=$(DEBIAN_BASE_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

.PHONY: distroless-iptables
distroless-iptables: $(BUILD_DIR)/release
	# Build distroless-iptables
	echo "Building release image: [distroless-iptables]" && \
	cd $(BUILD_DIR)/release/images/build/distroless-iptables && \
	ARCH=riscv64 CONFIG=distroless-trixie IMAGE_VERSION=$(KUBE_PROXY_BASE_VERSION) BASEIMAGE=$(DISTROLESS_IPTABLES_BASEIMAGE) GORUNNERIMAGE=$(REGISTRY)/go-runner-riscv64:$(KUBE_GORUNNER_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
