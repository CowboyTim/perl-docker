ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}base-sandbox:latest as b-sb

WORKDIR /opt/src/perl

RUN \
       curl -sSL -k --insecure https://www.cpan.org/src/5.0/perl-5.32.0.tar.xz -o perl-5.32.0.tar.xz \
    && echo '6f436b447cf56d22464f980fac1916e707a040e96d52172984c5d184c09b859b *perl-5.32.0.tar.xz' | sha256sum -c - \
    && tar --strip-components=1 -xaf perl-5.32.0.tar.xz -C /opt/src/perl \
    && rm perl-5.32.0.tar.xz \
    && ./Configure           \
        -Duse64bitall        \
        -Darchname=x86_64    \
        -Duseshrplib         \
        -Dprefix=/opt/       \
        -Duselargefiles      \
        -des                 \
    && make -j8              \
    && make install

RUN cp /busybox /opt/busybox

# install CPAN modules for CPAN in /var/tmp/local
COPY cpan_config.pl /
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    ExtUtils::PkgConfig \
    CPAN
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    HTTP::Date \
    HTML::Tiny \
    install
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    Canary::Stability
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    Algorithm::Diff
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    Spiffy
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    Text::Diff
RUN /opt/bin/cpan -j /cpan_config.pl -Ti \
    Test::Base

# install CPAN modules for perl itself in /usr/local
RUN INSTALL_BASE=/opt /opt/bin/cpan -j /cpan_config.pl -Ti \
    JSON::XS

# not working, as needs extra libs installed
#RUN cpan -j /cpan_config.pl -Ti \
    #Net::Curl \
    #WWW::Curl::Easy

# cleanup stuff in /usr/local we never will need
RUN rm -rf /opt/src
RUN rm -rf /opt/share
RUN rm -rf /opt/man
RUN rm -rf /opt/include
RUN rm -rf /opt/games
RUN rm -rf /opt/lib/python*
RUN rm -rf /opt/lib/perl5/*/unicore
RUN rm -rf /opt/lib/perl5/*/pod
RUN find /opt/lib/perl5/ -type f -name '.packlist'|xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.pod'    |xargs rm
RUN find /opt/lib/perl5/ -type f -name '*.h'      |xargs rm

ENTRYPOINT ["/busybox", "sh"]
