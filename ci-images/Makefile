DOCKER ?= docker
DEST_TAG ?= kireinahoro/flakes-base:v1
REGISTRY ?= registry-1.docker.io

.PHONY: update-image

update-image:
	$(DOCKER) build . -t $(DEST_TAG)
	$(DOCKER) image tag $(DEST_TAG) $(REGISTRY)/$(DEST_TAG)
	$(DOCKER) image push $(REGISTRY)/$(DEST_TAG)
