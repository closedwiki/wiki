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

$VERSION = 0.5;
$| = 1; # Autoflush buffers

our $query = new CGI;

=pod

=head2 _fixTags($text, $rhPrefs)

Expands tags in the passed in text to the appropriate value in the preferences hash and
returns modified $text.
 
=cut

sub _fixTags {
   my ($text, $rhPrefs) = @_;

   $text =~ s|%GENPDFADDON_BANNER%|$rhPrefs->{'banner'}|g;
   $text =~ s|%GENPDFADDON_TITLE%|$rhPrefs->{'title'}|g;
   $text =~ s|%GENPDFADDON_SUBTITLE%|$rhPrefs->{'subtitle'}|g;
   
   return $text;
}


=pod

=head2 _getRenderedView($webName, $topic)

Generates rendered HTML of $topic in $webName using TWiki rendering functions and
returns it.
 
=cut

sub _getRenderedView {
   my ($webName, $topic) = @_;

   my $text = TWiki::Func::readTopicText($webName, $topic);
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      TWiki::Func::redirectCgiQuery($query, $text);
   }
   $text =~ s/\%TOC({.*?})?\%//g; # remove TWiki TOC
   $text = TWiki::Func::expandCommonVariables($text, $topic, $webName);
   $text = TWiki::Func::renderText($text);

   return $text;
}


=pod

=head2 _extractPdfSections

Removes the text not found between PDFSTART and PDFSTOP HTML
comments. PDFSTART and PDFSTOP comments must appear in pairs.
If PDFSTART is not included in the text, the entire text is
return (i.e. as if PDFSTART was at the beginning and PDFSTOP
was at the end).

=cut

sub _extractPdfSections {
   my ($text) = @_;

   # If no start tag, just return everything
   return $text if ($text !~ /<!--\s*PDFSTART\s*-->/);

   my $output = "";
   while ($text =~ /(.*?)<!--\s*PDFSTART\s*-->(.*?)<!--\s*PDFSTOP\s*-->/sg) {
      $output .= $2;
   }
   return $output;
}

=pod

=head2 _getHeaderFooterData($webName, $rhPrefs)

If header/footer topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.
 
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
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      TWiki::Func::redirectCgiQuery($query, $text);
   }

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $text = _extractPdfSections($text);
   $text = _fixTags($text, $rhPrefs);

   my $output = "";
   # Expand common variables found between quotes. We have to jump through this loop hoop
   # as the variables to expand occur inside html comments so just expanding variables in
   # the full text doesn't do anything
   for my $line (split(/(?=<)/, $text)) {
      if ($line =~ /([^"]*")(.*)("[^"]*)/g) {
         my $start = $1;
         my $var = $2;
         my $end = $3;
         # Expand common variables and render
         #print STDERR "var = '$var'\n"; #DEBUG
         $var = TWiki::Func::expandCommonVariables($var, $topic, $webName);
         $var = TWiki::Func::renderText($var);
         $var =~ s/<.*?>|\n|\r//gs; # htmldoc can't use HTML tags in headers/footers
         #print STDERR "var = '$var'\n"; #DEBUG
         $output .= $start . $var . $end;
      }
      else {
         $output .= $line;
      }
   }

   return $output;
}


=pod

=head2 _createTitleFile($webName, $rhPrefs)

If title page topic is present in $webName, gets it, expands local tags, renders the
rest, and returns the data. "Local tags" (see _fixTags()) are expanded first to allow
values passed in from the query to have precendence.

=cut

sub _createTitleFile {
   my ($webName, $rhPrefs) = @_;

   my $text = undef;
   my $topic = $rhPrefs->{'titletopic'};
   # Get a topic name without any whitespace
   $topic =~ s|\s||g;
   # Get the title topic (if it exists)
   if ($rhPrefs->{'titletopic'}) {
      $text .= TWiki::Func::readTopicText($webName, $topic);
   }
   # FIXME - must be a better way?
   if ($text =~ /^http.*\/.*\/oops\/.*oopsaccessview$/) {
      TWiki::Func::redirectCgiQuery($query, $text);
   }

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $text = _extractPdfSections($text);
   $text = _fixTags($text, $rhPrefs);

   # Now render the rest of the topic
   $text = TWiki::Func::expandCommonVariables($text, $topic, $webName);
   $text = TWiki::Func::renderText($text);

   # FIXME - send to _fixHtml
   # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
   # convert some common HTML4.x elements to similar HTML3.2 elements
   $text =~ s/&ndash;/&shy;/g;
   $text =~ s/&[lr]dquo;/"/g;
   $text =~ s/&[lr]squo;/'/g;
   $text =~ s/&brvbar;/|/g;

   # convert twikiNewLinks to normal text
   # FIXME - should this be a preference?
   $text =~ s/<span class="twikiNewLink".*?>($TWiki::regex{wikiWordRegex}).*?\/span>/$1/gs;

   # Fix the image tags for links relative to web server root and
   # fully qualify any unqualified URLs (to make it portable to another host)
   my $url = TWiki::Func::getUrlHost();
   $text =~ s/<img(.*?) src="\//<img$1 src="$url\//sgi;
   $text =~ s/<a(.*?) href="\//<a$1 href="$url\//sgi;

   # Save it to a file
   my $fh = new File::Temp(TEMPLATE => 'GenPDFAddOnXXXXXXXXXX',
                           SUFFIX => '.html');
   print $fh $text;

   return $fh;
}


=pod

=head2 _shiftHeaders($html, $rhPrefs)

Functionality from original PDF script.

=cut

sub _shiftHeaders{
   my ($html, $rhPrefs) = @_;

   if ($rhPrefs->{'shift'} =~ /^[+-]?\d+$/) {
      my $newHead;
      # You may want to modify next line if you do not want to shift _all_ headers.
      # I leave for example all header that contain a digit folowed by a point.
      # Look like this:
      # $html =~ s&<h(\d)>((?:(?!(<h\d>|\d\.)).)*)</h\d>&'<h'.($newHead = ($1+$sh)>6?6:($1+$sh)<1?1:($1+$sh)).'>'.$2.'</h'.($newHead).'>'&gse;
      # NOTE - htmldoc allows headers up to <h15>
      $html =~ s|<h(\d)>((?:(?!<h\d>).)*)</h\d>|'<h'.($newHead = ($1+$rhPrefs->{'shift'})>15?15:($1+$rhPrefs->{'shift'})<1?1:($1+$rhPrefs->{'shift'})).'>'.$2.'</h'.($newHead).'>'|gsei;
   }

   return $html;
}

=pod

=head2 _fixHtml($html, $rhPrefs)

Cleans up the HTML as needed before htmldoc processing. This currently includes fixing
img links as needed, removing page breaks, META stuff, and inserting an h1 header if one
isn't present. Returns the modified html.

=cut

sub _fixHtml {
   my ($html, $rhPrefs, $topic, $webName) = @_;
   my $title = TWiki::Func::expandCommonVariables($rhPrefs->{'title'}, $topic, $webName);
   $title = TWiki::Func::renderText($title);
   $title =~ s/<.*?>//gs;
   #print STDERR "title: '$title'\n"; # DEBUG

   # Extract the content between the PDFSTART and PDFSTOP comment markers
   $html = _extractPdfSections($html);

   # remove all page breaks
   # FIXME - why remove a forced page break? Instead insert a <!-- PAGE BREAK -->
   #         otherwise dangling </p> is not cleaned up
   $html =~ s/(<p(.*) style="page-break-before:always")/\n<!-- PAGE BREAK -->\n<p$1/gis;

   # remove %META stuff
   $html =~ s/%META:\w+{.*?}%//gs;

   # Prepend META tags for PDF meta info - may be redefined later by topic text
   my $meta = '<META NAME="AUTHOR" CONTENT="%REVINFO{format="$wikiusername"}%"/>'; # Specifies the document author.
   $meta .= '<META NAME="COPYRIGHT" CONTENT="%WEBCOPYRIGHT%"/>'; # Specifies the document copyright.
   $meta .= '<META NAME="DOCNUMBER" CONTENT="%REVINFO{format="r1.$rev - $date"}%"/>'; # Specifies the document number.
   $meta .= '<META NAME="GENERATOR" CONTENT="%WIKITOOLNAME% %WIKIVERSION%"/>'; # Specifies the application that generated the HTML file.
   $meta .= '<META NAME="KEYWORDS" CONTENT="'. $rhPrefs->{'keywords'} .'"/>'; # Specifies document search keywords.
   $meta .= '<META NAME="SUBJECT" CONTENT="'. $rhPrefs->{'subject'} .'"/>'; # Specifies document subject.
   $meta = TWiki::Func::expandCommonVariables($meta, $topic, $webName);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   $meta = TWiki::Func::renderText($meta);
   $meta =~ s/<(?!META).*?>//g; # remove any tags from inside the <META />
   # FIXME - renderText converts the <META> tags to &lt;META&gt;
   # if the CONTENT contains anchor tags (trying to be XHTML compliant)
   $meta =~ s/&lt;/</g;
   $meta =~ s/&gt;/>/g;
   #print STDERR "meta: '$meta'\n"; # DEBUG

   $html = _shiftHeaders($html, $rhPrefs);

   # Insert an <h1> header if one isn't present
   if ($html !~ /<h1>/is) {
      $html = "<h1>$title</h1>$html";
   }
   # htmldoc reads <title> for PDF Title meta-info
   $html = "<head><title>$title</title>\n$meta</head>\n<body>$html</body>";

   # As of HtmlDoc 1.8.24, it only handles HTML3.2 elements so
   # convert some common HTML4.x elements to similar HTML3.2 elements
   $html =~ s/&ndash;/&shy;/g;
   $html =~ s/&[lr]dquo;/"/g;
   $html =~ s/&[lr]squo;/'/g;
   $html =~ s/&brvbar;/|/g;

   # convert twikiNewLinks to normal text
   # FIXME - should this be a preference?
   $html =~ s/<span class="twikiNewLink".*?>($TWiki::regex{wikiWordRegex}).*?\/span>/$1/gs;

   # Fix the image tags for links relative to web server root and
   # fully qualify any unqualified URLs (to make it portable to another host)
   my $url = TWiki::Func::getUrlHost();
   $html =~ s/<img(.*?) src="\//<img$1 src="$url\//sgi;
   $html =~ s/<a(.*?) href="\//<a$1 href="$url\//sgi;

   return $html;
}

=pod

=head2 _getPrefsHashRef($query)

Creates a hash with the various preference values. For each preference key, it will set the
value first to the one supplied in the URL query. If that is not present, it will use the TWiki
preference value, and if that is not present and a value is needed, it will use a default.

See the GenPDFAddOn topic for a description of the possible preference values and defaults.

=cut

sub _getPrefsHashRef {
   my %prefs = ();

   # HTMLDOC location
   # $TWiki::htmldocCmd must be set in TWiki.cfg

   # header/footer topic
   $prefs{'hftopic'} = $query->param('pdfheadertopic') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADERTOPIC");
   # title topic
   $prefs{'titletopic'} = $query->param('pdftitletopic') || TWiki::Func::getPreferencesValue("GENPDFADDON_TITLETOPIC");

   $prefs{'banner'} = $query->param('pdfbanner') || TWiki::Func::getPreferencesValue("GENPDFADDON_BANNER");
   $prefs{'title'} = $query->param('pdftitle') || TWiki::Func::getPreferencesValue("GENPDFADDON_TITLE");
   $prefs{'subtitle'} = $query->param('pdfsubtitle') || TWiki::Func::getPreferencesValue("GENPDFADDON_SUBTITLE");
   $prefs{'keywords'} = $query->param('pdfkeywords') || TWiki::Func::getPreferencesValue("GENPDFADDON_KEYWORDS")
                        || '%FORMFIELD{"KeyWords"}%';
   $prefs{'subject'} = $query->param('pdfsubject') || TWiki::Func::getPreferencesValue("GENPDFADDON_SUBJECT")
                        || '%FORMFIELD{"TopicHeadline"}%';

   $prefs{'skin'} = $query->param('skin') || TWiki::Func::getPreferencesValue("GENPDFADDON_SKIN");
   # Force a skin if the current value if the user didn't supply one (note that supplying a null one if OK)
   $prefs{'skin'} = "print.pattern" unless (defined $prefs{'skin'} || !defined $query->param('skin'));

   # Get TOC header/footer. Set to default if nothing useful given
   $prefs{'tocheader'} = $query->param('pdftocheader') || TWiki::Func::getPreferencesValue("GENPDFADDON_TOCHEADER");
   $prefs{'tocheader'} = "..." unless ($prefs{'tocheader'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);
   $prefs{'tocfooter'} = $query->param('pdftocfooter') || TWiki::Func::getPreferencesValue("GENPDFADDON_TOCFOOTER");
   $prefs{'tocfooter'} = "..i" unless ($prefs{'tocfooter'} =~ /^[\.\/:1aAcCdDhiIltT]{3}$/);

   # Get some other parameters and set reasonable defaults unless not supplied
   $prefs{'format'} = $query->param('pdfformat') || TWiki::Func::getPreferencesValue("GENPDFADDON_FORMAT");
   $prefs{'format'} = "pdf14" unless ($prefs{'format'} =~ /^(html(sep)?|ps([123])?|pdf(1[1234])?)$/);
   $prefs{'size'} = $query->param('pdfpagesize') || TWiki::Func::getPreferencesValue("GENPDFADDON_PAGESIZE");
   $prefs{'size'} = "a4" unless ($prefs{'size'} =~ /^(letter|legal|a4|universal|(\d+x\d+)(pt|mm|cm|in))$/);
   $prefs{'orientation'} = $query->param('pdforientation') || TWiki::Func::getPreferencesValue("GENPDFADDON_ORIENTATION");
   $prefs{'orientation'} = "portrait" unless ($prefs{'orientation'} =~ /^(landscape|portrait)$/);
   $prefs{'headfootfont'} = $query->param('pdfheadfootfont') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADFOOTFONT");
   $prefs{'headfootfont'} = undef unless ($prefs{'headfootfont'} =~
      /^(times(-roman|-bold|-italic|bolditalic)?|(courier|helvetica)(-bold|-oblique|-boldoblique)?)$/);
   $prefs{'width'} = $query->param('pdfwidth') || TWiki::Func::getPreferencesValue("GENPDFADDON_WIDTH");
   $prefs{'width'} = 860 unless ($prefs{'width'} =~ /^\d+$/);
   $prefs{'toclevels'} = $query->param('pdftoclevels') || TWiki::Func::getPreferencesValue("GENPDFADDON_TOCLEVELS");
   $prefs{'toclevels'} = 5 unless ($prefs{'toclevels'} =~ /^\d+$/);
   $prefs{'bodycolor'} = $query->param('pdfbodycolor') || TWiki::Func::getPreferencesValue("GENPDFADDON_BODYCOLOR");
   $prefs{'bodycolor'} = undef unless ($prefs{'bodycolor'} =~ /^[0-9a-fA-F]{6}$/);

   # Anything results in true (use 0 to turn these off or override the preference)
   $prefs{'bodyimage'} = $query->param('pdfbodyimage') || TWiki::Func::getPreferencesValue("GENPDFADDON_BODYIMAGE");
   $prefs{'logoimage'} = $query->param('pdflogoimage') || TWiki::Func::getPreferencesValue("GENPDFADDON_LOGOIMAGE");
   $prefs{'numbered'} = $query->param('pdfnumberedtoc') || TWiki::Func::getPreferencesValue("GENPDFADDON_NUMBEREDTOC");
   $prefs{'duplex'} = $query->param('pdfduplex') || TWiki::Func::getPreferencesValue("GENPDFADDON_DUPLEX");
   $prefs{'shift'} = $query->param('pdfheadershift') || TWiki::Func::getPreferencesValue("GENPDFADDON_HEADERSHIFT");
   $prefs{'shift'} = 0 unless ($prefs{'shift'} =~ /^[+-]?(\d+)?$/);
   $prefs{'permissions'} = $query->param('pdfpermissions') || TWiki::Func::getPreferencesValue("GENPDFADDON_PERMISSIONS");
   $prefs{'permissions'} = join(',', grep(/^(all|annotate|copy|modify|print|no-annotate|no-copy|no-modify|no-print|none)$/,
      split(/,/, $prefs{'permissions'})));
   my @margins = grep(/^(top|bottom|left|right):\d+(\.\d+)?(cm|mm|in|pt)?$/, split(',', ($query->param('pdfmargins') || TWiki::Func::getPreferencesValue("GENPDFADDON_MARGINS"))));
   for (@margins) {
      my ($key,$val) = split(/:/);
      $prefs{$key} = $val;
   }
   #print STDERR %prefs; #DEBUG

   return \%prefs;
}

=pod

=head2 viewPDF

This is the core method to convert the current page into PDF format.

=cut

sub viewPDF {

   # Initialize TWiki
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

   # Check for existence
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $topic, "oopsmissing"))
      unless TWiki::Func::topicExists($webName, $topic);
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $rhPrefs->{'hftopic'}, "oopscreatenewtopic"))
      unless TWiki::Func::topicExists($webName, $rhPrefs->{'hftopic'});
   TWiki::Func::redirectCgiQuery($query,
         TWiki::Func::getOopsUrl($webName, $rhPrefs->{'titletopic'}, "oopscreatenewtopic"))
      unless TWiki::Func::topicExists($webName, $rhPrefs->{'titletopic'});

   # Get ready to display HTML topic
   my $htmlData = _getRenderedView($webName, $topic);

   # Fix topic text (i.e. correct any problems with the HTML that htmldoc might not like
   $htmlData = _fixHtml($htmlData, $rhPrefs, $topic, $webName);

   # The data returned also incluides the header. Remove it.
   $htmlData =~ s|.*(<!DOCTYPE)|$1|s;

   # Get header/footer data
   my $hfData = _getHeaderFooterData($webName, $rhPrefs);

   # Save this to a temp file for htmldoc processing
   my $contentFile = new File::Temp(TEMPLATE => 'GenPDFAddOnXXXXXXXXXX',
                                    SUFFIX => '.html');
   print $contentFile $hfData . $htmlData;

   # Create a file holding the title data
   my $titleFile = _createTitleFile($webName, $rhPrefs);

   # Create a temp file for output
   my $outputFile = new File::Temp(TEMPLATE => 'GenPDFAddOnXXXXXXXXXX',
                                   SUFFIX => '.pdf');

   # Convert contentFile to PDF using HTMLDOC
   my @htmldocArgs;
   push @htmldocArgs, "--book",
                      "--quiet",
                      "--links",
                      "--linkstyle", "plain",
                      "--outfile", "$outputFile",
                      "--format", "$rhPrefs->{'format'}",
                      "--$rhPrefs->{'orientation'}",
                      "--size", "$rhPrefs->{'size'}",
                      "--browserwidth", "$rhPrefs->{'width'}",
                      "--titlefile", "$titleFile";
   if ($rhPrefs->{'toclevels'} eq '0' ) {
      push @htmldocArgs, "--no-toc",
                         "--firstpage", "p1";
   }
   else
   {
      push @htmldocArgs, "--numbered" if $rhPrefs->{'numbered'};
      push @htmldocArgs, "--toclevels", "$rhPrefs->{'toclevels'}",
                         "--tocheader", "$rhPrefs->{'tocheader'}",
                         "--tocfooter", "$rhPrefs->{'tocfooter'}",
                         "--firstpage", "toc";
   }
   push @htmldocArgs, "--duplex" if $rhPrefs->{'duplex'};
   push @htmldocArgs, "--bodyimage", "$rhPrefs->{'bodyimage'}" if $rhPrefs->{'bodyimage'};
   push @htmldocArgs, "--logoimage", "$rhPrefs->{'logoimage'}" if $rhPrefs->{'logoimage'};
   push @htmldocArgs, "--headfootfont", "$rhPrefs->{'headfootfont'}" if $rhPrefs->{'headfootfont'};
   push @htmldocArgs, "--permissions", "$rhPrefs->{'permissions'}" if $rhPrefs->{'permissions'};
   push @htmldocArgs, "--bodycolor", "$rhPrefs->{'bodycolor'}" if $rhPrefs->{'bodycolor'};
   push @htmldocArgs, "--top", "$rhPrefs->{'top'}" if $rhPrefs->{'top'};
   push @htmldocArgs, "--bottom", "$rhPrefs->{'bottom'}" if $rhPrefs->{'bottom'};
   push @htmldocArgs, "--left", "$rhPrefs->{'left'}" if $rhPrefs->{'left'};
   push @htmldocArgs, "--right", "$rhPrefs->{'right'}" if $rhPrefs->{'right'};

   push @htmldocArgs, "$contentFile";

   print STDERR "Calling htmldoc with args: @htmldocArgs\n";

   # Disable CGI feature of newer versions of htmldoc
   # (thanks to Brent Roberts for this fix)
   $ENV{HTMLDOC_NOCGI} = "yes";
   system($TWiki::htmldocCmd, @htmldocArgs);
   if ($? == -1) {
      croak "Failed to start htmldoc ($TWiki::htmldocCmd): $!\n";
   }
   elsif ($? & 127) {
      printf STDERR "child died with signal %d, %s coredump\n",
         ($? & 127),  ($? & 128) ? 'with' : 'without';
      croak "Conversion failed: '$!'";
   }
   else {
      printf STDERR "child exited with value %d\n", $? >> 8 unless $? >> 8 == 0;
   }

   #  output the HTML header and the output of HTMLDOC
   if ($rhPrefs->{'format'} =~ /pdf/) {
      print $query->header( -TYPE => "application/pdf" );
   }
   elsif ($rhPrefs->{'format'} =~ /ps/) {
      print $query->header( -TYPE => "application/postscript" );
   }
   else {
      print $query->header( -TYPE => "text/html" );
   }
   while(<$outputFile>){
      print;
   }
   close $outputFile;
}


