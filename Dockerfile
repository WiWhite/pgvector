# syntax=docker/dockerfile:1

ARG PG_MAJOR=17
ARG DEBIAN_CODENAME=bookworm

FROM debian:$DEBIAN_CODENAME AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        postgresql-server-dev-$PG_MAJOR \
        wget \
        unzip \
        default-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

ARG PG_MAJOR
ADD https://github.com/WiWhite/pgvector.git#v0.8.1 /tmp/pgvector
RUN cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install

RUN wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O /tmp/master.zip && \
    unzip /tmp/master.zip -d /tmp && \
    cp -r /tmp/dict_uk-master /tmp/dict_uk && \
    cd /tmp/dict_uk && ./gradlew expand && \
    cd distr/hunspell && ../../gradlew hunspell

FROM postgres:$PG_MAJOR-$DEBIAN_CODENAME
ARG PG_MAJOR

COPY --from=builder /usr/lib/postgresql/$PG_MAJOR/lib/pgvector.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=builder /usr/share/postgresql/$PG_MAJOR/extension/pgvector* /usr/share/postgresql/$PG_MAJOR/extension/

COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.aff /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.affix
COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.dic /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.dict
COPY --from=builder /tmp/dict_uk/distr/postgresql/ukrainian.stop /usr/share/postgresql/$PG_MAJOR/tsearch_data/ukrainian.stop
