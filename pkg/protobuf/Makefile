include ../common.mk

TAG=v$(PROTOBUF_VERSION)

all: protoc

.PHONY: protoc
protoc: folders
	cd $(BUILD_DIR) && \
	rm -rf protobuf && \
	git clone --branch $(TAG) --depth 1 https://github.com/protocolbuffers/protobuf.git && \
	cd protobuf && \
	cmake -S . -B build-cmake \
		-DCMAKE_BUILD_TYPE=Release \
		-Dprotobuf_BUILD_TESTS=OFF \
		-Dprotobuf_BUILD_SHARED_LIBS=OFF \
		-Dprotobuf_BUILD_PROTOBUF_BINARIES=ON && \
	cmake --build build-cmake --target protoc -j$$(nproc) && \
	mkdir -p stage/bin stage/include/google && \
	cp build-cmake/protoc stage/bin/ && \
	cp -R src/google/. stage/include/google/ && \
	cd stage && \
	zip -qr $(BIN_DIR)/$(PROTOC_ZIP) bin include

distclean:
	rm -rf $(BUILD_DIR)
