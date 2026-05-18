include ../common.mk

UPSTREAM_GOLANG_IMAGE=docker.io/library/golang:$(GOLANG_VERSION)-trixie

all: golang

.PHONY: golang
golang:
	docker pull $(UPSTREAM_GOLANG_IMAGE)
	docker tag $(UPSTREAM_GOLANG_IMAGE) $(GOLANG_IMAGE)

distclean:
	docker rmi $(GOLANG_IMAGE)
