#! /usr/bin/perl -w
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

use Cwd qw( cwd );
use File::Copy qw( cp );
use File::Path qw( rmtree );
use File::Find::Rule;
use File::Slurp::Tree;
#use File::Spec::Functions qw( abs2rel rel2abs );
#use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use LWP::UserAgent;
#use Error;

################################################################################
{
    package TWikiGuestAgent;
    our @ISA = qw(LWP::UserAgent);
    sub new			{ my $self = LWP::UserAgent::new(@_); $self->agent("TWikiKernel Builder/0.5"); $self; }
    sub get_basic_credentials	{ qw( TWikiGuest guest ) }
}

################################################################################

# commonly-used File::Find::Rule rules
my $discardSVN = File::Find::Rule->directory
    ->name(".svn")
    ->prune          # don't go into it
    ->discard;       # don't report it
my $all = File::Find::Rule->file;

my $installBase = cwd() . "/twiki";

################################################################################

( rmtree( $installBase ) or die $! ) if -e $installBase;
my $tar = 'TWiki20040901.tar.gz';
unless ( -e $tar )
{
    my $ua = TWikiGuestAgent->new or die $!;
    my $status = $ua->mirror( "http://twiki.org/release/$tar", $tar );
    # TODO: check for error
#    print Dumper( $status );
#    execute( "wget --http-user=TWikiGuest --http-passwd=guest -O $tar http://twiki.org/release/$tar" ) unless -e $tar;
}
execute( "tar xzf $tar" ) or die $!;
print scalar File::Find::Rule->file->in( 'twiki' ), " original files\n";

################################################################################

my $pwdStart = cwd();
chdir( '../..' ) or die $!;

#-[bin]-------------------------------------------------------------------------------
##my @bin = qw( attach changes edit geturl installpasswd mailnotify manage oops passwd preview rdiff rdiffauth
##	      register rename save search setlib.cfg statistics testenv upload view viewauth viewfile );
rmtree "$installBase/bin" or die $!;
my $treeBin = slurp_tree( 'bin', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'bin' ) );
spew_tree( "$installBase/bin" => $treeBin );

# create authorization required version of some scripts
foreach my $auth qw( rdiff view )
{
    cp( $_ = "$installBase/bin/$auth", "${_}auth" ) or warn "$auth: $!";
}
# ??? execute( "chmod a+rx,o+w $bin/*" );

#-[lib]-------------------------------------------------------------------------------
rmtree "$installBase/lib" or die $!;
my $treeLib = slurp_tree( 'lib', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'lib' ) );
spew_tree( "$installBase/lib" => $treeLib );

#-[templates]-------------------------------------------------------------------------------
rmtree "$installBase/templates" or die $!;
my $treeTemplates = slurp_tree( 'templates', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'templates' ) );
spew_tree( "$installBase/templates" => $treeTemplates );

#-[data]-------------------------------------------------------------------------------
{ my $dir = 'data';
rmtree "$installBase/$dir" or die $!;
my $tree = slurp_tree( $dir, rule => File::Find::Rule->or( $discardSVN, $all )->start( $dir ) );
spew_tree( "$installBase/$dir" => $tree ); }

#-[pub]-------------------------------------------------------------------------------
{ 
rmtree "$installBase/pub/Main/" or warn "Main: $!";
rmtree "$installBase/pub/Sandbox/" or warn "Sandbox; $!";
rmtree "$installBase/pub/Trash/" or warn "Trash: $!";

my $dir = 'pub/TWiki';
rmtree "$installBase/$dir" or die $!;
my $tree = slurp_tree( $dir, rule => File::Find::Rule->or( $discardSVN, $all )->start( $dir ) );
spew_tree( "$installBase/$dir" => $tree ); 
}

################################################################################
# some cleanup
rmtree( "$installBase/lib/Algorithm" ) or warn $!;
rmtree( "$installBase/lib/Text" ) or warn $!;
# ??? what else?

################################################################################

chdir $pwdStart;
print scalar File::Find::Rule->file->in( 'twiki' ), " new files\n";

################################################################################
# create TWikiKernel distribution file
chomp( my $now = `date +'%Y%m%d.%H%M%S'` );
chomp( my $branch = `head -n 1 branch` || 'MAIN' );
my $newDistro = "TWikiKernel-$branch-$now";
execute( "tar czf $newDistro.tar.gz twiki" );	# .tar.gz goes *here* because *z* is here

exit 0;

################################################################################
################################################################################

sub execute 
{
    my ($cmd) = @_;

    chomp( my @output = `$cmd` );
    my $error = $?;

    print "$error: $cmd\n";
    print join( "\n", @output );
}

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

================================================================================
# not assembled (yet) by build-twiki-kernel.pl; uses files from TWiki20040901.tar.gz

1352 -rw-r--r--    1 twiki  twiki  692162 31 Aug 12:35 TWikiDocumentation.html
 248 -rw-r--r--    1 twiki  twiki  123154 31 Aug 12:35 TWikiHistory.html
  24 -rwxr-xr-x    1 twiki  twiki   10283 21 Aug 18:35 UpgradeTwiki*
   8 -rw-r--r--    1 twiki  twiki     837 30 Aug 03:02 index.html
  40 -rw-r--r--    1 twiki  twiki   19696 30 Aug 02:52 license.txt
   8 -rw-r--r--    1 twiki  twiki     475 29 May 02:51 pub-htaccess.txt
  16 -rw-r--r--    1 twiki  twiki    4516 31 Aug 12:35 readme.txt
   8 -rw-r--r--    1 twiki  twiki     564 30 Aug 02:37 robots.txt
   8 -rw-r--r--    1 twiki  twiki     554 29 May 02:51 root-htaccess.txt
   8 -rw-r--r--    1 twiki  twiki     516 29 May 02:51 subdir-htaccess.txt

/pub
   * icn/_filetypes.txt, icn/*.gif
   * favicon.ico [blasted robot]
   * wikiHome.gif [blasted robot]

################################################################################
################################################################################
differences between output of build-twiki-kernel.pl vs. TWiki20040901.tar.gz
(not including the ,v files list)

672c363
>           'pub/TWiki/PatternSkin/empty.css',		# need to add empty.css to topic text attachment
1021,1022c478
>           'templates/.cvsignore',

################################################################################
# new code
492a285,287
>           'lib/TWiki/Templates.pm',

################################################################################
# old code / to get from cpan
480,481d272
<           'lib/Algorithm/Diff.pm',
<           'lib/Text/Diff.pm',

################################################################################
# new test cases
>           'data/TestCases/FixtureIncludedTopic.txt',
>           'data/TestCases/TestCaseAutoFormatting.txt',
>           'data/TestCases/TestCaseAutoInternalTags.txt',
>           'data/TestCases/TestCaseAutoUnexpandedTagsInSearchResults.txt',
>           'data/TestCases/TestCaseChangePassword.txt',
>           'data/TestCases/TestCaseDifferentSkin.txt',
>           'data/TestCases/TestCaseEmbeddedTags.txt',
>           'data/TestCases/TestCaseInternalTags.txt',
>           'data/TestCases/TestCaseIntranetRegistration.txt',
>           'data/TestCases/TestCaseNestedVerbatim.txt',
>           'data/TestCases/TestCaseTemplate.txt',
>           'data/TestCases/TestCaseTopicListTag.txt',
>           'data/TestCases/TestCaseWebListTag.txt',
>           'data/TestCases/WebHome.txt',
>           'data/TestCases/WebLeftBar.txt',
>           'data/TestCases/WebPreferences.txt',

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
