#!/usr/local/bin/perl -wI.
#
# GenPDF.pm (converts TWiki page to PDF using HTMLDOC)
#    (based on PrintUsingPDF pdf script)
#
# This script Copyright (c) 2005 Cygnus Communications
# and distributed under the GPL (see below)
#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
# Additional mess by Patrick Ohl - Biomax Bioinformatics AG
# January 2003
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

=pod

=head1 TWiki::Contrib::GenPDF

TWiki::Contrib::GenPDF - Displays TWiki page as PDF using HTMLDOC

=head1 DESCRIPTION

See the GenPDFAddOn TWiki topic for a description.

=head1 METHODS

Methods with a leading underscore should be considered local methods and not called from
outside the package.

=cut

package TWiki::Contrib::GenPDF;

use strict;
use CGI::Carp qw( fatalsToBrowser );
use CGI;
use TWiki::Func;
use TWiki::UI::View;
use File::Temp;

use vars qw($VERSION);

$VERSION = 0.1;

=pod

=head2 _fixTags($text, $rhPrefs)

Expands tags in the passed in text to the appropriate value in the preferences hash and
returns modified $text.
 
=cut

sub _fixTags {
   my ($text, $rhPrefs) = @_;

   $text =~ s|%PDFBANNER%|$rhPrefs->{'banner'}|g;
   $text =~ s|%PDFTITLE%|$rhPrefs->{'title'}|g;
   $text =~ s|%PDFSUBTITLE%|$rhPrefs->{'subtitle'}|g;
   
   return $text;
}


=pod

=head2 _getRenderedView($webName, $topic)

Generates rendered HTML of $topic in $webName using TWiki rendering functions and returns it.
 
=cut

sub _getRenderedView {
   my ($webName, $topic) = @_;

   my $text = TWiki::Func::readTopicText($webName, $topic);
   $text = TWiki::Func::expandCommonVariables($text, $topic, $webName);
   $text = TWiki::Func::renderText($text);

   return $text;
}


=pod

=head2 _getHeaderFooterData($webName, $rhPrefs)

If header/footer topic is present in $webName, gets it, expands tags, and returns
the header and footer data. It currently just uses the raw text from the topic and
does no rendering.
 
=cut

sub _getHeaderFooterData {
   my ($webName, $rhPrefs) = @_;

   # Get the header/footer data (if it exists)
   my $text = "";
   my $topic = $rhPrefs->{'hftopic'};
   # Get a topic name without any whitespace
   $topic =~ s|\s||g;
   if ($rhPrefs->{'hftopic'}) {
      $text = TWiki::Func::readTopicText($webName, $topic);
   }
   # TBD: Should probably check for valid text (e.g. topic actually found, no oops URL, etc.).

   # Extract the content between the %PDFSTART% and %PDFSTOP% comment markers
   $text =~ s|.*<!--\s*PDFSTART\s*-->(.*)<!--\s*PDFSTOP\s*-->.*|$1|s;
   $text = _fixTags($text, $rhPrefs);
   return $text;
}


=pod

=head2 _createTitleFile($webName, $rhPrefs)

If title page topic is present in $webName, gets it, expands tags, and returns
the data. It currently just uses the raw text from the topic and
does no rendering.

This operation could maybe be changed to perform TWIKI rendering to add additional
flexibility for creating a title page but I'm not sure how to allow URL params
to have precedence for the _fixTags() logic. I wanted to be able to pass
pdfbanner in from the URL and use it first. The same is true of the
getHeaderFooterData() operation. For now, it just used the text of the topic (which
is assumed to be in HTML format, not TWiki mark-up).

=cut

sub _createTitleFile {
   my ($webName, $rhPrefs) = @_;

   # Get the title data (if it exists)
   my $text = "";
   my $topic = $rhPrefs->{'titletopic'};
   # Get a topic name without any whitespace
   $topic =~ s|\s||g;
   if ($rhPrefs->{'titletopic'}) {
      $text = TWiki::Func::readTopicText($webName, $topic);
   }
   # TBD: Should probably check for valid text (e.g. topic actually found, no oops URL, etc.).

   # Extract the content between the %PDFSTART% and %PDFSTOP% markers
   $text =~ s|.*<!--\s*PDFSTART\s*-->(.*)<!--\s*PDFSTOP\s*-->.*|$1|s;
   $text = _fixTags($text, $rhPrefs);

   # Save it to a file
   my ($fh, $file) = mkstemps('/tmp/fileXXXXXXXXXX', '.html');
   print $fh $text;

   return $file;
}


=pod

=head2 _shiftHeaders($html, $rhPrefs)

Functionality from original PDF script. It currently doesn't work (maybe a porting
problem on my part).

=cut

sub _shiftHeaders{
   my ($html, $rhPrefs) = @_;

   if ($rhPrefs->{'shift'} =~ /^[+-]?\d+$/) {
      my $newHead;
      # You may want to modify next line if you do not want to shift _all_ headers.
      # I leave for example all header that contain a digit folowed by a point.
      # Look like this:
      # $html =~ s&<h(\d)>((?:(?!(<h\d>|\d\.)).)*)</h\d>&'<h'.($newHead = ($1+$sh)>6?6:($1+$sh)<1?1:($1+$sh)).'>'.$2.'</h'.($newHead).'>'&gse;
      $html =~ s|<h(\d)>((?:(?!<h\d>).)*)</h\d>|'<h'.($newHead = ($1+$rhPrefs->{'shift'})>6?6:($1+$rhPrefs-{'shift'})<1?1:($1+$rhPrefs->{'shift'})).'>'.$2.'</h'.($newHead).'>'|gse;
   }

   return $html;
}

=pod

=head2 _fixHtml($html, $rhPrefs)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modifies html.

=cut

sub _fixHtml {
   my ($html, $rhPrefs) = @_;

   # Insert an <h1> header if one isn't present
   if ($html !~ /<h1>/i) {
      $html =~ s|^(.)|<h1>$rhPrefs->{'title'}</h1>$1|;
   }

   # Extract the content between the %PDFSTART% and %PDFSTOP% markers
   if ($html =~ /<!--\s*PDFSTART\s*-->/) {
      $html =~ s|.*<!--\s*PDFSTART\s*-->(.*)<!--\s*PDFSTOP\s*-->.*|$1|s;
   }

   # Fix the image tags for links relative to web server root
   my $url = TWiki::Func::getUrlHost();
   $html =~ s|<img src=\"/|<img src=\"$url/|sgi;

   # remove all page breaks
   $html =~ s|<p style=\"page-break-before:always\"\/>||g;

   # remove %META stuff
   $html =~ s|%META:\w*{.*?}%||gs;

#   $html = _shiftHeaders($html, $rhPrefs);

   return $html;
}

=pod

=head2 _getPRefsHashRef($query)

Creates a hash with the various preference values. For each preference key, it will set the
value first to the one supplied in the URL query. If that is not present, it will use the TWiki
preference value, and if that is not present and a value is needed, it will usr a default.

See the GenPDFAddOn topic for a description of the possible preference values and defaults.

=cut

sub _getPrefsHashRef {
   my ($query) = @_;

   my %prefs = ();

   # HTMLDOC location
   $prefs{'htmldoc'} = TWiki::Func::getPreferencesValue("HTMLDOCLOC") || "/usr/bin/htmldoc";
   # header/footer topic
   $prefs{'hftopic'} = $query->param('pdfheadertopic') || TWiki::Func::getPreferencesValue("PDFHEADERTOPIC");
   # title topic
   $prefs{'titletopic'} = $query->param('pdftitletopic') || TWiki::Func::getPreferencesValue("PDFTITLETOPIC");

   $prefs{'banner'} = $query->param('pdfbanner') || TWiki::Func::getPreferencesValue("PDFBANNER");
   $prefs{'title'} = $query->param('pdftitle') || TWiki::Func::getPreferencesValue("PDFTITLE");
   $prefs{'subtitle'} = $query->param('pdfsubtitle') || TWiki::Func::getPreferencesValue("PDFSUBTITLE");

   
   $prefs{'skin'} = $query->param('skin') || TWiki::Func::getPreferencesValue("PDFSKIN");
   # Force a skin if the current value if the user didn't supply one (note that supplying a null one if OK)
   $prefs{'skin'} = "print.pattern" if (!defined($query->param('skin'))
                                        && TWiki::Func::getPreferencesValue("PDFSKIN") eq "");

   # Get TOC header/footer. Set to default if nothing useful given
   $prefs{'tocheader'} = $query->param('pdftocheader') || TWiki::Func::getPreferencesValue("PDFTOCHEADER");
   $prefs{'tocheader'} = "..." if ($prefs{'tocheader'} =~ /\s*/);
   $prefs{'tocfooter'} = $query->param('pdftocfooter') || TWiki::Func::getPreferencesValue("PDFTOCFOOTER");
   $prefs{'tocfooter'} = "..i" if ($prefs{'tocfooter'} =~ /\s*/);

   # Get some other parameters and set reasonable defaults if not supplied
   $prefs{'format'} = $query->param('pdfformat') || TWiki::Func::getPreferencesValue("PDFFORMAT");
   $prefs{'format'} = "pdf14" if ($prefs{'format'} =~ /\s*/);
   # note that 0 for toclevels with turn off the TOC
   $prefs{'toclevels'} = $query->param('pdftoclevels') || TWiki::Func::getPreferencesValue("PDFTOCLEVELS");
   $prefs{'toclevels'} = "5" if ($prefs{'toclevels'} =~ /\s*/);
   $prefs{'size'} = $query->param('pdfpagesize') || TWiki::Func::getPreferencesValue("PDFPAGESIZE");
   $prefs{'size'} = "a4" if ($prefs{'size'} =~ /\s*/);
   $prefs{'orientation'} = $query->param('pdforientation') || TWiki::Func::getPreferencesValue("PDFORIENTATION");
   $prefs{'orientation'} = "portrait" if ($prefs{'orientation'} =~ /\s*/);
   $prefs{'width'} = $query->param('pdfwidth') || TWiki::Func::getPreferencesValue("PDFWIDTH");
   $prefs{'width'} = "860" if ($prefs{'width'} =~ /\s*/);
   $prefs{'shift'} = $query->param('pdfheadershit') || TWiki::Func::getPreferencesValue("PDFHEADERSHIFT");
   $prefs{'shift'} = "2" if ($prefs{'shift'} =~ /\s*/);
   $prefs{'shift'} =~ s/\s//g;

   return \%prefs;
}

=pod

=head2 viewPDF

This is the core method to convert the current page into PDF format.

=cut

sub viewPDF {

   # Initialize TWiki
   my $query = new CGI;
   my $thePathInfo = $query->path_info(); 
   my $theRemoteUser = $query->remote_user();
   my $theTopic = $query->param('topic');
   my $theUrl = $query->url;

   my($topic, $webName, $scriptUrlPath, $userName) = 
      TWiki::initialize($thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query);

   # Get preferences
   my $rhPrefs = _getPrefsHashRef($query);

   # Set a default skin in the query
   $query->param('skin', $rhPrefs->{'skin'});

   # Get ready to display HTML topic
   my $htmlData = _getRenderedView($webName, $topic);
   # Fix topic text (i.e. correct any problems with the HTML that htmldoc might not like
   $htmlData = _fixHtml($htmlData, $rhPrefs);

   # The data returned also incluides the header. Remove it.
   $htmlData =~ s|.*(<!DOCTYPE)|$1|s;

   # Get header/footer data
   my $hfData = _getHeaderFooterData($webName, $rhPrefs);

   # Save this to a temp file for htmldoc processing
   my ($tf, $tmpFile) = mkstemps('/tmp/fileXXXXXXXXXX', '.html');
   print $tf $hfData . $htmlData;
   close($tf);

   # Create a file holding the title data
   my $titleFile = _createTitleFile($webName, $rhPrefs);

   # Convert tmpFile to PDF using HTMLDOC
   my $callHtmldoc = "$rhPrefs->{'htmldoc'} --book --links --linkstyle plain";
   $callHtmldoc   .= " -t $rhPrefs->{'format'}";
   $callHtmldoc   .= " --$rhPrefs->{'orientation'}";
   if ($rhPrefs->{'toclevels'} eq '0' ) {
      $callHtmldoc .= " --no-toc --firstpage p1";
   }
   else
   {
      $callHtmldoc .= " --toclevels $rhPrefs->{'toclevels'} --firstpage toc";
   }
   $callHtmldoc .= " --size $rhPrefs->{'size'}";
   $callHtmldoc .= " --browserwidth $rhPrefs->{'width'}";
   $callHtmldoc .= " --tocheader $rhPrefs->{'tocheader'}";
   $callHtmldoc .= " --tocfooter $rhPrefs->{'tocfooter'}";
   
   $callHtmldoc .= " --titlefile $titleFile $tmpFile";

   print STDERR "Calling htmldoc: $callHtmldoc\n";

   my $pid = open(PDF,"$callHtmldoc |") or die "Failed to fork: $!\n";

   #  output the HTML header and the output of HTMLDOC
   print CGI::header( -TYPE => "application/pdf" );
   while(<PDF>){
      print;
   }

   # dump the temporary files
   unlink("$tmpFile") or die "Failed to unlink $tmpFile : $!";
   unlink("$titleFile") or die "Failed to unlink $titleFile : $!";
}

