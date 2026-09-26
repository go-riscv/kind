.DEFAULT_GOAL := all
.NOTPARALLEL:
include ../common.mk

all: kubetools

.PHONY: kubetools
kubetools: folders $(BUILD_DIR)/kubernetes kubectl kubeadm pause

.PHONY: kubectl
kubectl: $(BUILD_DIR)/kubernetes
	# Build kubectl
	echo "Building kubectl" && \
	cd $(BUILD_DIR)/kubernetes && \
			KUBE_GIT_VERSION_FILE=$(KUBE_VERSION_FILE) $(MAKE) kubectl
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubectl $(BIN_DIR)/kubectl

.PHONY: kubeadm
kubeadm: $(BUILD_DIR)/kubernetes
	# Build kubeadm
	echo "Building kubeadm" && \
	cd $(BUILD_DIR)/kubernetes && \
			KUBE_GIT_VERSION_FILE=$(KUBE_VERSION_FILE) $(MAKE) kubeadm
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubeadm $(BIN_DIR)/kubeadm

.PHONY: pause
pause: $(BUILD_DIR)/kubernetes
	# Build pause
	echo "Building kubernetes image: [pause]" && \
	cd $(BUILD_DIR)/kubernetes/build/pause && \
		ARCH=riscv64 KUBE_CROSS_IMAGE=$(REGISTRY)/kube-cross-riscv64 KUBE_CROSS_VERSION=$(KUBE_CROSS_VERSION) REGISTRY=$(REGISTRY) $(MAKE) container

distclean:
	@if [ -d "$(BUILD_DIR)" ]; then chmod -R u+w "$(BUILD_DIR)"; fi
	rm -rf $(BUILD_DIR)
