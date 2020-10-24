# Introduction

This is perl 5.32.0. It's build to be used just as a docker that only contains
perl. The perl distribution is installed in /opt and is a vanilla perl install.
All bin scripts and binaries within a typical perl distribution are there.

The operating system perl was built against is not part of this docker,
instead, the glibc version is compied to /opt/lib64. This has a couple of
advantages and disadvantages:

* the size is very small and to the point: ~70MB
* you can't add cpan modules in the docker itself

This can easily be fixed by making a new docker where you combine this with the
original OS and add cpan modules again. Currently, Amnazon Linux 2 was used to
do this.

The perl distribution also contains busybox from the busybox docker and
installed symlinks in /opt/bin. This is needed as e.g. /opt/bin/sh and
/opt/bin/less is used by perldoc to show documentation.

The default entrypoint/env is set up to use perl, but when no arguments are
given, a /opt/bin/sh is exec'ed so you enter the busybox shell.

# Quick reference

You can use this perl docker like this:

  `$ docker run -it --rm aardbeiplantje/perl:5.32.0 -MConfig -we 'print $Config{version}."\n"'`

Similar, other tools can be run like this:

  `$ docker run -it --rm aardbeiplantje/perl:5.32.0 /opt/bin/perldoc POSIX`

# Images

* aardbeiplantje/perl:<version:5.32.0>
* aardbeiplantje/perl:latest

TODO:
* aardbeiplantje/perl:5.32.0-dev

# License

See [license information](https://dev.perl.org/licenses/)


