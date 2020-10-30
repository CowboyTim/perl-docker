# Introduction

This is a PERL docker.

This perl is built to be used just as a docker that only contains perl. The
perl distribution is installed in /opt and is a vanilla perl install. All bin
scripts and binaries within a typical perl distribution are installed.

The operating system this perl was built against is not part of this docker,
instead, the glibc version is compied to /opt/lib64. This has a couple of
advantages and disadvantages:

* the size is very small and to the point: ~60MB
* size can be reduced even more for pure runtime perl dockers: ~34MB
* only 1 perl in the docker image
* you can't add cpan modules in the docker itself

The restriction of cpan building can easily be fixed by making a new docker
where you combine this with the original OS and add cpan modules again. This is
probably even the normal case, as one will use this perl docker as a base to
create new dockers with the tools needed to run the application, and this isn't
limited to perl and cpan, but can as well be unix tools and other languages.

Currently, Amazon Linux 2 was used to make this build.

The perl distribution also contains busybox from the busybox docker and
installed symlinks in /opt/bin. This is needed as e.g. /opt/bin/sh and
/opt/bin/less is used by perldoc to show documentation.

# Environment variables

These are the environment variables defined within the docker by default to
help running scripts:

* `PATH=/opt/bin:/opt/scripts:$PATH`

# Quick reference

You can use this perl docker like this:

    $ docker run -it --rm aardbeiplantje/perl -MConfig -we 'print $Config{version}."\n"'

Similar, other tools can be run like this:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' perldoc -f sysopen
    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' perldoc perlguts

You can start perl interactively just like perl:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' sh

Or, as busybox is installed in /opt/bin, and /opt/bin is in the PATH, you can
for instance list what's in the docker:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' find / -xdev

To run external scripts, for instance:

    $ docker run -i --rm aardbeiplantje/perl < ./hello_world.pl

Or:

    $ docker run -it --rm -v $PWD:/opt/scripts aardbeiplantje/perl /opt/scripts/hello_world.pl

# Images

full runtime (~60MB):
* `aardbeiplantje/perl:5.32.0`
* `aardbeiplantje/perl:5.32.0-latest`
* `aardbeiplantje/perl:latest`

full OS dev for extending perl (~1.5GB):
* `aardbeiplantje/5.32.0-dev-latest`

# Building

To build the perl docker locally, you need to have docker set up on your host.
There's an easy to use default make target to build the perl-dev and perl
docker image:

    $ make

You can push the docker to your repository after that - note that you might
need to login first of course:

    $ export REMOTE_DOCKER_REPO=<docker_registry_hostname>/aardbeiplantje
    $ make docker_push_perl

To push to docker.io as docker registry, e.g.:

    $ export REMOTE_DOCKER_REPO=aardbeiplantje
    $ make docker_push_perl

# Extending the docker image

The docker image can be extened with other tools that you might need. Easiest
is to start from the `aardbeiplantje/perl:5.32.0-dev-latest` image as the CPAN
config is already present. Most of the build utilities typically needed on a
linux OS are also already preinstalled: make, gcc, tar, gzip,..

Let's say you want JSON to be added as a cpan module. The Dockerfile in our
test docker dir will need to look like this:

    $ cat myperl/Dockerfile
    # start from the perl-dev docker
    FROM aardbeiplantje/perl:5.32.0-dev-latest as my-perl-d

    # add a cpan module with the provided cpan config
    RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -fi -T JSON

    # squash the docker, by starting from scratch
    FROM scratch
    COPY --from=my-perl-d /opt/ /
    ENV PATH=/opt/bin/:/opt/scripts:$PATH
    ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]

    $ docker build ./myperl/ -f ./myperl/Dockerfile \
        --network host \
        --tag myperl:latest 

Note the cpan options: -fi -T. This is needed as the cpan modules for testing
are preinstalled in /tmp/cpan/local, which is about to be removed, and if a
cpan is already there, it won't be installed. The -f option will make sure it
does. Note that it invalidates the -T option.

When this docker is built, the perl docker will be capably of using JSON:

    $ docker run --rm -i myperl:latest -MJSON -we 'print "$JSON::VERSION\n"'


# TODO

* make a trimmed runtime, although this is usually up to the needs of the project


