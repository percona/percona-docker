#!/usr/bin/env bash

set -o errexit

declare -A dockerfilePaths
pathToTests=$(dirname $0)

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

	echo ======================================================
	echo = Testing $tag
	echo ======================================================
	echo + $pathToTests/run.sh $tag
	$pathToTests/run.sh $tag
	echo 
done

echo "Everything OK"
