ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG perl_version=5.32.0
ARG remote_docker_registry

# start new from the dev docker, copy /opt to /opt
FROM ${docker_registry}perl:${perl_version}-dev-latest as dev-sb-perl

ENV perl_version=${perl_version:-5.32.0}

# cleanup cpan stuff
RUN rm -rf /opt/tmp/cpan_local && rm -rf /opt/tmp && rm -rf /opt/perl

# setup a /tmp for File::Temp
RUN mkdir /opt/tmp && chmod 1777 /opt/tmp

# start new to have an empty layer
FROM scratch
COPY --from=dev-sb-perl /opt /opt

ENV perl_version=${perl_version:-5.32.0}

MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>

# ENV variables, still set TMPDIR for File::Temp
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/${perl_version}/x86_64/CORE
ENV PERL5LIB=\
/opt/lib/perl5:\
/opt/lib/perl5/site_perl:\
/opt/lib/perl5/site_perl/auto:\
/opt/lib/perl5/site_perl/${perl_version}/:\
/opt/lib/perl5/site_perl/${perl_version}/auto:\
/opt/lib/perl5/site_perl/${perl_version}/x86_64:\
/opt/lib/perl5/site_perl/${perl_version}/x86_64/auto:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/${perl_version}:\
/opt/lib/perl5/${perl_version}/auto:\
/opt/lib/perl5/${perl_version}/x86_64:\
/opt/lib/perl5/${perl_version}/x86_64/auto
ENV PATH=/opt/bin/:/opt:$PATH
ENV TMPDIR=/opt/tmp

# entrypoint + cmd, default to exec of /bin/sh
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
