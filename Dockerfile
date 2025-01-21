ARG PG_MAJOR=17
FROM postgres:$PG_MAJOR

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-server-dev-17 \
    wget \
    unzip \
    default-jdk && \
    rm -rf /var/lib/apt/lists/*

COPY . /tmp/pgvector
RUN cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install && \
    mkdir /usr/share/doc/pgvector && \
    cp LICENSE README.md /usr/share/doc/pgvector && \
    rm -r /tmp/pgvector

RUN wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O master.zip && \
    wget https://services.gradle.org/distributions/gradle-8.12-bin.zip -O gradle-8.12-bin.zip && \
    unzip master.zip && \
    mkdir -p /opt/gradle && \
    unzip -d /opt/gradle gradle-8.12-bin.zip && \
    export PATH=$PATH:/opt/gradle/gradle-8.12/bin && \
    cd dict_uk && ./gradlew expand && \
    cd distr/hunspell && ../../gradlew hunspell && \
    cp build/hunspell/uk_UA.aff /usr/share/postgresql/17/tsearch_data/uk_ua.affix && \
    cp build/hunspell/uk_UA.dic /usr/share/postgresql/17/tsearch_data/uk_ua.dict && \
    rm -rf /opt/gradle gradle-8.12-bin.zip master.zip dict_uk

RUN apt-get remove -y \
    build-essential \
    postgresql-server-dev-17 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
