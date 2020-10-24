ARG docker_registry
ARG upstream_tag
LABEL maintainer='Tim Aerts <aardbeiplantje@gmail.com>'
FROM amazonlinux:2-with-sources as base-image
FROM busybox:1.32.0             as busybox
FROM scratch
COPY --from=base-image / /
COPY --from=busybox    /bin/busybox /

RUN yum install -y make gcc tar gzip pkgconfig man groff

ENTRYPOINT ["/usr/bin/bash", "-i"]
