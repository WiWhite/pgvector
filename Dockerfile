ARG PG_MAJOR=17
ARG DEBIAN_CODENAME=bookworm

FROM debian:$DEBIAN_CODENAME AS builder

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

RUN cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install

RUN wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O /tmp/master.zip && \
    unzip /tmp/master.zip -d /tmp && \
    cp -r /tmp/dict_uk-master /tmp/dict_uk && \
    cd /tmp/dict_uk && ./gradlew expand && \
    cd distr/hunspell && ../../gradlew hunspell