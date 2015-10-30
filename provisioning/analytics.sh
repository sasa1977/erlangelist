#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

function run_sql {
  PGPASSWORD="$ERLANGELIST_DB_PASSWORD" psql \
  -h 127.0.0.1 -p $ERLANGELIST_POSTGRES_PORT \
  -U erlangelist -d erlangelist \
  -c "$1"
}

machine="$1"
shift

if [ "$machine" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine [psql_interval]\n\n"
  exit 1
fi

# defaults
interval="2 hours"

# parse options
while [ $# -gt 0 ]; do
  case "$1" in
    -i)
      interval="$2"
      shift 2
      ;;

    -no-rss)
      no_rss="true"
      shift
      ;;

    *)
      echo "Unknown parameter $1"
      exit 1
      ;;
  esac
done


settings=$(ssh $machine "cat /opt/erlangelist/erlangelist-settings.sh")
eval $settings

ssh -L $ERLANGELIST_POSTGRES_PORT:127.0.0.1:$ERLANGELIST_POSTGRES_PORT $machine "sleep infinity" &
pid=$!

until nc -z 127.0.0.1 $ERLANGELIST_POSTGRES_PORT; do
  sleep 0.1
done

basic_filter="
  created_at > now() - INTERVAL '$interval'
  and path not like '/2014/%'
  and path not like '/2015/%'
"

if [ "$no_rss" == "true" ]; then
  basic_filter="
    $basic_filter
    and ip not in (
      select distinct ip from request_log
      where $basic_filter and (
        path = '/feeds/posts/default' or
        path = '/rss'
      )
    )
  "
fi

run_sql "
  select count(*) total from request_log
  where $basic_filter
"

run_sql "
  select path, count(*) from request_log
  where $basic_filter
  group by path
  order by count(*) desc
  limit 10
"

run_sql "
  select country, count(*) from request_log
  where $basic_filter
  group by country
  order by count(*) desc
  limit 10
"

run_sql "
  select
    regexp_replace(
      regexp_replace(referer, '(www\.)?google\.(.*?)($|/)', 'google\\3'),
      '.*://(.*?)($|/).*', '\\1'
    ) referer_host,
    count(*)
  from request_log
  where
    $basic_filter
    and referer is not null
    and referer <> ''
    and referer not like '%theerlangelist.com%'
  group by referer_host
  order by count(*) desc
  limit 10
"

run_sql "
  select
    regexp_replace(
      regexp_replace(referer, '(www\.)?google\.(.*?)($|/)', 'google\\3'),
      '.*://(.*?)(($|/).*)', '\\1\\2'
    ) referer_url,
    count(*)
  from request_log
  where
    $basic_filter
    and referer is not null
    and referer <> ''
    and referer not like '%theerlangelist.com%'
  group by referer_url
  order by count(*) desc
  limit 10
"

kill -9 $pid || true
