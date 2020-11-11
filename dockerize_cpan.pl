#!/usr/bin/perl

use strict; use warnings;

use FindBin;

# config/defaults
my $perl_version     = $ENV{PERL_VERSION}    ||= "5.32.0";
my $perl_version_tag = $ENV{DOCKER_PERL_TAG} ||= "$perl_version-dev-latest";

$ENV{DOCKER_LOCAL}           //= "docker_build_$ENV{USER}";
$ENV{DOCKER_REGISTRY}        //= "aardbeiplantje";
$ENV{REMOTE_DOCKER_REGISTRY} //= $ENV{DOCKER_LOCAL};
$ENV{DOCKER_REPOSITORY}      //= $ENV{DOCKER_LOCAL}.'/'.$ENV{DOCKER_REGISTRY};

foreach my $cpan_to_add (@ARGV){
    my $docker_cpan_tag = lc($cpan_to_add =~ s/::/-/gr);
    my $d_dir = "$FindBin::Bin/dockers/perl:$docker_cpan_tag";
    print STDERR "checking for $d_dir\n";
    if(-d $d_dir){
        local $ENV{LATEST_TAG} = "";
        system("make -C $FindBin::Bin build_docker.perl:$docker_cpan_tag") == 0
            or die $!;
    } else {
        build_cpan_docker($cpan_to_add, $docker_cpan_tag);
    }
}

sub build_cpan_docker {
    my ($cpan_to_add, $docker_cpan_tag) = @_;

    # make a temp dir + Dockerfile
    my $tdir = "/tmp/dockerize_cpan_${$}_$ENV{USER}";
    mkdir($tdir) or die "Error making dir $tdir: $!\n";
    print STDERR "using $tdir/Dockerfile\n";

    # Dockerfile
    my $docker_fn = "$tdir/Dockerfile";
    open(my $d_fh, '>', $docker_fn)
        or die "Error opening $docker_fn: $!\n";
    print {$d_fh} <<EOdockerfile;
FROM $ENV{DOCKER_REGISTRY}/perl:$perl_version_tag as my-perl-d
ENV LD_LIBRARY_PATH=/opt/lib64:/opt/lib:/opt/lib/perl5/$perl_version/x86_64/CORE
ENV INSTALL_BASE=/newopt
ENV PERL5LIB=\\
\$INSTALL_BASE/lib/perl5:\\
\$INSTALL_BASE/lib/perl5/auto:\\
\$INSTALL_BASE/lib/perl5/site_perl:\\
\$INSTALL_BASE/lib/perl5/site_perl/auto:\\
\$INSTALL_BASE/lib/perl5/x86_64:\\
\$INSTALL_BASE/lib/perl5/x86_64/auto:\\
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
RUN /opt/bin/perl /opt/bin/cpan -j /tmp/cpan_config.pl -Ti \\
    $cpan_to_add         \\
    ; exit 0
RUN   rm -rf /newopt/share                                 \\
    ; rm -rf /newopt/man                                   \\
    ; find /newopt/ -type f -name '.packlist' |xargs rm -f \\
    ; find /newopt/ -type f -name '.pc'       |xargs rm -f \\
    ; find /newopt/ -type f -name '.h'        |xargs rm -f \\
    ; find /newopt/ -type f -name '.pod'      |xargs rm -f \\
    ; exit 0
FROM scratch
COPY --from=my-perl-d /newopt/ /
EOdockerfile
    close($d_fh)
        or die "Error closing $docker_fn: $!\n";

    # run docker build
    system(
         "docker build $tdir -f $tdir/Dockerfile"
        ." --cache-from $ENV{DOCKER_REPOSITORY}/perl:$docker_cpan_tag-$perl_version_tag"
        ." --tag $ENV{DOCKER_REPOSITORY}/perl:$docker_cpan_tag"
        ." --tag $ENV{DOCKER_REGISTRY}/perl:$docker_cpan_tag"
    ) == 0 or die $!;

    unlink $docker_fn;
    rmdir $tdir;
    return;
}
