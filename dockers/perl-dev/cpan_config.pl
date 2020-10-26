
no warnings 'once';
my $b_dir        = "/opt/";
my $base_dir     = $ENV{CPAN_HOME}    || "/opt/perl/cpan";
my $install_base = $ENV{INSTALL_BASE} || $b_dir;
$ENV{PERL5LIB} ||= "";
$ENV{PERL5LIB}  .= "$b_dir/lib/perl5:$b_dir/lib/perl5/auto:$b_dir/lib/perl5/x86_64:$b_dir/lib/perl5/x86_64/auto";
$CPAN::Config = {
  'applypatch' => q[],
  'auto_commit' => q[0],
  'build_cache' => q[100],
  'build_dir' => "$base_dir/build",
  'build_dir_reuse' => q[0],
  'build_requires_install_policy' => q[yes],
  'bzip2' => q[bzip2],
  'cache_metadata' => q[1],
  'check_sigs' => q[0],
  'cleanup_after_install' => q[0],
  'colorize_output' => q[0],
  'commandnumber_in_prompt' => q[1],
  'connect_to_internet_ok' => q[1],
  'cpan_home' => $base_dir,
  'ftp_passive' => q[1],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[gpg],
  'gzip' => q[gzip],
  'halt_on_failure' => q[0],
  'histfile' => "$base_dir/histfile",
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[0.001],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => "$base_dir/sources",
  'load_module_verbosity' => q[none],
  'make' => q[make],
  'make_arg' => q[-j8],
  'make_install_arg' => "INSTALLDIRS=site INSTALL_BASE=$install_base",
  'make_install_make_command' => q[make],
  'makepl_arg' => "INSTALLDIRS=site INSTALL_BASE=$install_base",
  'mbuild_arg' => q[],
  'mbuild_install_arg' => "INSTALLDIRS=site INSTALL_BASE=$install_base",
  'mbuild_install_build_command' => q[./Build],
  'mbuildpl_arg' => "--installdirs site --install_base $install_base",
  'no_proxy' => q[],
  'pager' => q[less],
  'patch' => q[patch],
  'perl5lib_verbosity' => q[none],
  'prefer_external_tar' => q[1],
  'prefer_installer' => q[MB],
  'prefs_dir' => $base_dir,
  'prerequisites_policy' => q[follow],
  'recommends_policy' => q[1],
  'scan_cache' => q[atstart],
  'shell' => q[bash],
  'show_unparsable_versions' => q[0],
  'show_upload_date' => q[0],
  'show_zero_versions' => q[0],
  'suggests_policy' => q[0],
  'tar' => q[tar],
  'tar_verbosity' => q[none],
  'term_is_latin' => q[1],
  'term_ornaments' => q[1],
  'test_report' => q[0],
  'trust_test_report_history' => q[0],
  'unzip' => q[unzip],
  'urllist' => [q[http://www.cpan.org/]],
  'use_prompt_default' => q[0],
  'use_sqlite' => q[0],
  'version_timeout' => q[15],
  'wget' => q[wget],
  'yaml_load_code' => q[0],
  'yaml_module' => q[YAML],
};
1;
__END__