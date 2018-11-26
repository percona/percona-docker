#!/usr/bin/env bash

set -o errexit

declare -A dockerfilePaths
pathToTests=$(dirname $0)

echo "Changed files between $@:"
for file in $(git --no-pager diff --name-only "$@"); do
	dir=$(dirname $file)
	echo -- $file
	if [ -d "$file" -a -f "$file/Dockerfile" ]; then
		dockerfilePaths["$file"]=1
	elif [ -f "$file" -a -d "$dir" -a -f "$dir/Dockerfile" ]; then
		dockerfilePaths["$dir"]=1
	fi
done

for dockerfilePath in "${!dockerfilePaths[@]}"; do
	tag="percona/${dockerfilePath%.*}:${dockerfilePath#*.}"

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
