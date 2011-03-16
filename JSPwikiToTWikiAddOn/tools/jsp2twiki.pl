# Utility for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 TWiki:Main.NilsBoysen 
# Copyright (C) 2008-2011 TWiki:TWiki.TWikiContributor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

#!/usr/bin/perl

use strict;
use warnings;

use vars qw/ $VERSION /;
use File::Copy;
use File::Basename;
use Data::Dumper;

$VERSION = '0.1';

my %ignore = ();

#############################################################
# edit this params:

die "Usage: $0 INDIR TWIKIROOT WEBNAME\n" unless @ARGV == 3;

# source directory of the jspwiki
my $indir = $ARGV[0];
die "$indir not a valid directory\n" unless -d $indir;

# source directory of the jspwiki attachements
my $attachments = "$indir/Attachments";

my $twikidir = $ARGV[1];
die "$twikidir not a valid TWiki root - should contain data/ and pub/\n"
  unless -d $twikidir &&
         -e "$twikidir/data" &&
         -e "$twikidir/pub";

my $web = $ARGV[2];
die "need web name\n" unless $web;

# destination dir of the new TWikiWeb
my $outdir = "$twikidir/data/$web";

# destination dir of the new TWikiWeb attachements
my $outattach = "$twikidir/pub/$web";

#############################################################

my %attachments = ();

my @ignore =
qw/
pic-att
PIC-att
Pic-att
PIC.txt
About.txt
attachments
AttachmentsIteratorTag.txt
AuthorTag.txt
BreadcrumbsTag.txt
CalendarTag.txt
CheckLockTag.txt
CheckRequestContextTag.txt
CheckVersionTag.txt
ContentEncodingTag.txt
CVSModulStruktur.txt
DiffLinkTag.txt
EditLinkTag.txt
EditPageHelp.txt
FullRecentChanges.txt
HasAttachmentsTag.txt
HistoryIteratorTag.txt
IncludeTag.txt
InsertDiffTag.txt
InsertPageTag.txt
JSPWikiFAQ.txt
JSPWikiPlugins.txt
JSPWikiTags.txt
JSPWikiTips.txt
LeftMenuFooter.txt
LeftMenu.txt
LinkToParentTag.txt
LinkToTag.txt
NoSuchPageTag.txt
OLD
OneMinuteWiki.txt
PageDateTag.txt
PageExistsTag.txt
PageIndex.txt
PageInfoLinkTag.txt
PageNameTag.txt
PageSizeTag.txt
PageTypeTag.txt
PageVersionTag.txt
ParentPageNameTag.txt
PermissionTag.txt
pic.txt
Pic.txt
PluginTag.txt
RCS
RecentChanges.txt
RSSCoffeeCupLinkTag.txt
RSSImageLinkTag.txt
RSSLinkTag.txt
SandBox.txt
SearchResultIteratorTag.txt
StatechangeCodes.txt
StepHandlerParameters.txt
SystemInfo.txt
TextFormattingRules.txt
TranslateTag.txt
UndefinedPages.txt
UnusedPages.txt
UploadLinkTag.txt
UserCheckTag.txt
UserNameTag.txt
VariableTag.txt
WikiAttachments.txt
WikiEtiquette.txt
WikiName.txt
WikiRPCInterface.txt
WikiTemplates.txt
WikiVariables.txt
WindowsInstall.txt
/;

sub convert_content
{
	my($content) = @_;

	# Definition List (;__Ergebnis__:)
	$content =~ s/^\;\_*([^\:\_]*)\_*\:(.*)$/\t$1\:\ $2/mg;

	# [Pic/processing.gif]
	$content =~ s/\[Pic\/([^\[\]\.]*)\.[^\[\]]*\]/\%\U$1\E\%/mg;

	# [Systemplanung-uebersicht2.gif]
	$content =~ s/\[([\|\[\]]*\.gif|jpg|png)\]/%ATTACHURL%\/$1/img;

	# [some link]
	$content =~ s/\[([^\[\]\|\/]*)\]/\[\[$1\]\]/mg;

	# [Preselection Ort | http://some.host.net/twiki/bin/view/SomeStuff]
	$content =~ s/\[([^\[\|\]]*)\s*\|\s*([^\[\|\]\/]*:\/\/[^\[\|\]]*)\]/\[\[$2\]\[$1\]\]/mg;

	# [SomeStuff/somepic.png]
	$content =~ s/([\[]*)\[[^\|\/]*\/([^\|\/]*\.png|jpg|gif)\]/%ATTACHURL%\/$2/mg;

	# [SomeStuff/some.doc]
	$content =~ s/\[([\[\]\|\/]*)\/([^\|\/\[\]]*)\]/$1\[\[\%ATTACHURL%\/$2\]\[$2\]\]/mg;

	# [SomeStuff |SomeTopic/somefile.doc]
	$content =~ s/\[([^\|\/\[\]]*)\|([^\|\[\]]*)\/([^\|\[\]]*)\]/\[\[%PUBURL%\/$web\/$2\/$3\]\[$1\]\]/mg;


	# [Some Topic Desc |SomeTopic]
	$content =~ s/\[([^\|\[\]]*)\|([^\|\[\]]*)\]/\[\[$2\]\[$1\]\]/mg;

	###########

	# fix tables
	$content =~ s/^(\|.*[^\|\n])$/$1\|/mg;

	$content =~ s/\\\\/<br>/mg;

	$content =~ s/^\*{10}([^\*]*)/\t\t\t\t\t\t\t\t\t\t\t\t\*\ $1/mg;
	$content =~ s/^\*{9}([^\*]*)/\t\t\t\t\t\t\t\t\t\t\t\*\ $1/mg;	
	$content =~ s/^\*{8}([^\*]*)/\t\t\\t\t\t\t\t\t\t\*\ $1/mg;
	$content =~ s/^\*{7}([^\*]*)/\t\t\t\t\t\t\t\t\*\ $1/mg;		
	$content =~ s/^\*{6}([^\*]*)/\t\t\t\t\t\t\t\*\ $1/mg;			
	$content =~ s/^\*{5}([^\*]*)/\t\t\t\t\t\*\ $1/mg;			
	$content =~ s/^\*{4}([^\*]*)/\t\t\t\t\*\ $1/mg;			
	$content =~ s/^\*{3}([^\*]*)/\t\t\t\*\ $1/mg;				
	$content =~ s/^\*{2}([^\*]*)/\t\t\*\ $1/mg;				
	$content =~ s/^\*([^\*]*)/\t\*\ $1/mg;				

	$content =~ s/^#\s*(.*)/\t1\ $1/mg;				

 	$content =~ s/^\!{4,}(.*)/\-\-\-\+ $1\n/mg;		# make a heading
 	$content =~ s/^\!{3}(.*)/\-\-\-\++ $1\n/mg;
 	$content =~ s/^\!{2}(.*)/\-\-\-\+++ $1\n/mg;
 	$content =~ s/^\!{1}(.*)/\-\-\-\++++ $1\n/mg;

	# italic text
	$content =~ s/\'\'/_/mg;

	# bold text
	$content =~ s/__/*/mg;

	# monospaced text
	$content =~ s/\{\{([^\{\}]*)\}\}/\ \=$1\=\ /mg;

	# code-blocks
	$content =~ s/\{\ \=/\<verbatim\>/mg;
	$content =~ s/\=\ \}/\<\/verbatim\>/mg;

	$content =~ s/\{\{\{/\<verbatim\>/mg;
	$content =~ s/\}\}\}/\<\/verbatim\>/mg;

	# hr
	$content =~ s/^\-\-\-\-$/\-\-\-\n/mg;

	$content =~ s/\´/\'/g;

	# add toc if appropriate
 	if( $content =~ /^\-\-\-\+\+/ )
 	{
 		$content = "---\n%TOC%\n---\n\n".$content;
 	}

	my @content = split( "\n", $content );
	$content = '';
	my $lastrow = '';


	# repair table headers
	foreach ( @content )
	{
		if( /^\|/ )
		{
			if( $lastrow !~ /^\|/ )
			{
				$_ =~ s/\|\|/\|/g;
				$_ =~ s/\|([^\|]*)/\|\*$1\*/g;
				$_ =~ s/\**$//g;
			}
		}
		$lastrow = $_;
		$content = $content . $_ . "\n";
	}

	return( $content );
}

foreach( @ignore )
{
	$ignore{ $_ } = 1;
}

opendir( ATTACH, $attachments ) || die( "open($attachments): $!" );

while( my $topic = readdir( ATTACH ) )
{
	my $srcfile = '';

	next if $ignore{$topic};

	$topic = "$attachments/$topic";

	next if $topic !~ /\-att$/;

	my $realtopic = $topic;
	$realtopic =~ s/\-att$//g;
	$realtopic = basename( $realtopic );

	opendir( TOPIC, $topic ) || die( $! );

	while( my $file = readdir( TOPIC ) )
	{
		my $topicfile = "$topic/$file";

		next if $file !~ /\-dir$/;

		my $realfile = $file;
		$realfile =~ s/\-dir$//g;

		opendir( VERSIONS, $topicfile ) || die( $! );

		while( my $version = readdir( VERSIONS ) )
		{
			next if -d $version;
			next if $version eq 'attachment.properties';

			$srcfile = "$topicfile/$version";
		}

		close( VERSIONS );

		my $dstfile = $srcfile;

        	$dstfile =~ s/%FC/ü/g;
		$dstfile =~ s/%F6/ö/g; 
		$dstfile =~ s/%C3%83%C2%BC/ü/g; 


		$dstfile =~ s/\-dir\/.*$//g;
		$dstfile =~ s/\-att\//\//g;
		$dstfile =~ s/\ //g;
		$dstfile =~ s/\+/\ /g;

		$dstfile =~ s!^\Q$attachments/!!g;

		my $outdir = $dstfile;
		$outdir =~ s/\/[^\/]*$//g;
		$outdir = "$outattach/$outdir";


		# print( "outdir: $outdir\n" );
		if( ! -d $outdir )
		{
			mkdir( $outdir, 0770 );
		}

		push( @{ $attachments{$realtopic} }, basename( $dstfile ) );

		$dstfile = "$outattach/$dstfile";

		# print( "$srcfile\n -> $dstfile\n" );

		copy( $srcfile, $dstfile ) || die( "copy($srcfile -> $dstfile) failed: $!" );

		system( "ci -q -t-import \"$dstfile\"" ) && die( $! );

		copy( $srcfile, $dstfile ) || die( "copy($srcfile -> $dstfile) failed: $!" );

	}

	closedir( TOPIC );
}

closedir( ATTACH );

opendir( INDIR, $indir ) || die( $! );

while( my $infile = readdir( INDIR ) )
{
	my $content = '';
	next if $ignore{ $infile };

	next if -d "$indir/$infile";

	my $topic = $infile;
	$topic =~ s/\.txt$//g;

	# print( "$infile\n" );

	open( INFILE, "$indir/$infile" ) || die( $! );
	{
		local $/;
		$content = <INFILE>;
	}
	close( INFILE );

	$content = convert_content( $content );

	if( $attachments{$topic} )
	{
		$content = '%META:TOPICINFO{author="converter" date="1061203348" format="1.0" version="1.2"}%' . $content;
		$content .= "\n";
		foreach( @{ $attachments{$topic} } )
		{
			$content .= '%META:FILEATTACHMENT{name="'.$_.'" attr="" comment="" date="1061203054" path="'.$_.'" size="3235" user="converter" version="1.1"}%';
		}
	}

	if( $infile eq 'Main.txt' )
	{
		$infile = 'WebHome.txt';
	}

	$infile =~ s/%FC/ü/g;
	$infile =~ s/%F6/ö/g;
	$infile =~ s/\.txt$//g;
	$infile =~ s/\.//g;

	$infile .= '.txt';

	open( OUTFILE, ">$outdir/$infile" ) || die( $! );
	print( OUTFILE $content );
	close( OUTFILE );

        # This is horribly slow and pointless AFAICS.
	#system( "unix2dos \"$outdir/$infile\"" ) && die( $! );
        # If you have to do it, do it like this:
        #unix2dos("$outdir/$infile");

	my $file = "$outdir/$infile";

	copy( "$file", "$file.tmp" ) || die( $! );

	system( "ci -q -t-import \"$file\"" ) && die( $! );

	move( "$file.tmp", "$file" ) || die( $! );
}

closedir( INDIR );

sub unix2dos {
  my ($file) = @_;
  open(IN, "+<$file") or die "open(+<$file) failed: $!\n";
  my $contents = "";
  while (<IN>) {
    s/$/\r/;
    $contents .= $_;
  }
  seek IN, 0, 0;
  truncate IN, 0;
  print IN $contents;
  close(IN);
}
