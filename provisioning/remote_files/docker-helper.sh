. $(dirname ${BASH_SOURCE[0]})/erlangelist-ports.sh

function start_container {
  docker run --name "$1" ${@:2}
}

function stop_container {
  for container in $(docker ps | grep "$1" | awk '{print $1}'); do
    docker stop -t 2 $container > /dev/null
  done

  for container in $(docker ps -a | grep "$1" | awk '{print $1}'); do
    docker rm $container > /dev/null
  done
}

function needs_restart {
  if [ -z "$(docker ps --filter=name=$1 | grep -v CONTAINER)" ]; then
    echo "yes"
  else
    image_id=$(docker inspect -f="{{.Image}}" $1)
    image_name=$(
      docker images --no-trunc |
      awk "{if (\$3 == \"$image_id\" && \$1 ~ /^erlangelist\/.+$/) print \$1}" |
      sort |
      uniq
    )

    latest_id=$(
      docker images --no-trunc |
      awk "{if (\$1 == \"$image_name\" && \$1 ~ /^erlangelist\/.+$/ && \$2 == \"latest\") print \$3}" |
      sort |
      uniq
    )

    if [ "$image_id" == "$latest_id" ]; then echo "no"; else echo "yes"; fi
  fi
}

function container_ctl {
  case "$2" in
    startf)
      start_container $1 "--rm $START_ARGS"
      ;;

    startd)
      start_container $1 "-d $START_ARGS"
      ;;

    console)
      start_container $1 "--rm -it $START_ARGS"
      ;;

    stop)
      stop_container $1
      ;;

    ssh)
      docker exec -u root -it $1 /bin/bash
      ;;

    needs_restart)
      needs_restart $1
      ;;

    exec)
      command="${@:3}"
      docker exec -it $1 /bin/bash -c "$command"
  esac
}

function http_site_up {
  curl --silent http://127.0.0.1:$1 > /dev/null || return 1
  return 0
}

function wait_for_site {
  until http_site_up $1; do
    echo "waiting for the localhost:$1 ..."
    sleep 1
  done
  echo "localhost:$1 running"
}
