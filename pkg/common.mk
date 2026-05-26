PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/../../bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

GOLANG_VERSION=1.25.10
GOLANG_IMAGE=$(REGISTRY)/golang:$(GOLANG_VERSION)-trixie

PROTOBUF_VERSION=34.1
PROTOC_ZIP=protoc-$(PROTOBUF_VERSION)-linux-riscv_64.zip

DEBIAN_BASE_VERSION=trixie-v1.0.7

DISTROLESS_REGISTRY=gcr.io/distroless
DISTROLESS_IMAGE=static-debian13

DISTROLESS_IPTABLES_BASEIMAGE=debian:trixie-slim

KUBERNETES_VERSION=1.35
KUBE_CROSS_VERSION=v1.35.0-go1.25.10-trixie.0
KUBE_GORUNNER_VERSION=v2.4.0-go1.25.10-trixie.0
KUBE_PROXY_BASE_VERSION=v0.8.10
KUBE_SETCAP_VERSION=trixie-v1.0.7

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
		if git rev-parse --verify HEAD >/dev/null 2>&1; then \
			git fetch origin release-$(KUBERNETES_VERSION) && \
			git reset --hard FETCH_HEAD; \
		else \
			git fetch --depth 1 origin release-$(KUBERNETES_VERSION) && \
			git checkout -f FETCH_HEAD; \
		fi && \
		if ! git describe --tags --match='v*' --abbrev=14 HEAD >/dev/null 2>&1; then \
			git tag -f v$(KUBERNETES_VERSION).0-rv64.0 HEAD; \
		fi && \
	cd $(BUILD_DIR)/kubernetes && \
	for patch in $(PWD)/../kubernetes/patches/*; do \
		patch -N --no-backup-if-mismatch -p1 < $$patch; \
	done
