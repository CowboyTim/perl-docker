ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}perl-sandbox:latest    as lambda-sb-perl
FROM scratch
COPY --from=lambda-sb-perl / /
