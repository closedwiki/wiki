#!/usr/bin/perl -w
# $Id$
#  Stage 2/3 of an automatic twiki install on macosx darwin
# Copyright Will Norris.  All Rights Reserved.
# License: GPL

################################################################################
# TODO:
#    * try to get rid of =pre-wiki.sh= and =post-wiki.sh= and therefore a completely web-based install!
#    * make web pages to guide through an install (with options!)
#       * and patches, too!
#          * for contributors who submitted the patches (so that they can continue running their changes)
#          * for contributors who want to provide testing
#          * for the automated test facility
#    * save (and/or publish) a "distribution definition"
#    * install web bundles
#       * these may be prepackaged templates
#       * or backups and downloads of your webs
#       * see about providing an "import web" in the wiki itself, and then this could just wget http:// the right thing
#    * try and get the _same_ code to be able to install twiki itself _or_ a plugin (cut code size ~50%)
#       * now, there's also duplicated code installing Contrib modules (which can _definitely_ be the same code as installing plugins)
#    * error checking is pretty good, but error recovery might not be
#    * the html output report has been pieced together ad hoc, and contains significant amounts of *bad html*
#    * get it to work on MacOsX / darwin
#    * ???
################################################################################
# TODO: (merged from original mac install.pl)
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

use strict;
++$|;
open(STDERR,'>&STDOUT'); # redirect error to browser
use CGI qw(:all);
use CGI::Carp qw(fatalsToBrowser);
use File::Copy qw( cp );
use File::Path qw( rmtree );
use File::Basename;
use Cwd qw( cwd getcwd );
use Data::Dumper qw( Dumper );
#use CPAN;

my $account = "twiki";

import_names();
my $cgibin      = getcwd();
my $project	= [ split( '/', $cgibin ) ]->[-2];	# (this script runs from cgi-bin; see what's above)
my $tar		= $Q::tar	|| 'TWiki20040901.tar.gz';
my $home        = "/Users/$account/Sites";
my $tmp		= "$cgibin/tmp";
my $htdocs	= $home . '/htdocs';
my $dest	= $home . '/twiki';
my $pub		= $htdocs . '/twiki';
my $bin		= $cgibin . '/twiki';
my $lib		= $cgibin . '/lib';
my $cpan        = "$lib/CPAN";

################################################################################
# check prerequisites

my $title = "TWiki Installation (Step 2/3)";
print header(), start_html( -title => $title );
print qq{<h1>$title</h1>\n};

unless (-e $tar) {
    print "File not found: $tar";
    exit 1;
}

checkdir($tmp);
checkdir($dest);
checkdir($bin);
checkdir($lib);
checkdir($cpan);

################################################################################
# setup directory skeleton workplace

execute("tar xzf $tar -C $tmp");
execute("cp -pr $tmp/twiki/data $dest"); execute("chmod -R 777 $dest");
execute("cp -r $tmp/twiki/bin/* $bin; cp $tmp/twiki/bin/.htaccess.txt $bin");  execute("chmod -R 777 $bin");
execute("cp -r $tmp/twiki/lib/* $lib");  execute("chmod -R 777 $lib");

################################################################################
# update TWiki.cfg for SourceForge specifics

print qq{<h2>TWiki.cfg</h2>\n};
my $file = "$lib/TWiki.cfg";
open(FH, "<$file") or die "Can't open $file: $!";
my $config = join( "", <FH> );
close(FH) || die "Can't write to $file: $!";

my $sourceForgeConfig = qq{

\$defaultUrlHost   = "http://localhost";
\$scriptUrlPath    = "/~$account/cgi-bin/twiki";
\$dispScriptUrlPath = \$scriptUrlPath;
\$pubUrlPath       = "/~$account/htdocs/twiki";
\$pubDir           = "$home/htdocs/twiki"; 
\$templateDir      = "$home/twiki/templates"; 
\$dataDir          = "$home/twiki/data"; 
\$logDir           = \$dataDir;

};

#\$templateDir      = "$home/twiki/templates"; => "$dest/templates" ???
#\$dataDir          = "$home/twiki/data"; => "$dest/data" ???

# need to put our configurations in the "right" spot in the configuration file
# they need to be inserted after the default definitions, but before any of them are used
# hm, maybe i could have just put the whole thing in a BEGIN { } block ?
$config =~ s/(# FIGURE OUT THE OS WE'RE RUNNING UNDER - from CGI.pm)/$sourceForgeConfig\n$1/;
open(FH, ">$file") || die "Can't open $file: $!";
print FH $config;
close(FH) || die "Can't write to $file: $!";

################################################################################

print "<h2>Authentication</h2>\n";

execute( "mv $bin/.htaccess.txt $bin/.htaccess" );

$file = "$bin/.htaccess";
open(FH, "<$file") or die "Can't open $file: $!";
my $htaccess = join( "", <FH> );
close(FH) || die "Can't write to $file: $!";

$htaccess =~ s|!FILE_path_to_TWiki!/data|$home/twiki/data|g;	# code smell: duplicated data from config file above
$htaccess =~ s|!URL_path_to_TWiki!/bin|/cgi-bin/twiki|g;	# ditto
# TODO: fix ErrorDocument 401 (what should it be set to?)

open( FH, ">$file" ) or die $!;
print FH $htaccess;
close( FH ) or die $!;

execute( "rm $dest/data/TWiki/TWikiRegistration.txt $dest/data/TWiki/TWikiRegistration.txt,v" ) or warn $!;
execute( "mv $dest/data/TWiki/TWikiRegistrationPub.txt $dest/data/TWiki/TWikiRegistration.txt") or warn $!;
execute( "mv $dest/data/TWiki/TWikiRegistrationPub.txt,v $dest/data/TWiki/TWikiRegistration.txt,v") or warn $!;

################################################################################

#exit 0;

eraseBundledPlugins();

#installLocalModules({
#    modules => [ qw( Data::UUID Date::Handler Safe Language::Prolog CGI::Session File::Temp List::Permutor File::Temp ) ],
#    dir => $cpan,
#});

################################################################################
# install contrib
# TODO: automatically download from http://twiki.org/cgi-bin/view/Plugins/ContributedCode
# (%SEARCH{"Contrib$" type="regex" nosearch="on" scope="topic" noheader="on" nototal="on"}% -ish)
print "<h2>Contrib</h2>\n";
my @contribs = qw(
		  AttrsContrib
		  DBCacheContrib
		  DistributionContrib
		  JSCalendarContrib
		 );
foreach my $contrib ( @contribs )
{
    chdir( "tmp/install" ) or warn $!;

    print "<h3>Installing $contrib</h3>\n";
    execute("tar xzvf downloads/contrib/$contrib.tar.gz") or warn $!;
    # TODO: run an standard-named install script (if included)

    # TODO: find perl move directory tree code
    if ( -d 'data/Plugins' ) { execute( "cp -rpv data/Plugins/* $dest/data/TWiki" ); execute( "rm -rf data/Plugins" ); }
    if ( -d 'data' ) { execute( "cp -rpv data $dest" ); execute( "rm -rf data" ); }
    # TODO: filter out ,v files (right???)
    if ( -d 'lib' ) { execute( "cp -rpv lib/* $lib" ); execute( "rm -rf lib" ); }
    if ( -d 'bin' ) { execute( "cp -rpv bin/* $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'pub' ) { execute( "cp -rpv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rpv templates $tmp/twiki/templates" ); execute( "rm -rf templates" ); }

    # TODO: assert( isDirectoryEmpty() );

    chdir ("../..") or warn $!;
}

################################################################################
# install plugins

my @availPlugins = (
################################################################################
# prebundled with twiki
		    'CommentPlugin',
		    'DefaultPlugin',	# want to delete, but gives errors 
		    'EditTablePlugin',
#		    'EmptyPlugin',
		    'InterwikiPlugin',
		    'RenderListPlugin',
		    'SlideShowPlugin',
		    'SmiliesPlugin',
		    'SpreadSheetPlugin',
		    'TablePlugin',

################################################################################
		    'BeautifierPlugin',
		    'ChartPlugin',
		    'GaugePlugin',
		    'SpacedWikiWordPlugin',
		    'RandomTopicPlugin',
		    'PerlDocPlugin',
		    'MacrosPlugin',

		    'AgentPlugin',
		    'BibliographyPlugin',
		    'ConditionalPlugin',
		    'EditInTablePlugin',
		    'EmbedPDFPlugin',
		    'EmbedQTPlugin',
		    'ExifMetaDataPlugin',
		    'ExplicitNumberingPlugin',
		    'FindElsewherePlugin',
		    'FormFieldListPlugin',
		    'FormQueryPlugin',
		    'GlobalReplacePlugin',
		    'HiddenTextPlugin',
		    'IncludeIndexPlugin',
		    'NewsPlugin',
		    'PageStatsPlugin',
		    'ProjectPlannerPlugin',
		    'PseudoXmlPlugin',
		    'RandomQuotePlugin',
		    'RecursiveRenderPlugin',
		    'RedirectPlugin',
		    'RicherSyntaxPlugin',
		    'SectionalEditPlugin',
		    'SessionPlugin',
		    'SingletonWikiWordPlugin',
		    'TextSectionPlugin',
		    'TopicVarsPlugin',
		    'TranslateTagPlugin',
		    'TreePlugin',
		    'TWikiDrawPlugin',
		    'TWikiReleaseTrackerPlugin',
		    'VarCachePlugin',


################################################################################
# not very good tests, so i can't really tell if it's working or not, but it seems to have installed correctly
		    'VersionLinkPlugin',	# attachment foo.c, reference by the example, isn't included (or maybe the %META% isn't correct)

################################################################################
# not showing up in the list
#AbusePlugin - ABUSEFILE_LOCATION - need to specify file location, and upload a word filter file
#ChildTopicTemplatePlugin - dunno
#CounterPlugin - COUNTERPLUGIN_COUNTER_FILE_PATH - /home/students/mtech03/rahulm/web/twiki/lib/TWiki/Plugins/datacount.txt!?!
#NavPlugin - dunno
#NavbarPlugin - dunno
#PerlSamplePlugin - dunno - don't have CPAN:Safe installed?
#PhotoarchivePlugin - ANYTOPNM => "/usr/bin/anytopnm" - PNMSCALE => "/usr/bin/pnmscale" - PNMTOPNG => "/usr/bin/pnmtopng" - PNMTOJPEG => "/usr/bin/pnmtojpeg"
#PrologSamplePlugin - need CPAN:Language::Prolog
#SearchToTablePlugin - dunno - needs lots of cleanup from original template
#StylePlugin - dunno
#SuggestLinksPlugin - need CPAN:List::Permutor ?
#UpdateInfoPlugin - dunno
#UserCookiePlugin - dunno

# or other installation issues
#BlackListPlugin - needs additional setup (should be renamed throttler (what did i call it before??))
#EmbedBibPlugin - need bibtool and bibtex2html
#GuidPlugin - needs CPAN:Data::UUID
#LocalTimePlugin - Date::Handler
#SourceHighlightPlugin - can't find CPAN:File::Temp
#TodaysVisitorsPlugin - configure the $TWIKILIBPATH var in lib/TWiki/Plugins/TodaysVisitorsPlugin.pm - configure the $LOGPATH var in lib/todaysvisitors.sh


# wrong directory structure, won't install
#EmbedFlashPlugin - left EmbedFlashPlugin - wrong directory structure
#FormFieldsPlugin - wrong directory structure
#FormPivotPlugin - wrong directory structure#
#IrcLogPlugin - IrcLogPlugin.txt.gz ???
#RevRecoverPlugin - left RevRecoverPlugin in (local) root
#RevisionLinkPlugin - left RevisionLinkPlugin in (local) root
#SyntaxHighlightingPlugin - wrong directory structure
#TocPlugin - left TocPlugin.xml in (local) root
#XpTrackerPlugin - wrong directory structure

# plain old install/runtime errors
#ActionTrackerPlugin - exists operator argument is not a HASH element at ../lib/TWiki/Plugins/ActionTrackerPlugin.pm line 213. (but i didn't run build.pl yet)
#AliasPlugin - []'s __everywhere__
#BugzillaQueryPlugin - can't rest - says "can't connect to database", which is true for the default install
#CalendarPlugin - Can't continue after import errors at ../lib/TWiki/Plugins/CalendarPlugin.pm line 240 BEGIN failed--compilation aborted at ../lib/TWiki/Plugins/CalendarPlugin.pm line 240.
#DiskUsagePlugin - Illegal division by zero at ../lib/TWiki/Plugins/DiskUsagePlugin.pm line 158.
#DoxygenPlugin - needs help
#HeadlinesPlugin - doesn't work from within sourceforge (http out)
#ImageGalleryPlugin - mkdir problem, too
#IncludeRevisionPlugin - co: /home/groups/g/gd/gdutree/twiki/data/1/RCS/3.txt,v: No such file or directory
#JavaDocPlugin - Unmatched right bracket at ../lib/TWiki/Plugins/JavaDocPlugin.pm line 119, at end of line syntax error at ../lib/TWiki/Plugins/JavaDocPlugin.pm line 119, near "}" - almost seems to work, tho? (tests show up right) - also, i think this left a tmp/ directory
#LaTeXToMathMLPlugin - page rendered inside page, no math to be seen - don't know if it's a problem with this plugin, or an interaction with another one
#MathModePlugin - Not enough arguments for mkdir at ../lib/TWiki/Plugins/MathModePlugin.pm line 193, near "$path )
#MessageBoardPlugin - warnings.pm (?)
#PdfPlugin - nope
#PhantomPlugin - interacts with RicherSyntaxPlugin?
#TouchGraphPlugin - don't know why
#TypographyPlugin - doesn't seem to work


# related to sourceforge restrictions (at least)
#LocalCityTimePlugin - ERROR: TWiki::Net::getUrl connect: Connection timed out.


# untested because they're scary user authentication stuff
#LDAPPasswordChangerPlugin
#LdapPlugin
#LoginNameAliasesPlugin


# mail/notify - related stuff (also untested)
#ImmediateNotifyPlugin
#NotificationPlugin

# can't test
#MsOfficeAttachmentsAsHTMLPlugin
#DatabasePlugin - need db to test it with (also look into CPAN:SQL::Lite)
#MovableTypePlugin
#SiteMinderPlugin
#WebDAVPlugin

# "special" plugins
#WtfPlugin - not a real plugin


# obselete (?)
#PollPlugin - obseleted in favor of CommentPlugin?


# addons
#SpellCheckerPlugin - more like an addon; has bin/ directory
		    );

################################################################################

print "<h2>Plugins</h2>\n";
foreach my $plugin ( @availPlugins )
{
    next if $plugin =~ /^#/;	# skip commented out plugins
    next if $plugin =~ /^\s*$/; # skip blank lines
    $plugin =~ s/#//g;

#    print getcwd() . "<br/>";
    chdir( "tmp/install" ) or warn $!;
#    print getcwd() . "<br/>";

    print "<h3>Installing $plugin</h3>\n";
    execute("tar xzvf downloads/plugins/$plugin.tar.gz") or warn $!;
    # TODO: run an standard-named install script (if included)
    my $installer = $plugin . '_installer.pl';
#    print "<b>$installer</b><br/>\n";
#    eval { execute( "cd tmp/install ; perl $installer" ) if -e $installer; };  # -a doesn't prompt
#    print "installer error: $@, ($!)\n" if $@;

    # TODO: find perl move directory tree code
    if ( -d 'data/Plugins' ) { execute( "cp -rpv data/Plugins/* $dest/data/TWiki" ); execute( "rm -rf data/Plugins" ); }
    if ( -d 'data' ) { execute( "cp -rpv data $dest" ); execute( "rm -rf data" ); }
    if ( -d 'lib' ) { execute( "cp -rpv lib/* $lib" ); execute( "rm -rf lib" ); }
    if ( -d 'bin' ) { execute( "cp -rpv bin/* $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'pub' ) { execute( "cp -rpv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rpv templates $tmp/twiki/templates" ); execute( "rm -rf templates" ); }

    # TODO: assert( isDirectoryEmpty() );

    chdir ("../..") or warn $!;
}


################################################################################
### various patches/fixes/upgrades
my @patches = (
	       'testenv',				# make testenv a little more useful...
	       'create-new-web-copy-attachments',	# update "create new web" to also copy attachments, not just topics
	       'trash-attachment-button',		# a clickable link/button to (more easily) trash attachments
	       'preview-manage-attachment',		# provide an image preview when working with attachments
	       'ImageGallery-fix-unrecognised-formats',	# bugfixes for ImageGalleryPlugin 
	       'PreviewOnEditPage',			# PreviewOnEditPage
	       'InterWikiPlugin-icons',			# InterWiki icons
	       'prefsperf',			# cdot's preferences handling performance improvements (http://twiki.org/cgi-bin/view/Codev/PrefsPmPerformanceFixes)
	       'WikiWord-web-names',			# fix templates use of %WEB% instead of <nop>%WEB%
	       'force-new-revision',			# add force new revision (TWiki:Codev.ForceNewRevisionCheckBox)
	       'AttachmentVersionsBrokenOnlyShowsLast',	# view attachment v1.1 fix
	       );

print qq{<h2>Patches</h2>\n};
#chdir "/Users/$account/Sites";
foreach my $patch ( @patches )
{
    print qq{<h3>Applying patch "$patch"</h3>\n};
#    execute( "patch -p2 <tmp/install/downloads/patches/local/${patch}.patch" ) or warn $!;
}
#chdir $install;

################################################################################
# (NOT DONE YET, but this code was in the original mac install.pl)
# addons
if ( 0 ) {
# install addons
chdir 'twiki/bin';
cp( qw( ../../install/downloads/xmlrpc xmlrpc ) ) or die $!;
`chmod +x xmlrpc` and die $!;
chdir '../..';
}

################################################################################
# TODO: install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...)
# ImageGalleryPlugin: sudo fink install ImageMagick (...)


################################################################################
# (NOT DONE YET, but this code was in the original mac install.pl)
# update standard webs 
# (created with: (sudo) tar cjvf ../install/ProjectManagement.wiki.tar.bz2 data/ProjectManagement/ pub/ProjectManagement/) (pkg-webs script now)

#opendir( WIKIS, "$install/downloads/webs/system" ) or die $!;
#my @webs = grep { /\.wiki\.tar\.bz2$/ } readdir( WIKIS ) or die $!; 
#closedir( WIKIS ) or die $!;
#chdir 'twiki';
#foreach my $web ( @webs )
#{
#    print STDERR "Updating system web [$web]\n";
#    `tar xjvf $install/downloads/webs/system/$web` or die $!;
#}
#chdir $install;

################################################################################
# install local webs

print qq{<h2>Installing local webs</h2>\n};
chdir( "tmp/install" ) or warn $!;
my @webs = ( 'HowToThinkLikeAComputerScientistUsingPython' );
if ( opendir( WIKIS, "webs/local" ) )
{
    @webs = grep { /\.wiki\.tar\.gz$/ } readdir( WIKIS );  #or warn $!; 
    closedir( WIKIS ) or warn $!;
}
foreach my $web ( @webs )
{
    $web = basename( $web, qw( .wiki.tar.gz ) );
    print "<h3>Installing web $web</h3>\n";
    execute("tar xzvf webs/local/$web.wiki.tar.gz") or warn $!;

    if ( -d 'data' ) { execute( "cp -rpv data $dest" ); execute( "rm -rf data" ); }
    if ( -d 'pub' ) { execute( "cp -rpv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rpv templates $dest" ); execute( "rm -rf templates" ); }	# untested
}
chdir( "../.." ) or warn $!;

################################################################################
#  cleanup / permissions

execute( "ls -lR tmp/install" );

execute("chmod -R 777 $dest");
execute("chmod -R 777 $bin");
execute("chmod -R 777 $lib");

execute("chmod -R 777 $tmp");

# a handy link to the place to go *after* the next step
print qq{<hr><hr>\n};
print qq{do a <tt>post-wiki.sh</tt> and then <br/><a href="http://localhost/~twiki/cgi-bin/twiki/view/TWiki/InstalledPlugins">continue to wiki</a><br/>\n};

print end_html();

################################################################################
################################################################################

sub mode {
	my ($file) = @_;
	my ($dev, $ino, $mode) = stat $file;
	return $mode;
}

sub checkdir {
	my ($dir) = @_;
	unless (-d $dir) {
	    print "Directory not found: $dir";
	    exit 1;
	}
	unless (mode($dir) & 0x2) {
	    print "Directory $dir is not world writable";
	    exit 1;
	}
}

{
    my $nCmd = 0;

sub execute {

    if ( $nCmd++ == 0 )
    {
	print <<'__HTML__';
	<script type="text/javascript">
	function toggleDisplay( id )
	{
	    var e = document.getElementById( id );
	    //	alert(e);
	    var style = e.style;
	    //	alert(e + 'style: ' + style.display);
	    style.display = style.display ? "" : "none";
	    return style.display;
	}
	function setClassname( e, c )
	{
	    //	alert( e + ': was: ' + e.className + ', now: ' + c );
	    e.className = c;
	}
	</script>
__HTML__
    }

    my ($cmd) = @_;

    chomp( my $output = `$cmd` );
    my ( $clrCommand, $clrError ) = ( ( my $error = $? ) ? qw( black red ) : qw( gray gray ) );

    print qq{<a href="#" onclick="toggleDisplay('cmd$nCmd')" >cmd</a> };

    my $display = $error ? "" : "none";
    print qq{<span style="display:$display" id="cmd$nCmd" >\n};

    print "<br/>[<font color=$clrError>$error</font>]: ";
    print "<font color=$clrCommand>", pre($cmd), "</font>\n";

    print "<pre>$output</pre>\n";

    print "</span>\n";
}

}

#--------------------------------------------------------------------------------

sub eraseBundledPlugins
{ # (remove plugins that ship with twiki)
    # TODO: fix errors when removing DefaultPlugin
    foreach my $plugin ( qw( CommentPlugin EditTablePlugin EmptyPlugin InterwikiPlugin RenderListPlugin SlideShowPlugin SmiliesPlugin SpreadSheetPlugin TablePlugin ) )
    {
	erasePlugin( $plugin );
    }
}

sub erasePlugin
{
    my ( $plugin ) = @_;

    print qq{<h3>Erasing preinstalled plugin $plugin</h3>\n};
#    print "pwd = [" . getcwd() . "]\n";
    # removing the code should be good enough (but not totally clean)
    # do this instead of modifying the standard TWiki20040901.tar.gz distribution file
    # when TWiki:Codev.AutomatedBuild is done, this won't be necessary 
    # (because specific distribution/release files will be able to be generated?)
    execute( "rm $lib/TWiki/Plugins/${plugin}.pm" );
    execute( "rm -r $lib/TWiki/Plugins/${plugin}" ) if -d "$lib/TWiki/Plugins/${plugin}";
    execute( "rm $dest/data/TWiki/${plugin}.txt*" );
    execute( "rm -r tmp/twiki/pub/TWiki/${plugin}" ) if -d "tmp/twiki/pub/TWiki/${plugin}";
}

__END__

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
