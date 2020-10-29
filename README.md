# Introduction

This is a PERL AWS Lambda.

This perl is built to be used in a docker that only contains perl and can be
added as a layer for bootstrapping lambda function in Amazon AWS. The delivered
build artifact is a zip file, with perl in ./lib and ./bin. Within aws lambda
bootstrap, this is virtually mounted on /opt.

The perl itself is taken from the aardbeiplantje/perl:5.32.0 docker, where we
basically copy the /opt to / in a docker from scratch. We add a bootstrap shell
script that execs in a perl lambda bootstrap script.

This is a perl that's built against Amazon Linux 2 (provided.al2), and the
glibc isn't perse needed in lib64 as it's the same.

Adding CPAN modules will need to be done seperately. Either you make a new
layer or change this perl runtime layer zip before uploading.

The restriction of cpan building can be fixed by making a new docker where you
combine this with the original OS and add cpan modules again. This is probably
even the normal case, as one will use this perl docker as a base to create new
dockers with the tools needed to run the application, and this isn't limited to
perl and cpan, but can as well be unix tools and other languages.

The perl distribution also contains busybox from the busybox docker and
installed symlinks in /bin. This is needed as e.g. /bin/sh. Other tools that
aren't needed to make a perl runtime lambda are removed which is the busybox
tools and perl itself. As a bootstrap docker runs in an provided.al2 bootstrap,
in theory they are already present in the bootstrap and thus can be removed.

# Environment variables

These are the environment variables defined within the perl lambda by default
to help running scripts:

* `PATH=$LAMBDA_TASK_ROOT/bin:/opt/bin:/opt/scripts:$PATH`
* `LD_LIBRARY_PATH=`
* `PERL5LIB=...`
* `PERL_VERSION=5.32.0`
* `TMPDIR=/opt/tmp`
* `LANG=C`

LD_LIBRARY_PATH is unset explicitly. The $LAMBDA_TASK_ROOT/bin is added so you
can easily place scripts there. PERL5LIB is set, but probably not needed.

# Building

To build the perl lambda locally from scratch, you need to have docker set up
on your host.  There's an easy to use Makefile with the default target to build
the lambda zip layer image:

    $ make

This will build perl:5.32-dev-latest, perl:lambda-dev, perl:lambda docker and
then extracts the files for zipping. We add the bootstrap logic in the zip
before zipping.

You can later on publish the new layer to AWS via either console, aws cli,
terraform, etc. There's a make target to do this via plain aws cli, you will
need to have set up your credentials properly to do so:

    $ make publish_aws_lambda_layer_runtime_zip

The `deploy` target combines build and publish:

    $ make deploy

# Extending the docker image


# TODO

* make a trimmed runtime, although this is usually up to the needs of the project


