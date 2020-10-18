ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}stage-sandbox:latest    as staged-sb-perl
FROM scratch
COPY --from=staged-sb-perl /opt /opt
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE
ENV PERL5LIB=/perl5:/perl5/vendor_perl:/lib/perl5:/lib/perl5/vendor_perl:/lib/perl5/auto:/lib/perl5/vendor_perl/auto:/lib/perl5:/lib/perl5/x86_64-linux-thread-multi:/lib/perl5/x86_64-linux-thread-multi/auto
ENTRYPOINT ["/opt/lib64/ld-2.28.so", "/opt/bin/perl"]
CMD ["-e", "exec '/opt/busybox', 'sh'"]
