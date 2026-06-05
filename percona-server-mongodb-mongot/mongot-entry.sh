#!/bin/bash
#
# Entry point for the Percona Search for MongoDB (mongot) image.
#
# This lets operators pass mongot options as arguments to the container, e.g.:
#
#     docker run ... percona/percona-server-mongodb-mongot --config /path/to/mongot.yml
#
# while a plain `docker run` still starts mongot with the bundled default
# config supplied via CMD. Any other command (e.g. `bash`) is execed as-is
# so the image stays debuggable.
set -e

# First argument is a flag -> the operator is passing mongot options; prepend
# the binary so they don't have to restate it.
if [ "${1:0:1}" = '-' ]; then
	set -- mongot "$@"
fi

# Normalize the bare `mongot` command to its absolute path.
if [ "$1" = 'mongot' ]; then
	shift
	set -- /usr/bin/mongot "$@"
fi

exec "$@"
