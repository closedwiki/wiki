#!/usr/bin/perl -w
# $Id$
#  Stage 2-3/4 of an automatic twiki install on macosx darwin
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL

################################################################################
# TODO: (soon)
#    * get rid of =pre-wiki.sh= and =post-wiki.sh= and become a completely web-based install!
#    * try and get the _same_ code to install twiki itself _or_ a TWikiExtension (they do have the same directory structure, after all)
#    * error checking is pretty good, but error recovery might not be
#    * install plugin dependencies (ooh, add to twiki form?)
#		(external dependencies like imagemagick and latex, not other perl modules as those will be handled automatically)
#    * run rcslock
#    * find proper instructions for locking/unlocking/updating the rcs files (?, for a proper topic update)
#    * ???
# TODO: (long term)
#    * compare/contrast with MS-'s installer
#    * put in package namespace
################################################################################
# TODO DOCS:
#    * install web bundles
#       * these may be prepackaged templates
#       * or backups and downloads of your webs
#       * see about providing an "import web" in the wiki itself, and then this could just wget http:// the right thing
#    * make web pages to guide through an install (with options!)
#       * and patches, too! (skins, addons, web templates)
#    * why is root needed? (oh, for writing the apache.conf file) --- is this all taken care of now?
#    * other stuff i deleted...
################################################################################

my $account;

BEGIN {
    use Cwd qw( cwd getcwd );
    use Config;
    $account = [ split( '/', getcwd() ) ]->[-3];   # format: /Users/(account)/Sites/cgi-bin/...
    my $localLibBase = getcwd() . "/lib/CPAN/lib/site_perl/" . $Config{version};
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
    # TODO: use setlib.cfg (is that which one it is?  along with some patch mc and i were working on)
}
use strict;
++$|;
open(STDERR,'>&STDOUT'); # redirect error to browser

use CGI qw( :all );
use CGI::Carp qw( fatalsToBrowser );
use File::Copy qw( cp );
use File::Path qw( rmtree );
use File::Basename qw( basename );
use Cwd qw( cwd getcwd );
use Data::Dumper qw( Dumper );
use CPAN;
use XML::Simple;

################################################################################

sub catalogue
{
    my $p = shift;
    die unless $p->{xml} && $p->{type} && $p->{cgi};
    $p->{title} ||= $p->{type};

    my $text = "<h2>" . $p->{title} . "</h2>\n";

    if ( -e $p->{xml} )
    {
	my $xs = new XML::Simple( ForceArray => 1, KeyAttr => 1, AttrIndent => 1 ) or die $!;
	my $xmlCatalogue = $xs->XMLin( $p->{xml} ) or warn qq{No xml catalogue "$p->{xml}": $!};

#	print "<pre>", Dumper( $p->{cgi}->param( $p->{type} ) ), "</pre>\n";
	foreach ( @{$xmlCatalogue->{ $p->{type} } } )
	{
	    my $findCheck = $_->{name}->[0];
	    my $checked = ( grep { /^\Q$findCheck\E$/ } ( $p->{cgi}->param($p->{type}) ) ) ? qq{checked="checked"} : '';
	    my $aAttr = {
		target => '_new',
		title => $_->{description}->[0],
	    };
	    $aAttr->{href} = $_->{homepage}->[0] if $_->{homepage}->[0];
	    $text .= qq{<input type="checkbox" name="$p->{type}" value="$_->{name}->[0]" $checked/> } . 
		$p->{cgi}->a( $aAttr, $_->{name}->[0] ) . "<br/>";
	}
    }

    return $text;
}

################################################################################

my $q = CGI->new() or die $!;
#$q->import_names();

################################################################################
################################################################################

unless ( $q->param('install') =~ /install/i )
{
    my $title = "TWiki Installation (Step 2/4)";
    print $q->header(), $q->start_html( 
					-title => $title,
					-style => { -code => 'table { width:100% }' },
					);
#    print "$q";
    print <<'__HTML__';
<form>
<input type="submit" name="install" value="install" /> <br/>
__HTML__

    print catalogue({ xml => "tmp/install/downloads/contribs/contrib.xml", title => "Contrib", type => "contrib", cgi => $q });
    print catalogue({ xml => "tmp/install/downloads/plugins/plugins.xml", title => "Plugins", type => "plugin", cgi => $q });
    print catalogue({ xml => "tmp/install/downloads/addons/addons.xml", title => "AddOns", type => "addon", cgi => $q });
    print catalogue({ xml => "tmp/install/downloads/skins/skins.xml", title => "Skins", type => "skin", cgi => $q });
    print catalogue({ xml => "tmp/install/downloads/patches/patches.xml", title => "Patches", type => "patch", cgi => $q });
    print catalogue({ xml => "tmp/install/downloads/webs/webs.xml", title => "Web Templates", type => "web", cgi => $q });

    chdir "tmp/install";
    my @systemwebs = ();
    if ( opendir( WIKIS, "downloads/webs/system" ) )
    {
	@systemwebs = grep { /\.wiki\.tar\.gz$/ } readdir( WIKIS );  #or warn $!; 
	closedir( WIKIS ) or warn $!;
    }
    chdir "../..";

    print qq{<h2>System Webs (Updates)</h2>\n};
    print checkbox_group( -name => "systemweb",
		    -values => \@systemwebs,
		    -defaults => [ $q->param( "systemweb" ) ],
#		    -cols => 5,
		    -linebreak => 'true',
		    );

    #--------------------------------------------------------------------------------

    chdir "tmp/install";
    my @localwebs = ();
    if ( opendir( WIKIS, "webs/local" ) )
    {
	@localwebs = grep { /\.wiki\.tar\.gz$/ } readdir( WIKIS );  #or warn $!; 
	closedir( WIKIS ) or warn $!;
    }
    chdir "../..";

    print qq{<h2>Local Webs</h2>\n};
    print checkbox_group( -name => "localweb",
		    -values => \@localwebs,
		    -defaults => [ $q->param( "localweb" ) ],
#		    -cols => 5,
		    -linebreak => 'true',
		    );

    print <<__HTML__;
</form>
</body>
</html>
__HTML__

    exit 0;
}

################################################################################
################################################################################

#my $cgibin      = getcwd();
my $cgibin      = "/Users/$account/Sites/cgi-bin";
my $tar		= "TWiki20040901.tar.gz";
my $home        = "/Users/$account/Sites";
my $tmp		= "$cgibin/tmp";
my $htdocs	= $home . '/htdocs';
my $dest	= $home . '/twiki';
my $pub		= $htdocs . '/twiki';
my $bin		= $cgibin . '/twiki';
my $lib		= $cgibin . '/lib';
my $cpan        = "$lib/CPAN";

my $xs = new XML::Simple( ForceArray => 1, KeyAttr => 1, AttrIndent => 1 ) or die $!;

################################################################################
# check prerequisites

my $title = "TWiki Installation (Step 3/4)";
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

# grr, can't get this working from *within* cgi... :*(
#installLocalModules({
#    modules => [ qw( Data::UUID Date::Handler Safe Language::Prolog CGI::Session File::Temp List::Permutor XML::Simple ) ],
#    dir => $cpan,
#});

################################################################################
# setup directory skeleton workplace

print qq{<h2>TWiki</h2>\n};
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
# authentication

print "<h2>Authentication</h2>\n";

execute( "mv $bin/.htaccess.txt $bin/.htaccess" );

$file = "$bin/.htaccess";
open(FH, "<$file") or die "Can't open $file: $!";
my $htaccess = join( "", <FH> );
close(FH) or warn "Can't close $file: $!";

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

# TODO: fix errors when removing DefaultPlugin
my @preinstalledPlugins = qw( CommentPlugin EditTablePlugin EmptyPlugin InterwikiPlugin RenderListPlugin SlideShowPlugin SmiliesPlugin SpreadSheetPlugin TablePlugin );
foreach my $plugin ( @preinstalledPlugins )
{
    erasePlugin( $plugin );
}

################################################################################
# install contrib

print "<h2>Contrib</h2>\n";
my $xmlContrib = $xs->XMLin( "tmp/install/downloads/contribs/contrib.xml" ) or warn "No contrib catalogue: $!";
my %hContrib = map { $_->{name}->[0], $_ } @{$xmlContrib->{contrib}};
foreach my $contribID ( $q->param('contrib') )
{
    my $contribS = $hContrib{$contribID} or die "no contrib entry for $contribID ?";
    my $contrib = $contribS->{name}->[0] or die "no contrib name? wtf?";

    installTWikiExtension({ file => "$contrib.tar.gz",
			    dir => "downloads/contribs",
			    name => $contrib,
			});
}

################################################################################
# install plugins

print "<h2>Plugins</h2>\n";
my $xmlPlugins = $xs->XMLin( "tmp/install/downloads/plugins/plugins.xml" ) or warn "No plugins catalogue: $!";
my %hPlugins = map { $_->{name}->[0], $_ } @{$xmlPlugins->{plugin}};
foreach my $pluginName ( $q->param('plugin') )
{
    my $pluginS = $hPlugins{$pluginName} or die "no plugin entry for $pluginName ?";
    my $plugin = $pluginS->{name}->[0] or die "no plugin name? wtf?";

    installTWikiExtension({ file => "$plugin.tar.gz",
			    dir => "downloads/plugins",
			    name => $plugin,
			});
}

################################################################################
### various patches/fixes/upgrades
my @patches = (
	       'macosx',				# fixes paths for gnu tools (e|f)grep
	       'SetMultipleDirsInSetlibDotCfg',		# 
#	       'testenv',				# make testenv a little more useful...
#	       'create-new-web-copy-attachments',	# update "create new web" to also copy attachments, not just topics
##	       'trash-attachment-button',		# a clickable link/button to (more easily) trash attachments
#	       'preview-manage-attachment',		# provide an image preview when working with attachments
#	       'ImageGallery-fix-unrecognised-formats',	# bugfixes for ImageGalleryPlugin 
#	       'PreviewOnEditPage',			# PreviewOnEditPage
#	       'InterWikiPlugin-icons',			# InterWiki icons
#	       'prefsperf',			# cdot's preferences handling performance improvements (http://twiki.org/cgi-bin/view/Codev/PrefsPmPerformanceFixes)
##	       'WikiWord-web-names',			# fix templates use of %WEB% instead of <nop>%WEB%
##	       'force-new-revision',			# add force new revision (TWiki:Codev.ForceNewRevisionCheckBox)
#	       'AttachmentVersionsBrokenOnlyShowsLast',	# view attachment v1.1 fix
	       );

print qq{<h2>Patches</h2>\n};
foreach my $patch ( @patches )
{
    print qq{<h3>Applying patch "$patch"</h3>\n};
    my $patchFile = "tmp/install/downloads/patches/local/${patch}.patch";
    execute( "(patch -p1 <$patchFile) || (patch -p0 <$patchFile)" ) or warn $!;
}

################################################################################
# AddOns
print qq{<h2>AddOns</h2>\n};

my $xmlAddOns = $xs->XMLin( "tmp/install/downloads/addons/addons.xml" ) or warn "No addons catalogue: $!";
my %hAddOns = map { $_->{name}->[0], $_ } @{$xmlAddOns->{addon}};
foreach my $addonName ( $q->param('addon') )
{
    my $addonS = $hAddOns{$addonName} or die "no addon entry for $addonName ?";
    my $addon = $addonS->{name}->[0] or die "no addon name? wtf?";

    installTWikiExtension({ file => "$addon.tar.gz",
			    dir => "downloads/addons",
			    name => $addon,
			});
}

################################################################################
# TODO: install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...)
# ImageGalleryPlugin: sudo fink install ImageMagick (...)
# ChartPlugin: sudo fink install GD


################################################################################
# update standard webs 

print qq{<h2>Updating system webs</h2>\n};
foreach my $web ( $q->param('systemweb') )
{
    installTWikiExtension({ file => "$web",
			    dir => "downloads/webs/system",
			    name => $web,
			});
}

################################################################################
# install local webs
print qq{<h2>Installing local webs</h2>\n};
foreach my $web ( $q->param('localweb') )
{
    installTWikiExtension({ file => "$web",
			    dir => "webs/local",
			    name => $web,
			});
}

################################################################################
#  cleanup / permissions

print qq{<h2>Final</h2>\n};
execute( "ls -lR tmp/install" );

execute("chmod -R 777 $dest");
execute("chmod -R 777 $bin");
execute("chmod -R 777 $lib");

execute("chmod -R 777 $tmp");

# a handy link to the place to go *after* the next step
print qq{<hr><hr>\n};
print qq{do a <tt>./post-wiki.sh</tt> and then <a href="http://localhost/~$account/cgi-bin/twiki/view/TWiki/InstalledPlugins">continue to wiki</a><br/>\n};
print qq{<br/><br/>};
print "you can perform this installation again using the following URL: <br/>";
#( my $installParameters = $ENV{QUERY_STRING} ) =~ s/install=install//;
#my $urlInstall = $ENV{SCRIPT_URI} . '?' . $installParameters;
( my $urlInstall = $q->self_url ) =~ s/install=install//;
print qq{<a href="$urlInstall"><tt>$urlInstall</tt></a>\n};

print end_html();

################################################################################
# uses globals $dest, $lib, $bin, $tmp

sub installTWikiExtension
{
    my $p = shift;
    my $file = $p->{file} or die "no twiki extension file specified";
    my $dir = $p->{dir} || ".";
    my $name = $p->{name} || $file;

    print "<h3>Installing $name</h3>\n";
    my $tarPackage = "$dir/$file";
    unless ( -e "tmp/install/$tarPackage" ) { print "<br/>Skipping $name ($tarPackage not found)<br/>\n"; return; }

    my $pushd = getcwd();
    chdir( "tmp/install" ) or warn $!;
    execute("tar xzvf $tarPackage") or warn $!;
    # TODO: run an standard-named install script (if included)
    my $installer = $name . '_installer.pl';
#    print "<b>$installer</b><br/>\n";
#    eval { execute( "cd tmp/install ; perl $installer" ) if -e $installer };  # -a doesn't prompt
#    print "installer error: $@, ($!)\n" if $@;

    # TODO: find perl move directory tree code
    # TODO: filter out ,v files (right???)
    if ( -d 'data/Plugins' ) { execute( "cp -rpv data/Plugins/* $dest/data/TWiki" ); execute( "rm -rf data/Plugins" ); }
    if ( -d 'data' ) { execute( "cp -rpv data $dest" ); execute( "rm -rf data" ); }
    if ( -d 'lib' ) { execute( "cp -rpv lib/* $lib" ); execute( "rm -rf lib" ); }
    # execute( "chmod +x bin/*" ); ???
    if ( -d 'bin' ) { execute( "cp -rpv bin/* $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'pub/Plugins' ) { execute( "cp -rpv pub/Plugins/* $tmp/twiki/TWiki" ); execute( "rm -rf pub/Plugins" ); }
    if ( -d 'pub' ) { execute( "cp -rpv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rpv templates/* $tmp/twiki/templates" ); execute( "rm -rf templates" ); }

    # TODO: assert( isDirectoryEmpty() );

    chdir $pushd or warn $!;
}

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

    chomp( my @output = `$cmd` );
    my ( $clrCommand, $clrError ) = ( ( my $error = $? ) ? qw( black red ) : qw( gray gray ) );

    ( my $cmdE = $cmd ) =~ s/&/&amp;/g;  $cmdE =~ s/</&lt;/g;  $cmdE =~ s/>/&gt;/g;  $cmdE =~ s/"/&quot;/g;
    print qq{<a href="#" title="$cmdE" onclick="toggleDisplay('cmd$nCmd')" >cmd</a> };

    my $display = $error ? "" : "none";
    print qq{<span style="display:$display" id="cmd$nCmd" >\n};

    print qq{<br/>[<font color="$clrError">$error</font>]: };
    $cmd =~ s/&/&amp;/g;  $cmd =~ s/</&lt;/g;  $cmd =~ s/>/&gt;/g;
    print qq{<font color="$clrCommand"><tt>$cmd</tt></font><br/>\n};

    print join( '<br/>', @output );

    print "<br/></span>\n";
}

}

#--------------------------------------------------------------------------------

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

################################################################################
################################################################################

#use CPAN;

sub installLocalModules
{
    my $parm = shift;
    my $cpan = $parm->{dir};

    print "<pre>\n";

    require CPAN;

#    CPAN::Shell->reload( qw( index ) ); # or die $!;
#      CPAN::Shell->o( qw( debug all ) );
#    exit 0;

#    ( mkdir $cpan or die $! ) unless -d $cpan;

    $CPAN::Config->{'ftp'} = q[/usr/bin/ftp];
    $CPAN::Config->{'gzip'} = q[/sw/bin/gzip];
    $CPAN::Config->{'pager'} = q[/usr/bin/less];
    $CPAN::Config->{'shell'} = q[/bin/bash];
    $CPAN::Config->{'tar'} = q[/sw/bin/tar];
    $CPAN::Config->{'unzip'} = q[/sw/bin/unzip];
    $CPAN::Config->{'wget'} = q[/sw/bin/wget];
    $CPAN::Config->{'make'} = q[/usr/bin/make];

    # some modules refuse to work if PREFIX is set, and some refuse to work if it is not. ???
    $CPAN::Config->{'makepl_arg'} = "PREFIX=$cpan";
    CPAN::Shell->o( conf => makepl_arg => "PREFIX=$cpan" );
    $CPAN::Config->{'make_arg'} = "";
    CPAN::Shell->o( conf => make_arg => "" );
    $CPAN::Config->{'make_install_arg'} = "";
    CPAN::Shell->o( conf => make_install_arg => "" );
    # TODO: try other setup of config if install fails?  PREFIX seems like the preferred method, so try that first
#    $CPAN::Config->{'make_arg'} = "-I$cpan/";
#    $CPAN::Config->{'make_install_arg'} = "-I$cpan/";
#    $CPAN::Config->{'makepl_arg'} = "LIB=$cpan/lib INSTALLMAN1DIR=$cpan/man/man1 INSTALLMAN3DIR=$cpan/man/man3";

#  'make_arg' => q[-I/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/],
#  'make_install_arg' => q[-I/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/lib/],
#  'makepl_arg' => q[LIB=/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/lib INSTALLMAN1DIR=/Users/wbniv/twiki/twikiplugins/lib/TWiki/Con\trib/TWikiInstallerContrib/cpan/man/man1 INSTALLMAN3DIR=/Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/man/man3],


    CPAN::Shell->o( conf => build_dir => "$cpan/.cpan/build" );
    $CPAN::Config->{'build_dir'} = "$cpan/.cpan/build";
    CPAN::Shell->o( conf => cpan_home => "$cpan/.cpan" );
    $CPAN::Config->{'cpan_home'} = "$cpan/.cpan";

#    'histfile' => q[/Users/wbniv/Sites/twiki/.cpan/histfile],
    $CPAN::Config->{'histsize'} = 0;

    $CPAN::Config->{'keep_source_where'} = "$cpan/.cpan/sources";
    CPAN::Shell->o( conf => keep_source_where => "$cpan/.cpan/sources" );

### set to same place as build_dir ?
    CPAN::Shell->o( conf => keep_source_where => "$cpan/.cpan/build" );

    $CPAN::Config->{'prerequisites_policy'} = 'follow';
    CPAN::Shell->o( conf => prerequisites_policy => 'follow' );

#    $CPAN::Config->{'urllist'} = [ "file:///Users/wbniv/twiki/twikiplugins/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/MIRROR/MINICPAN/" ];
    $CPAN::Config->{'urllist'} = [ "file:///Users/$account/Sites/cpan/MIRROR/TWIKI/" ];
#    $CPAN::Config{'urllist'} = [ "file:///Users/$account/Sites/cpan/MIRROR/TWIKI/" ];
#    $CPAN::Config->{'build_cache'} = q[0];
    CPAN::Shell->o( conf => build_cache => 0 );
    CPAN::Shell->o( conf => urllist => unshift => "file:///Users/$account/Sites/cpan/MIRROR/TWIKI/" );

#    CPAN::Shell->reload( qw( index ) ); # or die $!;
#    CPAN::Shell->o( conf => urllist => unshift => "file:///Users/$account/Sites/cpan/MIRROR/TWIKI/" );

###    print "xxx: ", Dumper( \{%CPAN::Config} );

    CPAN::Shell->o( conf => cache_metadata => 0 );
    CPAN::Shell->o( conf => index_expire => 1 );

#?  'index_expire' => q[1],

#?  'dontload_hash' => {  },
#  'ftp_proxy' => q[],
#?  'getcwd' => q[cwd],
#  'gpg' => q[],
#  'http_proxy' => q[],
#  'inactivity_timeout' => q[0],
#  'inhibit_startup_message' => q[0],
#  'lynx' => q[],
#  'ncftp' => q[],
#  'ncftpget' => q[],
#  'no_proxy' => q[],
#?  'scan_cache' => q[atstart],
#?  'term_is_latin' => q[1],

    print "<pre>o conf<br/>\n";
    CPAN::Shell->o( 'conf' );
    print "</pre>\n";

    print "<pre>", Data::Dumper::Dumper( $CPAN::Config ), "</pre>";
#    CPAN::Shell->reload( qw( index ) ); # or die $!;
#    print Data::Dumper::Dumper( $CPAN::Config );

    my @modules = @{$parm->{modules}};
    print Dumper( \@modules );
    foreach my $module ( @modules )
    {
	print qq{<h3>CPAN module $module</h3>\n};
	print "<pre>\n";
	my $obj = CPAN::Shell->expand( Module => $module ) or warn $!;
	next unless $obj;
	$obj->install; # or warn "Error installing $module\n"; 
	print "</pre>\n"
    }
    
#    print Dumper( $CPAN::Config );

    print "</pre>\n";
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

__DATA__
#================================================================================
# check to run as root (need permissions--- grrr, fix that) (why, again? i forget..., oh yeah, for apache.conf)
# TODO: try putting all setup in bin/.htaccess (sourceforge version does this)
chomp( my $whoami = `whoami` );
die "must run this as root (or sudo)\n" unless $whoami eq 'root';

my $account = shift or die "Usage: install.pl <accountName>\n";
# validate account exists -- how do you do that generally?  (eg, /etc/users doesn't exist on MacOsX)

my $install = cwd();

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

	# TODO: turn off warning for referencing undefined elements (still true?)
	$text .= checkbox_group( -name => $p->{type},
				 -values => [ map { $_->{name}->[0] } @{$xmlCatalogue->{$p->{type}}} ],
				 -labels => { map { 
				     $_->{name}->[0] => 
					 $p->{cgi}->a( { href => $_->{homepage}->[0], target => '_new', title => $_->{description}->[0] }, $_->{name}->[0] )
				     } @{$xmlCatalogue->{$p->{type}}} },
				 -defaults => [ $p->{cgi}->param( $p->{type} ) ],
				 -cols => 5,
#				 -linebreak => 'true',
				 );
