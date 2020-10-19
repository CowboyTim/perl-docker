ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}stage-sandbox:latest    as staged-sb-perl
FROM scratch
COPY --from=staged-sb-perl /opt /opt
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
ENTRYPOINT ["/opt/lib64/ld-2.28.so", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/busybox', 'sh'"]
