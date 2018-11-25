#!/bin/bash
set -e

testDir="$(realpath "$(dirname "$BASH_SOURCE")")"
runDir="$(dirname "$(realpath "$BASH_SOURCE")")"

source "$runDir/run-in-container.sh" "$testDir" "$1" bash ./container.sh
