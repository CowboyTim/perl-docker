# Introduction

This perl is built to be used just as a docker that only contains perl. The
perl distribution is installed in /opt and is a vanilla perl install. All bin
scripts and binaries within a typical perl distribution are installed, together
with some extra external binaries and libraries that are needed to have a fully
working perl distribution.

The operating system this perl was built against is Amazon Linux 2 and is not
part of this docker, instead, the glibc version where perl is built against is
copied to /opt/lib64.

This has a couple of advantages and disadvantages:
* the size is very small and to the point: ~60MB
* size can be reduced even more for pure runtime perl dockers: ~34MB
* only 1 perl in the docker image
* you can't add cpan modules in the docker itself (but there's a perl-dev docker image)

The restriction of not being able to add CPAN modules from cpan can easily be
fixed by making a new docker where you combine the perl docker with the
original OS docker and install the tools to add cpan modules.  Note that adding
modules is always possible when doing this manually in the case the module is a
PurePerl module, but there is no make installed.

This is probably even the normal case, as one will use this perl docker as a
base to create new dockers with the tools needed to run the application, and
this isn't limited to perl and cpan and can as well be unix tools and other
languages.

The perl distribution also contains busybox from the busybox docker and
installed symlinks in /opt/bin. This is needed as e.g. /opt/bin/sh and
/opt/bin/less is used by perldoc to show documentation.

# Links

* This project is maintained on github: [CowboyTim/perl-docker](https://github.com/CowboyTim/perl-docker)
* This docker can be fetched from docker hub: [aardbeiplantje/perl](https://hub.docker.com/r/aardbeiplantje/perl)

# Tags/Images

Currently these tags are supported:

full runtime (~60MB):
* `aardbeiplantje/perl:5.32.0`
* `aardbeiplantje/perl:5.32.0-latest`
* `aardbeiplantje/perl:latest`

full OS dev for extending perl (~1.5GB):
* `aardbeiplantje/5.32.0-dev-latest`


# Quick reference

When you run the perl docker without arguments, it reads from stdin perl code:

    $ docker run -it --rm aardbeiplantje/perl
    print "Hello World!\n";
    <ctrl-D>
    Hello World!
    $

To run a perl script from stdin, docker needs to be run without the -t option
though, so for instance:

    $ docker run -i --rm aardbeiplantje/perl < ./hello_world.pl

This is better done via the -v option:

    $ docker run -it --rm -v $PWD:/opt/scripts aardbeiplantje/perl /opt/scripts/hello_world.pl

You can use this perl docker also to run -e '' snippets:

    $ docker run -it --rm aardbeiplantje/perl -MConfig -we 'print $Config{version}."\n"'

Similar, other tools can be run:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' perldoc -f sysopen
    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' perldoc perlguts

You can start perl interactively just like perl:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' sh

Or, as busybox is installed in /opt/bin, and /opt/bin is in the PATH, you can
for instance list what's in the docker:

    $ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' find / -xdev

# Environment variables

These are the environment variables defined within the docker by default to
help running scripts:

* `PATH=/opt/bin:/opt/scripts:$PATH`

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

# Installing CPAN modules

The docker image can be extended with other tools that you might need. Easiest
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

# Precompiled PERL CPAN modules

In the dockers directory, there are precompiled docker extensions. E.g.
perl:ssl. To build that, specify a different tag:

    LATEST_TAG=-5.32.0-dev-latest make build_docker.perl:io-socket-ssl

These can be "stacked" upon each other to make the end perl runtime for your
app, even when they contain the same files. This is managed by docker. 

E.g.:

    $ cat myapp/Dockerfile
    FROM aardbeiplantje/perl:5.32.0           as app-sb-perl
    FROM aardbeiplantje/perl:io-socket-ssl    as app-sb-ssl
    FROM aardbeiplantje/perl:json-xs          as app-sb-json-xs
    FROM aardbeiplantje/perl:json-pp          as app-sb-json-pp
    FROM aardbeiplantje/perl:json             as app-sb-json
    FROM scratch
    COPY --from=app-sb-perl    / /
    COPY --from=app-sb-ssl     / /
    COPY --from=app-sb-json-xs / /
    COPY --from=app-sb-json-pp / /
    COPY --from=app-sb-json    / /
    # some own written scripts
    COPY src/bin/* /opt/scripts
    COPY src/lib/* /opt/scripts
    ENV PATH=/opt/bin/:/opt/scripts:$PATH
    ENV PERL5LIB=/opt/scripts/lib
    ENTRYPOINT ["/opt/lib64/ld-linux-x86-64.so.2", "/opt/bin/perl"]

    $ docker build ./myapp/ -f ./myapp/Dockerfile \
        --network host \
        --tag myapp:latest 

# Building PERL CPAN dockers

Most of the PurePerl CPAN modules will (or at least should) be possible to
build into a docker that can be used as  a precompiled CPAN docker. Pure XS
modules can be built, but when external libraries are needed, these need to be
added as a seperate Dockerfile.

To make a PurePerl CPAN module, the [dockerize_cpan.pl](https://github.com/CowboyTim/perl-docker/blob/docker/dockerize_cpan.pl) script can be used:

    perl dockerize_cpan.pl JSON JSON::XS JSON::PP

This will use the aardbeiplantje/perl:5.32.0-dev-latest docker to make 3
different dockers, one for each cpan specified. Note that a cpan module can
include dependencies, those will also be added to that cpan docker at build.

# TODO

* make a trimmed runtime, although this is usually up to the needs of the project
* make the docker cpan use the cpan module's version nr
* tag all of the dockers with a git ref
* allow for making layers that include more then 1 cpan module in dockerize_cpan.pl
* find a way to automate the external library check
* add a simple test for the built cpan module
* make the dockerize_cpan.pl be ran with the aardbeiplantje/perl:5.32.0-dev-latest docker


