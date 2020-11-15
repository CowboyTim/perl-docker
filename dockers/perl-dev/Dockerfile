ARG docker_registry=aardbeiplantje
ARG upstream_tag
ARG remote_docker_registry
ARG perl_version=5.32.0

# we start from Amazon Linux 2 with sources to build perl against, we also add
# busybox. We do a COPY to "start fresh", just because we can't (yet?) overlay
# multiple FROM dockers into 1 docker sadly enough
FROM busybox:1.32.0             as busybox
FROM amazonlinux:2-with-sources as base-image
# start from scratch (nr.1)
FROM scratch                    as perl-dev-build
COPY --from=base-image / /
COPY --from=busybox    /bin/busybox /

ENV perl_version=${perl_version:-5.32.0}
RUN echo Building for PERL ${perl_version}; echo DOCKER_TAG: ${DOCKER_TAG}

MAINTAINER Tim Aerts <aardbeiplantje@gmail.com>

# needed for building PERL and possibly cpan stuff (note that they are not
# included in the end perl docker as they don't go in /opt)
RUN yum install -y   \
        gdbm-devel   \
        libdb-devel  \
        gcc          \
        make         \
        tar          \
        man          \
        groff        \
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
        patch;       \
    yum clean all;   \
    rm -rf /var/lib/yum/repos; \
    exit 0

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
    && (cd /opt && ln -s / usr)                         \
    && (cd /opt && ln -s / opt)                         \
    && rm /opt/lib64/libcrypt.so         && (cd /opt/lib64 && ln -s libcrypt.so.1     libcrypt.so)   \
    && rm /opt/lib64/libdl.so            && (cd /opt/lib64 && ln -s libdl.so.2        libdl.so)      \
    && rm /opt/lib64/libnsl.so           && (cd /opt/lib64 && ln -s libnsl.so.1       libnsl.so)     \
    && rm /opt/lib64/libutil.so          && (cd /opt/lib64 && ln -s libutil.so.1      libutil.so)    \
    && rm /opt/lib64/libc.so             && (cd /opt/lib64 && ln -s libc.so.6         libc.so)       \
    && rm /opt/lib64/libm.so             && (cd /opt/lib64 && ln -s libm.so.6         libm.so)       \
    && rm /opt/lib64/libpthread.so       && (cd /opt/lib64 && ln -s libpthread.so.0   libpthread.so) \
    && cp -a /usr/lib64/libgdbm*            /opt/lib64/ \
    && cp -a /usr/lib64/libdb.so*           /opt/lib64/ \
    && cp -a /usr/lib64/libdb-*.so*         /opt/lib64/

# for easy script adding, this is also added to the PATH
# setup a /tmp for File::Temp
RUN mkdir /opt/scripts; mkdir /opt/tmp && chmod 1777 /opt/tmp

# copy busybox for debugging, add at least 'sh' for docker builds later on if
# we move from /opt to /. busybox can later on also be used in the perl-docker
RUN    mkdir -p /opt/lib64                   \
    && mkdir -p /opt/bin                     \
    && cp /busybox /opt/bin/busybox          \
    && (cd /opt/bin && for m in $(/opt/bin/busybox --list); do ln -s ./busybox $m; done)

# make sure to move /bin/sh away and start Configure with /opt/bin/sh which is
# at this point a full sh -> bash.  This is for later on, when perl in /opt
# needs to use sh for `` and system() calls, the default needs to be
# /opt/bin/sh as /bin/sh will simply not be there.
#
# Immediately install and cleanup the src directory so the docker layer stays
# "small"
#
# copy a real bash temporarily: before busybox --install -s as that add 'sh'
# after the perl build, switch the fat bash back to busybox sh

ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/${perl_version}/x86_64/CORE
ENV PATH=/opt/bin:$PATH

WORKDIR /opt/src/perl
RUN \
       mkdir -p /opt/bin                                                                     \
    && cp /bin/bash  /opt/bin/bash                                                           \
    && (cd /opt/bin && rm sh && ln -s ./bash sh)                                             \
    && cp /lib64/libtinfo.so*  /opt/lib64/                                                   \
    && (cd /opt/lib64 && ln -s libtinfo.so.5 libtinfo.so)                                    \
    ;  export perl_tar=perl-${perl_version}.tar.xz                                           \
    ;  echo   P:$perl_tar                                                                    \
    ;  curl -sSL -k --insecure https://www.cpan.org/src/5.0/$perl_tar -o $perl_tar           \
    && echo '6f436b447cf56d22464f980fac1916e707a040e96d52172984c5d184c09b859b *'${perl_tar}  \
        |sha256sum -c -                                                                      \
    && tar --strip-components=1 -xaf $perl_tar -C /opt/src/perl                              \
    && rm $perl_tar                                                                          \
    && mv /bin/sh /bin/sh.b                                                                  \
    && /opt/bin/sh                                                                           \
        ./Configure                                                                          \
        -Duse64bitall                                                                        \
        -Duseshrplib                                                                         \
        -Dprefix=/opt                                                                        \
        -Dinstallprefix=/opt                                                                 \
        -Dsiteprefix=/opt/site_perl                                                          \
        -Dvendorprefix=/opt/vendor_perl                                                      \
        -Dcf_by='CowboyTim <aardbeiplantje@gmail.com>'                                       \
        -Duselargefiles                                                                      \
        -Dinc_version_list=none                                                              \
        -Dldflags='-Wl,-R/opt/lib -Wl,-R/opt/lib64 -Wl,--dynamic-linker,/opt/lib64/ld-linux-x86-64.so.2' \
        -des                                                                                 \
    && make -j16                                                                             \
    && make -j16 install                                                                     \
    && rm -rf /opt/src/perl/*                                                                \
    && mv /bin/sh.b /bin/sh                                                                  \
    ; (cd /opt/bin && rm bash sh && ln -s busybox sh) && rm /opt/lib64/libtinfo*             \
    ; rm -rf /opt/src/perl                                                                   \
    ; rm -rf /opt/tmp/cpan                                                                   \
    ; rm -rf /opt/src                                                                        \
    ; rm -rf /opt/share                                                                      \
    ; rm -rf /opt/man                                                                        \
    ; rm -rf /opt/include                                                                    \
    ; rm -rf /opt/games                                                                      \
    ; rm -rf /opt/perl                                                                       \
    ; rm -rf /opt/lib/python*

WORKDIR /

ENV INSTALL_BASE=/tmp/cpan/local
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/${perl_version}/x86_64/CORE
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
/opt/lib/perl5/site_perl/${perl_version}/:\
/opt/lib/perl5/site_perl/${perl_version}/auto:\
/opt/lib/perl5/site_perl/${perl_version}/x86_64:\
/opt/lib/perl5/site_perl/${perl_version}/x86_64/auto:\
/opt/lib/perl5/auto:\
/opt/lib/perl5/${perl_version}:\
/opt/lib/perl5/${perl_version}/auto:\
/opt/lib/perl5/${perl_version}/x86_64:\
/opt/lib/perl5/${perl_version}/x86_64/auto

# cpan config
COPY cpan_config.pl /tmp/

# install CPAN modules for CPAN in INSTALL_BASE=/tmp/cpan/local. This is
# handled by cpan_config.pl. This is because we don't want cpan-needed modules
# in the end docker, we can't do anything with those and they take up space.
# Best is to look out for those while installing cpan modules that are needed,
# often they bring in dependencies that aren't needed later on at runtime
RUN \
       /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  CPAN                  \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  YAML                  \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  ExtUtils::PkgConfig   \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  ExtUtils::Helpers     \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  HTTP::Date            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  HTML::Tiny            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  install               \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Canary::Stability     \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Algorithm::Diff       \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Spiffy                \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Text::Diff            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::Base            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::Deep            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::LeakTrace       \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  inc::latest           \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Module::Build         \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  common::sense         \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::More            \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::Simple          \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::Builder         \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test::Harness         \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test2                 \
    && /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  Test2::Formatter      \
    || exit 1                                                                        \
    ; rm -rf /opt/tmp/cpan                                                           \
    ; rm -rf /opt/src                                                                \
    ; rm -rf /opt/share                                                              \
    ; rm -rf /opt/man                                                                \
    ; rm -rf /opt/include                                                            \
    ; rm -rf /opt/games                                                              \
    ; rm -rf /opt/perl                                                               \
    ; rm -rf /opt/lib/python*                                                        \
    ; find /opt/lib/perl5/ -type f -name '.packlist'|xargs rm -f                     \
    ; mkdir -p /opt/tmp && chmod 1777 /opt/tmp

# for testing, add the core modules test script
COPY test_core_modules.pl /tmp/

# and test this, if it fails, the docker image isn't tagged
RUN /opt/bin/perl /tmp/test_core_modules.pl

# start from scratch (nr.2)
FROM scratch
COPY --from=perl-dev-build / /

# reset ENV variables we don't need anymore
ENV PERL5LIB=
ENV TMPDIR=
ENV LD_LIBRARY_PATH=
ENV PATH=/opt/bin/:/opt:$PATH

# reset the default cpan install, this way, new cpan modules go to site_perl
ENV INSTALL_BASE=

# install CPAN modules for perl itself in /opt, keep this 1 cpan per RUN for
# docker's caching features. Use the correct INSTALL_BASE=/opt for this. Note
# that it's probably better to do that in the docker that inherit from this
# docker.
#
# temp use for cpan:
# E.g.:
# RUN INSTALL_BASE=/tmp/cpan/local /opt/bin/cpan -j /tmp/cpan_config.pl -Ti  CPAN
#
# add in the perl docker:
# E.g.:
# RUN /opt/bin/cpan -j /tmp/cpan_config.pl -Ti JSON::XS
#
ENTRYPOINT ["/opt/bin/busybox", "sh"]
