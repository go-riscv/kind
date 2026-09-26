PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/../../bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

# Canonical supported upstream release pair. Keep release identity here so
# Makefiles and shell tooling query the same values.
KIND_UPSTREAM_VERSION=0.33.0
KUBERNETES_VERSION=1.37.0
KUBERNETES_COMMIT=f54c212e3a2f75d674b717a9b29052b20b60aefc
KUBERNETES_MAJOR=$(word 1,$(subst ., ,$(KUBERNETES_VERSION)))
KUBERNETES_MINOR=$(word 2,$(subst ., ,$(KUBERNETES_VERSION)))

DEBIAN_SUITE=trixie

GOLANG_VERSION=1.26.7
GO_TOOLCHAIN_VERSION=$(GOLANG_VERSION)
ETCD_VERSION=3.7.0

DEBIAN_BASE_VERSION=$(DEBIAN_SUITE)-v1.0.7

DISTROLESS_REGISTRY=gcr.io/distroless
DISTROLESS_IMAGE=static-debian13

DISTROLESS_IPTABLES_BASEIMAGE=debian:$(DEBIAN_SUITE)-slim

KUBE_CROSS_VERSION=v$(KUBERNETES_VERSION)-go$(GO_TOOLCHAIN_VERSION)-$(DEBIAN_SUITE).0
KUBE_GORUNNER_VERSION=v2.4.0-go$(GO_TOOLCHAIN_VERSION)-$(DEBIAN_SUITE).0
KUBE_PROXY_BASE_VERSION=v0.9.6
KUBE_SETCAP_VERSION=$(DEBIAN_SUITE)-v1.0.7
PAUSE_VERSION=3.10.2-linux-riscv64
KIND_IMAGE_TAG=riscv64
KUBE_VERSION_FILE=$(BUILD_DIR)/kubernetes/.kind-kube-version-defs

KUBE_CROSS_RELEASE_IMAGE=$(REGISTRY)/kube-cross-riscv64:$(KUBE_CROSS_VERSION)
DEBIAN_BASE_RELEASE_IMAGE=$(REGISTRY)/debian-base-riscv64:$(DEBIAN_BASE_VERSION)
KUBE_GORUNNER_RELEASE_IMAGE=$(REGISTRY)/go-runner-riscv64:$(KUBE_GORUNNER_VERSION)
KUBE_SETCAP_RELEASE_IMAGE=$(REGISTRY)/setcap-riscv64:$(KUBE_SETCAP_VERSION)
KUBE_PROXY_BASE_RELEASE_IMAGE=$(REGISTRY)/distroless-iptables-riscv64:$(KUBE_PROXY_BASE_VERSION)
PAUSE_RELEASE_IMAGE=$(REGISTRY)/pause:$(PAUSE_VERSION)
ETCD_RELEASE_IMAGE=$(REGISTRY)/etcd:$(ETCD_VERSION)-riscv64
LOCAL_PATH_HELPER_RELEASE_IMAGE=$(REGISTRY)/local-path-helper:$(KIND_IMAGE_TAG)
LOCAL_PATH_PROVISIONER_RELEASE_IMAGE=$(REGISTRY)/local-path-provisioner:$(KIND_IMAGE_TAG)
KIND_BASE_RELEASE_IMAGE=$(REGISTRY)/base:$(KIND_IMAGE_TAG)
KINDNETD_RELEASE_IMAGE=$(REGISTRY)/kindnetd:$(KIND_IMAGE_TAG)
HAPROXY_RELEASE_IMAGE=$(REGISTRY)/haproxy:$(KIND_IMAGE_TAG)

RELEASE_IMAGE_REFS= \
	$(KUBE_CROSS_RELEASE_IMAGE) \
	$(DEBIAN_BASE_RELEASE_IMAGE) \
	$(KUBE_GORUNNER_RELEASE_IMAGE) \
	$(KUBE_SETCAP_RELEASE_IMAGE) \
	$(KUBE_PROXY_BASE_RELEASE_IMAGE) \
	$(PAUSE_RELEASE_IMAGE) \
	$(ETCD_RELEASE_IMAGE) \
	$(LOCAL_PATH_HELPER_RELEASE_IMAGE) \
	$(LOCAL_PATH_PROVISIONER_RELEASE_IMAGE) \
	$(KIND_BASE_RELEASE_IMAGE) \
	$(KINDNETD_RELEASE_IMAGE) \
	$(HAPROXY_RELEASE_IMAGE)

.PHONY: print-release-image-refs
print-release-image-refs:
	@for image in $(RELEASE_IMAGE_REFS); do printf "%s\n" "$$image"; done

.PHONY: print-release-metadata
print-release-metadata:
	@printf "KIND_UPSTREAM_VERSION=%s\n" "$(KIND_UPSTREAM_VERSION)"
	@printf "KIND_RELEASE_TAG=v%s\n" "$(KIND_UPSTREAM_VERSION)"
	@printf "KUBERNETES_VERSION=v%s\n" "$(KUBERNETES_VERSION)"
	@printf "KUBERNETES_COMMIT=%s\n" "$(KUBERNETES_COMMIT)"

.PHONY: folders
folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)

.PHONY: $(BUILD_DIR)/kubernetes
$(BUILD_DIR)/kubernetes: folders
	cd $(BUILD_DIR) && \
		if [ ! -d kubernetes/.git ]; then \
			git init kubernetes; \
		fi && \
		cd kubernetes && \
		(git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/kubernetes/kubernetes.git) && \
		git fetch --depth 1 origin tag v$(KUBERNETES_VERSION) && \
		git reset --hard FETCH_HEAD && \
		test "$$(git rev-parse HEAD)" = "$(KUBERNETES_COMMIT)" && \
		test "$$(git rev-parse v$(KUBERNETES_VERSION)^{commit})" = "$(KUBERNETES_COMMIT)" && \
		git clean -ffd && \
	cd $(BUILD_DIR)/kubernetes && \
	for patch in $(PWD)/../kubernetes/patches/*; do \
		patch -N --no-backup-if-mismatch -p1 < $$patch || exit 1; \
	done && \
	printf "KUBE_GIT_COMMIT='%s'\nKUBE_GIT_TREE_STATE='clean'\nKUBE_GIT_VERSION='v%s'\nKUBE_GIT_MAJOR='%s'\nKUBE_GIT_MINOR='%s'\n" \
		"$(KUBERNETES_COMMIT)" "$(KUBERNETES_VERSION)" "$(KUBERNETES_MAJOR)" "$(KUBERNETES_MINOR)" \
		> "$(KUBE_VERSION_FILE)"
