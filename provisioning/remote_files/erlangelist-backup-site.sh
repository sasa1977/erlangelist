#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

BACKUP_HTTP_PORT=$(($ERLANGELIST_SITE_HTTP_PORT + 500))
BACKUP_HTTPS_PORT=$(($ERLANGELIST_SITE_HTTPS_PORT + 500))
case "$1" in
  start)
    $(dirname ${BASH_SOURCE[0]})/erlangelist-site.sh backup startf &
    wait_for_site $BACKUP_HTTP_PORT

    # Temporary redirect to the backup site
    iptables -t mangle -A PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport $BACKUP_HTTP_PORT -j MARK --set-mark 1
    iptables -I INPUT 1 -i $ERLANGELIST_NETWORK_IF -m mark --mark 1 -p tcp --dport $BACKUP_HTTP_PORT -j LOG_AND_REJECT

    iptables -t mangle -A PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport $BACKUP_HTTPS_PORT -j MARK --set-mark 1
    iptables -I INPUT 1 -i $ERLANGELIST_NETWORK_IF -m mark --mark 1 -p tcp --dport $BACKUP_HTTPS_PORT -j LOG_AND_REJECT

    /opt/erlangelist/erlangelist-site-firewall.sh startf erlangelist-backup-site
    wait
    ;;

  stop)
    # revert back to the main site
    /opt/erlangelist/erlangelist-site-firewall.sh stop erlangelist-backup-site
    iptables -D INPUT -i $ERLANGELIST_NETWORK_IF -m mark --mark 1 -p tcp --dport $BACKUP_HTTP_PORT -j LOG_AND_REJECT || true
    iptables -t mangle -D PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport $BACKUP_HTTP_PORT -j MARK --set-mark 1 || true

    iptables -D INPUT -i $ERLANGELIST_NETWORK_IF -m mark --mark 1 -p tcp --dport $BACKUP_HTTPS_PORT -j LOG_AND_REJECT || true
    iptables -t mangle -D PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport $BACKUP_HTTPS_PORT -j MARK --set-mark 1 || true

    $(dirname ${BASH_SOURCE[0]})/erlangelist-site.sh backup stop
    ;;

  *)
    exit 1
    ;;
esac
