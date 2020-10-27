ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG remote_docker_registry
ARG perl_version=5.32.0

# we start this from the perl:<version>-dev-latest docker, so we have build tools
FROM ${remote_docker_registry}${docker_registry}/perl:${perl_version}-dev-latest as lambda-sb-perl

ENV perl_version=${perl_version:-5.32.0}
MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>

# base build stuff
RUN yum install -y make gcc tar gzip pkgconfig man groff

# needed for building PERL and possibly cpan stuff (note that they are not
# included in the end perl-sandbox as they don't go in /opt)
RUN yum install -y   \
        gdbm-devel   \
        libdb-devel  \
        gcc          \
        make         \
        tar          \
        curl         \
        xz           \
        gzip         \
        pkgconfig    \
        wget         \
        zip          \
        less         \
        bzip2        \
        bash         \
        ncurses-libs \
        coreutils    \
        findutils    \
        patch

# as the provided.al2 Amazon Linux 2 bootstrap lambda might be different then
# the glibc in /opt/lib64 from the perl docker we remove the glibc we added and
# make /opt/lib64 a sumlink to /lib64 just to be sure.
#
# This won't work when we use e.g. CentOS 8, as this has a newer glibc version
#RUN rm -rf /opt/lib64 && ln -s /lib64 /opt/lib64

ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE
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

# install perl extra cpan's, those go in /opt, as we add them to be used by
# Lambda note that if you need a module that's already added as a dependency in
# /opt/tmp/cpan_local, -fTi is needed to force install
RUN INSTALL_BASE=/opt /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -fTi common::sense
RUN INSTALL_BASE=/opt /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -fTi JSON::XS

# things we never will need for an AWS Lambda (or, if needed, can be adde. for
# instance to make a cpan build system with lambda .. or so)
RUN rm -rf /opt/lib/perl5/*/CPAN
RUN rm -rf /opt/lib/perl5/*/ExtUtils
RUN rm -rf /opt/lib/perl5/*/Pod
RUN rm -rf /opt/lib/perl5/*/TAP
RUN rm -rf /opt/lib/perl5/*/pod
RUN rm -rf /opt/share
RUN rm -rf /opt/man

# remove the cpan cache
RUN rm -rf /opt/perl/cpan && rmdir /opt/perl

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

# docker specific, won't be used for the lambda zip
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
