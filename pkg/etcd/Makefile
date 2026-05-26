include ../common.mk

VERSION=3.5

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
			git fetch origin release-$(VERSION) && \
			git reset --hard FETCH_HEAD; \
		else \
			git fetch --depth 1 origin release-$(VERSION) && \
			git checkout -f FETCH_HEAD; \
		fi && \
		rm -f .github/workflows/build.yaml Dockerfile-release.riscv64
	cd $(BUILD_DIR)/etcd && \
	for patch in $(PATCH_FOLDER)/*; do \
		patch -N --no-backup-if-mismatch -p1 < $$patch; \
	done
	cd $(BUILD_DIR)/etcd && \
		make && \
		TAG=$(REGISTRY)/etcd BINARYDIR=./bin ./scripts/build-docker $(VERSION)

distclean:
	rm -rf $(BUILD_DIR)
	docker rmi $(IMAGE)
