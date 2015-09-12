function start_container {
  echo "${@:2}"
  docker run --rm --name "$1" ${@:2}
}

function stop_container {
  for container in $(docker ps | grep "$1" | awk '{print $1}'); do
    docker stop -t 2 $container > /dev/null
  done

  for container in $(docker ps -a | grep "$1" | awk '{print $1}'); do
    docker rm $container > /dev/null
  done
}

function container_ctl {
  case "$2" in
    start)
      start_container $1 $START_ARGS
      ;;

    console)
      start_container $1 -it $START_ARGS
      ;;

    stop)
      stop_container $1
      ;;

    ssh)
      docker exec -it $1 /bin/bash
      ;;

    exec)
      command="${@:3}"
      docker exec -it $1 /bin/bash -c "$command"
  esac
}