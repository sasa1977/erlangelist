#!/bin/bash

set -o pipefail

cd /opt/graphite/webapp/graphite/ && echo no | python ./manage.py syncdb
exec /sbin/my_init