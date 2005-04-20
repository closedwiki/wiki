#!/home/wikihosting/packages/perl5.8.4/bin/perl -w
# $Id$
#  Stages 2-3/3 of an automatic twiki install
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;

################################################################################
# TODO: (soon)
#    * permissions!
#    * PATCHES!
#    * get rid of =pre-wiki.sh= and =post-wiki.sh= and become a completely web-based install! (oh so close!)
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

my $localDirConfig;
my $cgibin;
my $home;
my $tmp;
my ( $VIEW, $TESTENV );
my $PERL;
my $q;	# CGI object

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

################################################################################

BEGIN {
    use FindBin;
    use Config;
    use File::Path qw( mkpath );

    $cgibin = $FindBin::Bin;
    $home = (getpwuid($>))[7] or die "no home directory?";

    $tmp = "$cgibin/tmp";
    -e $tmp || mkpath $tmp, 0, 0777;

    eval qq{ 
	use lib( "$cgibin/lib/CPAN/lib" );

    	use URI;
	use CGI qw( :standard );
    };
    $q = CGI->new() or die $!;

    my $install_cgi = URI->new( $ENV{SCRIPT_URI} );

    $localDirConfig = {
	DefaultUrlHost   => $install_cgi->scheme . "://" . $install_cgi->host . ( $install_cgi->port != $install_cgi->default_port && ':'.$install_cgi->port ),
	ScriptUrlPath    => "/cgi-bin/twiki",
	ScriptSuffix     => $q->param( 'scriptsuffix' ) || '',# || '.cgi',
	PubUrlPath       => "/htdocs/twiki",
	PubDir           => "$cgibin/../htdocs/twiki",
	TemplateDir      => "$home/twiki/templates",
	DataDir          => "$home/twiki/data",
	LogDir           => "$home/twiki/data",
    };
    $VIEW = URI->new( "twiki/view$localDirConfig->{ScriptSuffix}", $install_cgi->scheme )->abs( $install_cgi );
    $TESTENV = URI->new( "twiki/testenv$localDirConfig->{ScriptSuffix}", $install_cgi->scheme )->abs( $install_cgi );

    $PERL = $q->param( 'perl' ) || findProgramOnPaths( 'perl' );
}
use strict;
use Error qw( :try );
++$|;
#open(STDERR,'>&STDOUT'); # redirect error to browser

use FindBin;
use CGI::Carp qw( fatalsToBrowser );
use File::Copy qw( cp mv );
use File::Path qw( mkpath rmtree );
use File::Basename qw( basename );
use Data::Dumper qw( Dumper );
use XML::Simple;
use Archive::Any;
use File::Slurp qw( read_file write_file );
use CPAN;

################################################################################

################################################################################
# already installed?
################################################################################
if ( -e "$FindBin::Bin/twiki" )
{
    print $q->header();
    print $q->h1( "already installed" );
    print continueToWikiText();
    exit 0;
}

################################################################################
# configuration page (in html) if the install button hasn't been clicked
################################################################################
unless ( $q->param( 'kernel' ) && ($q->param('install') || '') =~ /install/i )
{
    print installationMenu( $q );
    exit 0;
}

################################################################################
################################################################################
# INSTALL
################################################################################

my $mapTWikiDirs = {
    lib => { dest => "$cgibin/lib" },
    pub => { dest => $localDirConfig->{PubDir} },
    data => { dest => $localDirConfig->{DataDir} },
    templates => { dest => $localDirConfig->{TemplateDir} },
    bin => { dest => "$cgibin/twiki", perms => 0755, },
};

################################################################################
# start installation

my $title = "TWiki Installation (Step 3/3)";
print header(), start_html( -title => $title );
print $q->h1( $title );

#--------------------------------------------------------------------------------
# grr, can't get this working from *within* cgi... :*(
# local CPAN modules
#installLocalModules({
#    dir => $cpan,
#    modules => [ qw( Data::UUID Date::Handler Safe ... XML::Simple ) ],
#});

#--------------------------------------------------------------------------------
# install TWiki itself
my $tar = $q->param( 'kernel' ) or die "kernel parameter required (how did you get here?)";
if ( $tar =~ /^LATEST$/i ) { 
    $tar = ( reverse sort { ( $a =~ /.+?(\d+)/ )[0] <=> ( $b =~ /.+?(\d+)/ )[0] } <../downloads/releases/TWikiKernel-*> )[0];
    # SMELL: kludge to strip the extension (and path) which gets added back in next step
    ( $tar = basename( $tar ) ) =~ s/(\..*?)$//;
}

installTWikiExtension({ file => "../downloads/releases/$tar.zip", name => 'TWiki', dir => "downloads/releases", cdinto => 'twiki', mapDirs => $mapTWikiDirs });

#--------------------------------------------------------------------------------
# update LocalSite.cfg for local directories configuration
print $q->h2( 'LocalSite.cfg' );

my $file = "$mapTWikiDirs->{lib}->{dest}/LocalSite.cfg";
open(FH, ">$file") or die "Can't open $file: $!";
foreach my $localSiteEntry ( qw( DefaultUrlHost ScriptUrlPath ScriptSuffix PubUrlPath PubDir TemplateDir DataDir LogDir ) )
{
    print FH qq{\$cfg{$localSiteEntry} = "$localDirConfig->{$localSiteEntry}";\n};
}
close(FH) or die "Can't close $file: $! ???";

################################################################################
# authentication

print $q->h2( 'Authentication' );

##### UNTESTED!!!!!
if ( 0 ) 
{
    my $bin = $mapTWikiDirs->{bin}->{dest} or die "no bin dest?";
    mv( "$bin/.htaccess.txt $bin/.htaccess" );

    $file = "$bin/.htaccess";
    if ( open(FH, "<$file") )
    {
	my $htaccess = join( "", <FH> );
	close(FH) or warn "Can't close $file: $!";
	
	# change $home to $localConfigDir[...]
	$htaccess =~ s|!FILE_path_to_TWiki!/data|$home/twiki/data|g;	# code smell: duplicated data from config file above
	$htaccess =~ s|!URL_path_to_TWiki!/bin|/cgi-bin/twiki|g;	# ditto
	# TODO: fix ErrorDocument 401 (what should it be set to?)
	
	open( FH, ">$file" ) or die $!;
	print FH $htaccess;
	close( FH ) or die $!;
    }
    else
    {
	warn ".htaccess !!!";
    }
}

#my $data = $mapTWikiDirs->{data}->{dest} or die "no data dir?";
#unlink "$data/TWiki/TWikiRegistration.txt" or warn $!;
#my $reg = "$data/TWiki/TWikiRegistration.txt,v";
#if ( -e $reg ) { unlink $reg or warn $!; }
#mv( "$data/TWiki/TWikiRegistrationPub.txt", "$data/TWiki/TWikiRegistration.txt" ) or warn $!;
#my $pubreg = "$data/TWiki/TWikiRegistrationPub.txt,v";
#if ( -e $pubreg ) { mv( $pubreg, $reg ) or warn $!; }

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

    print $q->h2( $ext );
    my $xmlCatalogue = "../$iType->{dir}/$iType->{xml}";
    warn qq{xml catalogue file "$iType->{xml}" not found}, next unless -e $xmlCatalogue;
    my $xs = new XML::Simple( KeyAttr => 1, AttrIndent => 1 ) or die $!;
    my $xmlExt = $xs->XMLin( $xmlCatalogue, ForceArray => [ $ext ], SuppressEmpty => '' ) or warn "No ${ext}s catalogue: $!";
    my %hExt = map { $_->{name}, $_ } @{$xmlExt->{$ext}};
    foreach my $idExt ( $q->param($ext) )
    {
	my $ExtS = $hExt{$idExt} or warn "no entry for $idExt ?", next;
	my $name = $ExtS->{name} or die "no extension name? wtf?";
	$ExtS->{file} ||= "../$iType->{dir}/$name.zip";
	
	installTWikiExtension({ file => $ExtS->{file}, name => $name, dir => $iType->{dir}, mapDirs => $mapTWikiDirs });
    }
}

################################################################################
# TODO: install plugins dependencies (and/or optional core dependencies)
# MathModePlugin: sudo fink install latex2html (tetex, ...), gd, librsvg
# ImageGalleryPlugin: sudo fink install ImageMagick (...)
# ChartPlugin: sudo fink install gd2 librsvg


################################################################################
#  cleanup / continue links

#print $q->h2( 'Final' );
##### execute( "ls -lR tmp/install" );

rmtree $tmp;

# tighten permissions back up
#chmod 0755, $cgibin;
chmod 0755, "..";
chmod 0755, "$cgibin/lib";

# platform-specific (currently, tho should be able to use "variables" above)
print qq{<hr><hr>\n};
print continueToWikiText();
print "you can perform this installation again using the following URL: <br/>";
# remove the install button so it won't actually start installing until you click "install"
( my $urlInstall = $q->self_url ) =~ s/install=install//;
print qq{<a href="$urlInstall"><tt>$urlInstall</tt></a>\n};

print end_html();

exit 0;

################################################################################

# a handy link to the place to go after the next step
# uses globals: $VIEW $TESTENV
sub continueToWikiText
{
    my $text = '';
    $text .= qq{<a target="details" href="$VIEW/TWiki/InstalledPlugins">proceed to wiki</a><br/>\n};
    $text .= qq{run <a target="details" href="$TESTENV/foo/bar" >testenv</a><br/>\n};
    $text .= qq{<br/><br/>};
}

################################################################################

sub installTWikiExtension
{
    my $p = shift;
    print STDERR "installTWikiExtension: ", Dumper( $p );
    my $file = $p->{file} or die "no twiki extension file specified";
    my $dir = $p->{dir} || ".";
    my $name = $p->{name} || $file;
    my $cdinto = $p->{cdinto} || '.';
    $cdinto .= '/' unless $cdinto =~ m|/$|;	# directory names must be terminated with / for proper regex matching below
    my $mapDirs = $p->{mapDirs} or die "no mapDirs?";

    print $q->h3( "Installing $name" );
    my $archive = Archive::Any->new( $file ) or die "Archive::Any new failed [$file]";
    
    my $INSTALL = "$tmp/INSTALL";
    -d $INSTALL && rmtree $INSTALL;
    mkpath $INSTALL, 1;
    $archive->extract( $INSTALL ) or die $!;
    
    foreach my $file ( $archive->files )
    {
	# no file (just top of archive)
	next if $file eq './';
	# filter out rcs history ,v files (right???)
	next if $file =~ /,v$/;
	# filter out other miscellaneous crap that sometimes appear in plugins releases
	next if $file =~ m/~$/;

#	print STDERR "$file\n";

	if ( my ($cd,$path,$base) = $file =~ m|^($cdinto)?([^/]+)/(.+)?$| )
	# because path isn't optional, this skips over files in the (local) root directory
	# which, i don't think there's supposed to be anything in the root directory to be installed
	{
	    $cd ||= '';
	    $base ||= '/';
	    $base =~ s|^Plugins/|TWiki/| if $path =~ /^(data|pub)$/;	# LEGACY: map data/Plugins -> data/TWiki, pub/Plugins -> pub/TWiki

	    my $map = $mapDirs->{$path} or warn "no mapping for [$path]", next;
	    my $dirDest = $map->{dest} or die "no destination directory for [$path] " . Dumper( $map );

	    # handle directories (path ends with /?, if so, create (relative) mirror directory structure)
	    if ( $base =~ m|/$| )
	    {
		my $dir = "$dirDest/$base";
		-e $dir || mkpath( $dir );
		next;
	    }

	    # handle regular files
	    print "$path/$base <br />\n";
	    my $destFile = "$dirDest/$base";

	    # KLUDGEy implementation to support scriptSuffix
#	    print STDERR "path=[$path] INSTALL=[$INSTALL] file=[$file] dirDest=[$dirDest] base=[$base] scriptSuffix=[$localDirConfig->{ScriptSuffix}]\n";
	    if ( $path eq 'bin' && $base !~ /\./ )
	    {
		$destFile .= $localDirConfig->{ScriptSuffix};
		mv( "$INSTALL/$file", $destFile ) or die "$file -> $destFile: $!";
		# patch perl path for local installation
		my $bin = read_file( $destFile ) or warn "unable to change perl path on $destFile: $!";
		$bin =~ s|/usr/bin/perl|$PERL|;
		$bin && write_file( $destFile, $bin ) or warn "unable to change perl path on $destFile: $!";
	    }
	    else
	    {
		mv( "$INSTALL/$file", $destFile ) or die "$file -> $destFile: $!";
	    }
	    $map->{perms} && chmod $map->{perms}, $destFile;
	}
	else
	{
	    warn qq{don't know what to do with: "$file"\n};
	}
    }

    # TODO: run an standard-named install script (if included)
#    my $installer = $name . '_installer.pl';
#    print "<b>$installer</b><br/>\n";
#    eval { execute( "cd tmp/install ; perl $installer" ) if -e $installer };  # -a doesn't prompt
#    print "installer error: $@, ($!)\n" if $@;

    # TODO: assert( isDirectoryEmpty( $INSTALL ) );
    rmtree $INSTALL;
}

################################################################################
################################################################################
sub installationMenu
{
    my $q = shift or die "no cgi?";
    my $text = '';

    my $title = "TWiki Installation (Step 2/3)";
    $text .= $q->header();
    $text .= $q->start_html( 
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
.disabled { background-color:#cccccc; } \
.error { color:red; font-weight:bold; } \
" },
	);
    $text .= <<'__HTML__';
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

################################################################################
# SERVER SETTINGS
#<b>hostname</b>: <input type="text" size="25" name="hostname" value="$hostname" /><br />
$text .= <<__HTML__;
<h2>Server Settings</h2>
<b>perl</b> (full path): <input type="text" size="25" name="PERL" value="$PERL" /><br />
<small><small>may also be the name of a perl accelerator, e.g,. <a target="details" href="http://www.daemoninc.com/SpeedyCGI/">SpeedyCGI</a></small></small><br />
<b>cgi extension</b>: <input type="text" size="6" name="scriptsuffix" value="$localDirConfig->{ScriptSuffix}" /><br />
__HTML__

################################################################################
# KERNELS
    if ( $q->param( 'install' ) ) {
	$text .= $q->br() . q{<div class="error">} . $q->b( 'You need to select a ' . 
		$q->a( { -href=>'http://twiki.org/cgi-bin/view/Codev/TWikiKernel?skin=print.pattern', -target=>'details' }, 'TWikiKernel' )) .
		q{</div>};
    }
    my %kernels = ( dir => "../downloads/releases/", xml => "releases.xml", type => "kernel" );
    releasesCatalogue({ %kernels, cgi => $q });
    $text .= catalogue({ %kernels, inputType => "radio", title => "TWikiKernel", cgi => $q });

################################################################################
# PRECONFIGURATIONS
    $text .= preconfigurations();

################################################################################
# EXTENSIONS
    $text .= catalogue({ dir => "../downloads/contribs/", xml => "contribs.xml", title => "Contribs", type => "contrib", cgi => $q });
    $text .= catalogue({ dir => "../downloads/plugins/", xml => "plugins.xml", title => "Plugins", type => "plugin", cgi => $q });
    $text .= catalogue({ dir => "../downloads/addons/", xml => "addons.xml", title => "AddOns", type => "addon", cgi => $q });
#    $text .= catalogue({ dir => "../downloads/skins/", xml => "skins.xml", title => "Skins", type => "skin", cgi => $q });
#    $text .= catalogue({ dir => "../downloads/patches/", xml => "patches.xml", title => "Patches", type => "patch", cgi => $q });
#    $text .= catalogue({ dir => "../downloads/webs/", xml => "webs.xml", title => "Web Templates", type => "web", cgi => $q });

################################################################################
# WEBS
    my %systemWikis = ( dir => "../downloads/webs/system/", xml => "systemwebs.xml", type => "systemweb" );
    wikiCatalogue({ %systemWikis, cgi => $q });
    $text .= catalogue({ %systemWikis, title => "System Wiki Webs (Updates)", cgi => $q });

    my %localWikis = ( dir => "../webs/local/", xml => "localwebs.xml", type => "localweb" );
    wikiCatalogue({ %localWikis, cgi => $q });
    $text .= catalogue({ %localWikis, title => "Local Wiki Webs", cgi => $q });

    $text .= <<__HTML__;
</form>
</body>
</html>
__HTML__

    return $text;
}

################################################################################
# PRECONFIGURATIONS
################################################################################
sub preconfigurations
{
    my $releaseTracker = ";contrib=DistributionContrib;plugin=TWikiReleaseTrackerPlugin";

#plugin=CommentPlugin;plugin=SectionalEditPlugin
#plugin=CalendarPlugin or plugin=QuickCalendarPlugin
#addon=CompareRevisionsAddOn - waiting until TWiki:Codev....InsDelTags... fixed

    my $bare = ";";
    my $baseWiki = ";plugin=InterwikiPlugin;plugin=FindElsewherePlugin;plugin=SpacedWikiWordPlugin;plugin=SpreadSheetPlugin;plugin=TablePlugin;addon=GetAWebAddOn;plugin=SmiliesPlugin;plugin=SessionPlugin";
    my $level2Wiki = $baseWiki . $releaseTracker . ";plugin=SlideShowPlugin;plugin=TocPlugin;plugin=RandomTopicPlugin";
    my $publicWiki = $level2Wiki . ";plugin=BlackListPlugin";
    my $level3Wiki = $level2Wiki . ";plugin=InterwikiPlugin;contrib=AttrsContrib;plugin=ImageGalleryPlugin";
    #plugin=BatchPlugin (esp. handy with ImageGallery (but i haven't tested it))
    my $appWiki = $level3Wiki . ";plugin=FormQueryPlugin;plugin=MacrosPlugin";

    my $softwareDevWiki = $level3Wiki . ";plugin=BeautifierPlugin;plugin=MathModePlugin;plugin=PerlDocPlugin";

    return <<__HTML__;
<h2>Preconfigurations</h2>
Configuration <a href="?$bare">Bare</a><br/>
Configuration <a href="?$baseWiki">Lean and Mean Wiki</a><br/>
Configuration <a href="?$appWiki">Application Base Wiki</a><br/>
Configuration <a href="?$softwareDevWiki">Software Development Wiki</a><br/>
Configuration <a href="?$level3Wiki">Personal Wiki</a><br/>
Configuration <a href="?$publicWiki">Community Wiki</a><br/>
__HTML__
}

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
    $p->{dir} ||= $tmp;
    die unless $p->{dir} && $p->{xml} && $p->{list} && $p->{type};

    my $xs = new XML::Simple() or die $!;
    my $xml = "$p->{dir}/$p->{xml}";
    open( XML, ">$xml" ) or die qq{$!: Can't write xml to "$xml"\n};
    print XML $xs->XMLout( { $p->{type} => $p->{list} }, NoAttr => 1 );
    close( XML ) or warn $!;
}

################################################################################

sub wikiCatalogue
{
    my $p = shift;
    $p->{fileFilter} = qr/\.wiki\.tar\.gz$/;
    $p->{list} = _dirCatalogue( $p );
    $p->{dir} = $tmp;
    SaveXML( $p ) if @{$p->{list}};
}

################################################################################

sub releasesCatalogue
{
    my $p = shift;
    $p->{fileFilter} = qr/\.zip$/;
    if ( $p->{list} = [ reverse sort { $a->{name} cmp $b->{name} } @{_dirCatalogue( $p )} ] )
    {
    	foreach my $release ( @{$p->{list}} )
	{
	    my $rel = $release->{name};
	    my ( $label, undef, $branch, $revInfo ) = $rel =~ m/TWiki(Kernel)?(-([^-]+)-)?(.+)?/;
	    $label ||= '';
	    $branch ||= '';
	    warn "$release: $rel doesn't match?", next unless $revInfo;
	    print STDERR "label=[$label], branch=[$branch], revInfo=[$revInfo]\n";

	    $release->{homepage} ||= "http://twiki.org/cgi-bin/view/Codev/TWiki$label$branch$revInfo";

	    $release->{description} = "TWiki$label Release";
	    $release->{description} .= " $branch" if $branch;
	    if ( $revInfo !~ /^(\d+)$/ )
	    {
		$release->{description} .= " $revInfo";
	    }
	    else
	    {
		if ( $label )	# Kernel
		{
		    $release->{description} .= " SVN r$1";
		}
		else
		{
		    my ( $year, $month, $day, undef, $hour, $min, $sec ) = $revInfo =~ /(\d{4})(\d{2})(\d{2})(\.(\d{2})(\d{2})(\d{2}))?/;
		    my @month = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
		    $release->{description} .= " $day $month[$month-1] $year";
		    $release->{description} .= " ${hour}:${min}.${sec}" if ( $rel =~ /\./ );	# <date>.<time> format
		}
	    }
	}

	$p->{dir} = $tmp;
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

    my $xmlCatalogue = "$p->{dir}/$p->{xml}";
    -e $xmlCatalogue or $xmlCatalogue = "$tmp/$p->{xml}";
#    warn Dumper( $p ) unless -e $xmlCatalogue;
    if ( -e $xmlCatalogue )
    {
	my $xs = new XML::Simple( KeyAttr => 1, AttrIndent => 1 ) or die $!;
	my $xmlCatalogue = $xs->XMLin( $xmlCatalogue, ForceArray => [ $p->{type} ], SuppressEmpty => '' ) or warn qq{No xml catalogue "$p->{xml}": $!};

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
	    $aAttr->{href} = "$extInstall->{homepage}?skin=print.pattern" if $extInstall->{homepage};

	    $extInstall->{file} ||= "$p->{dir}/$extInstall->{name}.zip";

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

__DATA__
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


