ARG docker_registry
ARG upstream_tag

#
# The PERL docker has everything in /opt, even the glibc. But nothing to build
# new CPAN's with, so we also merge from a regular centos docker to have make
# and other libraries, not even bash is there.
#
# Note that we can use other dockers to do this too
#

FROM ${docker_registry}perl-sandbox:latest    as lambda-sb-perl
FROM ${docker_registry}base-sandbox:latest    as build-helper
FROM scratch
COPY --from=build-helper    / /
COPY --from=lambda-sb-perl  /opt /opt

ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE
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
/opt/lib/perl5/site_perl/5.32.0/:\
/opt/lib/perl5/site_perl/5.32.0/auto:\
/opt/lib/perl5/site_perl/5.32.0/x86_64:\
/opt/lib/perl5/site_perl/5.32.0/x86_64/auto:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/5.32.0:\
/opt/lib/perl5/5.32.0/auto:\
/opt/lib/perl5/5.32.0/x86_64:\
/opt/lib/perl5/5.32.0/x86_64/auto

# install CPAN modules for CPAN in /opt/tmp/cpan_local. This is handled by
# cpan_config.pl. This is because we don't want cpan-needed modules in Lambda,
# we can't do anything with those and they take up space. Best is to look out
# for those while installing cpan modules that are needed, often they bring in
# dependencies that aren't needed later on at runtime
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  CPAN
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  YAML
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  ExtUtils::PkgConfig
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  ExtUtils::Helpers
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  HTTP::Date
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  HTML::Tiny
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  install
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Canary::Stability
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Algorithm::Diff
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Spiffy
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Text::Diff
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::Base
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::Deep
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::LeakTrace
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  inc::latest
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Module::Build
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  common::sense
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::More
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::Simple
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::Builder
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test::Harness
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test2
RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti  Test2::Formatter

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
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
