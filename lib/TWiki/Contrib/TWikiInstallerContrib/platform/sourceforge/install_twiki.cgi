#!/usr/bin/perl -w
# $Id$
#  Stages 2-3/4 of an automatic twiki install on macosx darwin
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL

################################################################################
# TODO: (soon)
#    * PATCHES!
#    * get rid of =pre-wiki.sh= and =post-wiki.sh= and become a completely web-based install!
#    * error checking is pretty good, but error recovery might not be?
#    * run rcslock
#    * ???
# TODO: (long term)
#    * better mechanism to publish distribution definition
#    * compare/contrast with MS-'s installer
#    * put in package namespace
#    * install plugin dependencies (ooh, add to twiki form?)
#		(external dependencies like imagemagick and latex, not other perl modules as those will be handled automatically)
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
my ( $cgibin, $home );
my $localDirConfig;
my @patches;

BEGIN {
    use Cwd qw( cwd getcwd );
    use Config;
    $account = [ split( '/', getcwd() ) ]->[-2];   # format: /home/groups/p/pr/project/cgi-bin/...
    my $localLibBase = getcwd() . "/lib/CPAN/lib/site_perl/" . $Config{version};
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
    # TODO: use setlib.cfg (along with TWiki:Codev.SetMultipleDirsInSetlibDotCfg)

    $cgibin = getcwd();
    $home = '/home/groups/' . substr($project, 0, 1) . '/' . substr($project, 0, 2) . '/' . $project;

    $localDirConfig = qq{
\$defaultUrlHost   = "http://$project.sourceforge.net"; 
\$scriptUrlPath    = "/cgi-bin/twiki"; 
\$dispScriptUrlPath = \$scriptUrlPath;
\$pubUrlPath       = "/twiki"; 
\$pubDir           = "$home/htdocs/twiki"; 
\$templateDir      = "$home/twiki/templates"; 
\$dataDir          = "$home/twiki/data"; 
\$logDir           = \$dataDir;
};

################################################################################
### various patches/fixes/upgrades
    @patches = (
	       );
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
use XML::Simple;
use CPAN;

################################################################################

my $q = CGI->new() or die $!;

################################################################################
# configuration page (in html) if the install button hasn't been clicked
################################################################################
unless ( $q->param('install') =~ /install/i )
{
    my $title = "TWiki Installation (Step 2/4)";
    print $q->header(), $q->start_html( 
					-title => $title,
					-style => { -code => "\
html body { background:#77ee77; } \
table, tr, td, td p  { padding:0em; margin:0em; } \
table { width:90%; } \
td { padding:0.2em; background:#9999cc; } \
td:hover { background:#bbbbff; } \
th { background:pink; font:1.5em; padding:0.35em; text-align:right; } \
th:hover { background:#ffdddd; } \
#hdr td { padding:0.2em; background:#ffff66; border:0px; } \
.disabled { background-color:#cccccc; }
" },
					);
#    print "$q";
    print <<'__HTML__';
<script>
<!--
function toggleDisplay( e )
{
	var style = e.style;
	return style.display = style.display ? "" : "none";
}

function toggleAll(theForm, cName)
{
    for ( var i=0; i<theForm.elements.length; ++i )
    {
        var e = theForm.elements[i].parentNode.parentNode;
	if ( e.className == cName ) toggleDisplay( e );
    }
}

function toggleHover( e )
{
    var ee = e.firstChild.firstChild;	// >TR< --> TD --> [[INPUT]] checkbox
    if ( ee && !ee.disabled ) ee.checked = !ee.checked;
    return true;
}
-->
</script>
<h1>TWiki Installation</h1>

<form id="form">
<table id="hdr"><tr>
<td>Step 2/4</td>
<td align="right" width="1%" nowrap >
<input type="submit" name="install" value="install" /> <br/>
</td>
</table>
__HTML__

    my @releases = ();
    if ( opendir( RELEASES, "tmp/install/downloads/releases" ) )
    {
	@releases = grep { /\.tar\.gz$/ } readdir( RELEASES );  #or warn $!; 
	closedir( RELEASES ) or warn $!;
    }
    print releasesCatalogue({ list => [ @releases ], title => 'TWiki Kernel', type => 'twiki', cgi => $q });

    print catalogue({ dir => "tmp/install/downloads/contribs/", xml => "contribs.xml", title => "Contribs", type => "contrib", cgi => $q });
    print catalogue({ dir => "tmp/install/downloads/plugins/", xml => "plugins.xml", title => "Plugins", type => "plugin", cgi => $q });
    print catalogue({ dir => "tmp/install/downloads/addons/", xml => "addons.xml", title => "AddOns", type => "addon", cgi => $q });
#    print catalogue({ dir => "tmp/install/downloads/skins/", xml => "skins.xml", title => "Skins", type => "skin", cgi => $q });
    print catalogue({ dir => "tmp/install/downloads/patches/", xml => "patches.xml", title => "Patches", type => "patch", cgi => $q });
#    print catalogue({ dir => "tmp/install/downloads/webs/", xml => "webs.xml", title => "Web Templates", type => "web", cgi => $q });

    print wikiCatalogue({ webs => [ wikiWebList({ dir => "downloads/webs/system" }) ], title => "System Wiki Webs (Updates)", type => "systemweb", cgi => $q });
    print wikiCatalogue({ webs => [ wikiWebList({ dir => "webs/local" }) ], title => "Local Wiki Webs", type => "localweb", cgi => $q });

    print <<__HTML__;
</form>
</body>
</html>
__HTML__

    exit 0;
}

################################################################################
# INSTALL
################################################################################

my $tmp		= "$cgibin/tmp";
my $htdocs	= $home . '/htdocs';
my $dest	= $home . '/twiki';
my $pub		= $htdocs . '/twiki';
my $bin		= $cgibin . '/twiki';
my $lib		= $cgibin . '/lib';
my $cpan        = "$lib/CPAN";

my $xs = new XML::Simple( KeyAttr => 1, AttrIndent => 1 ) or die $!;

################################################################################
# start installation

my $title = "TWiki Installation (Step 3/4)";
print header(), start_html( -title => $title );
print qq{<h1>$title</h1>\n};

checkdir( $cpan );

################################################################################

# grr, can't get this working from *within* cgi... :*(
#installLocalModules({
#    modules => [ qw( Data::UUID Date::Handler Safe Language::Prolog CGI::Session File::Temp List::Permutor XML::Simple ) ],
#    dir => $cpan,
#});

################################################################################
# setup directory skeleton workplace

my $tar = $q->param( 'twiki' ) || "TWiki20040901.tar.gz";
installTWikiExtension({ file => $tar,
			dir => "downloads/releases",
			name => 'TWiki',
			cdinto => 'twiki',
		    });

# TODO: fix errors when removing DefaultPlugin
my @preinstalledPlugins = qw( 
    CommentPlugin EditTablePlugin EmptyPlugin InterwikiPlugin RenderListPlugin SlideShowPlugin SmiliesPlugin SpreadSheetPlugin TablePlugin 
    );
erasePlugin( @preinstalledPlugins );

################################################################################
# update TWiki.cfg for local directories configuration

print qq{<h2>TWiki.cfg</h2>\n};
my $file = "$lib/TWiki.cfg";
open(FH, "<$file") or die "Can't open $file: $!";
my $config = join( "", <FH> );
close(FH) || die "Can't write to $file: $!";

# need to put our configurations in the "right" spot in the configuration file
# they need to be inserted after the default definitions, but before any of them are used
# hm, maybe i could have just put the whole thing in a BEGIN { } block ?
$config =~ s/(# FIGURE OUT THE OS WE'RE RUNNING UNDER - from CGI.pm)/$localDirConfig\n$1/;
# TODO: check for success
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

# TODO: setup data/.htpasswd (default file contains TWikiGuest/guest)

################################################################################
# install contrib

print "<h2>Contrib</h2>\n";
my $xmlContrib = $xs->XMLin( "tmp/install/downloads/contribs/contribs.xml", ForceArray => [ 'contrib' ] ) or warn "No contribs catalogue: $!";
my %hContrib = map { $_->{name}, $_ } @{$xmlContrib->{contrib}};
foreach my $contribID ( $q->param('contrib') )
{
    my $contribS = $hContrib{$contribID} or warn "no contrib entry for $contribID ?", next;
    my $contrib = $contribS->{name} or die "no contrib name? wtf?";

    installTWikiExtension({ file => "$contrib.tar.gz",
			    dir => "downloads/contribs",
			    name => $contrib,
			});
}

################################################################################
# install plugins

print "<h2>Plugins</h2>\n";
my $xmlPlugins = $xs->XMLin( "tmp/install/downloads/plugins/plugins.xml", ForceArray => [ 'plugin' ] ) or warn "No plugins catalogue: $!";
my %hPlugins = map { $_->{name}, $_ } @{$xmlPlugins->{plugin}};
foreach my $pluginName ( $q->param('plugin') )
{
    my $pluginS = $hPlugins{$pluginName} or warn "no plugin entry for $pluginName ?", next;
    my $plugin = $pluginS->{name} or warn "no plugin name? wtf?", next;

    installTWikiExtension({ file => "$plugin.tar.gz",
			    dir => "downloads/plugins",
			    name => $plugin,
			});
}

################################################################################
# AddOns
print qq{<h2>AddOns</h2>\n};

my $xmlAddOns = $xs->XMLin( "tmp/install/downloads/addons/addons.xml", ForceArray => [ 'addon' ] ) or warn "No addons catalogue: $!";
my %hAddOns = map { $_->{name}, $_ } @{$xmlAddOns->{addon}};
foreach my $addonName ( $q->param('addon') )
{
    my $addonS = $hAddOns{$addonName} or warn "no addon entry for $addonName ?", next;
    my $addon = $addonS->{name} or warn "no addon name? wtf?", next;

    installTWikiExtension({ file => "$addon.tar.gz",
			    dir => "downloads/addons",
			    name => $addon,
			});
}

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
### various patches/fixes/upgrades

print qq{<h2>Patches</h2>\n};
foreach my $patch ( @patches )
{
    print qq{<h3>Applying patch "$patch"</h3>\n};
    my $patchFile = "tmp/install/downloads/patches/local/${patch}.patch";
    execute( "cat $patchFile ; (patch -p1 <$patchFile) || (patch -p0 <$patchFile)" ) or warn $!;
}

################################################################################
# TODO: install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...)
# ImageGalleryPlugin: sudo fink install ImageMagick (...)
# ChartPlugin: sudo fink install GD


################################################################################
#  cleanup / permissions

print qq{<h2>Final</h2>\n};
execute( "ls -lR tmp/install" );

# permissions should be correct with installTWikiExtension() calls
checkdir( $tmp, $dest, $bin, $lib, $cpan );

# a handy link to the place to go *after* the next step
print qq{<hr><hr>\n};
print qq{do a <tt>./post-wiki.sh</tt> and then <a href="http://localhost/~$account/cgi-bin/twiki/view/TWiki/InstalledPlugins">continue to wiki</a><br/>\n};
print qq{<br/><br/>};
print "you can perform this installation again using the following URL: <br/>";
( my $urlInstall = $q->self_url ) =~ s/install=install//;
print qq{<a href="$urlInstall"><tt>$urlInstall</tt></a>\n};

print end_html();

exit 0;

################################################################################
################################################################################

sub wikiWebList
{
    my $p = shift;

    chdir "tmp/install";
    my @webs = ();
    if ( opendir( WIKIS, $p->{dir} ) )
    {
	@webs = grep { /\.wiki\.tar\.gz$/ } readdir( WIKIS );  #or warn $!; 
	closedir( WIKIS ) or warn $!;
    }
    chdir "../..";

    return @webs;
}

################################################################################

sub wikiCatalogue
{
    my $p = shift;

    unless ( @{ $p->{webs} } ) { return "" }

    my $text = "";
    $text .= "<table>";
    $text .= qq{<tr><th onclick="toggleAll( document.getElementById('form'), '$p->{type}' )" >} . $p->{title} . "</th></tr>\n";

    foreach my $web ( @{ $p->{webs} } )
    {
	my $checked = ( grep { /^\Q$web\E$/ } ( $p->{cgi}->param($p->{type}) ) ) ? qq{checked="checked"} : '';

	$text .= qq{<tr class="$p->{type}" onclick="toggleHover(this)" ><td>};
	# BLECH - force a checkbox click, because the TD handler above will undo it (happens twice :( )
	$text .= qq{<input type="checkbox" name="$p->{type}" value="$web" $checked onclick="toggleHover(this.parentNode.parentNode);" /> $web};
	$text .= "</td></tr>";
    }

    $text .= "</table>";

    return $text;
}

################################################################################

sub releasesCatalogue
{
    my $p = shift;
    die unless $p->{type} && $p->{cgi};
    unless ( @{ $p->{list} } ) { return "" }
    $p->{title} ||= $p->{type};

    my $text = "";
    $text .= "<table>";
    $text .= qq{<tr><th onclick="toggleAll( document.getElementById('form'), '$p->{type}' )" >} . $p->{title} . "</th></tr>\n";

    foreach my $twiki ( @{ $p->{list} } )
    {
	my $checked = ( grep { /^\Q$twiki\E$/ } ( $p->{cgi}->param($p->{type}) ) ) ? qq{checked="checked"} : '';

	$text .= qq{<tr class="$p->{type}" onclick="toggleHover(this)" ><td>};
	# BLECH - force a checkbox click, because the TD handler above will undo it (happens twice :( )
	$text .= qq{<input type="radio" name="$p->{type}" value="$twiki" $checked onclick="toggleHover(this.parentNode.parentNode);" /> };
	( my $displayRelease = $twiki ) =~ s/.tar.gz//;
	my ( $label, undef, $branch, $year, $month, $day, undef, $hour, $min, $sec ) = 
	    $displayRelease =~ m/TWiki(Kernel)?(-([^-]+)-)?(\d{4})(\d{2})(\d{2})(\.(\d{2})(\d{2})(\d{2}))?/;
	$branch ||= '';
	$label ||= '';

	my @month = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	if ( $displayRelease =~ /\./ ) 
	{ 
	    $displayRelease = "$branch $day $month[$month-1] $year ${hour}.${min}.${sec}";
	}
	else
	{
	    $displayRelease = "$branch $day $month[$month-1] $year";
	}
	$text .= "TWiki$label Release $displayRelease";
	$text .= "</td></tr>";
    }

    $text .= "</table>";

    return $text;
}

################################################################################

sub catalogue
{
    my $p = shift;
    die unless $p->{xml} && $p->{type} && $p->{cgi};
    $p->{title} ||= $p->{type};
    $p->{dir} ||= './';

    my $text = "";
    $text .= qq{<table>};
    $text .= qq{<tr><th onclick="toggleAll( document.getElementById('form'), '$p->{type}' )" >} . $p->{title} . "</th></tr>\n";

    if ( -e "$p->{dir}/$p->{xml}" )
    {
	my $xs = new XML::Simple( KeyAttr => 1, AttrIndent => 1 ) or die $!;
	my $xmlCatalogue = $xs->XMLin( "$p->{dir}/$p->{xml}", ForceArray => [ $p->{type} ] ) or warn qq{No xml catalogue "$p->{xml}": $!};

#	print "<pre>", Dumper( $p->{cgi}->param( $p->{type} ) ), "</pre>\n";
	foreach ( @{$xmlCatalogue->{ $p->{type} } } )
	{
	    next unless $_->{name};

	    $text .= qq{<tr class="$p->{type}" onclick="toggleHover(this);" >};
	    #--------------------------------------------------------------------------------
	    my $findCheck = $_->{name};
	    my $checked = ( grep { /^\Q$findCheck\E$/ } ( $p->{cgi}->param($p->{type}) ) ) ? qq{checked="checked"} : '';
	    my $aAttr = {
		target => '_new',
		title => $_->{description},
	    };
	    $aAttr->{href} = $_->{homepage} if $_->{homepage};

	    $_->{file} = "$p->{dir}/$_->{name}.tar.gz";
	    my $disabled = -e $_->{file} ? "" : "disabled";

	    $text .= qq{<td class="$disabled" >};
	    # BLECH - force a checkbox click, because the TD handler above will undo it (happens twice :( )
	    $text .= qq{<input type="checkbox" name="$p->{type}" value="$_->{name}" $checked $disabled onclick="toggleHover(this.parentNode.parentNode);" /> };
	    $text .= "<b>" . $p->{cgi}->a( $aAttr, $_->{name} ) . "</b>\n";
	    $text .= $_->{description} || '';
	    $text .= "</td>";
	    #--------------------------------------------------------------------------------
	    $text .= "</tr>\n";
	}
    }
    $text .= "</table>\n";

    return $text;
}

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
    chdir $p->{cdinto} if $p->{cdinto};
    # TODO: run an standard-named install script (if included)
    my $installer = $name . '_installer.pl';
#    print "<b>$installer</b><br/>\n";
#    eval { execute( "cd tmp/install ; perl $installer" ) if -e $installer };  # -a doesn't prompt
#    print "installer error: $@, ($!)\n" if $@;

    checkdir( $tmp, $dest, $bin, $lib );

    # TODO: find perl move directory tree code
    # TODO: filter out ,v files (right???)
    if ( -d 'data/Plugins' ) { execute( "cp -rv data/Plugins/ $dest/data/TWiki" ); execute( "rm -rf data/Plugins" ); }
    if ( -d 'data' ) { execute( "cp -rv data $dest" ); execute( "rm -rf data" ); }
    if ( -d 'lib' ) { execute( "cp -rv lib/ $lib" ); execute( "rm -rf lib" ); }
#    if ( -d 'bin' ) { execute( "chmod +x bin/*" ); execute( "cp -rv bin/ $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'bin' ) { execute( "cp -rv bin/ $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'pub/Plugins' ) { execute( "cp -rv pub/Plugins/ $tmp/twiki/TWiki" ); execute( "rm -rf pub/Plugins" ); }
    if ( -d 'pub' ) { execute( "cp -rv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rv templates/ $tmp/twiki/templates" ); execute( "rm -rf templates" ); }

    # TODO: assert( isDirectoryEmpty() );

    execute("chmod -R 777 $dest $bin $lib $tmp");
    checkdir( $tmp, $dest, $bin, $lib );

    chdir $pushd or warn $!;
}

################################################################################

sub mode 
{
    my ($file) = @_;
    my ($dev, $ino, $mode) = stat $file;
    return $mode;
}

#--------------------------------------------------------------------------------

sub checkdir 
{
    foreach my $dir ( @_ )
    {
	unless (-d $dir) {
	    print "Directory not found: $dir";
	    exit 1;
	}
	unless (mode($dir) & 0x2) {
	    print "Directory $dir is not world writable";
	    exit 1;
	}
    }
}

#--------------------------------------------------------------------------------

{
    my $nCmd = 0;

sub execute {

    if ( $nCmd++ == 0 )
    {
	print <<'__HTML__';
	<script type="text/javascript">
<!--	    
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
-->
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
    foreach my $plugin ( @_ )
    {
	print qq{<h3>Erasing preinstalled plugin $plugin</h3>\n};
	execute( "rm $lib/TWiki/Plugins/${plugin}.pm" ) if -e "$lib/TWiki/Plugins/${plugin}.pm";
	execute( "rm $dest/data/TWiki/${plugin}.txt*" );
	execute( "rm -r $lib/TWiki/Plugins/${plugin}" ) if -d "$lib/TWiki/Plugins/${plugin}";
	execute( "rm -r tmp/twiki/pub/TWiki/${plugin}" ) if -d "tmp/twiki/pub/TWiki/${plugin}";
	# TODO: how to delete templates distribute with this? (and other files, too?)
    }
}

################################################################################

sub RestartApache
{
    `apachectl restart`;
}

#--------------------------------------------------------------------------------

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
