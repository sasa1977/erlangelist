#!/bin/bash

set -o pipefail

docker build -f=site-builder.dockerfile .
image_id=$(docker images | head -n 2 | tail -n 1 | awk '{print $3}')
id=$(docker create $image_id)
mkdir -p tmp
rm -rf tmp/* || true
docker cp $id:/tmp/erlangelist/site/rel/erlangelist/releases/0.0.1/erlangelist.tar.gz - > ./tmp/erlangelist.tar.gz
docker stop $id
docker rm -v $id
docker rmi $image_id

cd tmp && tar -xzvf erlangelist.tar.gz --to-stdout | tar -xzvf -
cd ..
rm tmp/erlangelist.tar.gz
rm tmp/releases/0.0.1/*.tar.gz || true
docker build -f=site.dockerfile .

image_id=$(docker images | head -n 2 | tail -n 1 | awk '{print $3}')
version=$(docker images | grep "erlangelist/site" | awk '{print $2}' | sort -r | head -n 1)

if [ "$version" == "" ]; then
  next_version=1
else
  next_version=$(($version+1))
fi
image_tag="erlangelist/site:$next_version"
echo "Tagging version $image_tag"
docker tag $image_id $image_tag