ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG remote_docker_registry
ARG perl_version=5.32.0

FROM ${remote_docker_registry}${docker_registry}/perl:${perl_version}-lambda-dev-latest as prl
# things we never will need for an AWS Lambda (or, if needed, can be adde. for
# instance to make a cpan build system with lambda .. or so)
RUN rm -rf /opt/lib/perl5/*/CPAN
RUN rm -rf /opt/lib/perl5/*/ExtUtils
RUN rm -rf /opt/lib/perl5/*/Pod
RUN rm -rf /opt/lib/perl5/*/TAP
RUN rm -rf /opt/lib/perl5/*/pod
RUN rm -rf /opt/share
RUN rm -rf /opt/man

# unicode/unicore
RUN rm -rf /opt/lib/perl5/*/unicore
RUN rm -rf /opt/lib/perl5/*/Unicode/Collate

# cleanup now
RUN find /opt/lib/perl5/ -type f -name '.packlist'|xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.pod'    |xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.h'      |xargs rm
RUN rm -rf /opt/tmp
RUN rm -rf /opt/cpan_config.pl
RUN rm -rf /opt/scripts

# start new
FROM scratch

ENV perl_version=${perl_version:-5.32.0}
MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>

# there's a symlink /opt/opt -> /opt, so this should work in /opt/bin, or /bin/
COPY --from=prl  /opt /
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE

# ENV, ENTRYPOINT, CMD aren't really needed in this final docker make
ENV PERL5LIB=\
/opt/tmp/cpan_local/lib/perl5:\
/opt/tmp/cpan_local/lib/perl5/auto:\
/opt/tmp/cpan_local/lib/perl5/site_perl:\
/opt/tmp/cpan_local/lib/perl5/site_perl/auto:\
/opt/tmp/cpan_local/lib/perl5/x86_64:\
/opt/tmp/cpan_local/lib/perl5/x86_64/auto:\
/opt/lib/perl5:\
/opt/lib/perl5/site_perl:\
/opt/lib/perl5/site_perl/auto:\
/opt/lib/perl5/site_perl/$perl_version/:\
/opt/lib/perl5/site_perl/$perl_version/auto:\
/opt/lib/perl5/site_perl/$perl_version/x86_64:\
/opt/lib/perl5/site_perl/$perl_version/x86_64/auto:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/$perl_version:\
/opt/lib/perl5/$perl_version/auto:\
/opt/lib/perl5/$perl_version/x86_64:\
/opt/lib/perl5/$perl_version/x86_64/auto
ENTRYPOINT ["/opt/bin/perl"]
CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
