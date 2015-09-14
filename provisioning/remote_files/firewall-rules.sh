#!/bin/bash

set -o pipefail

# Add the chain, just in case :-)
iptables -N LOG_AND_REJECT || true


# mangle

# We want to redirect 80 -> 5454, but forbid direct access to 5454. Thus, we'll
# mark this connection (since it's direct access to 5454), and reject it explicitly.
iptables -t mangle -A PREROUTING -i eth1 -p tcp --dport 5454 -j MARK --set-mark 1


# nat

# Insert nat rules for eth at the top. We'll deal with them ourselves and bypass
# whatever Docker (or anyone else) is doing.

# 80 -> 5454
iptables -t nat -i eth1 -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-port 5454

# No one else in the nat table touches our eth connections :-)
iptables -t nat -I PREROUTING 2 -i eth1 -j RETURN


# filter

# reject marked connection (direct access to 5454)
iptables -A INPUT -i eth1 -m mark --mark 1 -p tcp --dport 5454 -j LOG_AND_REJECT

# We allow only these ports
iptables -A INPUT -i eth1 -p tcp --match multiport --dports 22,80,5454 -j ACCEPT

# Reject everything else incoming on eth1
iptables -A INPUT -i eth1 -j LOG_AND_REJECT

# Nomen est omen :-)
iptables -A LOG_AND_REJECT -m limit --limit 10/min -j LOG --log-prefix "iptables rejected: " --log-level 7
iptables -A LOG_AND_REJECT -j REJECT