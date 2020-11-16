#!/usr/bin/perl

use strict; use warnings;

use FindBin;

# config/defaults
my $perl_version         = $ENV{PERL_VERSION}        ||= "5.32.0";
my $perl_version_tag     = $ENV{DOCKER_PERL_TAG}     ||= "$perl_version";
my $perl_dev_version_tag = $ENV{DOCKER_PERL_DEV_TAG} ||= "$perl_version-dev-latest";

$ENV{DOCKER_LOCAL}           //= "docker_build_$ENV{USER}";
$ENV{DOCKER_REGISTRY}        //= "aardbeiplantje";
$ENV{REMOTE_DOCKER_REGISTRY} //= $ENV{DOCKER_LOCAL};
$ENV{DOCKER_REPOSITORY}      //= $ENV{DOCKER_LOCAL}.'/'.$ENV{DOCKER_REGISTRY};

foreach my $cpan_to_add (@ARGV){
    # get some details
    my @cpan_details = `cpan -D $cpan_to_add`;
    my ($tarball_version, $cpan_version);
    while(defined(my $l = shift @cpan_details)){
        print STDERR $l;
        if($l =~ /CPAN:\s+(\S+)\s+/){
            $cpan_version = $1;
            next
        }
        if($l =~ /(\S+\.(?:tar\.gz|tgz))/){
            $tarball_version = $1;
            next
        }
    }
    die "No cpan $cpan_to_add found\n"
        unless $tarball_version and $cpan_version;
    my $docker_cpan_tag = lc($cpan_to_add =~ s/::/-/gr);
    print STDERR "will tag the docker image for $cpan_to_add with $docker_cpan_tag-$cpan_version\n";

    # build docker via make?
    my $d_dir = "$FindBin::Bin/dockers/perl:cpan-$docker_cpan_tag";
    print STDERR "checking for $d_dir\n";
    if(-d $d_dir){
        local $ENV{LATEST_TAG} = "-$cpan_version";
        system("make -C $FindBin::Bin build_docker.perl:cpan-$docker_cpan_tag") == 0
            or die $!;
    } else {
        build_cpan_docker($cpan_to_add, $docker_cpan_tag, $tarball_version, $cpan_version);
    }

    # put extra tags
    system("docker tag $ENV{DOCKER_REPOSITORY}/perl:cpan-$docker_cpan_tag-$cpan_version ".
                      "$ENV{DOCKER_REPOSITORY}/perl:cpan-$docker_cpan_tag") == 0 or die $!;
    system("docker tag $ENV{DOCKER_REPOSITORY}/perl:cpan-$docker_cpan_tag-$cpan_version ".
                      "$ENV{DOCKER_REGISTRY}/perl:cpan-$docker_cpan_tag") == 0 or die $!;
}

our $cfg_loaded;
sub build_cpan_docker {
    my ($cpan_to_add, $docker_cpan_tag, $tarball_version, $cpan_version) = @_;

    # make a temp dir + Dockerfile
    my $tdir = "/tmp/dockerize_cpan_${$}_$ENV{USER}";
    mkdir($tdir) or die "Error making dir $tdir: $!\n";
    print STDERR "using $tdir/Dockerfile\n";

    # Dockerfile
    my $docker_fn = "$tdir/Dockerfile";
    open(my $d_fh, '>', $docker_fn)
        or die "Error opening $docker_fn: $!\n";
    print {$d_fh} <<EOdockerfile;
# start from the perl-dev docker
FROM $ENV{DOCKER_REGISTRY}/perl:$perl_dev_version_tag as my-perl-d

# set some ENV vars, to be sure. Also, we will build in /newopt
# so PERL5LIB has to contain that
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE
# see cpan_config.pl for DESTDIR/INSTALL_BASE/PERL5LIB!! Add trailing slash (/)!!
ENV DESTDIR=/newopt/
ENV INSTALL_BASE=" DESTDIR=\$DESTDIR"
ENV PERL5LIB=\\
\$DESTDIR/opt/site_perl/lib/perl5:\\
\$DESTDIR/opt/site_perl/lib/perl5/site_perl/auto:\\
\$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version:\\
\$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version/x86_64-linux:\\
\$DESTDIR/opt/site_perl/lib/perl5/site_perl/$perl_version/x86_64-linux/auto:\\
/opt/lib/perl5:\\
/opt/lib/perl5/site_perl:\\
/opt/lib/perl5/site_perl/auto:\\
/opt/lib/perl5/site_perl/$perl_version/:\\
/opt/lib/perl5/site_perl/$perl_version/auto:\\
/opt/lib/perl5/site_perl/$perl_version/x86_64:\\
/opt/lib/perl5/site_perl/$perl_version/x86_64/auto:\\
/opt/lib/perl5/auto:\\
/opt/lib/perl5/$perl_version:\\
/opt/lib/perl5/$perl_version/auto:\\
/opt/lib/perl5/$perl_version/x86_64:\\
/opt/lib/perl5/$perl_version/x86_64/auto

# actually run cpan install
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti \\
    $tarball_version \\
    ; rm -rf \$DESTDIR/opt/site_perl/share                     \\
    ; rm -rf \$DESTDIR/opt/site_perl/man                       \\
    ; rm -rf \$DESTDIR/opt/lib                                 \\
    ; find   \$DESTDIR/ -type f -name '.packlist' |xargs rm -f \\
    ; find   \$DESTDIR/ -type f -name '.pc'       |xargs rm -f \\
    ; find   \$DESTDIR/ -type f -name '.h'        |xargs rm -f \\
    ; find   \$DESTDIR/ -type f -name '.pod'      |xargs rm -f \\
    ; exit 0
# and a simple test
RUN /opt/bin/perl -M$cpan_to_add -we 'print "[OK] CPAN TEST 1 ${cpan_to_add} built, version: \$${cpan_to_add}::VERSION\\n"'

# start a new scratch with runtime perl and move to / just to test (without PERL5LIB set!)
FROM $ENV{DOCKER_REGISTRY}/perl:$perl_version_tag as test-perl-cpan
FROM scratch
COPY --from=my-perl-d /newopt/opt/ /
COPY --from=test-perl-cpan / /
ENV DESTDIR=
ENV INSTALL_BASE=
ENV LD_LIBRARY_PATH=
ENV PERL5LIB=
RUN /opt/bin/perl -M$cpan_to_add -we 'print "[OK] CPAN TEST 2 ${cpan_to_add} built, version: \$${cpan_to_add}::VERSION\\n"'

# test ok, so squash for push
FROM scratch
COPY --from=my-perl-d /newopt/opt/ /

EOdockerfile
    close($d_fh)
        or die "Error closing $docker_fn: $!\n";

    # run docker build
    system(
         "docker build $tdir -f $tdir/Dockerfile"
        ." --cache-from $ENV{DOCKER_REPOSITORY}/perl:cpan-$docker_cpan_tag-$cpan_version"
        ." --tag $ENV{DOCKER_REPOSITORY}/perl:cpan-$docker_cpan_tag-$cpan_version"
        ." --tag $ENV{DOCKER_REGISTRY}/perl:cpan-$docker_cpan_tag-$cpan_version"
    ) == 0 or die $!;

    unlink $docker_fn;
    rmdir $tdir;
    return;
}
