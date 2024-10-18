DOCKER ?= docker
DEST_TAG ?= kireinahoro/flakes-base:v1
REGISTRY ?= registry-1.docker.io

.PHONY: build push

push: build
	$(DOCKER) image tag $(DEST_TAG) $(REGISTRY)/$(DEST_TAG)
	$(DOCKER) image push $(REGISTRY)/$(DEST_TAG)

build:
	$(DOCKER) build . -t $(DEST_TAG)

debug: build
	$(DOCKER) run -it $(DEST_TAG) /bin/bash
