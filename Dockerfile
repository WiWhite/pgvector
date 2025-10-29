# syntax=docker/dockerfile:1

ARG PG_MAJOR=17
ARG DEBIAN_CODENAME=bookworm

FROM debian:$DEBIAN_CODENAME AS builder

ARG PG_MAJOR
ARG DEBIAN_CODENAME

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
    && \
    curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $DEBIAN_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    \
    apt-get update && \
    \
    apt-get install -y --no-install-recommends \
        build-essential \
        postgresql-server-dev-$PG_MAJOR \
        wget \
        unzip \
        default-jdk-headless \
    && \
    apt-get purge -y --auto-remove curl gnupg && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/pgvector && \
    cd /tmp && \
    wget -O pgvector.tar.gz https://github.com/WiWhite/pgvector/archive/refs/tags/v0.8.1.tar.gz && \
    tar -xzf pgvector.tar.gz -C /tmp/pgvector --strip-components=1 && \
    rm pgvector.tar.gz && \
    cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install && \
    rm -rf /tmp/pgvector

RUN export _JAVA_OPTIONS="-Dfile.encoding=UTF-8" && \
    export LANG=C.UTF-8 && \
    wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O /tmp/master.zip && \
    unzip /tmp/master.zip -d /tmp && \
    cp -r /tmp/dict_uk-master /tmp/dict_uk && \
    cd /tmp/dict_uk && ./gradlew expand && \
    cd distr/hunspell && ../../gradlew hunspell && \
    rm -rf /tmp/master.zip /tmp/dict_uk-master

FROM postgres:$PG_MAJOR-$DEBIAN_CODENAME

ARG PG_MAJOR

COPY --from=builder /usr/lib/postgresql/$PG_MAJOR/lib/vector.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=builder /usr/share/postgresql/$PG_MAJOR/extension/vector* /usr/share/postgresql/$PG_MAJOR/extension/

COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.aff /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.affix
COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.dic /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.dict
COPY --from=builder /tmp/dict_uk/distr/postgresql/ukrainian.stop /usr/share/postgresql/$PG_MAJOR/tsearch_data/ukrainian.stop