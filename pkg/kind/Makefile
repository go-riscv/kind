include ../common.mk

VERSION=0.31.0
KIND_RELEASE_TAG ?= v$(VERSION)
KIND_DEFAULT_NODE_IMAGE ?= $(REGISTRY)/node:$(KIND_RELEASE_TAG)
KIND_DEFAULT_PAUSE_IMAGE ?= $(REGISTRY)/pause:$(KIND_RELEASE_TAG)
KIND_DEFAULT_KINDNETD_IMAGE ?= $(REGISTRY)/kindnetd:$(KIND_RELEASE_TAG)
KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE ?= $(REGISTRY)/local-path-provisioner:$(KIND_RELEASE_TAG)
KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE ?= $(REGISTRY)/local-path-helper:$(KIND_RELEASE_TAG)

all: folders kind node-image

.PHONY: $(BUILD_DIR)/kind
$(BUILD_DIR)/kind: folders
	cd $(BUILD_DIR) && \
		if [ ! -d kind/.git ]; then \
			git init kind; \
		fi && \
		cd kind && \
		(git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/kubernetes-sigs/kind.git) && \
		if git rev-parse --verify HEAD >/dev/null 2>&1; then \
			git fetch origin tag v$(VERSION) && \
			git reset --hard FETCH_HEAD; \
		else \
			git fetch --depth 1 origin tag v$(VERSION) && \
			git checkout -f FETCH_HEAD; \
		fi
	cd $(BUILD_DIR)/kind && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -N --no-backup-if-mismatch -p1 < $$patch || exit 1; \
	done
	@grep -q '^const Image = ' $(BUILD_DIR)/kind/pkg/apis/config/defaults/image.go
	@sed -i 's|^const Image = .*|const Image = "$(KIND_DEFAULT_NODE_IMAGE)"|' $(BUILD_DIR)/kind/pkg/apis/config/defaults/image.go
	@grep -q 'const Image = "$(KIND_DEFAULT_NODE_IMAGE)"' $(BUILD_DIR)/kind/pkg/apis/config/defaults/image.go
	@grep -q 'sandbox_image = ' $(BUILD_DIR)/kind/images/base/files/etc/containerd/config.toml
	@sed -i 's|sandbox_image = .*|sandbox_image = "$(KIND_DEFAULT_PAUSE_IMAGE)"|' $(BUILD_DIR)/kind/images/base/files/etc/containerd/config.toml
	@grep -q 'sandbox_image = "$(KIND_DEFAULT_PAUSE_IMAGE)"' $(BUILD_DIR)/kind/images/base/files/etc/containerd/config.toml
	@grep -q '^const kindnetdImage = ' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_cni.go
	@sed -i 's|^const kindnetdImage = .*|const kindnetdImage = "$(KIND_DEFAULT_KINDNETD_IMAGE)"|' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_cni.go
	@grep -q 'const kindnetdImage = "$(KIND_DEFAULT_KINDNETD_IMAGE)"' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_cni.go
	@grep -q '^const storageProvisionerImage = ' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go
	@sed -i 's|^const storageProvisionerImage = .*|const storageProvisionerImage = "$(KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE)"|' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go
	@grep -q 'const storageProvisionerImage = "$(KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE)"' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go
	@grep -q '^const storageHelperImage = ' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go
	@sed -i 's|^const storageHelperImage = .*|const storageHelperImage = "$(KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE)"|' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go
	@grep -q 'const storageHelperImage = "$(KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE)"' $(BUILD_DIR)/kind/pkg/build/nodeimage/const_storage.go


.PHONY: kind
kind: $(BUILD_DIR)/kind
	# build kind binary
	cd $(BUILD_DIR)/kind && \
		make build && \
		cp bin/kind $(BIN_DIR)/kind

.PHONY: node-image
node-image: kind $(BUILD_DIR)/kubernetes $(BUILD_DIR)/kind local-path-provisioner local-path-helper base kindnetd
	# Build kind node image
	docker tag $(PAUSE_RELEASE_IMAGE) $(KIND_DEFAULT_PAUSE_IMAGE)
	docker tag $(REGISTRY)/local-path-provisioner:riscv64 $(KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE)
	docker tag $(REGISTRY)/local-path-helper:riscv64 $(KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE)
	docker tag $(REGISTRY)/kindnetd:riscv64 $(KIND_DEFAULT_KINDNETD_IMAGE)
	KUBE_BUILD_PULL_LATEST_IMAGES=n \
	KUBE_CROSS_IMAGE=kube-cross-riscv64 \
	KUBE_CROSS_VERSION=$(KUBE_CROSS_VERSION) \
	KUBE_GORUNNER_IMAGE=go-runner-riscv64:$(KUBE_GORUNNER_VERSION) \
	KUBE_PROXY_BASE_IMAGE=distroless-iptables-riscv64:$(KUBE_PROXY_BASE_VERSION) \
	KUBE_BUILD_SETCAP_IMAGE=setcap-riscv64:$(KUBE_SETCAP_VERSION) \
	$(BIN_DIR)/kind build node-image --base-image base:riscv64 $(BUILD_DIR)/kubernetes

.PHONY: local-path-provisioner
local-path-provisioner:
	# Build local-path-provisioner image
	cd $(BUILD_DIR)/kind/images/local-path-provisioner && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build
	docker tag $(REGISTRY)/local-path-provisioner:riscv64 local-path-provisioner:riscv64

.PHONY: local-path-helper
local-path-helper:
	# Build local-path-helper image
	cd $(BUILD_DIR)/kind/images/local-path-helper && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build
	docker tag $(REGISTRY)/local-path-helper:riscv64 local-path-helper:riscv64

.PHONY: base
base:
	# Build kind base image
	cd $(BUILD_DIR)/kind/images/base && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) make build
	docker tag $(REGISTRY)/base:riscv64 base:riscv64

.PHONY: kindnetd
kindnetd:
	# Build kindnetd image
	cd $(BUILD_DIR)/kind/images/kindnetd && \
	PLATFORMS=riscv64 TAG=riscv64 REGISTRY=$(REGISTRY) KUBE_PROXY_BASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:$(KUBE_PROXY_BASE_VERSION) \
make build
	docker tag $(REGISTRY)/kindnetd:riscv64 kindnetd:riscv64

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
