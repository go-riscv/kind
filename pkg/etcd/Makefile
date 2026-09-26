.DEFAULT_GOAL := all
include ../common.mk

VERSION=$(ETCD_VERSION)

all: etcd

.PHONY: etcd
etcd: folders
	# Build etcd image
	cd $(BUILD_DIR) && \
		if [ ! -d etcd/.git ]; then \
			git init etcd; \
		fi && \
		cd etcd && \
		(git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/etcd-io/etcd.git) && \
		if git rev-parse --verify HEAD >/dev/null 2>&1; then \
			git fetch origin tag v$(VERSION) && \
			git reset --hard FETCH_HEAD; \
		else \
			git fetch --depth 1 origin tag v$(VERSION) && \
			git checkout -f FETCH_HEAD; \
		fi && \
		rm -f .github/workflows/build.yaml Dockerfile-release.riscv64
	cd $(BUILD_DIR)/etcd && \
	for patch in $(PATCH_FOLDER)/*; do \
		git apply --check "$$patch" && git apply "$$patch" || exit 1; \
	done
	cd $(BUILD_DIR)/etcd && \
			$(MAKE) && \
		TAG=$(REGISTRY)/etcd BINARYDIR=./bin ./scripts/build-docker.sh $(VERSION)

distclean:
	rm -rf $(BUILD_DIR)
