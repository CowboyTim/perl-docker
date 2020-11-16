ARG perl_version=5.32.0

# start from the perl-dev docker
FROM aardbeiplantje/perl:${perl_version}-dev-latest as my-perl-d

# reset the PATH to not include /opt first
ARG perl_version=5.32.0
ENV perl_version=${perl_version}
ENV PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
ENV DESTDIR=/newopt/
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE

# install ssl libraries + copy them over to /opt/lib64
RUN yum install -y                                              \
        openssl                                                 \
        openssl-devel                                           \
    && yum clean all                                            \
    && rm -rf /var/lib/yum/repos                                \
    && mkdir -p                             $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libssl.so*          $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libgssapi_krb5.so*  $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libcom_err.so*      $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libz*.so*           $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libk5crypto*.so*    $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libkrb5*.so*        $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libkrb5support*.so* $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libkeyutils*.so*    $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libresolv*.so*      $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libcrypto*.so*      $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libselinux*.so*     $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libpcre*.so*        $DESTDIR/opt/lib64/ \
    && cp -a /usr/lib64/libdl*.so*          $DESTDIR/opt/lib64/

# see cpan_config.pl!! Add trailing slash (/)!!
ENV DESTDIR=/newopt/
ENV INSTALL_BASE=" DESTDIR=\$DESTDIR"
# PERL5LIB correct: /opt + /newopt
ENV PERL5LIB=\
$DESTDIR/opt/site_perl/lib/perl5:\
$DESTDIR/opt/site_perl/lib/perl5/site_perl/auto:\
$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version:\
$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version/x86_64-linux:\
$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version/x86_64-linux/auto:\
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

# add a cpan module with the provided cpan config
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti    \
    IO::Socket::SSL                                           \
    URI                                                       \
    ; rm -rf $DESTDIR/opt/site_perl/share                     \
    ; rm -rf $DESTDIR/opt/site_perl/man                       \
    ; rm -rf $DESTDIR/opt/lib                                 \
    ; find   $DESTDIR/ -type f -name '.packlist' |xargs rm -f \
    ; find   $DESTDIR/ -type f -name '.pc'       |xargs rm -f \
    ; find   $DESTDIR/ -type f -name '.h'        |xargs rm -f \
    ; find   $DESTDIR/ -type f -name '.pod'      |xargs rm -f \
    ; exit 0

# a simple test
RUN /opt/bin/perl -MIO::Socket::SSL -we \
    'print "[OK] CPAN TEST 1 IO::Socket::SSL built, version: $IO::Socket::SSL::VERSION\n"'
RUN /opt/bin/perl -MURI -we \
    'print "[OK] CPAN TEST 1 URI built, version: $URI::VERSION\n"'

# start a new scratch with runtime perl and move to / just to test (without PERL5LIB set!)
FROM aardbeiplantje/perl:${perl_version} as test-perl-cpan
FROM scratch
COPY --from=my-perl-d /newopt/opt/ /
COPY --from=test-perl-cpan / /
ENV DESTDIR=
ENV INSTALL_BASE=
ENV LD_LIBRARY_PATH=
ENV PERL5LIB=
RUN /opt/bin/perl -MIO::Socket::SSL -we \
    'print "[OK] CPAN TEST 1 IO::Socket::SSL built, version: $IO::Socket::SSL::VERSION\n"'
RUN /opt/bin/perl -MURI -we \
    'print "[OK] CPAN TEST 1 URI built, version: $URI::VERSION\n"'

# squash the docker, by starting from scratch
FROM scratch
COPY --from=my-perl-d /newopt/opt/ /
ENV PATH=/opt/bin/:/opt/scripts:$PATH
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]

