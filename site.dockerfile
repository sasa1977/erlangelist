FROM ubuntu:14.04

RUN apt-get -y update\
    && dpkg-reconfigure locales \
    && locale-gen en_US.UTF-8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN mkdir -p /erlangelist
COPY tmp /erlangelist/