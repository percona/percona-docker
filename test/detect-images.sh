#!/usr/bin/env bash

set -o errexit

declare -A dockerfilePaths
pathToTests=$(dirname $0)
old_os_versions=("jessie" "wheezy" "trusty")

echo "Changed files between $@:"
for file in $(git --no-pager diff --name-only "$@"); do
	dir=$(dirname $file | cut -d '/' -f 1)
	echo -- $file
	if [ -d "$file" ] && [ -f "$file/Dockerfile" -o -f "$file/Dockerfile.k8s" ]; then
		dockerfilePaths["$file"]=1
	elif [ -f "$file" -a -d "$dir" ] && [ -f "$dir/Dockerfile" -o -f "$file/Dockerfile.k8s" ]; then
		dockerfilePaths["$dir"]=1
	fi
done

for dockerfilePath in "${!dockerfilePaths[@]}"; do
	tag_ver="$(echo $dockerfilePath | sed 's/[^0-9]*//g')"
	tag="percona/$(echo $dockerfilePath | sed 's/-[0-9].[0-9]//g'):${tag_ver:-latest}"
	echo ======================================================
	echo = Building $tag
	echo ======================================================
	echo + docker build --no-cache -t $tag $dockerfilePath
	docker build --no-cache -t $tag $dockerfilePath
	echo 

	os_used="$(grep FROM $dockerfilePath/Dockerfile | cut -d':' -f 2)"
	echo $os_version
	for old_os in ${old_os_versions[@]}
		do
			if [[ $os_used == $old_os ]]; then
				echo ======================================================
				echo = Tests are skipped due to an old os version
				echo ======================================================
				skip_tests=1
				break
			fi
		done
	if [[ $skip_tests != 1 ]]; then
		echo ======================================================
		echo = Testing $tag
		echo ======================================================
		echo + $pathToTests/run.sh $tag
		$pathToTests/run.sh $tag
		echo
	fi
done

echo "Everything OK"
