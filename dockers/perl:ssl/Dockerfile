# start from the perl-dev docker
FROM aardbeiplantje/perl:5.32.0-dev-latest as my-perl-d

# reset the PATH to not include /opt first
ENV PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH

# dev stuff can go in my-perl-d in /
RUN yum install -y \
        openssl openssl-devel

# add a cpan module with the provided cpan config
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti \
    IO::Socket::SSL         \
    ; exit 0

# copy over extra libraries that are needed for ssl
RUN    mkdir -p                             /opt/lib64/ \
    && cp -a /usr/lib64/libssl.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libgssapi_krb5.so*  /opt/lib64/ \
    && cp -a /usr/lib64/libcom_err.so*      /opt/lib64/ \
    && cp -a /usr/lib64/libz*.so*           /opt/lib64/ \
    && cp -a /usr/lib64/libk5crypto*.so*    /opt/lib64/ \
    && cp -a /usr/lib64/libkrb5*.so*        /opt/lib64/ \
    && cp -a /usr/lib64/libkrb5support*.so* /opt/lib64/ \
    && cp -a /usr/lib64/libkeyutils*.so*    /opt/lib64/ \
    && cp -a /usr/lib64/libresolv*.so*      /opt/lib64/ \
    && cp -a /usr/lib64/libcrypto*.so*      /opt/lib64/ \
    && cp -a /usr/lib64/libselinux*.so*     /opt/lib64/ \
    && cp -a /usr/lib64/libpcre*.so*        /opt/lib64/ \
    && cp -a /usr/lib64/libdl*.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libdl*.so*          /opt/lib64/

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
RUN   rm -rf /opt/share                              \
    ; rm -rf /opt/man                                \
    ; rm -rf /opt/include                            \
    ; rm -rf /opt/etc                                \
    ; rm -rf /opt/var                                \
    ; rm -rf /opt/lib/perl5/*/CPAN                   \
    ; rm -rf /opt/lib/perl5/*/ExtUtils               \
    ; rm -rf /opt/lib/perl5/*/TAP                    \
    ; rm -rf /opt/lib/perl5/*/pod                    \
    ; rm -rf /opt/lib/perl5/*/unicore                \
    ; rm -rf /opt/lib/perl5/*/Unicode                \
    ; rm -rf /opt/lib/pkgconfig                      \
    ; rm -rf /opt/lib64/pkgconfig                    \
    ; rm -rf /opt/lib64/golang                       \
    ; find /opt/ -type f -name '.packlist' |xargs rm \
    ; find /opt/ -type f -name '.pc'       |xargs rm \
    ; find /opt/ -type f -name '.h'        |xargs rm \
    ; find /opt/ -type f -name '.pod'      |xargs rm \
    ; exit 0 

# squash the docker, by starting from scratch
FROM scratch
COPY --from=my-perl-d /opt/ /
ENV PATH=/opt/bin/:/opt/scripts:$PATH
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]

