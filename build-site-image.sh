#!/bin/bash

set -o pipefail

function build_versioned_image {
  version=$(docker images | grep "$2" | awk '{print $2}' | sort -r | head -n 1)

  if [ "$version" == "" ]; then
    next_version=1
  else
    next_version=$(($version+1))
  fi
  image_tag="$2:$next_version"

  docker build -f="$1" --tag $image_tag . 1>&2
  echo "Built $image_tag" 1>&2
  echo "$image_tag"
}

image_tag=$(build_versioned_image site-builder.dockerfile erlangelist/site-builder)
id=$(docker create $image_tag)
mkdir -p tmp
rm -rf tmp/* || true
docker cp $id:/tmp/erlangelist/site/rel/erlangelist/releases/0.0.1/erlangelist.tar.gz - > ./tmp/erlangelist.tar.gz
docker stop $id
docker rm -v $id

cd tmp && tar -xzvf erlangelist.tar.gz --to-stdout | tar -xzvf -
cd ..
rm tmp/erlangelist.tar.gz
rm tmp/releases/0.0.1/*.tar.gz || true
build_versioned_image site.dockerfile erlangelist/site > /dev/null
