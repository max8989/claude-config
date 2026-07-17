FROM alpine:3.20
# Pin a known-good PocketBase release. Check the latest before scaffolding:
#   https://github.com/pocketbase/pocketbase/releases
ARG PB_VERSION=0.35.0
# tzdata: without it Go can't resolve TZ and silently runs on UTC.
RUN apk add --no-cache ca-certificates unzip wget tzdata
WORKDIR /pb
RUN wget -q https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
    && unzip pocketbase_${PB_VERSION}_linux_amd64.zip \
    && rm pocketbase_${PB_VERSION}_linux_amd64.zip
EXPOSE 8090
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090"]
