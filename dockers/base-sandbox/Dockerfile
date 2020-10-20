ARG docker_registry
ARG upstream_tag

FROM amazonlinux:2-with-sources as base-image
FROM busybox:1.32.0             as busybox
FROM scratch
COPY --from=base-image / /
COPY --from=busybox    /bin/busybox /

RUN yum install -y make gcc tar gzip pkgconfig

ENTRYPOINT ["/usr/bin/bash", "-i"]
