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

# install perl extra cpan's
RUN INSTALL_BASE=/opt /opt/bin/cpan -j /opt/cpan_config.pl -Ti Storable
RUN INSTALL_BASE=/opt /opt/bin/cpan -j /opt/cpan_config.pl -Ti JSON::XS

# cleanup now
RUN find /opt/lib/perl5/ -type f -name '.packlist'|xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.pod'    |xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.h'      |xargs rm
RUN rm -rf /opt/tmp

# docker specific, won't be used for the lambda zip
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE
ENTRYPOINT ["/opt/lib64/ld-2.28.so", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/busybox', 'sh'"]
