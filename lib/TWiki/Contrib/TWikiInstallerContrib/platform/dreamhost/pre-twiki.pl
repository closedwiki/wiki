#!/usr/bin/perl -w
# pre-twiki.pl
use strict;
use File::Path qw( mkpath rmtree );
use File::Copy qw( cp mv );
use File::Basename qw( dirname );
use FindBin;

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $opts = {
    whoami => mychomp( `whoami` ),
    cgibin => "$FindBin::Bin/cgi-bin",
    installcgi => 'install_twiki.cgi',
    hostname => 'wbniv.wikihosting.com',
    browser => 'links',
};

#my $INSTALL = "http://$opts->{hostname}/~$opts->{whoami}/config/install.html";
my $INSTALL = "http://$opts->{hostname}/config/install.html";

if ( -e "$opts->{cgibin}/install_twiki.cgi" )
{
    print <<__MSG__;
pre-twiki.pl has already been run
	(i checked for the existence of $opts->{cgibin}/install_twiki.cgi)
	you can delete $opts->{cgibin}/install_twiki.cgi and rerun pre-twiki.pl to force ...

continue installation at $INSTALL
__MSG__
    exit 0;
}

################################################################################
# create (copy) install_twiki.cgi into cgi-bin/ for second stage
################################################################################
-d $opts->{cgibin} || mkpath( $opts->{cgibin} );
chmod 0755, $opts->{cgibin};
#unless ( -e "$opts->{cgibin}/$opts->{installcgi}" )
#{
    cp( $opts->{installcgi}, "$opts->{cgibin}/$opts->{installcgi}" ) or die $!;
    chmod 0755, "$opts->{cgibin}/$opts->{installcgi}" or die $!;
#}

################################################################################
# install CPAN modules
################################################################################
my $cpan = "$opts->{cgibin}/lib/CPAN/";
mkpath $cpan;
my $mirror = '/home/wikihosting/CPAN-live/MIRROR/MINICPAN/' || "$FindBin::Bin/cpan/MIRROR/TWIKI/";
createMyConfigDotPm({ cpan => $cpan, config => '~/.cpan/CPAN/MyConfig.pm', mirror => "file:$mirror" });
foreach my $module (
		    qw( Test::More YAML Compress::Zlib IO::Zlib IO::String Archive::Tar Data::Startup File::Package File::Where File::AnySpec Tie::Gzip Archive::TarGzip ExtUtils::CBuilder ExtUtils::ParserXS Tree::DAG_Node ),
		    # Module::Build
		    qw( Error URI HTML::Tagset HTML::Parser LWP XML::Parser XML::Simple Algorithm::Diff Text::Diff HTML::Diff ),
		    qw( WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki ),
		    # Net::SSLeay IO::Socket::SSL
		    qw( Number::Compare Text::Glob File::Find::Rule File::Slurp File::Slurp::Tree ),
		    )
{
    print "Installing $module\n";
    print "-" x 80, "\n";
#    next;	# for testing when i already know they're all already installed
    print `~/bin/perl cpan/install-cpan.pl --mirror=$mirror --baselibdir=$cpan $module`;
#    last;
}

################################################################################
# setup permissions for rest of install
################################################################################
my $tmp = "$opts->{cgibin}/tmp";
rmtree( $tmp );
mkpath( $tmp, 0, 0777 );
chmod 0777, ".";
chmod 0777, $opts->{cgibin};
chmod 0777, "$opts->{cgibin}/lib";

################################################################################
#system( $opts->{browser} => $INSTALL ) == 0 or print "continue installation at $INSTALL\n";

################################################################################
################################################################################

sub findProgramOnPaths
{
    my ( $prog, $paths ) = @_;
    $paths ||= [ qw( /sw/bin /usr/local/bin /usr/bin /bin ) ];
    foreach my $path ( @$paths )
    {
#        print "$path\n";
        my $test = "$path/$prog";
        return $test if -x $test;
    }

    return undef;
}

sub expandTilde
{
    my $dir = shift || '';

    # expand tildes in paths (from Perl Cookbook: 7.3. Expanding Tildes in Filenames)
    $dir =~ s{ ^ ~ ( [^/]* ) }
    { $1
	  ? (getpwnam($1))[7]
	  : ( $ENV{HOME} || $ENV{LOGDIR}
	      || (getpwuid($>))[7]
	      )
      }ex;

    return $dir;
}

# FIX: copied from install-cpan.pl !!!
# updated: ~ expansion
# updated: added mirror parameter
# updated: find programs on paths
sub createMyConfigDotPm
{
    my $parm = shift;
    my $cpan = expandTilde( $parm->{cpan} ) or die "no cpan directory?";
    my $cpanConfig = expandTilde( $parm->{config} ) or die "no config file specified?";

#    unless ( -e $cpanConfig )
    {
        mkpath( dirname( $cpanConfig ) );

        open( FH, ">$cpanConfig" ) or die "$!: Can't create $cpanConfig";
        $CPAN::Config = {
            'build_cache' => q[0],
            'build_dir' => "$cpan/.cpan/build",
            'cache_metadata' => q[1],
            'cpan_home' => "$cpan/.cpan",
            'ftp' => findProgramOnPaths( 'ftp' ),
            'ftp_proxy' => q[],
            'getcwd' => q[cwd],
            'gpg' => q[],
            'gzip' => findProgramOnPaths( 'gzip' ),
            'histfile' => "$cpan/.cpan/histfile",
            'histsize' => q[0],
            'http_proxy' => q[],
            'inactivity_timeout' => q[0],
            'index_expire' => q[1],
            'inhibit_startup_message' => q[0],
            'keep_source_where' => "$cpan/.cpan/sources",
            'lynx' => q[],
            'make' => findProgramOnPaths( 'make' ),
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
            'pager' => findProgramOnPaths( 'less' ),
            'prerequisites_policy' => q[follow],
            'scan_cache' => q[atstart],
            'shell' => findProgramOnPaths( 'bash' ),
            'tar' => findProgramOnPaths( 'tar' ),
            'term_is_latin' => q[1],
            'unzip' => findProgramOnPaths( 'unzip' ),
            'wget' => findProgramOnPaths( 'wget' ),
        };

        print FH "\$CPAN::Config = {\n";
        foreach my $key ( sort keys %$CPAN::Config )
        {
            print FH qq{\t'$key' => q[$CPAN::Config->{$key}],\n};
        }
	die "no mirror specified?" unless $parm->{mirror};
        print FH qq{\t'urllist' => [ q[$parm->{mirror}] ],\n};
        print FH "};\n",
        "1;\n",
        "__END__\n";
    }

    close FH;
}
