include ../common.mk

BRANCH=master
SHA=0d55e3269177e9084168bfe19ebde15469252e52

all: release

.PHONY: release
release: folders cross debian-base go-runner setcap distroless-iptables
	@echo "Release done"

.PHONY: $(BUILD_DIR)/release
$(BUILD_DIR)/release: folders
	docker buildx use default
	cd $(BUILD_DIR) && \
		if [ ! -d release/.git ]; then \
			git init release; \
		fi && \
		cd release && \
		(git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/kubernetes/release.git) && \
		if git rev-parse --verify HEAD >/dev/null 2>&1; then \
			git fetch origin $(BRANCH) && \
			git reset --hard $(SHA); \
		else \
			git fetch origin $(BRANCH) && \
			git checkout -f $(SHA); \
		fi && \
		for patch in $(PATCH_FOLDER)/*; do \
			patch -N --no-backup-if-mismatch -p1 < $$patch; \
		done


.PHONY: cross
cross: $(BUILD_DIR)/release
	# Build cross
	echo "Building release image: [cross]" && \
	mkdir -p $(BUILD_DIR)/release/images/build/cross/precompiled && \
	if [ -f $(BIN_DIR)/$(PROTOC_ZIP) ]; then cp $(BIN_DIR)/$(PROTOC_ZIP) $(BUILD_DIR)/release/images/build/cross/precompiled/; fi && \
	cd $(BUILD_DIR)/release/images/build/cross && \
	PLATFORMS=linux/riscv64 KUBERNETES_VERSION=v$(KUBERNETES_VERSION).0 GO_VERSION=1.25.10 GO_MAJOR_VERSION=1.25 OS_CODENAME=trixie REGISTRY=$(REGISTRY) make container
	docker tag $(REGISTRY)/kube-cross-riscv64:$(KUBE_CROSS_VERSION) kube-cross-riscv64
	docker tag $(REGISTRY)/kube-cross-riscv64:$(KUBE_CROSS_VERSION) kube-cross-riscv64:$(KUBE_CROSS_VERSION)

.PHONY: debian-base
debian-base: $(BUILD_DIR)/release
	# Build debian-base
	echo "Building release image: [debian-base]" && \
	cd $(BUILD_DIR)/release/images/build/debian-base && \
	ARCH=riscv64 CONFIG=bookworm BASEIMAGE=debian:trixie-slim IMAGE_VERSION=$(DEBIAN_BASE_VERSION) REGISTRY=$(REGISTRY) make build
	docker tag $(REGISTRY)/debian-base-riscv64:$(DEBIAN_BASE_VERSION) debian-base-riscv64:$(DEBIAN_BASE_VERSION)

.PHONY: go-runner
go-runner: $(BUILD_DIR)/release
	# Build go-runner
	echo "Building release image: [go-runner]" && \
	cd $(BUILD_DIR)/release/images/build/go-runner && \
	PLATFORMS=linux/riscv64 GO_VERSION=1.25.10 GO_MAJOR_VERSION=1.25 OS_CODENAME=trixie DISTROLESS_REGISTRY=$(DISTROLESS_REGISTRY) DISTROLESS_IMAGE=$(DISTROLESS_IMAGE) REGISTRY=$(REGISTRY) make container
	docker tag $(REGISTRY)/go-runner-riscv64:$(KUBE_GORUNNER_VERSION) go-runner-riscv64:$(KUBE_GORUNNER_VERSION)

.PHONY: setcap
setcap: $(BUILD_DIR)/release
	echo "Building release image: [setcap]" && \
	cd $(BUILD_DIR)/release/images/build/setcap && \
	ARCH=riscv64 CONFIG=trixie IMAGE_VERSION=$(KUBE_SETCAP_VERSION) DEBIAN_BASE_VERSION=$(DEBIAN_BASE_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) BASEIMAGE=debian-base-riscv64:$(DEBIAN_BASE_VERSION) make build
	docker tag $(REGISTRY)/setcap-riscv64:$(KUBE_SETCAP_VERSION) setcap-riscv64:$(KUBE_SETCAP_VERSION)

.PHONY: distroless-iptables
distroless-iptables: $(BUILD_DIR)/release
	# Build distroless-iptables
	echo "Building release image: [distroless-iptables]" && \
	cd $(BUILD_DIR)/release/images/build/distroless-iptables && \
	ARCH=riscv64 CONFIG=distroless-trixie IMAGE_VERSION=$(KUBE_PROXY_BASE_VERSION) BASEIMAGE=$(DISTROLESS_IPTABLES_BASEIMAGE) GORUNNERIMAGE=go-runner-riscv64:$(KUBE_GORUNNER_VERSION) BASE_REGISTRY=$(REGISTRY) REGISTRY=$(REGISTRY) make build
	docker tag $(REGISTRY)/distroless-iptables-riscv64:$(KUBE_PROXY_BASE_VERSION) distroless-iptables-riscv64:$(KUBE_PROXY_BASE_VERSION)

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
