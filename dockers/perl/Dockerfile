ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG remote_docker_registry
ARG perl_version=5.32.0

# start new from the dev docker, copy /opt to /opt
FROM ${remote_docker_registry}${docker_registry}/perl:${perl_version}-dev-latest as dev-sb-perl

# add CPAN modules that we need for this runtime
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -fTi common::sense
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -fTi JSON::XS

# start new to have an empty layer, we basically squash the docker here
FROM scratch
COPY --from=dev-sb-perl /opt/ /
ENV PATH=/opt/bin/:/opt/scripts:$PATH
MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
