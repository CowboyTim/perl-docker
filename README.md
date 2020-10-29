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
* `LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/5.32.0/x86_64/CORE`
* `PERL_VERSION=5.32.0`
* `TMPDIR=/opt/tmp`

# Quick reference

You can use this perl docker like this:

  `$ docker run -it --rm aardbeiplantje/perl -MConfig -we 'print $Config{version}."\n"'`

Similar, other tools can be run like this:

  `$ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' perldoc -f sysopen`

You can start perl interactively just like perl:

  `$ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' sh`

Or, as busybox is installed in /opt/bin, and /opt/bin is in the PATH, you can
for instance list what's in the docker:

  `$ docker run -it --rm aardbeiplantje/perl -e 'exec @ARGV' find / -xdev`

To run external scripts, for instance:

  `$ docker run -i --rm aardbeiplantje/perl < ./hello_world.pl`

Or:

  `$ docker run -it --rm -v $PWD:/opt/scripts aardbeiplantje/perl /opt/scripts/hello_world.pl`

# Images

full runtime:
* aardbeiplantje/perl:5.32.0
* aardbeiplantje/perl:5.32.0-latest
* aardbeiplantje/perl:latest

full dev (~1GB):
* aardbeiplantje/5.32.0-dev-latest

# Building

To build the perl docker locally, you need to have docker set up on your host.
There's an easy to use Makefile with the default target to build the perl-dev
docker image and then the perl docker image:

  `$ make`

You can push the docker to your repository after that - note that you might
need to login first of course:

  `$ export REMOTE_DOCKER_PUSH=<docker_registry_hostname>/aardbeiplantje
   $ make docker_push_perl`

If the REMOTE_DOCKER_PUSH environment variable isn't set, default the push is
to docker hub.

# Extending the docker image

The docker image can be extened with other tools that you might need. Easiest
is to start from the aardbeiplantje/perl:5.32.0-dev-latest image as the CPAN
config is already present. Most of the build utilities typically needed on a
linux OS are also already preinstalled: make, gcc, tar, gzip,..

# TODO

* make a trimmed runtime, although this is usually up to the needs of the project


