# Contributing

## How it works

`transform.py` reads an official Percona Dockerfile and outputs a community
version. `sync.sh` drives the pipeline: it hashes each source file, calls
`transform.py` when the source changes, and writes the result to `build/`.

Do not edit files under `build/` directly — they are regenerated on every sync.

## Making changes to the transform

1. Edit `transform.py`.
2. Run the test suite:
   ```bash
   make test
   ```
3. Regenerate all community Dockerfiles:
   ```bash
   ./sync.sh --force --apply
   ```
4. Build one image locally to verify:
   ```bash
   make postgres17 PLATFORMS=linux/amd64 OUTPUT=--load
   ```
5. Commit both `transform.py` and the regenerated `build/` files together.

## Adding a new PostgreSQL major version

1. Add source → target mappings to the `TARGETS` array in `sync.sh` for both
   the UBI9 and UBI8 variants.
2. Add image name variables and build targets to `Makefile` following the
   existing pattern.
3. Add the new version to `all` and `all-ubi8` targets.
4. Run `./sync.sh --apply` to generate the new Dockerfiles.
5. Add test coverage in `tests/test_transform.py` for any version-specific
   behaviour.

## Running tests

```bash
make test
# or
python3 -m pytest tests/ -v
```

Tests are in `tests/test_transform.py` and cover package mapping, transforms,
extension injection, and pgaudit legacy naming.

## Keeping sources up to date

```bash
# Check which sources have changed
./sync.sh

# Apply updates
./sync.sh --apply
```

`sync.sh` stores a SHA256 of each source file in `.source-hashes`. Commit
`.source-hashes` together with any regenerated `build/` files so the sync
state stays consistent in the repository.
