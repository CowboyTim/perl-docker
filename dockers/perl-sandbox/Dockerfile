ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}stage-sandbox:latest    as staged-sb-perl
FROM scratch
COPY --from=staged-sb-perl /opt /opt
COPY --from=staged-sb-perl /opt/bin/busybox /busybox
COPY --from=staged-sb-perl /opt/bin/busybox /bin/sh
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE
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
ENV PATH=/opt/bin/:/opt:$PATH
ENV TMPDIR=/opt/tmp
RUN /busybox ln -s /opt/tmp /tmp && /busybox rm -rf /busybox bin
ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/bin/busybox', 'sh'"]
