FROM postgres:9.4.4
COPY docker/database/* /docker-entrypoint-initdb.d/