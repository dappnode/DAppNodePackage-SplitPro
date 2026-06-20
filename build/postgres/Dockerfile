ARG POSTGRES_MAJOR=17
ARG POSTGRES_MINOR=7
ARG POSTGRES_BASE=trixie

FROM postgres:${POSTGRES_MAJOR}.${POSTGRES_MINOR}-${POSTGRES_BASE}

ARG POSTGRES_MAJOR

RUN apt-get update && apt-get install -y \
    postgresql-${POSTGRES_MAJOR}-cron \
    && rm -rf /var/lib/apt/lists/*
