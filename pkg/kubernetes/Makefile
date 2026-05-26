include ../common.mk

all: kubetools

.PHONY: kubetools
kubetools: folders $(BUILD_DIR)/kubernetes kubectl kubeadm pause

.PHONY: kubectl
kubectl: $(BUILD_DIR)/kubernetes
	# Build kubectl
	echo "Building kubectl" && \
	cd $(BUILD_DIR)/kubernetes && \
		make kubectl
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubectl $(BIN_DIR)/kubectl

.PHONY: kubeadm
kubeadm: $(BUILD_DIR)/kubernetes
	# Build kubeadm
	echo "Building kubeadm" && \
	cd $(BUILD_DIR)/kubernetes && \
		make kubeadm
	cp $(BUILD_DIR)/kubernetes/_output/local/go/bin/kubeadm $(BIN_DIR)/kubeadm

.PHONY: pause
pause: $(BUILD_DIR)/kubernetes
	# Build pause
	echo "Building kubernetes image: [pause]" && \
	cd $(BUILD_DIR)/kubernetes/build/pause && \
	ARCH=riscv64 KUBE_CROSS_IMAGE=$(REGISTRY)/kube-cross-riscv64 KUBE_CROSS_VERSION=$(KUBE_CROSS_VERSION) REGISTRY=$(REGISTRY) make container

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
