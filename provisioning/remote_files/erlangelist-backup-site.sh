#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

BACKUP_HTTP_PORT=$(($ERLANGELIST_SITE_HTTP_PORT + 500))
case "$1" in
  start)
    $(dirname ${BASH_SOURCE[0]})/erlangelist-site.sh backup startf &
    wait_for_site $BACKUP_HTTP_PORT

    # Temporary redirect 80 to the backup site
    iptables -t mangle -A PREROUTING -i eth1 -p tcp --dport $BACKUP_HTTP_PORT -j MARK --set-mark 1
    iptables -I INPUT 1 -i eth1 -m mark --mark 1 -p tcp --dport $BACKUP_HTTP_PORT -j LOG_AND_REJECT
    iptables -I INPUT 2 -i eth1 -p tcp --match multiport --dports 22,80,$ERLANGELIST_SITE_HTTP_PORT,$BACKUP_HTTP_PORT -j ACCEPT
    iptables -t nat -I PREROUTING 1 -i eth1 -p tcp --dport 80 -j REDIRECT --to-port $BACKUP_HTTP_PORT
    wait
    ;;

  stop)
    # remove previous rules (effectively reverting to the main site)
    iptables -t nat -D PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to-port $BACKUP_HTTP_PORT || true
    iptables -D INPUT -i eth1 -p tcp --match multiport --dports 22,80,$ERLANGELIST_SITE_HTTP_PORT,$BACKUP_HTTP_PORT -j ACCEPT || true
    iptables -D INPUT -i eth1 -m mark --mark 1 -p tcp --dport $BACKUP_HTTP_PORT -j LOG_AND_REJECT || true
    iptables -t mangle -D PREROUTING -i eth1 -p tcp --dport $BACKUP_HTTP_PORT -j MARK --set-mark 1 || true

    $(dirname ${BASH_SOURCE[0]})/erlangelist-site.sh backup stop
    ;;

  *)
    exit 1
    ;;
esac