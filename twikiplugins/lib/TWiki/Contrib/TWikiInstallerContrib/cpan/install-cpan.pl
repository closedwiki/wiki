#!/usr/bin/perl -w
# $Id$
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL

################################################################################

use strict;
use Data::Dumper qw( Dumper );
++$|;
#open(STDERR,'>&STDOUT'); # redirect error to browser
use CPAN;
use File::Path qw( mkpath );
use File::Spec qw( rel2abs );
use Getopt::Long;
use FindBin;
use Pod::Usage;
use Cwd qw( cwd );
sub mychomp { chomp $_[0]; $_[0] }

my $optsConfig = {
#
    baselibdir => $FindBin::Bin . "/../cgi-bin/lib/CPAN",
    mirror => "file:$FindBin::Bin/MIRROR/TWIKI",
#
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

GetOptions( $optsConfig,
	    'baselibdir=s', 'mirror=s', 'user=s',
#	    'baselibdir=s', 'mirror=s@', 'user=s',
# miscellaneous/generic options
	    'help', 'man', 'debug', 'verbose|v',
	    );
pod2usage( 1 ) if $optsConfig->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $optsConfig->{man};
print STDERR Dumper( $optsConfig ) if $optsConfig->{debug};

# fix up relative paths
$optsConfig->{baselibdir} = File::Spec->rel2abs( $optsConfig->{baselibdir} );
$optsConfig->{mirror} = File::Spec->rel2abs( $optsConfig->{mirror} );

# TODO: copied (and cropped) from install_twiki.cgi
use Config;
#my $localLibBase = "$optsConfig->{baselibdir}/lib/" . $Config{version};
my $localLibBase = "$optsConfig->{baselibdir}/lib";
my @localLibs = ( $localLibBase, "$localLibBase/$Config{archname}" );
unshift @INC, @localLibs;
$ENV{PERL5LIB} = join( ':', @localLibs );
print STDERR Dumper( \@INC ) if $optsConfig->{debug};

################################################################################

-d $optsConfig->{baselibdir} or mkpath $optsConfig->{baselibdir};

# eg
#installLocalModules({
#    dir => $cpan,
#    config => {
#	'XML::SAX' => [ ( 'Do you want XML::SAX to alter ParserDetails.ini? [Y]' => 'Y' ) ],
#(or)	'XML::SAX' => [ ( 'Do you want XML::SAX to alter ParserDetails.ini?' => 'Y' ) ],
#(or)	'XML::SAX' => [ ( qr/^Do you want XML::SAX to alter ParserDetails.ini\?/ => 'Y' ) ],
#    },
#    modules => [ qw( XML::SAX ) ],
#});

my @defaultTWikiModules;	# forward declaration
installLocalModules({
    dir => $optsConfig->{baselibdir},
    config => {
	'HTML::Parser' => [ qw( no ) ],
	'XML::SAX' => [ qw( Y ) ],
	'Data::UUID' => [ qw( /var/tmp 0007 ) ],
	'GD' => [ qw( /sw/lib y y y ) ],
    },
    # TODO: update to use same output as =cpan/calc-twiki-deps.pl=
    modules => [ @ARGV || @defaultTWikiModules ],
});
# Image::LibRSVG

################################################################################
################################################################################

sub installLocalModules
{
    my $parm = shift;
    my $cpan = $parm->{dir};

    $CPAN::Config->{'make'} = q[/usr/bin/make];
    # some modules refuse to work if PREFIX is set, and some refuse to work if it is not. ???
    $CPAN::Config->{'makepl_arg'} = "PREFIX=$cpan";
    $CPAN::Config->{'make_arg'} = "";
    $CPAN::Config->{'make_install_arg'} = "";
    $CPAN::Config->{'makepl_arg'} = "";
    # TODO: try other setup of config if install fails?  PREFIX seems like the preferred method, so try that first
#    $CPAN::Config->{'make_arg'} = "-I$cpan/";
#    $CPAN::Config->{'make_install_arg'} = "-I$cpan/";
#    $CPAN::Config->{'makepl_arg'} = "LIB=$cpan/lib INSTALLMAN1DIR=$cpan/man/man1 INSTALLMAN3DIR=$cpan/man/man3";

    $CPAN::Config->{'build_dir'} = "$cpan/.cpan/build";
    $CPAN::Config->{'cpan_home'} = "$cpan/.cpan";

#    'histfile' => q[/Users/wbniv/Sites/twiki/.cpan/histfile],
    $CPAN::Config->{'histsize'} = 0;

    $CPAN::Config->{'keep_source_where'} = "$cpan/.cpan/sources";

    $CPAN::Config->{'prerequisites_policy'} = 'follow';

#    $CPAN::Config->{'urllist'} = [ "file:/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/MIRROR/MINICPAN/" ];
#    $CPAN::Config->{'urllist'} = [ "file:/Users/$account/Sites/cpan/MIRROR/TWIKI/" ];
    $CPAN::Config->{'urllist'} = [ $optsConfig->{mirror} ];
    $CPAN::Config->{'build_cache'} = q[0];

    $CPAN::Config->{'ftp'} = q[/usr/bin/ftp];
    $CPAN::Config->{'gzip'} = q[/sw/bin/gzip];
    $CPAN::Config->{'pager'} = q[/usr/bin/less];
    $CPAN::Config->{'shell'} = q[/bin/bash];
    $CPAN::Config->{'tar'} = q[/sw/bin/tar];
    $CPAN::Config->{'unzip'} = q[/sw/bin/unzip];
    $CPAN::Config->{'wget'} = q[/sw/bin/wget];

#?  'cache_metadata' => q[1],
#?  'dontload_hash' => {  },
#  'ftp_proxy' => q[],
#?  'getcwd' => q[cwd],
#  'gpg' => q[],
#  'http_proxy' => q[],
#  'inactivity_timeout' => q[0],
#?  'index_expire' => q[1],
#  'inhibit_startup_message' => q[0],
#  'lynx' => q[],
#  'ncftp' => q[],
#  'ncftpget' => q[],
#  'no_proxy' => q[],
#?  'scan_cache' => q[atstart],
#?  'term_is_latin' => q[1],

#    print Data::Dumper::Dumper( $CPAN::Config );
#    CPAN::Shell->reload( qw( index ) ); # or die $!;
#    print Data::Dumper::Dumper( $CPAN::Config );

    my @modules = @{$parm->{modules}};
    print "Installing the following modules: ", Dumper( \@modules ) if $optsConfig->{debug};
    foreach my $module ( @modules )
    {
	print "Installing $module\n" if $optsConfig->{verbose};
	my $obj = CPAN::Shell->expand( Module => $module ) or warn "$module: $!";
	next unless $obj;
#	$obj->force( 'install' ); # or warn "Error installing $module\n"; 
	$obj->install; # or warn "Error installing $module\n"; 
    }
    
#    print Dumper( $CPAN::Config );
}

@defaultTWikiModules = qw(
			  XML::Parser XML::Simple 
			  Algorithm::Diff Text::Diff HTML::Diff
			  Text::Glob Number::Compare File::Find::Rule 
			  File::Slurp File::Slurp::Tree
			  List::Permutor File::Temp 
			  WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki LWP::UserAgent::TWiki::TWikiGuest
			  Archive::Zip 
			  IO::Zlib
			  IO::String Archive::Tar 
			  File::AnySpec File::Package Data::Startup Tie::Gzip File::Where Archive::TarGzip
			  Class::Virtually::Abstract Carp::Assert Class::Data::Inheritable Archive::Any
			  Time::HiRes
			  Carp::Clan Bit::Vector Date::Calc 
			  Error Class::Inner Devel::Symdump
			  URI HTML::Parser HTML::Tagset
			  Digest::MD5 Storable
			  SOAP::Lite 
			  Time::ParseDate Date::Handler Date::Parse 
			  HTML::CalendarMonthSimple 
			  Test::Unit 
			  LWP::Simple 
			  CGI::Session 
			  Weather::Com
			  GD Barcode::Code128
			  XML::NamespaceSupport XML::SAX XML::LibXML::Common XML::LibXML 
			  XML::LibXSLT Cache::Cache String::CRC
			  Data::UUID Safe Language::Prolog XMLRPC::Transport::HTTP
			  );

################################################################################
################################################################################

__DATA__
=head1 NAME

install-cpan.pl - ...

=head1 SYNOPSIS

install-cpan.pl [options] [-baselibdir] [-mirrordir]

Copyright 2004, 2005 Will Norris.  All Rights Reserved.

  Options:
   -baselibdir         where to install the CPAN modules
   -mirrordir          location of the (mini) CPAN mirror
   -verbose
   -debug
   -help               this documentation
   -man                full docs

=head1 OPTIONS

=over 8

=item B<-baselibdir>

=item B<-mirrordir>

=back

=head1 DESCRIPTION

B<install-cpan.pl> will ...

=head2 SEE ALSO

        http://twiki.org/cgi-bin/view/Codev/...

=cut

__END__
################################################################################
[~/.cpan/CPAN/MyConfig.pm]:

$CPAN::Config = {
  'build_cache' => q[10],
  'build_dir' => q[/Users/twiki/.cpan/build],
  'cache_metadata' => q[1],
  'cpan_home' => q[/Users/twiki/.cpan],
  'ftp' => q[/usr/bin/ftp],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[],
  'gzip' => q[/sw/bin/gzip],
  'histfile' => q[/Users/twiki/.cpan/histfile],
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => q[/Users/twiki/.cpan/sources],
  'lynx' => q[],
  'make' => q[/usr/bin/make],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'makepl_arg' => q[PREFIX=/Users/twiki/Sites/cgi-bin/lib/CPAN/],
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
  'urllist' => ["file:///Users/twiki/Sites/cpan/MIRROR/TWIKI/"],
  'wget' => q[/sw/bin/wget],
};
1;
__END__
