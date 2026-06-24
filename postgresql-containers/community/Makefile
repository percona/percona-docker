REGISTRY  ?= perconalab/percona-postgresql-operator
TAG       ?= main
PLATFORMS ?= linux/amd64,linux/arm64
OUTPUT    ?= --push

BASE_IMAGE        ?= redhat/ubi9-minimal
TIMESCALEDB_MAJOR ?= 2
PG_MAJOR          ?= 18

BUILD_ARGS = \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--build-arg TIMESCALEDB_MAJOR=$(TIMESCALEDB_MAJOR)

BUILD_ARGS_UBI8 = \
	--build-arg BASE_IMAGE=redhat/ubi8-minimal \
	--build-arg TIMESCALEDB_MAJOR=$(TIMESCALEDB_MAJOR)

POSTGRES18_IMAGE ?= $(REGISTRY):$(TAG)-postgres18-community
POSTGRES17_IMAGE ?= $(REGISTRY):$(TAG)-postgres17-community
POSTGRES16_IMAGE ?= $(REGISTRY):$(TAG)-postgres16-community
POSTGRES15_IMAGE ?= $(REGISTRY):$(TAG)-postgres15-community
POSTGRES14_IMAGE ?= $(REGISTRY):$(TAG)-postgres14-community
PGBACKREST_IMAGE ?= $(REGISTRY):$(TAG)-pgbackrest-community
PGBOUNCER_IMAGE  ?= $(REGISTRY):$(TAG)-pgbouncer-community
UPGRADE_IMAGE    ?= $(REGISTRY):$(TAG)-upgrade-community

IMAGE ?=

.PHONY: sync test
sync:
	./sync.sh --apply

test:
	python3 -m pytest tests/ -v

.PHONY: all postgres18 postgres17 postgres16 postgres15 postgres14 pgbackrest pgbouncer upgrade \
        postgres18-ubi8 postgres17-ubi8 postgres16-ubi8 postgres15-ubi8 postgres14-ubi8 upgrade-ubi8 \
        all-ubi8

all: postgres18 postgres17 postgres16 postgres15 postgres14 pgbackrest pgbouncer upgrade

all-ubi8: postgres18-ubi8 postgres17-ubi8 postgres16-ubi8 postgres15-ubi8 postgres14-ubi8 upgrade-ubi8

postgres18:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES18_IMAGE)) build/postgres18/

postgres17:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES17_IMAGE)) build/postgres17/

postgres16:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES16_IMAGE)) build/postgres16/

postgres15:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES15_IMAGE)) build/postgres15/

postgres14:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES14_IMAGE)) build/postgres14/

pgbackrest:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(PGBACKREST_IMAGE)) build/pgbackrest/

pgbouncer:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(PGBOUNCER_IMAGE)) build/pgbouncer/

upgrade:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		-f build/upgrade/Dockerfile \
		-t $(or $(IMAGE),$(UPGRADE_IMAGE)) \
		../

postgres18-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		-t $(or $(IMAGE),$(POSTGRES18_IMAGE)) build/postgres18-ubi8/

postgres17-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		-t $(or $(IMAGE),$(POSTGRES17_IMAGE)) build/postgres17-ubi8/

postgres16-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		-t $(or $(IMAGE),$(POSTGRES16_IMAGE)) build/postgres16-ubi8/

postgres15-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		-t $(or $(IMAGE),$(POSTGRES15_IMAGE)) build/postgres15-ubi8/

postgres14-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		-t $(or $(IMAGE),$(POSTGRES14_IMAGE)) build/postgres14-ubi8/

upgrade-ubi8:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS_UBI8) \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		-f build/upgrade-ubi8/Dockerfile \
		-t $(or $(IMAGE),$(UPGRADE_IMAGE)) \
		../
