FROM hopsoft/graphite-statsd:latest
RUN apt-get update && apt-get upgrade -y
COPY docker/graphite/storage-schemas.conf docker/graphite/storage-aggregation.conf /opt/graphite/conf/
COPY docker/graphite/start.sh /home/root/start.sh
COPY docker/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
