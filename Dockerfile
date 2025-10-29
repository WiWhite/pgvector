# syntax=docker/dockerfile:1

# --- Глобальні аргументи ---
# Оголошуємо до 'FROM', щоб вони були доступні в 'FROM' інструкціях
ARG PG_MAJOR=17
ARG DEBIAN_CODENAME=bookworm

# --- Етап 1: "Builder" ---
# Використовуємо повний образ Debian з інструментами для збірки
FROM debian:$DEBIAN_CODENAME AS builder

# Повторно оголошуємо аргументи, щоб вони були доступні всередині RUN
ARG PG_MAJOR
ARG DEBIAN_CODENAME

# Встановлюємо ВСІ залежності для збірки (PostgreSQL + Словники)
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

# 1. Збірка pgvector
RUN mkdir -p /tmp/pgvector && \
    cd /tmp && \
    wget -O pgvector.tar.gz https://github.com/WiWhite/pgvector/archive/refs/tags/v0.8.1.tar.gz && \
    # Використовуємо strip-components=1, щоб покласти вміст прямо в /tmp/pgvector
    tar -xzf pgvector.tar.gz -C /tmp/pgvector --strip-components=1 && \
    rm pgvector.tar.gz && \
    cd /tmp/pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install

# 2. Збірка словників
RUN wget https://github.com/brown-uk/dict_uk/archive/refs/heads/master.zip -O /tmp/master.zip && \
    unzip /tmp/master.zip -d /tmp && \
    cp -r /tmp/dict_uk-master /tmp/dict_uk && \
    cd /tmp/dict_uk && ./gradlew expand && \
    cd distr/hunspell && ../../gradlew hunspell && \
    rm -rf /tmp/master.zip /tmp/dict_uk-master


# --- Етап 2: Фінальний образ ---
# Починаємо з чистого образу postgres
FROM postgres:$PG_MAJOR-$DEBIAN_CODENAME

# Повторно оголошуємо ARG для використання в COPY
ARG PG_MAJOR

# Копіюємо зібрані артефакти з етапу "builder"

# 1. Копіюємо скомпільований pgvector
COPY --from=builder /usr/lib/postgresql/$PG_MAJOR/lib/pgvector.so /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=builder /usr/share/postgresql/$PG_MAJOR/extension/pgvector* /usr/share/postgresql/$PG_MAJOR/extension/

# 2. Копіюємо зібрані словники
COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.aff /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.affix
COPY --from=builder /tmp/dict_uk/distr/hunspell/build/hunspell/uk_UA.dic /usr/share/postgresql/$PG_MAJOR/tsearch_data/uk_ua.dict
COPY --from=builder /tmp/dict_uk/distr/postgresql/ukrainian.stop /usr/share/postgresql/$PG_MAJOR/tsearch_data/ukrainian.stop