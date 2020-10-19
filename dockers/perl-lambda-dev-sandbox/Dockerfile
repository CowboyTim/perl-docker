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
/opt/lib/perl5:\
/opt/lib/perl5/vendor_perl:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/vendor_perl/auto:\
/opt/lib/perl5/x86_64:\
/opt/lib/perl5/x86_64/auto:\
/opt/lib64/perl5:\
/opt/lib64/perl5/vendor_perl:\
/opt/lib64/perl5/auto:\
/opt/lib64/perl5/vendor_perl/auto:\
/opt/lib64/perl5/x86_64:\
/opt/lib64/perl5/x86_64/auto:\
/opt/tmp/cpan_local/lib/perl5:\
/opt/tmp/cpan_local/lib/perl5/x86_64:\
/opt/tmp/cpan_local/lib/perl5/x86_64/auto

# install perl extra cpan's
RUN INSTALL_BASE=/opt /opt/lib64/ld-2.28.so /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti Storable
RUN INSTALL_BASE=/opt /opt/lib64/ld-2.28.so /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti JSON::XS
RUN INSTALL_BASE=/opt /opt/lib64/ld-2.28.so /opt/bin/perl /opt/bin/cpan -j /opt/cpan_config.pl -Ti POSIX::strptime

# things we never will need for an AWS Lambda (or, if needed, can be adde. for
# instance to make a cpan build system with lambda .. or so)
RUN rm -rf /opt/lib/perl5/*/CPAN
RUN rm -rf /opt/lib/perl5/*/ExtUtils
RUN rm -rf /opt/lib/perl5/*/Pod
RUN rm -rf /opt/lib/perl5/*/TAP

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
ENTRYPOINT ["/opt/lib64/ld-2.28.so", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/busybox', 'sh'"]
