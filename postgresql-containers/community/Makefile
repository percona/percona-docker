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

# PG 19 (beta): the versioned tags mirror the regular per-version naming used
# by the operator CR (main-ppg19-postgres / main-pgbackrest19 / main-pgbouncer19).
POSTGRES19_IMAGE     ?= $(REGISTRY):$(TAG)-postgres19-community
POSTGRES19_PPG_IMAGE ?= $(REGISTRY):$(TAG)-ppg19-postgres
PGBACKREST19_IMAGE   ?= $(REGISTRY):$(TAG)-pgbackrest19
PGBOUNCER19_IMAGE    ?= $(REGISTRY):$(TAG)-pgbouncer19
UPGRADE19_IMAGE      ?= $(REGISTRY):$(TAG)-upgrade19
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

.PHONY: all postgres19 postgres18 postgres17 postgres16 postgres15 postgres14 pgbackrest pgbouncer upgrade \
        postgres18-ubi8 postgres17-ubi8 postgres16-ubi8 postgres15-ubi8 postgres14-ubi8 upgrade-ubi8 \
        all-ubi8 pg19 pgbackrest19 pgbouncer19 upgrade19

# postgres19 is deliberately NOT part of `all`: PostgreSQL 19 is in beta
# (packages come from the PGDG testing repo) — build it explicitly with `make postgres19`
# or build the full versioned PG 19 image set with `make pg19`.
all: postgres18 postgres17 postgres16 postgres15 postgres14 pgbackrest pgbouncer upgrade

all-ubi8: postgres18-ubi8 postgres17-ubi8 postgres16-ubi8 postgres15-ubi8 postgres14-ubi8 upgrade-ubi8

# Everything the operator needs for a PG 19 (beta) cluster, under the versioned
# tags referenced by the CR. pgbackrest19 layers on an EXISTING community
# pgbackrest image (override the base with PGBACKREST_IMAGE=..., or run
# `make pgbackrest` first to refresh it).
pg19: postgres19 pgbackrest19 pgbouncer19 upgrade19

# Print the image names each build group pushes, one per line. CI builds its
# image summary from these instead of hard-coding tags, so the report stays in
# lockstep with the *_IMAGE definitions above.
.PHONY: list-images-all list-images-all-ubi8 list-images-pg19
list-images-all:
	@printf '%s\n' $(POSTGRES18_IMAGE) $(POSTGRES17_IMAGE) $(POSTGRES16_IMAGE) \
		$(POSTGRES15_IMAGE) $(POSTGRES14_IMAGE) $(PGBACKREST_IMAGE) \
		$(PGBOUNCER_IMAGE) $(UPGRADE_IMAGE)

# the ubi8 targets reuse the same image variables (callers pass TAG=<tag>-ubi8);
# pgbackrest and pgbouncer have no UBI8 variant
list-images-all-ubi8:
	@printf '%s\n' $(POSTGRES18_IMAGE) $(POSTGRES17_IMAGE) $(POSTGRES16_IMAGE) \
		$(POSTGRES15_IMAGE) $(POSTGRES14_IMAGE) $(UPGRADE_IMAGE)

list-images-pg19:
	@printf '%s\n' $(POSTGRES19_IMAGE) $(POSTGRES19_PPG_IMAGE) \
		$(PGBACKREST19_IMAGE) $(PGBOUNCER19_IMAGE) $(UPGRADE19_IMAGE)

postgres19:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(POSTGRES19_IMAGE)) $(if $(IMAGE),,-t $(POSTGRES19_PPG_IMAGE)) build/postgres19/

pgbackrest19:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) \
		--build-arg BASE_IMAGE=$(PGBACKREST_IMAGE) \
		-t $(or $(IMAGE),$(PGBACKREST19_IMAGE)) build/pgbackrest19/

pgbouncer19:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-t $(or $(IMAGE),$(PGBOUNCER19_IMAGE)) build/pgbouncer/

upgrade19:
	docker buildx build --platform $(PLATFORMS) $(OUTPUT) $(BUILD_ARGS) \
		-f build/upgrade19/Dockerfile \
		-t $(or $(IMAGE),$(UPGRADE19_IMAGE)) \
		../

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
