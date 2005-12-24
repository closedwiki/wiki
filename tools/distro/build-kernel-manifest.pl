#! /usr/bin/perl -w
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

BEGIN {
    my $dirHome = $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7];
    $ENV{TWIKIDEV} ||= "$dirHome/twiki";
    eval qq{ use lib( "$ENV{TWIKIDEV}/CPAN/lib/", "$ENV{TWIKIDEV}/CPAN/lib/arch/" ) };
}

use Cwd qw( cwd );
use File::Find::Rule;
use Getopt::Long;
use Pod::Usage;
use ManifestEntry;

my @manifestEntries;

my $Config = {
# 
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

my $result = GetOptions( $Config,
# miscellaneous/generic options
			'agent=s', 'help', 'man', 'debug', 'verbose|v',
			);
pod2usage( 1 ) if $Config->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
print STDERR Dumper( $Config ) if $Config->{debug};
	 
################################################################################
# commonly-used File::Find::Rule rules
my $ruleDiscardRcsHistory = File::Find::Rule->file->name("*,v")->discard;
my $ruleDiscardRcsLock = File::Find::Rule->file->name("*.lock")->discard;
my $ruleDiscardBackup = File::Find::Rule->file->name("*~")->discard;
my $ruleDiscardOS = File::Find::Rule->file->name(".DS_Store")->discard;
my $ruleDiscardLogFiles = File::Find::Rule->or( File::Find::Rule->file->name("log*.txt"), File::Find::Rule->file->name("debug*.txt"), File::Find::Rule->file->name("warn*.txt") )->discard;
my $ruleDiscardTestCasesFiles = File::Find::Rule->directory->name('TestCases')->prune->discard;
my $ruleDiscardSubversionFiles = File::Find::Rule->directory->name('.svn')->prune->discard;

my $ruleNormalFiles = File::Find::Rule->or( $ruleDiscardOS, $ruleDiscardRcsHistory, $ruleDiscardRcsLock, $ruleDiscardBackup, $ruleDiscardLogFiles, $ruleDiscardTestCasesFiles, $ruleDiscardSubversionFiles, File::Find::Rule->directory, File::Find::Rule->file );

################################################################################

my $pwdStart = cwd();
chdir( '../..' ) or die $!;            # from tools/distro up to BRANCH (eg, trunk, DEVELOP)

#-[lib/, templates/, data/, pub/icn, pub/TWiki, bin/]-----------------------------------
foreach my $dir qw( lib templates data bin pub logs )
{
    my @fileList = $ruleNormalFiles->in( $dir );
    foreach ( @fileList ) 
    { 
	push @manifestEntries, ManifestEntry->new({ source => $_ });
    }
}
# stop distributing cpan modules; get the latest versions from cpan itself
#rmtree( [ "$installBase/lib/Algorithm", "$installBase/lib/Text", "$installBase/lib/Error.pm" ] ) or warn $!;
chdir $pwdStart;

################################################################################

#-[docs]-------------------------------------------------------------------------------
foreach my $file qw (
		     pub-htaccess.txt root-htaccess.txt subdir-htaccess.txt robots.txt
		     index.html UpgradeTwiki
		     AUTHORS COPYING COPYRIGHT LICENSE readme.txt 
		     pub/TWiki/TWikiContributor/AUTHORS
		     TWikiDocumentation.html TWikiHistory.html
		     CHANGELOG
		     )
{
    push @manifestEntries, ManifestEntry->new({ source => $file });
}

# bin/ additional post processing: create "authorisation required" version of some scripts
foreach my $auth qw( rdiff view )
{
    push @manifestEntries, ManifestEntry->new({ source => "bin/${auth}auth" });
}

################################################################################

map { print "$_\n" } @manifestEntries;

exit 0;

################################################################################
################################################################################

__DATA__
=head1 NAME

kernel-manifest.pl - Codev.

=head1 SYNOPSIS

kernel-manifest.pl [options]

Copyright 2004, 2005 Will Norris and Sven Dowideit.  All Rights Reserved.

 Options:
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=back

=head1 DESCRIPTION


=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/TWikiKernel

=cut

__END__
 
################################################################################
################################################################################
differences between output of build-twiki-kernel.pl vs. TWiki20040901.tar.gz
(not including the ,v files list)


################################################################################
# questionable files in the new build
>           'templates/.cvsignore',			# where did this come from???
>           'data/_empty/.placeholder',		# because tar ignores empty directories


################################################################################
# new/refactored code
>           'lib/TWiki/Sandbox.pm',
>           'lib/TWiki/Templates.pm',
>           'lib/TWiki/Prefs/Parser.pm',
>           'lib/TWiki/Prefs/PrefsCache.pm',
>           'lib/TWiki/Prefs/TopicPrefs.pm',

################################################################################
# images changes (see above)
<           'pub/TWiki/TWikiLogos/twikilogo88x31.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot121x54.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot121x54a.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot131x64.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot46x50.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot81x119.gif',
<           'pub/TWiki/TWikiLogos/twikiRobot88x31.gif',
<           'pub/favicon.ico',
>           'pub/TWiki/WebPreferences/favicon.ico',


################################################################################
# to get from cpan
<           'lib/Algorithm/Diff.pm',
<           'lib/Text/Diff.pm',
<           'lib/Error.pm',


################################################################################
# empty and/or junk files recreated at runtime
<           'logs/debug.txt',
<           'logs/warning.txt',
<           'data/_default/.changes',
<           'data/_default/.mailnotify',
<           'data/Main/.changes',
<           'data/Main/.mailnotify',
<           'data/Sandbox/.changes',
<           'data/Sandbox/.mailnotify',
<           'data/Trash/.changes',
<           'data/Trash/.mailnotify',
<           'data/TWiki/.changes',
<           'data/TWiki/.mailnotify',


################################################################################
# cairo preinstalled plugins
<           'lib/TWiki/Plugins/CommentPlugin.pm',
<           'lib/TWiki/Plugins/EditTablePlugin.pm',
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


################################################################################
# added new test cases: data/TestCases/*, pub/TestCases/*
>           'data/TWiki/TestFixturePlugin.txt',
>           'lib/TWiki/Plugins/TestFixturePlugin.pm',
>           'data/TestCases/AnInvalidGroup.txt',
>           'data/TestCases/CreateNewTestCaseForm.txt',
>           'data/TestCases/FixtureIncludedTopic.txt',
>           'data/TestCases/IncludeMeTwice.txt',
>           'data/TestCases/RecursiveInclude.txt',
>           'data/TestCases/TestCaseAmISane.txt',
>           'data/TestCases/TestCaseAutoCategoryTable1.txt',
>           'data/TestCases/TestCaseAutoCategoryTable2.txt',
>           'data/TestCases/TestCaseAutoFormatting.txt',
>           'data/TestCases/TestCaseAutoIncludeAttachment.txt',
>           'data/TestCases/TestCaseAutoIncludes.txt',
>           'data/TestCases/TestCaseAutoInOutPre.txt',
>           'data/TestCases/TestCaseAutoInternalTags.txt',
>           'data/TestCases/TestCaseAutoSearchWithInternalTag.txt',
>           'data/TestCases/TestCaseAutoTagFromTags.txt',
>           'data/TestCases/TestCaseAutoUnexpandedTagsInSearchResults.txt',
>           'data/TestCases/TestCaseChangePassword.txt',
>           'data/TestCases/TestCaseDifferentSkin.txt',
>           'data/TestCases/TestCaseEmbeddedTags.txt',
>           'data/TestCases/TestCaseEmptyGroupTreatedAsNoGroup.txt',
>           'data/TestCases/TestCaseInternalTags.txt',
>           'data/TestCases/TestCaseIntranetRegistration.txt',
>           'data/TestCases/TestCaseNestedVerbatim.txt',
>           'data/TestCases/TestCaseTemplate.txt',
>           'data/TestCases/TestCaseTemplatedTopic.txt',
>           'data/TestCases/TestCaseTopicListTag.txt',
>           'data/TestCases/TestCaseWebListTag.txt',
>           'data/TestCases/WebHome.txt',
>           'data/TestCases/WebLeftBar.txt',
>           'data/TestCases/WebPreferences.txt',
>           'pub/TestCases/TestCaseAutoIncludeAttachment/attachment.html',


################################################################################
# cario preinstalled skins
>           'pub/TWiki/PatternSkin/empty.css',						# need to add empty.css to topic text attachment
<           'templates/attach.dragon.tmpl',
<           'templates/changeform.dragon.tmpl',
<           'templates/changes.dragon.tmpl',
<           'templates/comments.tmpl',
<           'templates/dragoncssvars.dragon.tmpl',
<           'templates/dragonmenu.dragon.tmpl',
<           'templates/edit.dragon.tmpl',
<           'templates/moveattachment.dragon.tmpl',
<           'templates/preview.dragon.tmpl',
<           'templates/rdiff.dragon.tmpl',
<           'templates/renamebase.dragon.tmpl',
<           'templates/search.dragon.tmpl',
<           'templates/searchbookview.dragon.tmpl',
<           'templates/searchformat.dragon.tmpl',
<           'templates/searchrenameview.dragon.tmpl',
<           'templates/twiki.dragon.tmpl',
<           'templates/view.dragon.tmpl',
<           'pub/TWiki/DragonSkin/fullscreen.gif',
<           'pub/TWiki/DragonSkin/gray.theme.css',
<           'pub/TWiki/DragonSkin/monochrome.theme.css',
<           'pub/TWiki/DragonSkin/screenshot.gif',
<           'pub/TWiki/DragonSkin/spacer.gif',
<           'pub/TWiki/DragonSkin/tabstyle.theme.css',
<           'pub/TWiki/DragonSkin/typography.css',




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
