FROM postgres:9.4.6
COPY docker/database/* /docker-entrypoint-initdb.d/
