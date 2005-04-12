#! /usr/bin/perl -w
# $Id$
#  Stages 2-3/4 of an automatic twiki install on macosx darwin
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL

################################################################################
# TODO: (soon)
#    * PATCHES!
#    * get rid of =pre-wiki.sh= and =post-wiki.sh= and become a completely web-based install!
#    * permissions!
#    * error checking is pretty good, but error recovery might not be?
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
# OBSELETED:
#    * run rcslock
################################################################################

my ( $hostname, $account );
my ( $cgibin, $home );
my $localDirConfig;

BEGIN {
    ++$|;
    open( STDERR, ">>/tmp/error.log" );
    print STDERR `date`;

    use Cwd qw( cwd );
    use Config;
    # FIXME: (darwin,redhat)-specific
    # format: /Users/(account)/Sites/cgi-bin/...
    # format: /home/(account)/public_html/cgi-bin/...
    $account = [ split( '/', cwd() ) ]->[-3] or die "no account?";
#    print STDERR "account=[$account]\n";
#    my $localLibBase = cwd() . "/lib/CPAN/lib/site_perl/" . $Config{version};
    my $localLibBase = cwd() . "/lib/CPAN/lib";

    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
    # TODO: use setlib.cfg (along with TWiki:Codev.SetMultipleDirsInSetlibDotCfg)

    # TODO: use some form of cwd()
    # dreamhost
#   $home = 
    # darwin
#    $home = "/Users/$account/Sites";
    # redhat
    $home = "/home/$account/public_html";

    # TODO: test this should work: 
    $cgibin = "$home/cgi-bin";
#    $cgibin = cwd();
    chomp( $hostname = $ENV{SERVER_NAME} || `hostname` || 'localhost' );
    die "hostname?" unless $hostname;

    $localDirConfig = qq{
\$cfg{DefaultUrlHost}   = "http://$hostname";
\$cfg{ScriptUrlPath}    = "/~$account/cgi-bin/twiki";
\$cfg{PubUrlPath}       = "/~$account/htdocs/twiki";
\$cfg{PubDir}           = "$home/htdocs/twiki"; 
\$cfg{TemplateDir}      = "$home/twiki/templates"; 
\$cfg{DataDir}          = "$home/twiki/data"; 
\$cfg{LogDir}           = "$home/twiki/data"; 

\$cfg{LogFileName}      = "\$cfg{LogDir}/log%DATE%.txt";
\$cfg{WarningFileName}  = "\$cfg{LogDir}/warn%DATE%.txt";
\$cfg{DebugFileName}    = "\$cfg{LogDir}/debug.txt";

\$cfg{HtpasswdFileName}   = "\$cfg{DataDir}/.htpasswd";
\$cfg{RemoteUserFileName} = "\$cfg{DataDir}/remoteusers.txt";
\$cfg{MimeTypesFileName}  = "\$cfg{DataDir}/mime.types";

# Mac-specific
#\$cfg{EgrepCmd}         = '/usr/bin/egrep';
#\$cfg{FgrepCmd}         = '/usr/bin/fgrep';
};
}
use Error qw( :try );
use strict;
++$|;
#open(STDERR,'>&STDOUT'); # redirect error to browser

use CGI qw( :all );
use CGI::Carp qw( fatalsToBrowser );
use File::Copy qw( cp mv );
use File::Path qw( rmtree mkpath );
use File::Basename qw( basename );
use Cwd qw( cwd );
use Data::Dumper qw( Dumper );
use XML::Simple;
use CPAN;

################################################################################

my $q = CGI->new() or die $!;

################################################################################
# configuration page (in html) if the install button hasn't been clicked
################################################################################
unless ( ($q->param('install') || '') =~ /install/i )
{
    my $title = "TWiki Installation (Step 2/4)";
    print $q->header(), $q->start_html( 
					-title => $title,
					-style => { -code => "\
html body { background:#dddddd; padding:0em; margin:0em; margin:0.2em 0 0.1em 0.2em; } \
table, tr, td, td p  { padding:0em; margin:0em; } \
table { width:100%; } \
html body { font-size:0.9em; }
td { padding:0.1em; background:#9999cc; } \
td:hover { background:#bbbbff; } \
th { background:pink; font:1.5em; padding:0.35em; text-align:right; } \
th:hover { background:#ffdddd; } \
#hdr td { padding:0.2em; background:#ffff66; border:0px; } \
.disabled { background-color:#cccccc; }
" },
					);
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
<div style="font-size:1.5em;">TWiki Installation</div>

<form id="form">
<table id="hdr"><tr>
<td>Step 2/4 <span style="text-align:right;">[<a target="details" href="../config/instructions.html" >help</a>]</span></td>
<td align="right" width="1%" nowrap >
<input type="submit" name="install" value="install" /> <br/>
</td>
</table>
__HTML__

    my %kernels = ( dir => "tmp/install/downloads/releases/", xml => "releases.xml", type => "kernel" );
    releasesCatalogue({ %kernels, cgi => $q });
    print catalogue({ %kernels, inputType => "radio", title => "TWikiKernel", cgi => $q });

    print catalogue({ dir => "tmp/install/downloads/contribs/", xml => "contribs.xml", title => "Contribs", type => "contrib", cgi => $q });
    print catalogue({ dir => "tmp/install/downloads/plugins/", xml => "plugins.xml", title => "Plugins", type => "plugin", cgi => $q });
    print catalogue({ dir => "tmp/install/downloads/addons/", xml => "addons.xml", title => "AddOns", type => "addon", cgi => $q });
#    print catalogue({ dir => "tmp/install/downloads/skins/", xml => "skins.xml", title => "Skins", type => "skin", cgi => $q });
#    print catalogue({ dir => "tmp/install/downloads/patches/", xml => "patches.xml", title => "Patches", type => "patch", cgi => $q });
#    print catalogue({ dir => "tmp/install/downloads/webs/", xml => "webs.xml", title => "Web Templates", type => "web", cgi => $q });

    my %systemWikis = ( dir => "tmp/install/downloads/webs/system/", xml => "systemwebs.xml", type => "systemweb" );
    wikiCatalogue({ %systemWikis, cgi => $q });
    print catalogue({ %systemWikis, title => "System Wiki Webs (Updates)", cgi => $q });

    my %localWikis = ( dir => "tmp/install/webs/local/", xml => "localwebs.xml", type => "localweb" );
    wikiCatalogue({ %localWikis, cgi => $q });
    print catalogue({ %localWikis, title => "Local Wiki Webs", cgi => $q });

################################################################################
# PRECONFIGURATIONS

my $releaseTracker = ";contrib=DistributionContrib;plugin=TWikiReleaseTrackerPlugin";

#plugin=CommentPlugin;plugin=SectionalEditPlugin
#plugin=CalendarPlugin or plugin=QuickCalendarPlugin
#addon=CompareRevisionsAddOn - waiting until TWiki:Codev....InsDelTags... fixed

my $baseWiki = ";plugin=InterwikiPlugin;plugin=FindElsewherePlugin;plugin=SpacedWikiWordPlugin;plugin=SpreadSheetPlugin;plugin=TablePlugin;addon=GetAWebAddOn;plugin=SmiliesPlugin;plugin=SessionPlugin";
my $level2Wiki = $baseWiki . $releaseTracker . ";plugin=SlideShowPlugin;plugin=TocPlugin;plugin=RandomTopicPlugin";
my $publicWiki = $level2Wiki . ";plugin=BlackListPlugin";
my $level3Wiki = $level2Wiki . ";plugin=InterwikiPlugin;contrib=AttrsContrib;plugin=ImageGalleryPlugin";
	#plugin=BatchPlugin (esp. handy with ImageGallery (but i haven't tested it))
my $appWiki = $level3Wiki . ";plugin=FormQueryPlugin;plugin=MacrosPlugin";

my $softwareDevWiki = $level3Wiki . ";plugin=BeautifierPlugin;plugin=MathModePlugin;plugin=PerlDocPlugin";

    print <<__HTML__;
<h2>Preconfigurations</h2>
Configuration <a href="?$baseWiki">Lean and Mean Wiki</a><br/>
Configuration <a href="?$appWiki">Application Base Wiki</a><br/>
Configuration <a href="?$softwareDevWiki">Software Development Wiki</a><br/>
Configuration <a href="?$level3Wiki">Personal Wiki</a><br/>
Configuration <a href="?$publicWiki">Community Wiki</a><br/>
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
#    dir => $cpan,
#    modules => [ qw( Data::UUID Date::Handler Safe Language::Prolog CGI::Session File::Temp List::Permutor XML::Simple ) ],
#});

################################################################################
# setup directory skeleton workplace

# TODO: change this to require a kernel parameter? (probably, but need to deal with creating the error "screens")
my $tar = $q->param( 'kernel' ) || "TWiki20040902.tar.gz";
# SMELL: not a proper choosing of the latest version (esp. will break when SVN rev. >= 10000)
if ( $tar =~ /^LATEST$/i ) { 
    $tar = ( reverse sort { ( $a =~ /.+?(\d+)/ )[0] <=> ( $b =~ /.+?(\d+)/ )[0] } <downloads/releases/TWikiKernel-*> )[0];
print STDERR "using LATEST: $tar\n";
}
$tar ||= "TWiki20040902.tar.gz";

print STDERR "About to install TWikiKernel\n";
installTWikiExtension({ file => $tar, name => 'TWiki', dir => "downloads/releases", cdinto => 'twiki' });

################################################################################
# update TWiki.cfg for local directories configuration
print qq{<h2>TWiki.cfg</h2>\n};
print qq{<h3>LocalSite.cfg</h3>\n};

#my $file = "$lib/LocalSite.cfg";
my $file = "tmp/install/LocalSite.cfg";
open(FH, ">$file") or die "Can't open $file: $!";
print FH $localDirConfig;
close(FH) or die "Can't write to $file: $!";



################################################################################
# authentication

print "<h2>Authentication</h2>\n";

# SMELL: was mv, but a pain while debugging...
execute( "cp $bin/.htaccess.txt $bin/.htaccess" );

$file = "$bin/.htaccess";
#open(FH, "<$file") or die "Can't open $file: $!";
if ( open(FH, "<$file") ) {
	my $htaccess = join( "", <FH> );
	close(FH) or warn "Can't close $file: $!";

$htaccess =~ s|!FILE_path_to_TWiki!/data|$home/twiki/data|g;	# code smell: duplicated data from config file above
$htaccess =~ s|!URL_path_to_TWiki!/bin|/cgi-bin/twiki|g;	# ditto
# TODO: fix ErrorDocument 401 (what should it be set to?)

	open( FH, ">$file" ) or die $!;
	print FH $htaccess;
	close( FH ) or die $!;
}

execute( "rm $dest/data/TWiki/TWikiRegistration.txt" ) or warn $!;
my $reg = "$dest/data/TWiki/TWikiRegistration.txt,v";
if ( -e $reg ) { execute( "rm $reg" ) or warn $!; }
execute( "mv $dest/data/TWiki/TWikiRegistrationPub.txt $dest/data/TWiki/TWikiRegistration.txt") or warn $!;
my $pubreg = "$dest/data/TWiki/TWikiRegistrationPub.txt,v";
if ( -e $pubreg ) { execute( "mv $pubreg $reg") or warn $!; }

# TODO: setup data/.htpasswd (default file contains TWikiGuest/guest)

################################################################################
# install contrib plugin addon
################################################################################
my @types = (
	{ type => 'contrib', dir => "downloads/contribs/", xml => "contribs.xml", },
	{ type => 'plugin', dir => "downloads/plugins/", xml => "plugins.xml", },
	{ type => 'addon', dir => "downloads/addons/", xml => "addons.xml", },
	{ type => 'systemweb', dir => "downloads/webs/system/", xml => "systemwebs.xml", },
	{ type => 'localweb', dir => "webs/local/", xml => "localwebs.xml", },
    );
    
foreach my $iType ( @types )
{
    my $ext = $iType->{type};
#    print STDERR $ext, "\n";

    print "<h2>$ext</h2>\n";
    my $xmlCatalogue = "tmp/install/$iType->{dir}/$iType->{xml}";
    warn qq{xml catalogue file "$iType->{xml}" not found}, next unless -e $xmlCatalogue;
    my $xmlExt = $xs->XMLin( $xmlCatalogue, ForceArray => [ $ext ], SuppressEmpty => '' ) or warn "No ${ext}s catalogue: $!";
    my %hExt = map { $_->{name}, $_ } @{$xmlExt->{$ext}};
    foreach my $idExt ( $q->param($ext) )
    {
	my $ExtS = $hExt{$idExt} or warn "no entry for $idExt ?", next;
	my $name = $ExtS->{name} or die "no extension name? wtf?";
	$ExtS->{file} ||= "$name.tar.gz";
	
	installTWikiExtension({ file => $ExtS->{file}, name => $name, dir => $iType->{dir} });
    }
}

################################################################################
# TODO: install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...), gd, librsvg
# ImageGalleryPlugin: sudo fink install ImageMagick (...)
# ChartPlugin: sudo fink install gd2 librsvg


################################################################################
#  cleanup / permissions

print qq{<h2>Final</h2>\n};
execute( "ls -lR tmp/install" );

# permissions should be correct with installTWikiExtenson() calls
checkdir( $tmp, $dest, $bin, $lib, $cpan );

# a handy link to the place to go *after* the next step
print qq{<hr><hr>\n};
print qq{do a <tt>./post-wiki.sh</tt> and then <a target="details" href="http://$hostname/~$account/cgi-bin/twiki/view/TWiki/InstalledPlugins">continue to wiki</a><br/>\n};
print qq{run <a target="details" href="http://$hostname/~$account/cgi-bin/twiki/testenv/foo/bar" >testenv</a><br/>\n};
print qq{<br/><br/>};
print "you can perform this installation again using the following URL: <br/>";
( my $urlInstall = $q->self_url ) =~ s/install=install//;
print qq{<a href="$urlInstall"><tt>$urlInstall</tt></a>\n};

print end_html();

exit 0;

################################################################################
################################################################################

sub _dirCatalogue
{
    my $p = shift;

    die unless $p->{type} && $p->{cgi} && $p->{dir};
    my @releases = ();

    my @dirReleases = ();
    if ( opendir( RELEASES, $p->{dir} ) )
    {
	@dirReleases = grep { /$p->{fileFilter}/ } readdir( RELEASES );  #or warn $!; 
	closedir( RELEASES ) or warn $!;
    }
    return [] unless @dirReleases;

    foreach my $twiki ( @dirReleases )
    {
	( my $rel = $twiki ) =~ s/$p->{fileFilter}//;
	push @releases, {
	    file => "$p->{dir}/$twiki",
	    name => $rel,
	};
    }

    return \@releases;
}

################################################################################

# dir
# xml
# type
# list
sub SaveXML
{
    my $p = shift;
    die unless $p->{dir} && $p->{xml} && $p->{list} && $p->{type};

    my $xs = new XML::Simple() or die $!;
    my $xml = "$p->{dir}/$p->{xml}";
    open( XML, ">$xml" ) or die "$!: Can't write xml to \"$xml\"\n";
    print XML $xs->XMLout( { $p->{type} => $p->{list} }, NoAttr => 1 );
    close( XML ) or warn $!;

}

################################################################################

sub wikiCatalogue
{
    my $p = shift;
    $p->{fileFilter} = qr/\.wiki\.tar\.gz$/;
    $p->{list} = _dirCatalogue( $p );
    SaveXML( $p ) if @{$p->{list}};
}

################################################################################

sub releasesCatalogue
{
    my $p = shift;
    $p->{fileFilter} = qr/\.tar\.gz$/;
    if ( $p->{list} = [ reverse sort { $a->{name} cmp $b->{name} } @{_dirCatalogue( $p )} ] )
    {
    	foreach my $release ( @{$p->{list}} )
	{
	    my $rel = $release->{name};
	    my ( $label, undef, $branch, $revInfo ) = $rel =~ m/TWiki(Kernel)?(-([^-]+)-)?(.+)?/;
	    $label ||= '';
	    $branch ||= '';
	    warn $rel, next unless $revInfo;

	    $release->{homepage} ||= "http://twiki.org/cgi-bin/view/Codev/TWikiKernel$branch$revInfo";

	    $release->{description} = "TWiki$label Release $branch";
	    if ( $label && $revInfo =~ /^(\d+)$/ )
	    {
		$release->{description} .= " SVN r$1";
	    }
	    else
	    {
		my ( $year, $month, $day, undef, $hour, $min, $sec ) = $revInfo =~ /(\d{4})(\d{2})(\d{2})(\.(\d{2})(\d{2})(\d{2}))?/;
		my @month = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
		$release->{description} .= " $day $month[$month-1] $year";
		$release->{description} .= " ${hour}:${min}.${sec}" if ( $rel =~ /\./ );
	    }
	}

	SaveXML( $p );
    }
}

################################################################################

sub catalogue
{
    my $p = shift;
    die unless $p->{xml} && $p->{type} && $p->{cgi};
    $p->{title} ||= $p->{type};
    $p->{inputType} ||= 'checkbox';
    $p->{dir} ||= './';

    my $text = "";
    $text .= qq{<table>};
    $text .= qq{<tr><th onclick="toggleAll( document.getElementById('form'), '$p->{type}' )" >} . $p->{title} . "</th></tr>\n";

#    warn Dumper( $p ) unless -e "$p->{dir}/$p->{xml}";
    if ( -e "$p->{dir}/$p->{xml}" )
    {
	my $xs = new XML::Simple( KeyAttr => 1, AttrIndent => 1 ) or die $!;
	my $xmlCatalogue = $xs->XMLin( "$p->{dir}/$p->{xml}", ForceArray => [ $p->{type} ], SuppressEmpty => '' ) or warn qq{No xml catalogue "$p->{xml}": $!};

#	print "<pre>", Dumper( $p->{cgi}->param( $p->{type} ) ), "</pre>\n";
#	<plugin>
#	    <name>ActionTrackerPlugin</name>
#	    <description>ActionTrackerPlugin description</description>
#	    <homepage>http://twiki.org/cgi-bin/view/Plugins/ActionTrackerPlugin</homepage>
#	</plugin>
	foreach my $extInstall ( @{ $xmlCatalogue->{ $p->{type} } } )
	{
	    next unless $extInstall->{name};

	    $extInstall->{description} ||= "";		# qq{<font color="gray" >(no description available)</font >};

	    $text .= qq{<tr class="$p->{type}" >};
	    #--------------------------------------------------------------------------------
#	    print STDERR Dumper( $extInstall->{name} ), Dumper( $p->{type} ), Dumper( [ $p->{cgi}->param( $p->{type} ) ] ), "\n";
	    my $checked = ( grep { /^\Q$extInstall->{name}\E$/ } $p->{cgi}->param($p->{type}) ) ? qq{checked="checked"} : '';
	    my $aAttr = {
		target => 'details',
		title => $extInstall->{description},
	    };
	    $aAttr->{href} = "$extInstall->{homepage}?skin=plain" if $extInstall->{homepage};

	    # CODE SMELL: blech, assumes .tar.gz extension is the right thing to add, should be generated by download-twiki-extensions.pl (probably, i guess)
	    $extInstall->{file} ||= "$p->{dir}/$extInstall->{name}.tar.gz";

	    my $disabled = -e $extInstall->{file} ? "" : "disabled";
	    $text .= qq{<td class="$disabled" >};
	    $text .= qq{<input type="$p->{inputType}" name="$p->{type}" value="$extInstall->{name}" $checked $disabled /> };
	    $text .= "<b>" . $p->{cgi}->a( $aAttr, $extInstall->{name} ) . "</b>\n";
	    $text .= $extInstall->{description};
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

    print STDERR "Installing [$name] dir=[$dir] file=[$file] " . Dumper( $p ), "\n";

    print "<h3>Installing $name</h3>\n";
    (my $tarPackage = $file);
    unless ( -e $tarPackage )
    {
	($tarPackage = "$dir/$file") =~ s|^tmp/install/||;
	unless ( -e "tmp/install/$tarPackage" )
	{ 
	    $tarPackage .= ".tar.gz";
	    unless ( -e "tmp/install/$tarPackage" )
	    {
		print "<br/>Skipping $name ($tarPackage not found)<br/>\n"; 
		return;
	    }
	}
    }

    my $pushd = cwd();
    chdir( "tmp/install" ) or warn $!;
    ( $tarPackage ) =~ s|^tmp/install/||;
    execute("tar xzvf $tarPackage") or warn $!;
    chdir $p->{cdinto} if $p->{cdinto};
    # TODO: run an standard-named install script (if included)
    my $installer = $name . '_installer.pl';
#    print "<b>$installer</b><br/>\n";
#    eval { execute( "cd tmp/install ; perl $installer" ) if -e $installer };  # -a doesn't prompt
#    print "installer error: $@, ($!)\n" if $@;

    checkdir( $tmp, $dest, $bin, $lib );
    mkpath( "$dest/data/TWiki" );
    checkdir( "$dest/data/TWiki" );
    mkpath( "$tmp/twiki" );
    checkdir( "$tmp/twiki" );
    mkpath( "$tmp/twiki/TWiki" );
    checkdir( "$tmp/twiki/TWiki" );
    mkpath( "$tmp/twiki/templates" );
    checkdir( "$tmp/twiki/templates" );

    # TODO: find perl move directory tree code
    # TODO: filter out ,v files (right???)
    if ( -d 'data/Plugins' ) { execute( "cp -rv data/Plugins/* $dest/data/TWiki" ); execute( "rm -rf data/Plugins" ); }
    if ( -d 'data' ) { execute( "cp -rv data $dest" ); execute( "rm -rf data" ); }
    if ( -d 'lib' ) { execute( "cp -rv lib/* $lib" ); execute( "rm -rf lib" ); }
#    if ( -d 'bin' ) { execute( "chmod +x bin/*" ); execute( "cp -rv bin/ $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'bin' ) { execute( "cp -rv bin/* $bin" ); execute( "rm -rf bin" ); }
    if ( -d 'pub/Plugins' ) { execute( "cp -rv pub/Plugins/* $tmp/twiki/TWiki" ); execute( "rm -rf pub/Plugins" ); }
    if ( -d 'pub' ) { execute( "cp -rv pub $tmp/twiki" ); execute( "rm -rf pub" ); }
    if ( -d 'templates' ) { execute( "cp -rv templates/* $tmp/twiki/templates" ); execute( "rm -rf templates" ); }

    # TODO: assert( isDirectoryEmpty() );

	print STDERR "fixing permissions...\n";
    execute("chmod -R 777 $dest $lib $tmp; chmod -R 755 $bin $lib; chmod -R 775 $dest/data; chmod -R 775 $tmp/twiki");
    checkdir( $tmp, $dest, $bin, $lib );		# removed bin because it shouldn't be world-writable (taint checking)

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
#	    exit 1;
	}
#	unless (mode($dir) & 0x2) {
#	    print "Directory $dir is not world writable";
#	    exit 1;
#	}
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

#    print join( '<br/>', @output );

    print "<br/></span>\n";
}

}

################################################################################

sub RestartApache
{
    system qw( apachectl restart );
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
<Directory "$home/">
    Options Indexes MultiViews
    AllowOverride None
    Order allow,deny
    Allow from all
</Directory>

ScriptAlias /~$account/twiki/bin/ "$home/twiki/bin/"
Alias /~$account/twiki/ "$home/twiki/"
<Directory "$home/twiki/bin">
    Options +ExecCGI
    SetHandler cgi-script
    Allow from all
</Directory>
<Directory "$home/twiki/pub">
    Options FollowSymLinks +Includes
    AllowOverride None
    Allow from all
</Directory>
<Directory "$home/twiki/data">
    deny from all
</Directory>
<Directory "$home/twiki/templates">
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


