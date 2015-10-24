FROM alpine:3.2

RUN echo 'http://dl-4.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories \
    && echo 'http://dl-4.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories \
    && apk --update add ncurses-libs=6.0-r0 bash && rm -rf /var/cache/apk/*

ENV SHELL=/bin/bash TERM=xterm

RUN adduser -h /erlangelist -s /bin/bash -D erlangelist
COPY tmp /erlangelist/
RUN chown -R erlangelist:erlangelist /erlangelist

# Default pass is blank, so generate a random root pass.
RUN \
  password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;) \
  && printf "$password\n$password\n" | passwd root

COPY docker/site/run.sh /erlangelist/

USER erlangelist
