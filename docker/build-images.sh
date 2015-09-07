#!/bin/bash

set -o pipefail

function image_id {
  docker images | awk "{if (\$1 == \"$1\" && \$2 == \"$2\") print \$3}"
}

function build_versioned_image {
  image_name="$1"
  docker_file="$2"

  version=$(
    docker images |
    awk "{if (\$1 == \"$image_name\" && \$2 != "latest") print \$2}" |
    sort -g -r |
    head -n 1
  )

  if [ "$version" == "" ]; then
    next_version=1
  else
    this_version=$(image_id $image_name $version)
    next_version=$(($version+1))
  fi

  tmp_repository_name="tmp_$image_name"
  tmp_image_version=$(uuidgen)
  docker build -f="docker/$docker_file" -t "$tmp_repository_name:$tmp_image_version" .
  image_id=$(image_id $tmp_repository_name $tmp_image_version)

  if [ "$this_version" == "$image_id" ]; then
    docker tag -f $image_id "$image_name:latest"
    echo "No changes, using $image_name:$version"
  else
    echo "Built $image_name:$next_version"
    docker tag $image_id "$image_name:$next_version"
    docker tag -f $image_id "$image_name:latest"
  fi
  docker rmi "$tmp_repository_name:$tmp_image_version" > /dev/null

  for old_version in $(
    docker images |
    awk "{if (\$1 == \"$image_name\" && \$2 != \"latest\") print \$2}" |
    sort -g -r |
    tail -n+3
  ); do
    docker rmi "$image_name:$old_version"
  done

  docker rmi $(docker images -f "dangling=true" -q) > /dev/null 2>&1
}

cd $(dirname ${BASH_SOURCE[0]})/..

build_versioned_image erlangelist/graphite graphite.dockerfile

build_versioned_image erlangelist/site-builder site-builder.dockerfile
id=$(docker create "erlangelist/site-builder:latest")
mkdir -p tmp
rm -rf tmp/* || true
docker cp $id:/tmp/erlangelist/site/rel/erlangelist/releases/0.0.1/erlangelist.tar.gz - > ./tmp/erlangelist.tar.gz
docker stop $id > /dev/null
docker rm -v $id > /dev/null

cd tmp && tar -xf erlangelist.tar.gz --to-stdout | tar -xzf -
cd ..
rm tmp/erlangelist.tar.gz
rm tmp/releases/0.0.1/*.tar.gz || true
build_versioned_image erlangelist/site site.dockerfile
