PWD=$(shell pwd)
BUILD_DIR=$(PWD)/build
BIN_DIR=$(PWD)/../../bin
PATCH_FOLDER=$(PWD)/patches
REGISTRY=ghcr.io/go-riscv

GOLANG_VERSION=1.25.10
GOLANG_IMAGE=$(REGISTRY)/golang:$(GOLANG_VERSION)-trixie

PROTOC_ZIP=protoc-23.4-linux-riscv_64.zip

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
$(BUILD_DIR)/kubernetes:
	cd $(BUILD_DIR) && \
		rm -rf kubernetes && \
		git clone --filter=tree:0 --branch release-$(KUBERNETES_VERSION) https://github.com/kubernetes/kubernetes.git && \
	cd $(BUILD_DIR)/kubernetes && \
	for patch in $(PWD)/../kubernetes/patches/*; do \
		patch -p1 < $$patch; \
	done
