#!/opt/bin/perl

# check a few things, default, sanity
use strict; use warnings;
unless($ENV{_HANDLER}){
    die "This is the AWS Lambda PERL runtime, _HANDLER ENV is not set\n";
}

use Fcntl qw(FD_CLOEXEC F_GETFL F_SETFL);

$ENV{LAMBDA_TASK_ROOT}             ||= '';

# for when we just want to execute a script
$ENV{SCRIPT_EXEC}                  ||= 0;
# default in process libcurl (as opposed to `` fork/exec of curl)
$ENV{USE_LIBCURL}                  ||= 1;
# always clean up /tmp (it's small, and we want to sandbox as much as possible INVARIANT)
$ENV{INVARIANT_TMP}                ||= 1;
# default print output
$ENV{PRINT_LOG}                    ||= 1;
# default namespace the script
$ENV{SCRIPT_NAMESPACE}             ||= 0;

# FH  buffering
my $oldfh = select STDOUT;
local $|=1;
select $oldfh;
$oldfh = select STDERR;
local $|=1;
select $oldfh;

# multi processes state (if needed)
my $m_proc_state;

# init the handler
my ($pkg_name, $perl_method) = init_handler();

# start looping: fetch and process
infinite_loop("$ENV{_HANDLER} [${pkg_name}::".($perl_method//'')."] for");

exit 0;

sub init_handler {
    # load handler, use another namespace to do this in
    my ($perl_snippet, $perl_method, @rest) = split m/\./, $ENV{_HANDLER};
    my $pkg_name = $perl_snippet =~ s/\W/_/gr;
    return ($perl_snippet, undef) unless length($perl_method//'');
    eval {
        my $handler_script = "$ENV{LAMBDA_TASK_ROOT}/$perl_snippet.pl";
        if($ENV{SCRIPT_NAMESPACE}){
            eval "package $pkg_name {
                do('$handler_script') // do {
                    die \"problem loading handler script $handler_script: \$!\n\"   if \$!;
                    die \"problem compiling handler script $handler_script: \$@\n\" if \$@;
                }
            }}";
            die $@ if $@;
        } else {
            do($handler_script) // do {
                die "problem loading handler script $handler_script: $!\n"   if $!;
                die "problem compiling handler script $handler_script: $@\n" if $@;
            };
        }
    };
    if($@){
        # FIXME: improve/fix/test/implement this check
        my $handle_request_data = "{\"errorMessage\" : \"Failed to load function $ENV{_HANDLER}: $@\", \"errorType\" : \"InvalidFunctionException\"}";
        if($ENV{USE_LIBCURL}){
            Util::HTTP::http_do('POST', "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/init/error", undef, \$handle_request_data);
        } else {
            # handle '' escaping for shells
            $handle_request_data =~ s/'/'"'"'/g;
            my $request_handled = `curl -v -sS -X POST "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/init/error" -d '$handle_request_data'`;
            if($?){
                my $exit_value   = $? >> 8;
                my $signal_value = $? & 127;
                die "problem running lambda executor for $ENV{_HANDLER}: signal=$signal_value,exit=$exit_value\n";
            }
            p_log($request_handled) if length($request_handled);
        }
    }
    return ($pkg_name, $perl_method);
}

sub infinite_loop {
    my ($info_abbr) = @_;
    # localize INT|TERM|HUP
    my $loop = 1;
    my $s_handler = sub {$loop=0};
    local $SIG{HUP}  = $s_handler;
    local $SIG{INT}  = $s_handler;
    local $SIG{TERM} = $s_handler;
    local @ARGV = ();
    while($loop){
        p_log("ENV ".join(',', (map {"$_=".($ENV{$_}//'')} qw(USE_LIBCURL INVARIANT_TMP PRINT_LOG SCRIPT_EXEC SCRIPT_NAMESPACE))));
        # fetch a new lambda invocation
        my ($event_data, $request_headers, $invocation_id) = fetch_new();
        my $s_abbr = "$info_abbr [$invocation_id]";
        p_log($s_abbr);

        # first process the request
        my ($response_t, $handle_request_data) = process_request($invocation_id, $event_data, $request_headers);

        # post response
        p_log("$s_abbr $response_t");
        post_response($invocation_id, $response_t, $handle_request_data);
    }
    return;
}

sub process_request {
    my ($invocation_id, $input_data, $request_headers) = @_;

    # now execute what was requested
    my $lambda_context = {};
    my ($response_t, $handle_request_data);
    my $exit_value_wanted;
    my ($oldout, $olderr, $oldin);
    eval {
        # clean /tmp
        cleantmp();

        # chdir LAMBDA_TASK_ROOT
        chdir($ENV{LAMBDA_TASK_ROOT})
            or die "Error chdir to LAMBDA_TASK_ROOT path=$ENV{LAMBDA_TASK_ROOT}: $!\n";

        # save STDOUT, STDERR and STDIN
        open($oldout, ">&STDOUT") or die "Can't dup STDOUT: $!\n";
        open($olderr, ">&STDERR") or die "Can't dup STDERR: $!\n";
        open($oldin,  "<&STDIN")  or die "Can't dup STDIN: $!\n";

        # fake stdout
        my $tmp_out_fn = "/tmp/fake_out.$$.".time().".out";
        open(my $fake_out_fh, ">", $tmp_out_fn)   or die "Error opening $tmp_out_fn for write (stdout): $!\n";
        open(STDOUT, ">&=".fileno($fake_out_fh))  or die "Error dup STDOUT to $tmp_out_fn: $!\n";
        my $old_fh_out = select STDOUT; $|=1; select $old_fh_out;

        # fake stdin, fill the file with the input data from the request
        my $tmp_in_fn  = "/tmp/fake_in.$$.".time().".in";
        open(my $fake_in_fh, "+>", $tmp_in_fn)    or die "Error opening $tmp_in_fn for read/write (stdin): $!\n";
        unlink $tmp_in_fn or p_log("Error unlink $tmp_in_fn: $!");
        syswrite($fake_in_fh, $input_data)        // die "Error write ".length($input_data)." bytes to $tmp_in_fn: $!\n";
        seek($fake_in_fh, 0, 0)                   or die "Error seek to 0 in $tmp_in_fn: $!\n";
        open(STDIN, "<&=".fileno($fake_in_fh))    or die "Error dup STDIN to $tmp_in_fn: $!\n";

        # process/run
        eval {
            if(defined $perl_method){
                # localize an exit to be a fake die + keep what exit code was requested
                no warnings 'once';
                local *CORE::GLOBAL::exit = sub {
                    $exit_value_wanted = $_[0]//0;
                    if($exit_value_wanted != 0){
                        die "exit called with exit_value=$exit_value_wanted, at ".join(':', (caller(1))[0,3,6])."\n";
                    }
                };

                # pkg_name is the script itself now, as we don't have a perl_method
                # set back STDOUT, STDERR and STDIN
                open(STDOUT, ">&", $oldout)  or die "Can't dup back STDOUT: $!\n";
                open(STDERR, ">&", $olderr)  or die "Can't dup back STDERR: $!\n";
                open(STDIN,  "<&", $oldin)   or die "Can't dup back STDIN: $!\n";
                local ($?, $!, $@);
                if($ENV{SCRIPT_NAMESPACE}){
                    ($response_t, $handle_request_data) = eval "package $pkg_name {$perl_method(\$input_data //= '', \$lambda_context)}";
                } else {
                    no strict 'refs';
                    ($response_t, $handle_request_data) = eval {&$perl_method($input_data //= '', $lambda_context)};
                }
                if($@){
                    chomp(my $err = $@);
                    die "$err\n";
                }
                if(!defined $handle_request_data and length($response_t//'') and $response_t !~ m/^(response|error)$/){
                    $handle_request_data = $response_t;
                    $response_t          = 'response';
                }
            } else {
                if($ENV{SCRIPT_EXEC}){
                    Util::ASYNC::execute_async(\$m_proc_state, 1, "[$$] $invocation_id process forked", sub {
                        my $handler_script = "$ENV{LAMBDA_TASK_ROOT}/$pkg_name";
                        # make sure stdin, stdout and stderr aren't closed on exec
                        for (*STDIN, *STDOUT, *STDERR){
                            my $fl = fcntl($_, F_GETFL, 0)        or p_log("problem F_GETFL on FD=".fileno($_).": $!");
                            fcntl($_, F_SETFL, $fl & ~FD_CLOEXEC) or p_log("problem F_SETFL on FD=".fileno($_).": $!");
                        }
                        exec $handler_script or die "Error exec $handler_script: $!\n";
                    },
                    sub {
                        my ($_me, $pid, $exit_v, $signal_v) = @_;
                        die "$_me exited with: exit_value=$exit_v,signal_value=$signal_v\n" if $signal_v or $exit_v;
                        $response_t        //= 'response';
                        $exit_value_wanted //= 0;
                        return;
                    });
                    Util::ASYNC::wait_for_all_async_jobs(\$m_proc_state);
                } else {
                    # localize an exit to be a fake die + keep what exit code was requested
                    no warnings 'once';
                    local *CORE::GLOBAL::exit = sub {
                        $exit_value_wanted = $_[0]//0;
                        if($exit_value_wanted != 0){
                            die "exit called with exit_value=$exit_value_wanted, at ".join(':', (caller(1))[0,3,6])."\n";
                        }
                    };
                    local ($?, $!, $@);
                    my $handler_script = "$ENV{LAMBDA_TASK_ROOT}/$pkg_name.pl";
                    do($handler_script) // do {
                        die "problem loading handler script $handler_script: $!\n"   if $!;
                        die "problem compiling handler script $handler_script: $@\n" if $@;
                    };
                }
            }

            # set back STDOUT, STDERR and STDIN
            open(STDOUT, ">&", $oldout)  or die "Can't dup back STDOUT: $!\n";
            open(STDERR, ">&", $olderr)  or die "Can't dup back STDERR: $!\n";
            open(STDIN,  "<&", $oldin)   or die "Can't dup back STDIN: $!\n";

            # fake an "exit 0" if it wasn't done yet
            close($fake_in_fh);
            close($fake_out_fh) or die "Error closing tmp $tmp_out_fn: $!\n";

            # we don't have a returned handler data, but we do check for stdout
            $handle_request_data //= do {
                open(my $fake_out_fh_in, "<", $tmp_out_fn)
                    or die "Error opening $tmp_out_fn for re-read (stdout): $!\n";
                local $/; <$fake_out_fh_in>
            };
            $response_t          //= 'response';
            $exit_value_wanted   //= 0;
        };
        if($@){
            chomp(my $err = $@);
            $err = "problem executing $ENV{_HANDLER} for [$invocation_id]: $err\n";
            p_log($err);
            # was exit requested and 0? If NOT: make an error response
            if(!defined $exit_value_wanted or $exit_value_wanted > 0){
                $response_t = 'error';
                local $@;
                eval {cpan_load('JSON::XS')};
                p_log("problem loading JSON::XS: $@") if $@;
                $handle_request_data  = JSON::XS::encode_json({
                    errorType    => "RuntimeException",
                    errorMessage => $err,
                });
            }
        }

        # set back STDOUT, STDERR and STDIN
        open(STDOUT, ">&", $oldout)  or die "Can't dup back STDOUT: $!\n";
        open(STDERR, ">&", $olderr)  or die "Can't dup back STDERR: $!\n";
        open(STDIN,  "<&", $oldin)   or die "Can't dup back STDIN: $!\n";

        # chdir LAMBDA_TASK_ROOT
        chdir($ENV{LAMBDA_TASK_ROOT})
            or die "Error chdir to LAMBDA_TASK_ROOT path=$ENV{LAMBDA_TASK_ROOT}: $!\n";

        # clean /tmp
        cleantmp();
    };
    if($@){
        chomp(my $err = $@);
        eval {
            open(STDOUT, ">&", $oldout)  or die "Can't dup back STDOUT: $!\n";
            open(STDERR, ">&", $olderr)  or die "Can't dup back STDERR: $!\n";
            open(STDIN,  "<&", $oldin)   or die "Can't dup back STDIN: $!\n";
        };
        p_log("problem setting FD=1,2,3 back: $@") if $@;
        chdir($ENV{LAMBDA_TASK_ROOT});
        cleantmp();
        $response_t = 'error';
        eval {cpan_load('JSON::XS')};
        p_log("problem loading JSON::XS: $@") if $@;
        $handle_request_data  = JSON::XS::encode_json({
            errorType    => "RuntimeException",
            errorMessage => "problem executing $ENV{_HANDLER} for [$invocation_id]: $err\n"
        });
    }
    $response_t          //= 'response';
    $handle_request_data //= '';
    return ($response_t, $handle_request_data);
}

sub fetch_new {
    my ($event_data, $next_headers);
    if($ENV{USE_LIBCURL}){
        my $next_lambda = Util::HTTP::http_do('GET', "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next");
        $event_data    = $next_lambda->{body_ref};
        $next_headers  = $next_lambda->{headers_ref};
    } else {
        # new request
        my $tmp_headers_fn = "/tmp/h_tmp.$$.".time();
        $event_data = `curl -v -sS -LD "$tmp_headers_fn" -X GET "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next"`;
        if($?){
            my $exit_value   = $? >> 8;
            my $signal_value = $? & 127;
            die "problem running curl new lambda fetch: signal=$signal_value,exit=$exit_value\n";
        }
        $next_headers = do {open(my $_h_fn, '<', $tmp_headers_fn); <$_h_fn>};
    }
    my $invocation_id = (grep {s/^Lambda-Runtime-Aws-Request-Id: (.*?)\r?$/$1/} split m/\n/, ($next_headers//''))[0];
    die "no $invocation_id found\n" unless length($invocation_id//'');
    return ($event_data, $next_headers, $invocation_id);
}

sub post_response {
    my ($invocation_id, $response_t, $handle_request_data) = @_;
    $response_t //= 'response';
    $response_t   = 'error' unless $response_t =~ m/^(error|response)$/;
    if($ENV{USE_LIBCURL}){
        Util::HTTP::http_do('POST', "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$invocation_id/$response_t", undef, \$handle_request_data);
    } else {
        # handle '' escaping for shells
        $handle_request_data =~ s/'/'"'"'/g;
        my $request_handled = `curl -v -sS -X POST "http://$ENV{AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$invocation_id/$response_t" -d '$handle_request_data'`;
        if($?){
            my $exit_value   = $? >> 8;
            my $signal_value = $? & 127;
            die "problem running curl end lambda invocation for [$invocation_id]: signal=$signal_value,exit=$exit_value\n";
        }
        p_log($request_handled) if length($request_handled);
    }
    return;
}

# NOTE: /tmp dir usage is limited to 512MB (see https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
sub cleantmp {
    return unless $ENV{INVARIANT_TMP}||1;
    eval {
        cpan_load('File::Path');
        chdir($ENV{LAMBDA_TASK_ROOT})
            or die "Error chdir to LAMBDA_TASK_ROOT path=$ENV{LAMBDA_TASK_ROOT}: $!\n";
        if(opendir(my $d_h, '/tmp')){
            File::Path::rmtree("/tmp/$_") for grep !m/^\.\.?$/, readdir($d_h);
            closedir($d_h);
        } else {
            p_log("error opendir /tmp: $!");
        }
    };
    p_log("error cleaning /tmp: $@") if $@;
    return;
}

# to dynamically load stuff
sub cpan_load {
    eval "require $_[0]";
    die $@ if $@;
    return $_[0];
}

sub p_log {
    my (@msg) = @_;
    return unless ($ENV{PRINT_LOG}||1);
    my $msg = "LOG [$$] ".join('', map {$_//''} @msg);
    chomp($msg);
    chomp($msg);
    return print "$msg\n";
}


# this is copy-pasted for the moment and can be extremely slimmed down

package Util::HTTP;

use Errno qw(EINTR EAGAIN);

use WWW::Curl::Easy;
use WWW::Curl::Multi;
use URI;

our @EXPORT_OK = qw(
    http_do
    http_handle
    http_request
    http_request_prepare
    http_request_schedule
    http_request_schedule_wait_all
    http_request_scheduled_currently
    http_request_schedule_loop
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub http_do {
    my ($http_method, $url, $headers, $request_body_ref, $cfg, $curl_state_ref) = @_;
    $cfg //= {};
    $$curl_state_ref //= http_handle({
        useragent         => 'PP/1.1',
        (($cfg->{username} and $cfg->{password})?(
            user          => $cfg->{username},
            pass          => $cfg->{password}
        ):()),
        httpsverify       => $cfg->{httpsverify}?0x01:0x0,
        ca_path           => $cfg->{capath},
        ca_cert           => $cfg->{certfile},
        ssl_pass          => $cfg->{pem_pass},
        ($cfg->{bind_ip}?(
            bind_ip       => $cfg->{bind_ip}
        ):()),
        timeout           => 0,
        verbose           => 0,
        %{$cfg},
    });
    my $result = eval {
        return http_request($http_method, $url, $headers, $request_body_ref, $curl_state_ref, $cfg);
    };
    if($@ or !defined($result) or ($result and not($result->{http_code} =~ m/^(100|200|201|202|307|206|204)$/))){
        die "http error: ".($result->{http_code}//'<no http code>').": ".($result->{errstring}||$result->{body}||$@)."\n";
    }
    return $result;
}

sub http_request_schedule {
    my ($mcurl_state_ref, $curl_handle, $c_sub, $e_sub, $response_headers_ref) = @_;
    my $_st = $mcurl_state_ref //= {still_running => 0};
    $_st->{mcurl} //= WWW::Curl::Multi->new();

    # set an id
    my $cid = $curl_handle->getinfo(CURLINFO_PRIVATE) // do {
        $curl_handle->setopt(CURLOPT_PRIVATE, "$curl_handle");
        $curl_handle->getinfo(CURLINFO_PRIVATE);
    };

    # keep the response headers, this is kept in the mcurl state
    $response_headers_ref //= \(my $_dummy = '');
    $curl_handle->setopt(CURLOPT_WRITEHEADER, $response_headers_ref);

    # run loop once, we might have stuff todo
    http_request_schedule_loop($_st);

    # but block until we have < max_parallel
    if(defined $_st->{max_parallel}){
        while(($_st->{still_running}//0) >= $_st->{max_parallel}){
            http_request_schedule_loop($_st);
        }
    }

    # actually schedule the request, keeping the response callback
    $_st->{h}{$cid} = {ch => $curl_handle, c => $c_sub, (defined $e_sub?(e => $e_sub):()), h => $response_headers_ref};
    $_st->{mcurl}->add_handle($curl_handle);
    return;
}

sub http_request_schedule_loop {
    my ($_st) = @_;
    return unless $_st->{mcurl};
    return unless http_request_scheduled_currently($_st);
    $_st->{still_running} = $_st->{mcurl}->perform;
    my ($rd_fd, $wr_fd, $e_fd) = $_st->{mcurl}->fdset;
    my $r;
    if(@{$rd_fd} or @{$wr_fd}){
        local $!;
        my $rd_fd_bm = '';
        my $wr_fd_bm = '';
        my $e_fd_bm  = '';
        vec($rd_fd_bm, $_, 1) = 1 for @{$rd_fd};
        vec($wr_fd_bm, $_, 1) = 1 for @{$wr_fd};
        vec($e_fd_bm,  $_, 1) = 1 for @{$e_fd};
        $r = select(my $rout = $rd_fd_bm, my $wout = $wr_fd_bm, $e_fd_bm, 0.1) //
            do {die "system call failed: $!\n" unless $!{EINTR} || $!{EAGAIN} || $!{EINPROGRESS}};
    } else {
        # http://manpages.ubuntu.com/manpages/trusty/man3/curl_multi_fdset.3.html
        local $!;
        $r = select(undef, undef, undef, 0.1);
    }

    $_st->{still_running} = $_st->{mcurl}->perform;
    while (my ($cid, $return_value) = $_st->{mcurl}->info_read){
        last unless defined $cid;
        my $http_h = delete $_st->{h}{$cid};
        my $curl_h = delete $http_h->{ch};

        my %res;
        $res{errcode}     = $return_value;
        $res{http_code}   = $curl_h->getinfo(CURLINFO_HTTP_CODE) // 0;
        $res{http_err}    = $curl_h->strerror($res{errcode}) if ($res{errcode}//'0') ne '0';
        $res{errstring}   = $curl_h->errbuf;
        $res{http_req_id} = $cid;
        $res{headers_ref} = ${$http_h->{h}//\(my $_dummy = '')};
        my $r_headers = $res{headers_hash} = {};
        foreach my $kv (split m/\r\n/, ($res{headers_ref}//'')){
            my @h_kv = split m/: /, $kv, 2;
            if(@h_kv >= 2){
                if(!defined $r_headers->{$h_kv[0]}){
                    $r_headers->{$h_kv[0]} = $h_kv[1];
                } else {
                    push @{$r_headers->{$h_kv[0]}}, $h_kv[1];
                }
            }
        }

        eval {&{$http_h->{c}}($curl_h, \%res)};
        if($@){
            chomp(my $err = $@);
            die "$err\n";
        }
    }
    return;
}

sub http_request_scheduled_currently {
    my ($mcurl_state_ref) = @_;
    return scalar(keys %{$mcurl_state_ref->{h}//{}});
}

sub http_request_schedule_wait_all {
    my ($_st) = @_;
    return unless $_st->{mcurl};
    do {
        http_request_schedule_loop($_st);
    } while ($_st->{still_running} or http_request_scheduled_currently($_st));
    return;
}

sub http_request {
    my ($method, $url, $headers, $request_body_ref, $curl_state_ref, $cfg) = @_;
    $request_body_ref //= \(my $dummy = '');
    my $curl_h = http_request_prepare($method, $url, $headers, $request_body_ref, $curl_state_ref, $cfg, \(my $response_headers = ''), \(my $response_body_ref = ''));

    my %res;
    $res{errcode}     = $curl_h->perform;
    $res{http_code}   = $curl_h->getinfo(CURLINFO_HTTP_CODE) // 0;
    $res{http_err}    = $curl_h->strerror($res{errcode}) if ($res{errcode}//'0') ne '0';
    $res{errstring}   = $curl_h->errbuf;
    $res{body_ref}    = $response_body_ref if length($response_body_ref);
    $res{body_ref}  //= $dummy             if length($dummy);
    $res{headers_ref} = $response_headers  if length($response_headers);
    return \%res;
}

sub http_request_prepare {
    my ($method, $url, $headers, $request_body_ref, $curl_state_ref, $cfg, $response_headers_ref, $response_body_ref) = @_;

    $request_body_ref     //= \(my $_dummy_r = '');
    $response_headers_ref //= \(my $_dummy_h = '');
    $response_body_ref    //= \(my $_dummy_b = '');
    my $curl = $$curl_state_ref //= http_handle($cfg//{});

    my $u = URI->new($url);
    $curl->setopt(CURLOPT_URL,                        $u->as_string            );
    $curl->setopt(CURLOPT_PORT,                       $u->port                 );
    $curl->setopt(CURLOPT_WRITEHEADER,                $response_headers_ref    );

    $headers          //= {};
    $method             = uc($method//'GET');

    $curl->setopt( CURLOPT_CUSTOMREQUEST,             $method                  );
    if      ($method eq 'GET'){
        if(ref($request_body_ref) eq 'CODE'){
            $curl->setopt( CURLOPT_WRITEDATA,         $response_body_ref       ); # the provided callback will handle it anyways
            $curl->setopt( CURLOPT_WRITEFUNCTION,     sub {
                my (@args) = @_;
                return &{$request_body_ref}(@args, $response_headers_ref, ($curl->getinfo(CURLINFO_HTTP_CODE)//0));
            });
        } else {
            $curl->setopt( CURLOPT_WRITEDATA,         $request_body_ref        );
            $curl->setopt( CURLOPT_WRITEFUNCTION,     \&_writer_callback       );
        }
    } elsif ($method eq 'PUT' or $method eq 'POST'){
        $curl->setopt( CURLOPT_UPLOAD,                1                        );
        if(ref($request_body_ref) eq 'CODE'){
            $curl->setopt( CURLOPT_READDATA,          [\(my $_d=''), 0, 0]     ); # the provided callback will handle it anyways
            $curl->setopt( CURLOPT_READFUNCTION,      $request_body_ref        );
            my $sz = $headers->{'Content-Length'} // $headers->{'content-length'};
            $curl->setopt( CURLOPT_INFILESIZE_LARGE,  $sz) if defined $sz;
        } else {
            $curl->setopt( CURLOPT_READDATA,          [$request_body_ref,0,length($$request_body_ref)]);
            $curl->setopt( CURLOPT_READFUNCTION,      \&_reader_callback       );
            my $sz = $headers->{'Content-Length'} // $headers->{'content-length'} //length($$request_body_ref);
            $curl->setopt( CURLOPT_INFILESIZE_LARGE,  $sz);
        }
        $curl->setopt( CURLOPT_WRITEDATA,             $response_body_ref       ); # the provided callback will handle it anyways
        $curl->setopt( CURLOPT_WRITEFUNCTION,         \&_writer_callback       );
    } elsif ($method eq 'HEAD'){
        $curl->setopt( CURLOPT_NOBODY,                1                        );
    }

    $curl->setopt( CURLOPT_HTTPHEADER,                [map {"$_: $headers->{$_}"} grep {defined $headers->{$_}} keys %{$headers//{}}]) if keys %{$headers};

    return $curl;
}

sub http_handle {
    my ($args) = @_;

    my $HTTP_VERSION;
    $HTTP_VERSION = CURL_HTTP_VERSION_1_1 if ($args->{httpver}//'') eq '1.1';
    $HTTP_VERSION = CURL_HTTP_VERSION_1_0 if ($args->{httpver}//'') eq '1.0';

    my $curl = $args->{curl} // WWW::Curl::Easy->new();
    $curl->setopt( CURLOPT_TCP_NODELAY,            $args->{tcp_nodelay}   ) if exists $args->{tcp_nodelay};
    $curl->setopt( CURLOPT_INTERFACE,              $args->{bind_ip}       ) if $args->{bind_ip};
    $curl->setopt( CURLOPT_HTTP_VERSION,           $HTTP_VERSION          ) if $HTTP_VERSION;
    $curl->setopt( CURLOPT_CONNECTTIMEOUT,         $args->{timeout}//120  );
    $curl->setopt( CURLOPT_TIMEOUT,                $args->{timeout}//120  );
    $curl->setopt( CURLOPT_USERAGENT,              $args->{useragent}  // 'PP/1.0' );
    $curl->setopt( CURLOPT_USERNAME,               $args->{user}          ) if $args->{user};
    $curl->setopt( CURLOPT_PASSWORD,               $args->{pass}          ) if defined $args->{pass};
    $curl->setopt( CURLOPT_FOLLOWLOCATION,         1                      ) if $args->{follow_last};
    $curl->setopt( CURLOPT_REFERER,                $args->{referer}       ) if $args->{referer};
    $curl->setopt( CURLOPT_FTP_USE_EPSV,           0                      ) if $args->{passive};
    $curl->setopt( CURLOPT_RANGE,                  $args->{range}         ) if $args->{range};
    if($args->{proxy}){
        $curl->setopt( CURLOPT_PROXY,              $args->{proxy}             );
        $curl->setopt( CURLOPT_PROXYPORT,          $args->{proxyport} // 8080 );
        $curl->setopt( CURLOPT_PROXYTYPE,          (($args->{proxyscheme}//'http') eq 'http')?1:($args->{proxyscheme} eq 'https'?2:0));
        if(defined $args->{proxyuser} && defined $args->{proxypassword}){
            my $proxy_auth = $args->{proxy_auth} // "$args->{proxyuser}:$args->{proxypassword}";
            $curl->setopt( CURLOPT_PROXYUSERPWD,  $proxy_auth );
            if($args->{proxy_auth_type}){
                my $proxy_auth_type   = CURLAUTH_NONE;
                $proxy_auth_type += CURLAUTH_BASIC  if $args->{proxy_auth_type} =~ /basic/i;
                $proxy_auth_type += CURLAUTH_DIGEST if $args->{proxy_auth_type} =~ /digest/i;
                $proxy_auth_type += CURLAUTH_NTLM   if $args->{proxy_auth_type} =~ /ntlm/i;
                $proxy_auth_type  = CURLAUTH_ANY    if $args->{proxy_auth_type} =~ /any/i;

                $curl->setopt( CURLOPT_PROXYAUTH, $proxy_auth_type );
            }
        }
    }

    $curl->setopt( CURLOPT_TRANSFER_ENCODING,      0                           );
    $curl->setopt( CURLOPT_SSL_VERIFYPEER,         (($args->{httpsverify}//0x0) & 0x01) );
    $curl->setopt( CURLOPT_SSL_VERIFYHOST,         (($args->{httpsverify}//0x0) & 0x02) );
    $curl->setopt( CURLOPT_SSL_SESSIONID_CACHE,    0                      );
    $curl->setopt( CURLOPT_CAPATH,                 $args->{ca_path}       ) if $args->{ca_path};
    $curl->setopt( CURLOPT_SSLKEYPASSWD,           $args->{ssl_pass}      ) if $args->{ssl_pass};
    $curl->setopt( CURLOPT_CAINFO,                 $args->{ca_cert}       ) if $args->{ca_cert}  && -f $args->{ca_cert};
    $curl->setopt( CURLOPT_SSLCERT,                $args->{pem_cert}      ) if $args->{pem_cert} && -f $args->{pem_cert};
    $curl->setopt( CURLOPT_SSLVERSION,             $args->{ssl_ver}       ) if $args->{ssl_ver};
    $curl->setopt( CURLOPT_NOSIGNAL,               1                      ) if $args->{nosignal};
    $curl->setopt( CURLOPT_HEADERFUNCTION,         \&_header_callback     );
    $curl->setopt( CURLOPT_VERBOSE,                1                      ) if $args->{verbose};
    $curl->setopt( CURLOPT_PRIVATE,                $args->{http_req_id}   ) if defined $args->{http_req_id};

    return $curl;
}

sub _header_callback {
    my ($chunk, $header_data) = @_;
    $$header_data .= $chunk;
    return length($chunk);
}

sub _reader_callback {
    my ($sz, $scratch_state) = @_;
    return '' if $scratch_state->[1] >= $scratch_state->[2];
    my $chunk = substr(${$scratch_state->[0]}, $scratch_state->[1], $sz);
    $scratch_state->[1] += length($chunk);
    return $chunk;
}

sub _writer_callback {
    my ($chunk, $userdata_ref) = @_;
    $$userdata_ref .= $chunk;
    return length($chunk);
}

package Util::ASYNC;

use strict; use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
    execute_async
    wait_for_all_async_jobs
    collect_jobs
    real_exit
);

use POSIX qw(:sys_wait_h sigprocmask SIG_BLOCK SIG_UNBLOCK SIGCHLD SIGINT SIGTERM SIGHUP SIGQUIT);

sub execute_async {
    my ($state, $max_parallel, $abbr, $c_sub, $e_sub) = @_;
    $$state //= {};

    $max_parallel ||= 1;
    $max_parallel   = 1 if $max_parallel < 0;
    $max_parallel++ if $$state->{_child};
    while(0 < _collect_job($state, waitpid(-1, WNOHANG))){};
    while(keys %{$$state->{_workers}} >= $max_parallel){
        my $ok = _collect_job($state, waitpid(-1, 0));
        last if $ok == -1;
        next unless $ok;
    }

    REFORK:
    # block signal handlers locally *BEFORE* the fork()
    my $signals_block = POSIX::SigSet->new(SIGINT, SIGQUIT, SIGTERM, SIGCHLD, SIGHUP);
    sigprocmask(SIG_BLOCK, $signals_block, my $dummy)
        || die "Error setting signal mask to block: $!\n";
    my $new_pid = fork();
    if($new_pid){
        sigprocmask(SIG_UNBLOCK, $signals_block, my $dummy)
            || die "Error setting signal mask to unblock (parent): $!\n";
        $$state->{_workers}{$new_pid} = [$abbr, $e_sub];
        return;
    } elsif(!defined $new_pid) {
        goto REFORK;
    } else {
        eval {
            # internal perl defaults again
            local $SIG{__DIE__}  = 'DEFAULT';
            local $SIG{__WARN__} = sub {
                my ($msg) = @_;
                chomp($msg);
                warn("$msg\n");
            };

            # reset all signal handlers to ignore stuff, ppl should set them in
            # the sub {} that's given, we don't want the process to die before
            # the sub is being executed, first set default handlers, then
            # unblock the signals
            local $SIG{HUP} = local $SIG{INT} = local $SIG{TERM} = local $SIG{QUIT} = 'IGNORE';
            local $SIG{CHLD} = 'DEFAULT';
            sigprocmask(SIG_UNBLOCK, $signals_block, my $dummy)
                // die "Error setting signal mask to unblock (worker): $!\n";

            my $oldfh = select STDOUT;
            local $|=1;
            select $oldfh;
            $oldfh = select STDERR;
            local $|=1;
            select $oldfh;
            %{$$state} = ();
            local $!;
            local $?;
            return &$c_sub();
        };
        if($@){
            my $err = $@;
            my $orig_error = $@;
            chomp($err);
            eval {
                if(defined $e_sub){
                    &{$e_sub}($abbr, $$, undef, undef, $orig_error);
                } else {
                    warn("$err\n");
                }
            };
            eval {warn($@) if $@};
            # never die in a child fork(): END gets executed
            POSIX::_exit(255);
        }
        POSIX::_exit(0);
    }
    return $new_pid;
}

sub wait_for_all_async_jobs {
    my ($state) = @_;
    $$state //= {};
    return unless keys %{$$state->{_workers}};
    while(-1 != _collect_job($state, waitpid(-1, 0))){
        return unless keys %{$$state->{_workers}};
    }
    return;
}

sub collect_jobs {
    my ($state) = @_;
    $$state //= {};
    return unless keys %{$$state->{_workers}};
    my $nr = 0;
    while(0 < _collect_job($state, waitpid(-1, WNOHANG))){$nr++};
    return $nr > 0;
}

sub _collect_job {
    my ($state, $pid) = @_;
    $$state //= {};
    return $pid if $pid <= 0;
    my $p_entry = delete $$state->{_workers}{$pid};
    if($?){
        my $exit_value   = $? >> 8;
        my $signal_value = $? & 127;
        if(defined $p_entry and defined $p_entry->[1]){
            eval {&{$p_entry->[1]}($p_entry->[0], $pid, $exit_value, $signal_value)};
            die $@ if $@;
        } else {
            warn("execute failed for:pid=$pid,exit=$exit_value,signal=$signal_value\n");
        }
        return $pid;
    }
    return -1 if !keys %{$$state->{_workers}}; # to allow for the start_collect_data() daemon to stop
    return $pid;
}

sub real_exit {
    my ($err) = @_;
    POSIX::_exit($err) if defined $err;
    POSIX::_exit($??$?>>8:0);
    return;
}

1;
