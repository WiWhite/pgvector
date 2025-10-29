
ARG PG_MAJOR=17
ARG DEBIAN_CODENAME=bookworm

FROM debian:${DEBIAN_CODENAME} AS builder

ARG PG_MAJOR
ARG DEBIAN_CODENAME

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        wget \
        unzip \
        build-essential \
        default-jdk-headless \
    && \
    curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ ${DEBIAN_CODENAME}-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-server-dev-${PG_MAJOR} \
        make \
        gcc \
    && \
    rm -rf /var/lib/apt/lists/*

ARG PGVECTOR_VERSION=0.8.1
RUN mkdir -p /tmp/pgvector && \
    cd /tmp && \
    wget -O pgvector.tar.gz https://github.com/WiWhite/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz && \
    tar -xzf pgvector.tar.gz -C /tmp && \
    mv /tmp/pgvector-* /tmp/pgvector && \
    cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install

# 3. Побудова словника dict_uk
RUN wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O /tmp/master.zip && \
    unzip /tmp/master.zip -d /tmp && \
    mv /tmp/dict_uk-master /tmp/dict_uk && \
    cd /tmp/dict_uk && ./gradlew expand && \
    cd /tmp/dict_uk/distr/hunspell && ../../gradlew hunspell

FROM postgres:${PG_MAJOR}-bookworm

COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/vector.so /usr/lib/postgresql/${PG_MAJOR}/lib/vector.so
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/vector* /usr/share/postgresql/${PG_MAJOR}/extension/

RUN mkdir -p /usr/share/hunspell
COPY --from=builder /tmp/dict_uk/distr/hunspell/*.aff /usr/share/hunspell/
COPY --from=builder /tmp/dict_uk/distr/hunspell/*.dic /usr/share/hunspell/

RUN chmod 644 /usr/share/hunspell/*

