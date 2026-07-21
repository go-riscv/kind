include ../common.mk

KIND_UPSTREAM_VERSION=0.31.0
VERSION=$(KIND_UPSTREAM_VERSION)
KIND_BUILD_PROFILE ?= local
RELEASE_TAG ?=

ifeq ($(KIND_BUILD_PROFILE),release)
KIND_DEFAULT_NODE_IMAGE ?= $(REGISTRY)/node:$(RELEASE_TAG)
KIND_DEFAULT_PAUSE_IMAGE ?= $(REGISTRY)/pause:$(RELEASE_TAG)
KIND_DEFAULT_KINDNETD_IMAGE ?= $(REGISTRY)/kindnetd:$(RELEASE_TAG)
KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE ?= $(REGISTRY)/local-path-provisioner:$(RELEASE_TAG)
KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE ?= $(REGISTRY)/local-path-helper:$(RELEASE_TAG)
else
KIND_DEFAULT_NODE_IMAGE ?= kindest/node:latest
KIND_DEFAULT_PAUSE_IMAGE ?= pause:riscv64
KIND_DEFAULT_KINDNETD_IMAGE ?= kindnetd:riscv64
KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE ?= local-path-provisioner:riscv64
KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE ?= local-path-helper:riscv64
endif

all: folders kind node-image

.PHONY: validate-kind-build-profile
validate-kind-build-profile:
	@if [ "$(KIND_BUILD_PROFILE)" != "local" ] && [ "$(KIND_BUILD_PROFILE)" != "release" ]; then \
		echo "KIND_BUILD_PROFILE must be local or release, got: $(KIND_BUILD_PROFILE)" >&2; \
		exit 1; \
	fi
	@if [ "$(KIND_BUILD_PROFILE)" = "release" ]; then \
		printf '%s\n' "$(RELEASE_TAG)" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$$' || { \
			echo "RELEASE_TAG must match vX.Y.Z for release builds, got: $(RELEASE_TAG)" >&2; \
			exit 1; \
		}; \
	fi

.PHONY: print-kind-runtime-image-refs
print-kind-runtime-image-refs: validate-kind-build-profile
	@printf "node=%s\n" "$(KIND_DEFAULT_NODE_IMAGE)"
	@printf "pause=%s\n" "$(KIND_DEFAULT_PAUSE_IMAGE)"
	@printf "kindnetd=%s\n" "$(KIND_DEFAULT_KINDNETD_IMAGE)"
	@printf "local-path-provisioner=%s\n" "$(KIND_DEFAULT_LOCAL_PATH_PROVISIONER_IMAGE)"
	@printf "local-path-helper=%s\n" "$(KIND_DEFAULT_LOCAL_PATH_HELPER_IMAGE)"

.PHONY: $(BUILD_DIR)/kind
$(BUILD_DIR)/kind: folders validate-kind-build-profile
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
