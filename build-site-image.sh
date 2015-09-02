#!/bin/bash

set -o pipefail

function image_id {
  docker images | awk "{if (\$1 == \"$1\" && \$2 == \"$2\") print \$3}"
}

function build_versioned_image {
  version=$(docker images | awk "{if (\$1 == \"$2\") print \$2}" | sort -g -r | head -n 1)

  if [ "$version" == "" ]; then
    next_version=1
  else
    this_version=$(image_id $2 $version)
    next_version=$(($version+1))
  fi
  next_version_tag="$2:$next_version"

  docker build -f="$1" --tag $next_version_tag . 1>&2

  if [ "$this_version" == "$(image_id $2 $next_version)" ]; then
    docker rmi "$next_version_tag" 1>&2
    echo "No changes, using $2:$version" 1>&2
    echo "$2:$version"
  else
    for old_version in $(
      docker images |
      awk "{if (\$1 == \"$2\") print \$2}" |
      sort -g -r |
      tail -n+3
    ); do
      docker rmi "$2:$old_version" 1>&2
    done

    docker rmi $(docker images -f "dangling=true" -q) > /dev/null 2>&1

    echo "Built $next_version_tag" 1>&2
    echo "$next_version_tag"
  fi
}

image_tag=$(build_versioned_image site-builder.dockerfile erlangelist/site-builder)
id=$(docker create $image_tag)
mkdir -p tmp
rm -rf tmp/* || true
docker cp $id:/tmp/erlangelist/site/rel/erlangelist/releases/0.0.1/erlangelist.tar.gz - > ./tmp/erlangelist.tar.gz
docker stop $id
docker rm -v $id

cd tmp && tar -xzvf erlangelist.tar.gz --to-stdout | tar -xzf -
cd ..
rm tmp/erlangelist.tar.gz
rm tmp/releases/0.0.1/*.tar.gz || true
build_versioned_image site.dockerfile erlangelist/site > /dev/null
