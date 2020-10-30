use strict; use warnings;

use Module::CoreList;

my $err;
my @bad_modules;
my @perl_modules = Module::CoreList->find_modules(qr/./);
foreach my $m (@perl_modules){
    next unless Module::CoreList::is_core($m);
    next if $m =~ m/^(
         Moped::Msg
        |XS::APItest
        |XS::Typemap
        |ExtUtils::XSSymSet
        |Pod::Perldoc::ToTk
        |Pod::Functions::Functions
        |VMS::.*
        |Win32API
        |Amiga::.*
        |OS2::.*
        |.*?::Win32
        |ExtUtils::MakeMaker::version::regex
        |.*?::VMS
        |Win32
        |Win32CORE
        |Unicode
    $)/x;
    print "[TEST] $m\n";
    $m = "Test::Tester; require $m" if $m eq 'Test::Builder';
    eval "require $m";
    if($@ and $@ =~ m/Can't locate/){
        print "[ERROR] $m: $@\n";
        push @bad_modules, $m;
        $err = 1;
    }
}
print "[BAD] ".join(' ', @bad_modules)."\n" if @bad_modules;
exit 1 if $err;
