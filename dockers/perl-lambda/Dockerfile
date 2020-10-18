ARG docker_registry
ARG upstream_tag

FROM ${docker_registry}perl-lambda-dev-sandbox:latest as prl
FROM scratch
COPY --from=prl  /opt /
ENV LD_LIBRARY_PATH=/lib64:/lib:/lib/perl5/5.32.0/x86_64/CORE
ENV PERL5LIB=/perl5:/perl5/vendor_perl:/lib/perl5:/lib/perl5/vendor_perl:/lib/perl5/auto:/lib/perl5/vendor_perl/auto:/lib/perl5:/lib/perl5/x86_64-linux-thread-multi:/lib/perl5/x86_64-linux-thread-multi/auto
ENTRYPOINT ["/lib64/ld-2.28.so", "/bin/perl"]
CMD ["-e", "exec '/busybox', 'sh'"]
