#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

echo "Configuring ports on $ERLANGELIST_NETWORK_IF"

# Add the chain, just in case :-)
iptables -N LOG_AND_REJECT || true


# mangle

# We want to redirect 80 -> $ERLANGELIST_SITE_HTTP_PORT, but forbid direct access
# to $ERLANGELIST_SITE_HTTP_PORT. Thus, we'll mark this connection (since it's
# direct access to $ERLANGELIST_SITE_HTTP_PORT), and reject it explicitly.
iptables -t mangle -A PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport $ERLANGELIST_SITE_HTTP_PORT -j MARK --set-mark 1


# nat

# Don't allow docker to route incoming traffic on $ERLANGELIST_NETWORK_IF. The site service will insert a custom rule
# at the top to manually route traffic on port 80.
iptables -t nat -I PREROUTING -i $ERLANGELIST_NETWORK_IF -j RETURN

# filter

# Allow all established/related
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow icmp
iptables -A INPUT -p icmp -j ACCEPT

# reject marked connection (direct access to $ERLANGELIST_SITE_HTTP_PORT)
iptables -A INPUT -i $ERLANGELIST_NETWORK_IF -m mark --mark 1 -p tcp --dport $ERLANGELIST_SITE_HTTP_PORT -j LOG_AND_REJECT

# Allow ssh
iptables -A INPUT -i $ERLANGELIST_NETWORK_IF -p tcp --dport 22 -j ACCEPT

# Drop broadcast/multicast without logging
iptables -A INPUT -i $ERLANGELIST_NETWORK_IF -m pkttype --pkt-type broadcast -j DROP
iptables -A INPUT -i $ERLANGELIST_NETWORK_IF -m pkttype --pkt-type multicast -j DROP

# Reject everything else incoming on $ERLANGELIST_NETWORK_IF
iptables -A INPUT -i $ERLANGELIST_NETWORK_IF -j LOG_AND_REJECT

# Nomen est omen :-)
iptables -A LOG_AND_REJECT -m limit --limit 10/min -j LOG --log-prefix "iptables rejected: " --log-level 7
iptables -A LOG_AND_REJECT -j REJECT
