FROM alpine:3.21

RUN apk add --no-cache openssl

COPY build/secrets/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
