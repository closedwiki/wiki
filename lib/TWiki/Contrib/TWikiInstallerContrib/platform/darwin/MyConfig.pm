# this gets moved to ~/.cpan/CPAN

sub mychomp { chomp $_[0]; $_[0] }

# FIXME: darwin-specific
my $cpan = "/Users/" . mychomp(`whoami`) . "/Sites/cgi-bin/lib/CPAN";

$CPAN::Config = {
  'build_cache' => q[10],
  'build_dir' => "$cpan/.cpan/build",
  'cache_metadata' => q[1],
  'cpan_home' => "$cpan/.cpan",
  'ftp' => q[/usr/bin/ftp],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[],
  'gzip' => q[/sw/bin/gzip],
  'histfile' => "$cpan/.cpan/histfile",
  'histsize' => q[0],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => "$cpan/.cpan/sources",
  'lynx' => q[],
  'make' => q[/usr/bin/make],
  'make_arg' => "-I$cpan/",
#  'make_arg' => q[],
  'make_install_arg' => "-I$cpan/lib/",
#  'make_install_arg' => q[],
  'makepl_arg' => "LIB=$cpan/lib INSTALLMAN1DIR=$cpan/man/man1 INSTALLMAN3DIR=$cpan/man/man3",
#???(sometimes?) $CPAN::Config->{'makepl_arg'} = "PREFIX=$cpan";
#  'makepl_arg' => q[],
  'ncftp' => q[],
  'ncftpget' => q[],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  'prerequisites_policy' => q[follow],
  'scan_cache' => q[atstart],
  'shell' => q[/bin/bash],
  'tar' => q[/sw/bin/tar],
  'term_is_latin' => q[1],
  'unzip' => q[/sw/bin/unzip],
  'urllist' => ["file:$cpan/MIRROR/TWIKI/"],
  'wget' => q[/sw/bin/wget],
};
1;
__END__
