# start from the perl-dev docker
FROM aardbeiplantje/perl:5.32.0-dev-latest as my-perl-d

# reset the PATH to not include /opt first
ENV perl_version=5.32.0
ENV PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
ENV INSTALL_BASE=/newopt
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE

# dev stuff can go in my-perl-d in /
RUN yum install -y \
        openssl openssl-devel

# copy over extra libraries that are needed for ssl
RUN    mkdir -p                             $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libssl.so*          $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libgssapi_krb5.so*  $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libcom_err.so*      $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libz*.so*           $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libk5crypto*.so*    $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libkrb5*.so*        $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libkrb5support*.so* $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libkeyutils*.so*    $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libresolv*.so*      $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libcrypto*.so*      $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libselinux*.so*     $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libpcre*.so*        $INSTALL_BASE/lib64/ \
    && cp -a /usr/lib64/libdl*.so*          $INSTALL_BASE/lib64/

# PERL5LIB correct: /opt + /newopt
ENV PERL5LIB=\
$INSTALL_BASE/lib/perl5:\
$INSTALL_BASE/lib/perl5/auto:\
$INSTALL_BASE/lib/perl5/site_perl:\
$INSTALL_BASE/lib/perl5/site_perl/auto:\
$INSTALL_BASE/lib/perl5/x86_64:\
$INSTALL_BASE/lib/perl5/x86_64/auto:\
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
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti \
    IO::Socket::SSL         \
    ; exit 0

#
# RUNTIME:
#
# cleanup stuff in /opt we never will need. This of course needs to be double
# checked when adding things, sometimes things are actually needed for the app
# to work
#
# when this is ment as a development style perl docker with the extra cpan/libs
# installed, these might be kept as they contain valuable documentation
#
RUN   rm -rf $INSTALL_BASE/share                                 \
    ; rm -rf $INSTALL_BASE/man                                   \
    ; find $INSTALL_BASE/ -type f -name '.packlist' |xargs rm -f \
    ; find $INSTALL_BASE/ -type f -name '.pc'       |xargs rm -f \
    ; find $INSTALL_BASE/ -type f -name '.h'        |xargs rm -f \
    ; find $INSTALL_BASE/ -type f -name '.pod'      |xargs rm -f \
    ; exit 0 

# squash the docker, by starting from scratch
FROM scratch
COPY --from=my-perl-d /newopt/ /
ENV PATH=/opt/bin/:/opt/scripts:$PATH
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]

