#! /usr/bin/perl -w
use strict;
use Data::Dumper;
use Cwd qw( cwd getcwd );
use CPAN;
use File::Copy qw( cp );

################################################################################
# TODO: 
#	put in package namespace
#	compare/contrast with MS-'s installer
#	why is root needed? (oh, for writing the apache.conf file)
#	install plugin dependencies (ooh, add to twiki form?)
#		(external dependencies like imagemagick and latex, not other perl modules as those will be handled automatically)
#	install perl modules to ~user account (see CpanPerlModulesRequirement) (work in progress at bottom)
#		CPAN:Test::Unit (CPAN:Error, CPAN:Class::Inner, CPAN:Devel::Symdump)
#		CPAN:LWP::Simple (CPAN:URI, CPAN:HTML::Parser, CPAN:HTML::Tagset)
#		CPAN:CGI::Session (CPAN:Digest::MD5, CPAN:Storable) (SmartSessionPlugin)
#	find proper instructions for locking/unlocking/updating the rcs files (?, for a proper topic update)
################################################################################

#================================================================================
# check to run as root (need permissions--- grrr, fix that) (why, again? i forget..., oh yeah, for apache.conf)
# TODO: try putting all setup in bin/.htaccess
chomp( my $whoami = `whoami` );
die "must run this as root (or sudo)\n" unless $whoami eq 'root';

my $account = shift or die "Usage: install.pl <accountName>\n";
# validate account exists -- how do you do that generally?  (eg, /etc/users doesn't exist on MacOsX)

my $install = cwd();
#my $twiki = "/Users/$account/Sites/twiki";

#================================================================================

my $twiki = $install . '/downloads/releases/TWiki20040901.tar.gz';
# find official TWiki distribution file
#unless ( -f $twiki ) { chdir 'install' }
die "no twiki install tar file ($twiki)\n" unless -f $twiki;

#================================================================================
# prepare for the actual installation
print <<__CONFIRM__;

About to install TWiki ($twiki) to user account (short account name is "$account")

(Ctrl+C to abort installation, ENTER to continue)
__CONFIRM__
<>;

#================================================================================

# "install" official TWiki distribution file
chdir "/Users/$account/Sites" or die $!;
system qq{tar xzf $twiki --owner $account} and die $!;

# update standard webs 
# (created with: (sudo) tar cjvf ../install/ProjectManagement.wiki.tar.bz2 data/ProjectManagement/ pub/ProjectManagement/) (pkg-webs script now)
opendir( WIKIS, "$install/downloads/webs/system" ) or die $!;
my @webs = grep { /\.wiki\.tar\.bz2$/ } readdir( WIKIS ) or die $!; 
closedir( WIKIS ) or die $!;
chdir 'twiki';
foreach my $web ( @webs )
{
    print STDERR "Updating system web [$web]\n";
    `tar xjvf $install/downloads/webs/system/$web` or die $!;
}
chdir $install;

chdir "/Users/$account/Sites" or die $!;
# install local webs
if ( opendir( WIKIS, "$install/webs/local" ) )
{
    my @myWebs = grep { /\.wiki\.tar\.bz2$/ } readdir( WIKIS ) or die $!; 
    closedir( WIKIS ) or die $!;

    chdir 'twiki';
    foreach my $localweb ( @myWebs )
    {
	print STDERR "Installing web [$localweb]\n";
	`tar xjvf $install/webs/local/$localweb` or warn $!
    }
    chdir '..';
}
chdir $install;

my @contribs = qw(
    BuildContrib 
    DistributionContrib
    AttrsContrib
    );
chdir "/Users/$account/Sites/twiki" or die $!;
foreach my $contrib ( @contribs )
{
    print STDERR qq{installing contrib "$contrib"\n};
    `unzip -u $install/downloads/contrib/$contrib.zip` or die $!;
}
chdir $install;


# install plugins
my @plugins = qw( 
    TWikiReleaseTrackerPlugin 
    MacrosPlugin 
    ImageGalleryPlugin
    MathModePlugin
    SessionPlugin
    );
chdir "/Users/$account/Sites/twiki" or die $!;
foreach my $plugin ( @plugins )
{
    print STDERR qq{installing plugin "$plugin"\n};
    `unzip -u $install/downloads/plugins/$plugin.zip` or die $!;
    # TODO: run an standard-named install script (if included)
}
chdir $install;

if ( 0 ) {
# install addons
chdir 'twiki/bin';
cp( qw( ../../install/downloads/xmlrpc xmlrpc ) ) or die $!;
`chmod +x xmlrpc` and die $!;
chdir '../..';
}

################################################################################

# install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...)
# ImageGalleryPlugin: sudo fink install ImageMagick (...)


################################################################################
# install cpan modules used by plugins (and, optionally, by the core)

if ( 0 ) {
installLocalModules({
    modules => [ ],
    dir => q[],
});
}

################################################################################

my $apacheConfig = "/private/etc/httpd/users/$account.conf";

# MacOsX-specific apache configuration file (shouldn't be hard to finish generalising)

if ( open( CONF, ">$apacheConfig" ) )
{
    print CONF <<__APACHECONF__;
<Directory "/Users/$account/Sites/">
    Options Indexes MultiViews
    AllowOverride None
    Order allow,deny
    Allow from all
</Directory>

ScriptAlias /~$account/twiki/bin/ "/Users/$account/Sites/twiki/bin/"
Alias /~$account/twiki/ "/Users/$account/Sites/twiki/"
<Directory "/Users/$account/Sites/twiki/bin">
    Options +ExecCGI
    SetHandler cgi-script
    Allow from all
</Directory>
<Directory "/Users/$account/Sites/twiki/pub">
    Options FollowSymLinks +Includes
    AllowOverride None
    Allow from all
</Directory>
<Directory "/Users/$account/Sites/twiki/data">
    deny from all
</Directory>
<Directory "/Users/$account/Sites/twiki/templates">
    deny from all
</Directory>
__APACHECONF__
    close( CONF );
}
else
{
    print STDERR "Unable to write apache configuration file!\n";
}


### fix file permissions
### grrr, add these checks for file persmissions and ownerships to testenv...

chdir "/Users/$account/Sites/twiki";

chdir 'bin';	# twiki/bin
my $bin = `ls | grep -v \\\\.`;;
#`chmod 755 $bin` and die $!;
chdir '..';	# twiki

`chown -R www pub data` and die $!;

chdir 'data';	# twiki/data

`chmod -R 644 *` and die $!;

`chmod 775 *` and die $!;

chdir $install;

################################################################################
### various patches/fixes/upgrades
my @patches = (
	       'testenv',				# make testenv a little more useful...
	       'create-new-web-copy-attachments',	# update "create new web" to also copy attachments, not just topics
	       'trash-attachment-button',		# a clickable link/button to (more easily) trash attachments
	       'preview-manage-attachment',		# provide an image preview when working with attachments
	       'ImageGallery-fix-unrecognised-formats',	# bugfixes for ImageGalleryPlugin 
	       'PreviewOnEditPage',			# PreviewOnEditPage
	       'TWiki.cfg',				# adjust main configuration file
	       'setlib.cfg',				# update library patch (look into apache 2 issues)
	       'InterWikiPlugin-icons',			# InterWiki icons
	       'prefsperf',			# cdot's preferences handling performance improvements (http://twiki.org/cgi-bin/view/Codev/PrefsPmPerformanceFixes)
	       'WikiWord-web-names',			# fix templates use of %WEB% instead of <nop>%WEB%
	       'force-new-revision',			# add force new revision (TWiki:Codev.ForceNewRevisionCheckBox)
	       'AttachmentVersionsBrokenOnlyShowsLast',	# view attachment v1.1 fix
	       );

chdir "/Users/$account/Sites";
foreach my $patch ( @patches )
{
    print STDERR qq{applying patch "$patch"\n};
    `patch -p0 <$install/downloads/patches/${patch}.patch` or warn $!;
}
chdir $install;

#--------------------------------------------------------------------------------
# enable/setup authentication (only partially completed atm)
chdir "/Users/$account/Sites";
`mv twiki/bin/.htaccess.txt twiki/bin/.htaccess`;
# !FILE_path_to_TWiki!  /Users/wbniv/Sites/twiki
# !URL_path_to_TWiki!   /~wbniv/twiki
`patch -p0 <$install/downloads/patches/user-authentication.patch` or die $!;
chdir $install;

chdir "/Users/$account/Sites/twiki/data/TWiki";

# use inclusive topic registration
# TODO: remove some junk from the page (eg, OfficeLocation)
(-d 'orig' || mkdir 'orig') or die $!;
if ( -e 'TWikiRegistration.txt' )
{ 
    `mv TWikiRegistration.txt orig/` and die $!;
    `mv TWikiRegistration.txt,v orig/` and die $!;
}
`mv TWikiRegistrationPub.txt TWikiRegistration.txt` and die $!;
`mv TWikiRegistrationPub.txt,v TWikiRegistration.txt,v` and die $!;

chdir $install;

#================================================================================
# fix topics' permissions
RestartApache();
print `wget -O - http://localhost/~$account/twiki/bin/manage?action=relockrcs | grep code | wc -l`, " topic(s) unlocked\n";

################################################################################

# handy link to start with post-install 
WebBrowser( "http://localhost/~$account/twiki/bin/testenv" );

exit 0;

################################################################################
################################################################################

use CPAN;

sub installLocalModules
{
    my $parm = shift;
    my $cpan = $parm->{dir};

    CPAN::Shell->reload( qw( index ) ); # or die $!;
#      CPAN::Shell->o( qw( debug all ) );
#      CPAN::Shell->expand("Module","/TWiki/");

#    ( mkdir $cpan or die $! ) unless -d $cpan;

    # some modules refuse to work if PREFIX is set, and some refuse to work if it is not. ???
    $CPAN::Config->{'makepl_arg'} = "PREFIX=$cpan";
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

#[using default ok for start]  'urllist' => [q[file:/Users/wbniv/twiki/cpan/MIRROR/MINICPAN/]],
    $CPAN::Config->{'build_cache'} = q[0];
#  'cache_metadata' => q[1],

#$CPAN::Config = {
#  'ftp' => q[/usr/bin/ftp],
#  'ftp_proxy' => q[],
#  'getcwd' => q[cwd],
#  'gpg' => q[],
#  'gzip' => q[/sw/bin/gzip],
#  'http_proxy' => q[],
#  'inactivity_timeout' => q[0],
#  'index_expire' => q[1],
#  'inhibit_startup_message' => q[0],
#  'lynx' => q[],
#  'make' => q[/usr/bin/make],
#  'ncftp' => q[],
#  'ncftpget' => q[],
#  'no_proxy' => q[],
#  'pager' => q[/usr/bin/less],
#?  'scan_cache' => q[atstart],
#  'shell' => q[/bin/bash],
#  'tar' => q[/sw/bin/tar],
#  'term_is_latin' => q[1],
#  'unzip' => q[/sw/bin/unzip],
#  'wget' => q[/sw/bin/wget],
#};

#print Dumper( $CPAN::Config );

    my @modules = @{$parm->{modules}};
    print Dumper( \@modules );
    foreach my $module ( @modules )
    {
	my $obj = CPAN::Shell->expand( Module => $module ) or warn $!;
	next unless $obj;
	$obj->install; # or warn "Error installing $module\n"; 
    }
    
#    print Dumper( $CPAN::Config );
}

################################################################################

sub RestartApache
{
    `apachectl restart`;
}

# TODO: howto launch the web browser?
sub WebBrowser
{
    my $url = shift or die "no url";
    print $url, "\n";
}

################################################################################
################################################################################
