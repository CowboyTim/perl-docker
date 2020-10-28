ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG remote_docker_registry
ARG perl_version=5.32.0

# start new from the dev docker, copy /opt to /opt
FROM ${remote_docker_registry}${docker_registry}/perl:${perl_version}-dev-latest as dev-sb-perl

ARG perl_version=5.32.0
ENV PERL_VERSION=${perl_version:-5.32.0}

# cleanup cpan stuff
RUN rm -rf /opt/tmp/cpan_local && rm -rf /opt/tmp && rm -rf /opt/perl

# setup a /tmp for File::Temp
RUN mkdir /opt/tmp && chmod 1777 /opt/tmp

# for easy script adding, this is also added to the PATH
RUN mkdir /opt/scripts

# start new to have an empty layer
FROM scratch
COPY --from=dev-sb-perl /opt /opt

ARG perl_version=5.32.0
ENV PERL_VERSION=${perl_version:-5.32.0}
MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>

# ENV variables, still set TMPDIR for File::Temp
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/${PERL_VERSION}/x86_64/CORE
ENV PERL5LIB=\
/opt/lib/perl5:\
/opt/lib/perl5/site_perl:\
/opt/lib/perl5/site_perl/auto:\
/opt/lib/perl5/site_perl/${PERL_VERSION}/:\
/opt/lib/perl5/site_perl/${PERL_VERSION}/auto:\
/opt/lib/perl5/site_perl/${PERL_VERSION}/x86_64:\
/opt/lib/perl5/site_perl/${PERL_VERSION}/x86_64/auto:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/${PERL_VERSION}:\
/opt/lib/perl5/${PERL_VERSION}/auto:\
/opt/lib/perl5/${PERL_VERSION}/x86_64:\
/opt/lib/perl5/${PERL_VERSION}/x86_64/auto
ENV PATH=/opt/bin/:/opt/scripts:$PATH
ENV TMPDIR=/opt/tmp

# entrypoint + cmd, default to exec of /bin/sh
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
#CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
