#! /usr/bin/perl -w
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

use Cwd qw( cwd );
use File::Copy qw( cp );
use File::Path qw( rmtree mkpath );
use File::Spec::Functions qw( rel2abs );
use File::Find::Rule;
use File::Slurp::Tree;
use LWP::UserAgent;
use Getopt::Long;
use Pod::Usage;
use LWP::UserAgent::TWiki::TWikiGuest;

my $Config = {
# 
    tempdir => '.',
    outputdir => '.',
    # change to out|file
    agent => "TWikiKernel Builder/v0.6",
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
			'localcache=s', 'tempdir=s', 'outputdir=s',
# miscellaneous/generic options
			'agent=s', 'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print Dumper( $Config ) if $Config->{verbose};
	 
# TODO: use Getopt to process these (learn how to do this), er, maybe not?
map { checkdirs( $Config->{$_} = rel2abs( $Config->{$_} ) ) } qw( tempdir outputdir );

$Config->{localcache} = $Config->{tempdir} . "/.cache";
$Config->{install_base} = $Config->{tempdir} . "/twiki";		# the directory the official release is untarred into
map { ( mkpath $Config->{$_} or die $! ) unless -d $Config->{$_} } qw( localcache install_base );

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
my $ruleDiscardSVN = File::Find::Rule->directory->name(".svn")->prune->discard;
my $ruleNormalFiles = File::Find::Rule->or( $ruleDiscardSVN, $ruleDiscardBackup, File::Find::Rule->file );

################################################################################

my $installBase = $Config->{install_base};
( rmtree( $installBase ) or die "Unable to empty the twiki build directory: $!" ) if -e $installBase;
mkpath( $installBase ) or die "Unable to create the new build directory: $!";

################################################################################

my $pwdStart = cwd();
chdir( '../..' ) or die $!;		# from tools/distro up to BRANCH (eg, trunk, DEVELOP)

################################################################################
#-[lib/, templates/, data/, pub/icn, pub/TWiki, bin/]-----------------------------------
foreach my $dir qw( lib templates data bin pub )
{
    my $tree = slurp_tree( $dir, rule => $ruleNormalFiles->start( $dir ) );
    spew_tree( "$installBase/$dir" => $tree );
}

#-[docs]-------------------------------------------------------------------------------
map { my $doc = $_; cp( $doc, "$installBase/$doc" ) or warn "$doc: $!" }
qw (
      pub-htaccess.txt root-htaccess.txt subdir-htaccess.txt robots.txt
      index.html readme.txt license.txt
      UpgradeTwiki
    );

my $ua = LWP::UserAgent::TWiki::TWikiGuest->new( agent => $Config->{agent} ) or die $!;
foreach my $doc qw( TWikiDocumentation TWikiHistory )
{
    my $destDoc = "$Config->{localcache}/${doc}.html";
    # TODO: issue: doesn't mirror the css or bullet image; however, page will display properly if connected to the internet (and thus, twiki.org); page still displays *legibly* if not connected ( no pretty styles, tho :( )
    $ua->mirror( "http://twiki.org/cgi-bin/view/TWiki/$doc", $destDoc ) or warn "$doc: $!";
    cp( $destDoc, "$installBase/${doc}.html" ) or die "$destDoc: $!";
}


#[ POST ]-------------------------------------------------------------------------------
# bin/ additional post processing: create authorization required version of some scripts
foreach my $auth qw( rdiff view )
{
    cp( $_ = "$installBase/bin/$auth", "${_}auth" ) or warn "$auth: $!";
}
# ??? execute( "chmod a+rx,o+w $bin/*" ); (er, add this to spew_tree or slurp_tree or File::Find::Rule...)
#my @bin = qw( attach changes edit geturl installpasswd mailnotify manage oops passwd preview rdiff rdiffauth register rename save search setlib.cfg statistics testenv upload view viewauth viewfile );

# stop distributing cpan modules; get the latest versions from cpan itself
rmtree( [ "$installBase/lib/Algorithm", "$installBase/lib/Text" ] ) or warn $!;

################################################################################

chdir $pwdStart;
if ( $Config->{verbose} ) { print scalar File::Find::Rule->file->in( $installBase ), " new files\n" }

################################################################################
# create TWikiKernel distribution file
chomp( my $now = `date +'%Y%m%d.%H%M%S'` );
chomp( my $branch = `head -n 1 branch` || 'MAIN' );
my $newFile = "TWikiKernel-$branch-$now";
my $newDistro = "$Config->{outputdir}/$newFile";
execute( "cd $Config->{tempdir} ; tar czf ${newDistro}.tar.gz twiki" ) or die $!;	# .tar.gz goes *here* because *z* is here
print "${newDistro}.tar.gz\n";			# print name of generated file; other tools later in the chain use it

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

build-twiki-kernel.pl [options] [-tempdir=] [-outputdir=] [-agent=]

Copyright 2004 Will Norris and Sven Dowideit.  All Rights Reserved.

 Options:
   -tempdir=[.]		where all temporary files for this build are placed
   -outputdir=[.]	where the generated TWikiKernel-BRANCH-DATE.tar.gz is placed
   -agent=[$Config->{agent}]	LWP::UserAgent name (used for downloading some documentation from wiki pages on twiki.org)
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-tempdir>

=item B<-outputdir>

=item B<-agent>

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

__END__
################################################################################
# from source control and/or automated 

[X] /bin (SVN)

[X] /lib (on down, from SVN)

[x] /templates (SVN)

[x] /data (SVN)
   * Main/, Sandbox/, TWiki/, Trash/, _default/ (SVN); also TestWeb/
   * .htpasswd (SVN; added to DEVELOP)
   * mime.types (SVN; added to DEVELOP)
   * delete debug.txt, warning.txt (deletes whole data/ tree from .tar.gz now)

/pub
   * TWiki/ (SVN)
   * Main/, Sandbox/, Trash/, <strike>_default/</strike> (empty; deleted by build-twiki-kernel.pl)
   * icn/_filetypes.txt, icn/*.gif (SVN)
   * wikiHome.gif (changed to TWiki BGCOLOR)
   * favicon.ico (changed to TWiki BGCOLOR; moved to pub/TWiki/WebPreferences)

/
   8 -rw-r--r--    1 twiki  twiki     475 29 May 02:51 pub-htaccess.txt (SVN)
   8 -rw-r--r--    1 twiki  twiki     564 30 Aug 02:37 robots.txt (SVN)
   8 -rw-r--r--    1 twiki  twiki     554 29 May 02:51 root-htaccess.txt (SVN)
   8 -rw-r--r--    1 twiki  twiki     516 29 May 02:51 subdir-htaccess.txt (SVN)
  24 -rwxr-xr-x    1 twiki  twiki   10283 21 Aug 18:35 UpgradeTwiki* (SVN)
1352 -rw-r--r--    1 twiki  twiki  692162 31 Aug 12:35 TWikiDocumentation.html (mirrored from twiki.org)
 248 -rw-r--r--    1 twiki  twiki  123154 31 Aug 12:35 TWikiHistory.html (mirrored from twiki.org)
(these need updating)
   8 -rw-r--r--    1 twiki  twiki     837 30 Aug 03:02 index.html (SVN) - doesn't look very good (at all!) really needs upating
  16 -rw-r--r--    1 twiki  twiki    4516 31 Aug 12:35 readme.txt (SVN) - needs editting, customising per build (type, etc.)
  40 -rw-r--r--    1 twiki  twiki   19696 30 Aug 02:52 license.txt (SVN) - use confused with (re-)distribution
 
================================================================================
# not assembled (yet) by build-twiki-kernel.pl; uses files from TWiki20040901.tar.gz
# THESE FILES HAVE "ISSUES"

/pub/TWiki/TWikiLogos
   * Codev.TWikiLogosDropInReplacements - hm, actually, i'm not sure sure now...


################################################################################
################################################################################
differences between output of build-twiki-kernel.pl vs. TWiki20040901.tar.gz
(not including the ,v files list)

672c363
>           'pub/TWiki/PatternSkin/empty.css',		# need to add empty.css to topic text attachment
1021,1022c478
>           'templates/.cvsignore',

################################################################################
# old code / to get from cpan
480,481d272
<           'lib/Algorithm/Diff.pm',
<           'lib/Text/Diff.pm',

################################################################################
# new code
492a285,287
>           'lib/TWiki/Templates.pm',

################################################################################
# added new test cases: data/TestCases/*, pub/TestCases/*

################################################################################
################################################################################

################################################################################
# empty and/or junk files recreated at runtime
37d37
<           'data/debug.txt',
39,41d38
<           'data/warning.txt',
<           'data/_default/.changes',
<           'data/_default/.mailnotify',
63,65d49
<           'data/Main/.changes',
<           'data/Main/.mailnotify',
115,117d74
<           'data/Sandbox/.changes',
<           'data/Sandbox/.mailnotify',
139,141c86,101
<           'data/Trash/.changes',
<           'data/Trash/.mailnotify',
163,165d112
<           'data/TWiki/.changes',
<           'data/TWiki/.mailnotify',

################################################################################
# preinstalled plugins/skin
495d289
<           'lib/TWiki/Plugins/CommentPlugin.pm',
497d290
<           'lib/TWiki/Plugins/EditTablePlugin.pm',
500,509c293,296
<           'lib/TWiki/Plugins/RenderListPlugin.pm',
<           'lib/TWiki/Plugins/SlideShowPlugin.pm',
<           'lib/TWiki/Plugins/SmiliesPlugin.pm',
<           'lib/TWiki/Plugins/SpreadSheetPlugin.pm',
<           'lib/TWiki/Plugins/TablePlugin.pm',
<           'lib/TWiki/Plugins/CommentPlugin/Attrs.pm',
<           'lib/TWiki/Plugins/CommentPlugin/build.pl',
<           'lib/TWiki/Plugins/CommentPlugin/Comment.pm',
<           'lib/TWiki/Plugins/CommentPlugin/Templates.pm',
<           'lib/TWiki/Plugins/CommentPlugin/test.zip',
---
>           'lib/TWiki/Plugins/TestFixturePlugin.pm',
>           'lib/TWiki/Prefs/Parser.pm',
>           'lib/TWiki/Prefs/PrefsCache.pm',
>           'lib/TWiki/Prefs/TopicPrefs.pm',
579,669d360
<           'pub/TWiki/DragonSkin/fullscreen.gif',
<           'pub/TWiki/DragonSkin/gray.theme.css',
<           'pub/TWiki/DragonSkin/monochrome.theme.css',
<           'pub/TWiki/DragonSkin/screenshot.gif',
<           'pub/TWiki/DragonSkin/spacer.gif',
<           'pub/TWiki/DragonSkin/tabstyle.theme.css',
<           'pub/TWiki/DragonSkin/typography.css',
<           'pub/TWiki/EditTablePlugin/calendar-af.js',
<           'pub/TWiki/EditTablePlugin/calendar-br.js',
<           'pub/TWiki/EditTablePlugin/calendar-ca.js',
<           'pub/TWiki/EditTablePlugin/calendar-cs-win.js',
<           'pub/TWiki/EditTablePlugin/calendar-da.js',
<           'pub/TWiki/EditTablePlugin/calendar-de.js',
<           'pub/TWiki/EditTablePlugin/calendar-du.js',
<           'pub/TWiki/EditTablePlugin/calendar-el.js',
<           'pub/TWiki/EditTablePlugin/calendar-en.js',
<           'pub/TWiki/EditTablePlugin/calendar-es.js',
<           'pub/TWiki/EditTablePlugin/calendar-fr.js',
<           'pub/TWiki/EditTablePlugin/calendar-hr-utf8.js',
<           'pub/TWiki/EditTablePlugin/calendar-hr.js',
<           'pub/TWiki/EditTablePlugin/calendar-hu.js',
<           'pub/TWiki/EditTablePlugin/calendar-it.js',
<           'pub/TWiki/EditTablePlugin/calendar-jp.js',
<           'pub/TWiki/EditTablePlugin/calendar-nl.js',
<           'pub/TWiki/EditTablePlugin/calendar-no.js',
<           'pub/TWiki/EditTablePlugin/calendar-pl.js',
<           'pub/TWiki/EditTablePlugin/calendar-pt.js',
<           'pub/TWiki/EditTablePlugin/calendar-ro.js',
<           'pub/TWiki/EditTablePlugin/calendar-ru.js',
<           'pub/TWiki/EditTablePlugin/calendar-setup.js',
<           'pub/TWiki/EditTablePlugin/calendar-sk.js',
<           'pub/TWiki/EditTablePlugin/calendar-sp.js',
<           'pub/TWiki/EditTablePlugin/calendar-sv.js',
<           'pub/TWiki/EditTablePlugin/calendar-system.css',
<           'pub/TWiki/EditTablePlugin/calendar-tr.js',
<           'pub/TWiki/EditTablePlugin/calendar-zh.js',
<           'pub/TWiki/EditTablePlugin/calendar.js',
<           'pub/TWiki/EditTablePlugin/edittable.gif',
<           'pub/TWiki/EditTablePlugin/EditTablePluginCalendarExample.gif',
<           'pub/TWiki/EditTablePlugin/img.gif',
<           'pub/TWiki/EditTablePlugin/menuarrow.gif',
<           'pub/TWiki/EditTablePlugin/README',
<           'pub/TWiki/EditTablePlugin/release-notes.html',
<           'pub/TWiki/EditTablePlugin/ScreenshotEditCell1.gif',
<           'pub/TWiki/EditTablePlugin/ScreenshotEditCell2.gif',
707,817d382
<           'pub/TWiki/RenderListPlugin/doc.gif',
<           'pub/TWiki/RenderListPlugin/dot_ud.gif',
<           'pub/TWiki/RenderListPlugin/dot_udr.gif',
<           'pub/TWiki/RenderListPlugin/dot_ur.gif',
<           'pub/TWiki/RenderListPlugin/email.gif',
<           'pub/TWiki/RenderListPlugin/empty.gif',
<           'pub/TWiki/RenderListPlugin/file.gif',
<           'pub/TWiki/RenderListPlugin/folder.gif',
<           'pub/TWiki/RenderListPlugin/globe.gif',
<           'pub/TWiki/RenderListPlugin/group.gif',
<           'pub/TWiki/RenderListPlugin/home.gif',
<           'pub/TWiki/RenderListPlugin/image.gif',
<           'pub/TWiki/RenderListPlugin/pdf.gif',
<           'pub/TWiki/RenderListPlugin/person.gif',
<           'pub/TWiki/RenderListPlugin/persons.gif',
<           'pub/TWiki/RenderListPlugin/ppt.gif',
<           'pub/TWiki/RenderListPlugin/see.gif',
<           'pub/TWiki/RenderListPlugin/sound.gif',
<           'pub/TWiki/RenderListPlugin/trend.gif',
<           'pub/TWiki/RenderListPlugin/virtualhome.gif',
<           'pub/TWiki/RenderListPlugin/virtualperson.gif',
<           'pub/TWiki/RenderListPlugin/virtualpersons.gif',
<           'pub/TWiki/RenderListPlugin/xls.gif',
<           'pub/TWiki/RenderListPlugin/zip.gif',
<           'pub/TWiki/SlideShowPlugin/clearpixel.gif',
<           'pub/TWiki/SlideShowPlugin/endpres.gif',
<           'pub/TWiki/SlideShowPlugin/first.gif',
<           'pub/TWiki/SlideShowPlugin/last.gif',
<           'pub/TWiki/SlideShowPlugin/logo.gif',
<           'pub/TWiki/SlideShowPlugin/next.gif',
<           'pub/TWiki/SlideShowPlugin/prev.gif',
<           'pub/TWiki/SlideShowPlugin/startpres.gif',
<           'pub/TWiki/SmiliesPlugin/biggrin.gif',
<           'pub/TWiki/SmiliesPlugin/confused.gif',
<           'pub/TWiki/SmiliesPlugin/cool.gif',
<           'pub/TWiki/SmiliesPlugin/devil.gif',
<           'pub/TWiki/SmiliesPlugin/devilwink.gif',
<           'pub/TWiki/SmiliesPlugin/eek.gif',
<           'pub/TWiki/SmiliesPlugin/frown.gif',
<           'pub/TWiki/SmiliesPlugin/indifferent.gif',
<           'pub/TWiki/SmiliesPlugin/love.gif',
<           'pub/TWiki/SmiliesPlugin/mad.gif',
<           'pub/TWiki/SmiliesPlugin/no.gif',
<           'pub/TWiki/SmiliesPlugin/redface.gif',
<           'pub/TWiki/SmiliesPlugin/rolleyes.gif',
<           'pub/TWiki/SmiliesPlugin/scull.gif',
<           'pub/TWiki/SmiliesPlugin/sealed.gif',
<           'pub/TWiki/SmiliesPlugin/smile.gif',
<           'pub/TWiki/SmiliesPlugin/thumbs.gif',
<           'pub/TWiki/SmiliesPlugin/tongue.gif',
<           'pub/TWiki/SmiliesPlugin/wink.gif',
<           'pub/TWiki/SmiliesPlugin/yes.gif',
<           'pub/TWiki/TablePlugin/diamond.gif',
<           'pub/TWiki/TablePlugin/down.gif',
<           'pub/TWiki/TablePlugin/up.gif',
1001,1015d474
<           'pub/TWiki/TWikiLogos/twikilogo88x31.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot121x54.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot121x54a.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot131x64.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot46x50.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot81x119.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot88x31.gif',
1021,1022c478
<           'templates/attach.dragon.tmpl',
1031d486
<           'templates/changeform.dragon.tmpl',
1034d488
<           'templates/changes.dragon.tmpl',
1037,1040d490
<           'templates/comments.tmpl',
<           'templates/dragoncssvars.dragon.tmpl',
<           'templates/dragonmenu.dragon.tmpl',
<           'templates/edit.dragon.tmpl',
1045d494
<           'templates/moveattachment.dragon.tmpl',
1092d540
<           'templates/preview.dragon.tmpl',
1095d542
<           'templates/rdiff.dragon.tmpl',
1102d548
<           'templates/renamebase.dragon.tmpl',
1111d556
<           'templates/search.dragon.tmpl',
1114d558
<           'templates/searchbookview.dragon.tmpl',
1117d560
<           'templates/searchformat.dragon.tmpl',
1122d564
<           'templates/searchrenameview.dragon.tmpl',
1125d566
<           'templates/twiki.dragon.tmpl',
1128d568
<           'templates/view.dragon.tmpl',


wikiHome.gif references:
========================
wbniv:~/twiki/DEVELOP/tools/distro/yyy wbniv$ grep -r wikiHome.gif * | grep -v ,v
twiki/bin/testenv:print "$pubUrlPath/wikiHome.gif image below is broken:<br />";
twiki/bin/testenv:print "<img src=\"$pubUrlPath/wikiHome.gif\" />";
twiki/bin/testenv:if( ! ( -e "$pubDir/wikiHome.gif" ) ) {
twiki/bin/testenv:    print "Directory does not exist or file <tt>wikiHome.gif</tt> does not exist in this directory.";
twiki/data/TWiki/AppendixFileSystem.txt:| =wikiHome.gif= | GIF file |
twiki/data/TWiki/AppendixFileSystem.txt:-rw-rw-r--       1 twiki        twiki             2877 Jun  7  1999 wikiHome.gif
twiki/data/TWiki/TWikiTemplates.txt:            &lt;img src="%<nop>PUBURLPATH%/wikiHome.gif" border="0"&gt;&lt;/a&gt;
twiki/data/TWiki/TWikiUpgradeTo01Feb2003.txt:                   * Replace img tag's =src=%<nop>PUBURLPATH%/wikiHome.gif= with =src=%<nop>WIKILOGOIMG%=
twiki/TWikiDocumentation.html:      &lt;img src="%PUBURLPATH%/wikiHome.gif" border="0"&gt;&lt;/a&gt;
twiki/TWikiDocumentation.html:<tr><td>  <code>wikiHome.gif</code>  </td><td>  GIF file  </td></tr>
twiki/TWikiDocumentation.html:-rw-rw-r--    1 twiki   twiki        2877 Jun  7  1999 wikiHome.gif
