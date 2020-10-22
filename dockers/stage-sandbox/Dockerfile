ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}base-sandbox:latest as b-sb

WORKDIR /opt/src/perl

# needed for building PERL and possibly cpan stuff (note that they are not
# included in the end perl-sandbox as they don't go in /opt)
RUN yum install -y  \
        gdbm-devel  \
        libdb-devel \
        gcc         \
        make        \
        tar         \
        curl        \
        xz          \
        gzip        \
        pkgconfig   \
        wget        \
        zip         \
        less        \
        bzip2       \
        bash        \
        patch

# to be sure to have that
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE

# copy busybox for debugging, add at least 'sh' for docker builds later on if
# we move from /opt to /. busybox can later on also be used in the perl-docker
RUN    mkdir -p /opt/lib64          \
    && mkdir -p /opt/bin            \
    && cp /busybox /opt/bin/busybox \
    && (cd /opt/bin && ln -s busybox sh)

# now we add OS dependencies from / to /opt, as later on we will be squashing
# the docker fs by moving everything from /opt to / and abandon what's there

# PERL libs needed: "copy" the glibc and others to /opt/lib64, make some symlinks
RUN    mkdir -p                             /opt/lib64/ \
    && cp -a /usr/lib64/ld-2*.so            /opt/lib64/ \
    && cp -a /lib64/ld-linux-x86-64*.so*    /opt/lib64/ \
    && cp -a /usr/lib64/libpthread*.so*     /opt/lib64/ \
    && cp -a /usr/lib64/libdl*.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libcrypt.so*        /opt/lib64/ \
    && cp -a /usr/lib64/libcrypt-*.so*      /opt/lib64/ \
    && cp -a /usr/lib64/libm.so*            /opt/lib64/ \
    && cp -a /usr/lib64/libm-*.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libutil*.so*        /opt/lib64/ \
    && cp -a /usr/lib64/libc.so*            /opt/lib64/ \
    && cp -a /usr/lib64/libc-*.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libnsl.so*          /opt/lib64/ \
    && cp -a /usr/lib64/libnsl-*.so*        /opt/lib64/ \
    && (cd /opt && ln -s / usr) \
    && (cd /opt && ln -s / opt)

# fix a few symlinks
RUN rm /opt/lib64/libcrypt.so         && (cd /opt/lib64 && ln -s libcrypt.so.1     libcrypt.so)
RUN rm /opt/lib64/libdl.so            && (cd /opt/lib64 && ln -s libdl.so.2        libdl.so)
RUN rm /opt/lib64/libnsl.so           && (cd /opt/lib64 && ln -s libnsl.so.1       libnsl.so)
RUN rm /opt/lib64/libutil.so          && (cd /opt/lib64 && ln -s libutil.so.1      libutil.so)
RUN rm /opt/lib64/libc.so             && (cd /opt/lib64 && ln -s libc.so.6         libc.so)
RUN rm /opt/lib64/libm.so             && (cd /opt/lib64 && ln -s libm.so.6         libm.so)
RUN rm /opt/lib64/libpthread.so       && (cd /opt/lib64 && ln -s libpthread.so.0   libpthread.so)

# PERL CORE modules need extra libs from the OS
RUN    \
       cp -a /usr/lib64/libgdbm*            /opt/lib64/ \
    && cp -a /usr/lib64/libdb.so*           /opt/lib64/ \
    && cp -a /usr/lib64/libdb-*.so*         /opt/lib64/

RUN ls -l /opt/lib64/


RUN \
       curl -sSL -k --insecure https://www.cpan.org/src/5.0/perl-5.32.0.tar.xz -o perl-5.32.0.tar.xz \
    && echo '6f436b447cf56d22464f980fac1916e707a040e96d52172984c5d184c09b859b *perl-5.32.0.tar.xz' | sha256sum -c - \
    && tar --strip-components=1 -xaf perl-5.32.0.tar.xz -C /opt/src/perl \
    && rm perl-5.32.0.tar.xz                                             \
    && ./Configure                                                       \
        -Duse64bitall                                                    \
        -Darchname=x86_64                                                \
        -Duseshrplib                                                     \
        -Dprefix=/opt/                                                   \
        -Duselargefiles                                                  \
        -Dldflags='-Wl,-R/opt/lib -Wl,-R/opt/lib64 -Wl,--dynamic-linker,/opt/lib64/ld-linux-x86-64.so.2' \
        -des                                                             \
    && make -j16                                                         \
    && make install

WORKDIR /

ENV PERL5LIB=\
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

# cpan config
COPY cpan_config.pl /opt

# our test script
COPY test_core_modules.pl /opt/scripts/

# cleanup stuff in /opt we never will need
RUN rm -rf /opt/src
RUN rm -rf /opt/share
RUN rm -rf /opt/man
RUN rm -rf /opt/include
RUN rm -rf /opt/games
RUN rm -rf /opt/lib/python*
RUN rm -rf /opt/lib/perl5/*/pod

# install CPAN modules for perl itself in /opt, keep this 1 cpan per RUN for
# docker's caching features. Use the correct INSTALL_BASE=/opt for this. Note
# that it's probably better to do that in the docker that inherit from this
# docker.
#
# temp use for cpan:
# E.g.:
# RUN INSTALL_BASE=/opt/tmp/cpan_local /opt/bin/cpan -j /opt/cpan_config.pl -Ti  CPAN
#
# add in the perl docker:
# E.g.:
# RUN /opt/bin/cpan -j /opt/cpan_config.pl -Ti JSON::XS
#

# after the extra cpan modules install, cleanup the .h files
RUN find /opt/lib/perl5/ -type f -name '.packlist'|xargs rm

ENV PATH=/opt/bin/:/opt:$PATH
ENTRYPOINT ["/opt/bin/busybox", "sh"]
