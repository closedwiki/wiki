#! /usr/bin/perl -w
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

BEGIN {
    my $dirHome = $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7];
    $ENV{TWIKIDEV} ||= "$dirHome/twiki";
    eval qq{ use lib( "$ENV{TWIKIDEV}/CPAN/lib", "$ENV{TWIKIDEV}/CPAN/lib/arch" ) };
}

# TODO:
#   * separate file selection from packaging (use separate step to create MANIFEST)
#   * (probably eliminate outputdir completely)
#   * use svn export (but mirror it so 
#   * readme.txt - needs editting, customising per build (type, etc.)

use Cwd qw( cwd );
use File::Copy qw( cp );
use File::Path qw( rmtree mkpath );
use File::Spec::Functions qw( rel2abs );
use File::Find::Rule;
use File::Slurp;
use File::Slurp::Tree qw( slurp_tree spew_tree );
use LWP::UserAgent;
use Getopt::Long;
use Pod::Usage;
use LWP::UserAgent::TWiki::TWikiGuest;

my $Config = {
# 
    tempdir => '.',
    outputdir => '.',
    outfile => undef,
    agent => "TWikiKernel Builder/v0.7.2",
    manifest => '-',
# output formats
    tar => 1,
    zip => 1,
# documentation switches
    changelog => 1,
    pdoc => 0,
# AUTODETECT:   pdoc => eval { require Pdoc::Parsers::Files::PerlModule } && $@ eq '',
    gendocs => 1,
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
			'localcache=s', 'tempdir=s', 'outputdir=s', 'outfile=s', 'manifest=s',
# output formats
			 'changelog!', 'tar!', 'zip!',
# documentation switches
			'pdoc!', 'gendocs!',
# miscellaneous/generic options
			'agent=s', 'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print STDERR Dumper( $Config ) if $Config->{debug};
	 
#chomp( my @svnInfo = `/home/wbniv/bin/svn/svn info .` );
chomp( my @svnInfo = `svn info .` );
die "no svn info?" unless @svnInfo;
my ( $svnRev ) = ( ( grep { /^Revision:\s+(\d+)$/ } @svnInfo )[0] ) =~ /(\d+)$/;
my ( $branch ) = ( ( grep { /^URL:/ } @svnInfo )[0] ) =~ m/^.+?\/branches\/([^\/]+)\/.+?$/;

# TODO: use Getopt to process these (learn how to do this), er, maybe not?
map { checkdirs( $Config->{$_} = rel2abs( $Config->{$_} ) ) } qw( tempdir outputdir );

$Config->{localcache} = $Config->{tempdir} . "/.cache";
$Config->{svn_export} = $Config->{localcache} . "/twiki";
$Config->{install_base} = $Config->{tempdir} . "/twiki";		# the directory the official release is untarred into
$Config->{outfile} ||= "TWikiKernel-$branch-$svnRev";
# make sure output directories exist
map { ( mkpath $Config->{$_} or die $! ) unless -d $Config->{$_} } qw( localcache install_base );
print STDERR Dumper( $Config ) if $Config->{debug};

################################################################################

if ( $Config->{verbose} )
{
    print "temporary files will go into $Config->{tempdir}\n";
    print "output tar file will go into $Config->{outputdir}\n";
}

################################################################################
# commonly-used File::Find::Rule rules
my $ruleDiscardRcsHistory = File::Find::Rule->file->name("*,v")->discard;
my $ruleDiscardRcsLock = File::Find::Rule->file->name("*.lock")->discard;
my $ruleDiscardBackup = File::Find::Rule->file->name("*~")->discard;
my $ruleDiscardOS = File::Find::Rule->file->name(".DS_Store")->discard;
my $ruleDiscardLogFiles = File::Find::Rule->or( File::Find::Rule->file->name("log*.txt"), File::Find::Rule->file->name("debug*.txt"), File::Find::Rule->file->name("warn*.txt") )->discard;
my $ruleDiscardTestCasesFiles = File::Find::Rule->directory->name('TestCases')->prune->discard;

my $ruleNormalFiles = File::Find::Rule->or( $ruleDiscardOS, $ruleDiscardRcsHistory, $ruleDiscardRcsLock, $ruleDiscardBackup, $ruleDiscardLogFiles, $ruleDiscardTestCasesFiles, File::Find::Rule->directory, File::Find::Rule->file );

################################################################################

my $installBase = $Config->{install_base} or die "no install_base?";
( rmtree( $installBase ) or die "Unable to empty the twiki build directory: $!" ) if -e $installBase;
mkpath( $installBase ) or die "Unable to create the new build directory: $!";

################################################################################

my $pwdStart = cwd();

if ( 0 ) {	# SVN EXPORT concept on hold (i _want_ anonymous svn checkouts...)
    my $svnExport = $Config->{svn_export} or die "no svn_export?";
    ( rmtree( $svnExport ) or die qq{Unable to empty the svn export directory "$svnExport": $!} ) if -e $svnExport;
    execute( qq{svn export ../.. $svnExport} ) or die $!;
#    die "no svn export output?" unless -d $svnExport;
    chdir( $svnExport ) or die $!;
}
else {
    chdir( '../..' ) or die $!;            # from tools/distro up to BRANCH (eg, trunk, DEVELOP)
}

###############################################################################
# build source code docs
if ( $Config->{changelog} )
{
    $Config->{verbose} && print "Generating CHANGELOG\n";
    # test for xsltproc
    `xsltproc --version` ?
	execute( "svn log --xml --verbose | xsltproc tools/distro/svn2cl.xsl - > CHANGELOG" )
	: die "xsltproc not found; can't generate CHANGELOG";
}

if ( $Config->{pdoc} )
{
    $Config->{verbose} && print "Generating pdoc\n";
    execute( "rm -rf doc/ ; mkdir doc/ && cd tools && perl perlmod2www.pl -source ../lib/TWiki/ -target ../doc/" ) or die $!;
    my $dirDocs = "doc";
    spew_tree( "$installBase/doc" => slurp_tree( $dirDocs, rule => $ruleNormalFiles->start( $dirDocs ) ) );
}

################################################################################
#-[lib/, templates/, data/, pub/icn, pub/TWiki, bin/]-----------------------------------
foreach my $dir qw( lib templates data bin pub logs )
{
    my $tree = slurp_tree( $dir, rule => $ruleNormalFiles->start( $dir ) );
    spew_tree( "$installBase/$dir" => $tree );
}

###############################################################################
# timestamp version number in lib/TWiki.pm
{
    my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my @dow = qw( Sun Mon Tue Wed Thu Fri Sat );
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    my $VERSION = '$Date: ' . sprintf("%04d-%02d-%02d", 1900+$year, $mon+1, $mday )
	. sprintf(" %02d:%02d:%02d +0000 ", $hour, $min, $sec )
	. sprintf("(%s, %02d %s %04d)", $dow[$wday], $mday, $months[$mon], 1900+$year) 
	. ' $ $Rev: ' . $svnRev . ' $ ';

    my $fileTWikiDotPm = "$installBase/lib/TWiki.pm";
    my $twiki_pm = read_file( $fileTWikiDotPm ) or die "version update of $fileTWikiDotPm failed";
    $twiki_pm =~ s/(\$VERSION = )('\$Date:.+?');/$1'$VERSION';/s;
    write_file( $fileTWikiDotPm, $twiki_pm ) or die "version update of $fileTWikiDotPm failed";
}

sub filterDoc {
    my $path = $File::Find::name;
    return 1 unless $path && $path =~ /\.txt$/;
    open(FR, "<$path") || die "failed to open $path for read";
    my $slash = $/;
    undef $/;
    my $conts = <FR>;
    $/ = $slash;
    close(FR);

    if ($conts =~ /%STARTINCLUDE%/ ) {
        $conts =~ s/^.*%STARTINCLUDE%//s;
    }
    if ($conts =~ /%STOPINCLUDE%/ ) {
        $conts =~ s/%STOPINCLUDE%.*$//s;
    }
    $conts =~ s/^(-- (TWiki:)?Main.[A-Z]+[a-z]+[A-Z]+\w+ - \d{2} \w{3} \d{4}( <br \/>)?\s*)$/<!-- $1 -->/mg;

    open(FR, ">$path") || die "failed to open $path for write";;
    print FR $conts;
    close(FR);
    return 1;
}

# post-filter docs
File::Find::find( \&filterDoc, "$installBase/data/TWiki" );

#-[docs]-------------------------------------------------------------------------------
map { my $doc = $_; cp( $doc, "$installBase/$doc" ) or warn "$doc: $!" }
qw (
      pub-htaccess.txt root-htaccess.txt subdir-htaccess.txt robots.txt
      index.html UpgradeTwiki
      AUTHORS COPYING COPYRIGHT LICENSE readme.txt 
    );
cp( "$installBase/AUTHORS", "$installBase/pub/TWiki/TWikiContributor/AUTHORS" );
cp( "CHANGELOG", "$installBase/CHANGELOG" ) unless -z 'CHANGELOG';

################################################################################
# all files copied to $installBase now
################################################################################

if ( $Config->{gendocs} )
{
    $Config->{verbose} && print "Generating docs\n";

    my $gendocsLocalLibCfg = "$installBase/bin/LocalLib.cfg";
    unless ( -e $gendocsLocalLibCfg )
    {
	open( LL_CFG, ">$gendocsLocalLibCfg" ) or die "can't write to LocalLib.cfg in order to run gendocs";
	print LL_CFG <<__LOCALLIB_CFG__;
\$twikiLibPath = "$installBase/lib";
\$CPANBASE = "$installBase/lib/CPAN/lib";
1;
__LOCALLIB_CFG__
	close( LL_CFG );
    }

    my $gendocsLocalSiteCfg = "$installBase/lib/LocalSite.cfg";
    unless ( -e $gendocsLocalSiteCfg )
    {
	open( LS_CFG, ">$gendocsLocalSiteCfg" ) or die "can't write to LocalSite.cfg in order to run gendocs";
	print LS_CFG <<__LOCALSITE_CFG__;
\$cfg{PubDir} = "$installBase/pub";
\$cfg{TemplateDir} = "$installBase/templates";
\$cfg{DataDir} = "$installBase/data";
\$cfg{LogDir} = \$cfg{DataDir};
1;
__LOCALSITE_CFG__
	close( LS_CFG );
    }

    execute( "cd tools && perl gendocs.pl --nosmells" ) or die $!;

    # cleanup (this deletes the files _even if_ this program didn't create them, as they shouldn't be shipped anyway!)
    unlink "$gendocsLocalLibCfg" or warn "no delete LocalLib.cfg?";
    unlink "$gendocsLocalSiteCfg" or warn "no delete LocalLib.cfg?";
}


my $ua = LWP::UserAgent::TWiki::TWikiGuest->new( agent => $Config->{agent} ) or die $!;
foreach my $doc qw( TWikiDocumentation TWikiHistory )
{
    my $destDoc = "$Config->{localcache}/${doc}.html";
    # TODO: issue: doesn't mirror the css or bullet image; however, page will display properly if connected to the internet (and thus, twiki.org); page still displays *legibly* if not connected ( no pretty styles, tho :( )
    $ua->mirror( "http://twiki.org/cgi-bin/view/TWiki/$doc", $destDoc ) or warn "$doc: $!";
    cp( $destDoc, "$installBase/${doc}.html" ) or warn "$destDoc: $!";
}


#[ POST ]-------------------------------------------------------------------------------
# bin/ additional post processing: create "authorisation required" version of some scripts
foreach my $auth qw( rdiff view )
{
    cp( $_ = "$installBase/bin/$auth", "${_}auth" ) or warn "$auth: $!";
}
# ??? execute( "chmod a+rx,o+w $bin/*" ); (er, add this to spew_tree or slurp_tree or File::Find::Rule...)
#my @bin = qw( attach changes edit geturl installpasswd mailnotify manage oops passwd preview rdiff rdiffauth register rename save search setlib.cfg statistics testenv upload view viewauth viewfile );

# stop distributing cpan modules; get the latest versions from cpan itself
rmtree( [ "$installBase/lib/Algorithm", "$installBase/lib/Text", "$installBase/lib/Error.pm" ] ) or warn $!;

# create TWikiGuest entry in .htpasswd
my $htpasswd = "$installBase/data/.htpasswd";
execute( qq{htpasswd -bcd "$htpasswd" TWikiGuest guest} );
chmod 0640, $htpasswd or die "$htpasswd: $!";

################################################################################

chdir $pwdStart;
if ( $Config->{verbose} ) { print scalar File::Find::Rule->file->in( $installBase ), " new files\n" }

################################################################################
# create TWikiKernel distribution file
my $newDistro = "$Config->{outputdir}/$Config->{outfile}";
if ( $Config->{tar} ) { execute( "cd $Config->{tempdir} ; tar czf ${newDistro}.tar.gz twiki" ) or warn $!; }
if ( $Config->{zip} ) { execute( "cd $Config->{tempdir} ; zip -qr ${newDistro}.zip twiki" ) or warn $!; }

exit 0;

################################################################################
################################################################################

sub execute 
{
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output ) if $Config->{verbose};
    return not $?;
}

################################################################################

sub _checkdir
{
	my $dir = shift or die "no dir?";
	if (( ! -e $dir ) || ( ! -d $dir )) 
	{
	    print STDERR qq{Error: "$dir" does not exist, or is not a directory\n};
	    return 0;
	}
	return 1;
}
	
sub checkdirs
{
	map { _checkdir( $_ ) or exit( 2 ) } @_;
}

################################################################################

__DATA__
=head1 NAME

build-twiki-kernel.pl - Codev.TWikiKernel

=head1 SYNOPSIS

build-twiki-kernel.pl [options] [-tempdir] [-outputdir] [-outfile] [-agent]

Copyright 2004, 2005 Will Norris and Sven Dowideit.  All Rights Reserved.

 Options:
   -tempdir [.]		where all temporary files for this build are placed
   -outputdir [.]	where the generated TWikiKernel-BRANCH-DATE.tar.gz is placed
   -outfile		.
   -manifest            .
   -tar                 produce an .tar.gz output file (disable with -notar)
   -zip                 produce a .zip output file (disable with -nozip)
   -changelog           automatically generate CHANGELOG from SVN (requires xsltproc)
   -agent [$Config->{agent}]	LWP::UserAgent name (used for downloading some documentation from wiki pages on twiki.org)
   -pdoc		process source code using Pdoc to produce html in twiki/doc/ (off)
   -gendocs		process source code using the equivalent of TWiki:Plugins.PerlPodPlugin 
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-tempdir>

=item B<-outputdir>

=item B<-outfile>

=item B<-tar>

=item B<-zip>

=item B<-changelog>

=item B<-agent>

=item B<-pdoc>

=back

=head1 DESCRIPTION

B<build-twiki-kernel.pl> will build a TWikiKernel release file base suitable for creating a TWikiRelease/TWikiDistribution

The TWikiKernel is comprised of several subsystems:
    * CgiScripts - fulfils requests from the web. Primarily through the ViewCgiScript
    * AuthenticationSubSystem - authenticates users and bestows privileges
    * ParsePipeline - interprets what's typed in forms and topics and converts into Topics, Forms, MetaData and Attachments
    * StorageSubSystem - arranges for data to be stored, currently in RcsFormat
    * RenderingPipeline - displays WikiML Topics, Forms, MetaData and Attachments as HTML
    * SearchSubsystem - fulfils searches

Notably the TWikiKernel does not include any TWikiExtensions (e.g. Plugins or Skins); they are bundled into a particular TWikiRelease (or TWikiDistribution).

=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/TWikiKernel

=cut
