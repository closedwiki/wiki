###############################################################################
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
# Based on parts of the EmbedBibPlugin by TWiki:Main/DonnyKurniawan
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
#
###############################################################################

package TWiki::Plugins::BibtexPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $defaultTopic $defaultSearchTemplate
	$isInitialized $currentBibWeb $currentBibTopic 
	$cmdTemplate1 $cmdTemplate2 
        $BIBTOOL $BIB2BIB $BIBTEX2HTML $BIBTEX
    );

use strict;

my $BIBTOOL = $TWiki::cfg{Plugins}{BibtexPlugin}{bibtool} ||
    'usr/bin/bibtool';
my $BIB2BIB = $TWiki::cfg{Plugins}{BibtexPlugin}{bib2bib} ||
    '/usr/bin/bib2bib';
my $BIBTEX2HTML =  $TWiki::cfg{Plugins}{BibtexPlugin}{bibtex2html} ||
    '/usr/bin/bibtex2html';
my $BIBTEX =  $TWiki::cfg{Plugins}{BibtexPlugin}{bibtex} ||
    '/usr/bin/bibtex';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("$pluginName - " . $_[0]) if $debug;
}

# sub writeDebugTimes {
#   &TWiki::writeDebugTimes("$pluginName - " . $_[0]) if $debug;
# }



###############################################################################
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
      TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
      return 0;
  }

  $isInitialized = 0;

  $VERSION = '1.100';
  $RELEASE = 'Dakar';
  $pluginName = 'BibtexPlugin'; 

  return 1;
}

###############################################################################
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;

  $debug = 0;

  # for getRegularExpression
  if ($TWiki::Plugins::VERSION < 1.020) {
    eval 'use TWiki::Contrib::CairoContrib;';
    #writeDebug("reading in CairoContrib");
  }

  # get configuration
  $defaultTopic = TWiki::Func::getPreferencesValue( "\U${pluginName}\E_DEFAULTTOPIC" ) || 
    "TWiki.BibtexPlugin";
  $defaultSearchTemplate = TWiki::Func::getPreferencesValue( "\U${pluginName}\E_DEFAULTSEARCHTEMPLATE" ) || 
    "TWiki.BibtexSearchTemplate";
  
  $cmdTemplate1 = 
    $BIBTOOL." -r %BIBTOOLRSC|F% %BIBTOOLARGS% %BIBFILES|F% 2>%BIBTOOLSTDERR|F% | " .
    $BIB2BIB." -q -oc /dev/null %SELECT|U% 2>%BIB2BIBSTDERR|F% ";

  $cmdTemplate2 = " | ".$BIBTEX2HTML.
    "-c '".$BIBTEX." -terse -min-crossrefs=1000 2>%BIBTEXSTDERR|F% ' " .
    "%BIBTEX2HTMLARGS|U% 2>%BIBTEX2HTMLSTDERR|F%";

  $currentBibWeb = "";
  $currentBibTopic = "";


  &writeDebug( "doInit( ) is OK" );
}



###############################################################################
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  $_[0] =~ s/%BIBTEX%/&handleBibtex()/ge;
  $_[0] =~ s/%BIBTEX{(.*?)}%/&handleBibtex($1)/ge;
  $_[0] =~ s/%STARTBIBTEX%(.*?)%STOPBIBTEX%/&handleInlineBibtex("", $1)/ges;
  $_[0] =~ s/%STARTBIBTEX{(.*?)}%(.*?)%STOPBIBTEX%/&handleInlineBibtex($1, $2)/ges;
  $_[0] =~ s/%CITE{(.*?)}%/&handleCitation($1)/ge;
}

###############################################################################
sub handleBibtex
{
  &doInit();

  # get all attributes
  my $theAttributes = shift;
  $theAttributes = "" if !$theAttributes;

  &writeDebug("handleBibtex - theAttributes=$theAttributes");

  my $theSelect = &TWiki::Func::extractNameValuePair($theAttributes, "select");
  my $theBibfile = &TWiki::Func::extractNameValuePair($theAttributes, "file");
  my $theTopic = &TWiki::Func::extractNameValuePair($theAttributes, "topic");
  my $theStyle = &TWiki::Func::extractNameValuePair($theAttributes, "style");
  my $theSort = &TWiki::Func::extractNameValuePair($theAttributes, "sort");
  my $theErrors = &TWiki::Func::extractNameValuePair($theAttributes, "errors");
  my $theReverse = &TWiki::Func::extractNameValuePair($theAttributes, "rev");
  my $theMixed = &TWiki::Func::extractNameValuePair($theAttributes, "mix");
  my $theForm = &TWiki::Func::extractNameValuePair($theAttributes, "form");
  my $theAbstracts = &TWiki::Func::extractNameValuePair($theAttributes, "abstracts") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "abstract");
  my $theKeywords = &TWiki::Func::extractNameValuePair($theAttributes, "keywords") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "keyword");
  my $theTotal = &TWiki::Func::extractNameValuePair($theAttributes, "total");
  my $theDisplay = &TWiki::Func::extractNameValuePair($theAttributes, "display");
  
  return &bibSearch($theTopic, $theBibfile, $theSelect, $theStyle, $theSort, 
	 $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, $theKeywords, 
	 $theTotal, $theDisplay);
}

###############################################################################
sub handleInlineBibtex
{
  my ($theAttributes, $theBibtext) = @_;

  &doInit();

  &writeDebug("handleInlineBibtex: attributes=$theAttributes") if $theAttributes;
  #&writeDebug("handleInlineBibtex: bibtext=$theBibtext");

  my $theSelect = &TWiki::Func::extractNameValuePair($theAttributes, "select");
  my $theStyle = &TWiki::Func::extractNameValuePair($theAttributes, "style");
  my $theSort = &TWiki::Func::extractNameValuePair($theAttributes, "sort");
  my $theErrors = &TWiki::Func::extractNameValuePair($theAttributes, "errors");
  my $theReverse = &TWiki::Func::extractNameValuePair($theAttributes, "rev");
  my $theMixed = &TWiki::Func::extractNameValuePair($theAttributes, "mix");
  my $theForm = &TWiki::Func::extractNameValuePair($theAttributes, "form");
  my $theAbstracts = &TWiki::Func::extractNameValuePair($theAttributes, "abstracts") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "abstract");
  my $theKeywords = &TWiki::Func::extractNameValuePair($theAttributes, "keywords") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "keyword");
  my $theTotal = &TWiki::Func::extractNameValuePair($theAttributes, "total");
  my $theDisplay = &TWiki::Func::extractNameValuePair($theAttributes, "display");

  $theBibtext =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $topic, $web)/ge;

  return &bibSearch("", "", $theSelect, $theStyle, $theSort, 
	 $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, $theKeywords, 
	 $theTotal, $theDisplay, $theBibtext);
}

###############################################################################
sub handleCitation
{
  &doInit();
  my $theAttributes = shift;

  my $theKey = &TWiki::Func::extractNameValuePair($theAttributes) ||
    &TWiki::Func::extractNameValuePair($theAttributes, "key");
    
  my $theTopic = &TWiki::Func::extractNameValuePair($theAttributes, "topic");
  if ($theTopic) {
    ($currentBibWeb, $currentBibTopic) = &scanWebTopic($theTopic);
  } elsif (!$currentBibWeb || !$currentBibTopic) {
    ($currentBibWeb, $currentBibTopic) = &scanWebTopic($defaultTopic);
  }

  return "[[$currentBibWeb.$currentBibTopic#$theKey][$theKey]]";
}

###############################################################################
# use a pipe of three programs:
# 1. bibtool to normalize the bibfile(s)
# 2. bib2bib to select
# 3. bibtex2html to render
sub bibSearch {
  my ($theTopic, $theBibfile, $theSelect, $theStyle, $theSort, 
      $theReverse, $theMixed, $theErrors, $theForm, $theAbstracts, 
      $theKeywords, $theTotal, $theDisplay, $theBibtext) = @_;

  my $result = "";
  my $code;

  &doInit();
#  &writeDebugTimes("bibSearch() called" );

  # fallback to default values
  $theTopic = "$web.$topic" if ! $theTopic;
  $theStyle = "bibtool" if ! $theStyle;
  $theSort = "year" if ! $theSort;
  $theReverse = "on" if ! $theReverse;
  $theMixed = "off" if ! $theMixed;
  $theErrors = "off" if ! $theErrors;
  $theSelect = "" if ! $theSelect;
  $theAbstracts = "off" if ! $theAbstracts;
  $theKeywords = "off" if ! $theKeywords;
  $theTotal = "off" if ! $theTotal;
  $theForm = "off" if ! $theForm;
  $theDisplay = "on" if ! $theDisplay;
  $theBibfile = ".*\.bib" if ! $theBibfile;

  # replace single quote with double quote in theSelect
  $theSelect =~ s/'/"/go;

  &writeDebug("theTopic=$theTopic");
  &writeDebug("theSelect=$theSelect");
  &writeDebug("theStyle=$theStyle");
  &writeDebug("theSort=$theSort");
  &writeDebug("theReverse=$theReverse");
  &writeDebug("theMixed=$theMixed");
  &writeDebug("theErrors=$theErrors");
  &writeDebug("theForm=$theForm");
  &writeDebug("theAbstracts=$theAbstracts");
  &writeDebug("theKeywords=$theKeywords");
  &writeDebug("theTotal=$theTotal");
  &writeDebug("theDisplay=$theDisplay");
  &writeDebug("theBibfile=$theBibfile");


  # extract webName and topicName
  my $formTemplate = "";
  if ($theForm eq "off") {
    $formTemplate = "";
  } elsif ($theForm eq "on") {
    $formTemplate = $defaultSearchTemplate;
  } else {
    $formTemplate = $theForm;
  }

  my ($formWebName, $formTopicName) = &scanWebTopic($formTemplate) if $formTemplate;
  my ($webName, $topicName) = &scanWebTopic($theTopic) if $theTopic;

  &writeDebug("formWebName=$formWebName") if $formTemplate;
  &writeDebug("formTopicName=$formTopicName") if $formTemplate;


  # check for error
  return &TWiki::showError("Error: topic '$theTopic' not found") 
    if !$theBibtext && !&TWiki::Func::topicExists($webName, $topicName);
  return &TWiki::showError("Error: topic '$formTemplate' not found") 
    if $formTemplate && !&TWiki::Func::topicExists($formWebName, $formTopicName);


  # get bibtex database
  my @bibfiles;
  if (!$theBibtext) {
    @bibfiles = &getBibfiles($webName, $topicName, $theBibfile);
    if (!@bibfiles) {
      &writeDebug("no bibfiles found at $webName.$topicName");
      &writeDebug("... trying inlined $webName.$topicName now");
      my ($meta, $text) = &TWiki::Func::readTopic($webName, $topicName);
      if ($text =~ /%STARTBIBTEX.*?%(.*?)%STOPBIBTEX%/gs) {
	$theBibtext = $1;
	&writeDebug("found inline bibtex database at $webName.$topicName");
      } else {
	($webName, $topicName) = &scanWebTopic($defaultTopic);
	&writeDebug("... trying $webName.$topicName now");
	return &TWiki::showError("Error: topic '$defaultTopic' not found") 
	  if !&TWiki::Func::topicExists($webName, $topicName);
	@bibfiles = &getBibfiles($webName, $topicName, $theBibfile);

	if (!@bibfiles) {
	  &writeDebug("no bibfiles found at $webName.$topicName");
	  &writeDebug("... trying inlined $webName.$topicName now");
	  ($meta, $text) = &TWiki::Func::readTopic($webName, $topicName);
	  if ($text =~ /%STARTBIBTEX.*?%(.*)%STOPBIBTEX%/gs) {
	    $theBibtext = $1;
	    &writeDebug("found inline bibtex database at $webName.$topicName");
	  }
	}
      }
    }
    return &TWiki::showError("Error: no bibtex database found.")
      if ! @bibfiles && !$theBibtext;

    &writeDebug("bibfiles=<" . join(">, <",@bibfiles) . ">")
      if @bibfiles;
  }
    
  &writeDebug("webName=$webName, topicName=$topicName");

  # set the current bib topic used in CITE
  $currentBibWeb = $webName;
  $currentBibTopic = $topicName;

  if ($theDisplay eq "on") {

    # generate a temporary bibfile for inline stuff
    my $tempBibfile;
    if ($theBibtext) {
      $tempBibfile = &getTempFileName("bibfile");
      open (BIBFILE, ">$tempBibfile");
      print BIBFILE "$theBibtext\n";
      close BIBFILE;
      push @bibfiles, $tempBibfile;
    }

    my $bibtoolStderr = &getTempFileName("bibtool");
    my $bib2bibStderr = &getTempFileName("bib2bib");

      $code = '/usr/bin/bibtool ';
      $code .= '-r '.&TWiki::Func::getPubDir()."/TWiki/BibtexPlugin/bibtoolrsc ";
      $code .= join(' ',@bibfiles);
      $code .= ' 2> '.$bibtoolStderr;
      $code .= ' | /usr/bin/bib2bib -q -oc /dev/null ';
      $code .= $theSelect? "-c '$theSelect'" : "";
      $code .= ' 2> '.$bib2bibStderr;

    # raw mode
    if ($theStyle eq "raw") {
#      ($result, $code) = &TWiki::readFromProcess($cmdTemplate1,
#	BIBTOOLRSC => &TWiki::Func::getPubDir() . "/TWiki/BibtexPlugin/bibtoolrsc",
#	BIBTOOLARGS => "",
#	BIBFILES => \@bibfiles,
#	BIBTOOLSTDERR => $bibtoolStderr,
#	SELECT => $theSelect? "-c '$theSelect'" : "",
#	BIB2BIBSTDERR => $bib2bibStderr
#      );
      $result = `$code`;
      
      &writeDebug("result code $code");
      &writeDebug("result $result");
      &processBibResult(\$result, $webName, $topicName);
      $result = "<div class=\"bibtex\"><pre>\n" . $result . "\n</pre></div>"
	if $result;
      $result .= &renderStderror($bibtoolStderr, $bib2bibStderr)
	if $theErrors eq "on";
    } else {
      # bibtex2html command
      my $bibtexStderr = &getTempFileName("bibtex");
      my $bibtex2htmlStderr = &getTempFileName("bibtex2html");
      my $bibtex2HtmlArgs =
	"-nodoc -nobibsource " .
#  	"-nokeys " .
	"-noheader " .
	"-q -dl -u " .
	"-note annote ".
        "-output -";
#       $bibtex2HtmlArgs .= "--use-keys " if $theStyle eq "bibtool";
#       $bibtex2HtmlArgs .= "-a " if $theSort =~ /^(author|name)$/;
#       $bibtex2HtmlArgs .= "-d " if $theSort =~ /^(date|year)$/;
#       $bibtex2HtmlArgs .= "-u " if $theSort !~ /^(author|name|date|year)$/;
#       $bibtex2HtmlArgs .= "-r " if $theReverse eq "on";
#       $bibtex2HtmlArgs .= "-single " if $theMixed eq "on";
#       $bibtex2HtmlArgs .= "-s $theStyle " if $theStyle ne "bibtool";
#       $bibtex2HtmlArgs .= "--no-abstract " if $theAbstracts eq "off";
#       $bibtex2HtmlArgs .= "--no-keywords " if $theKeywords eq "off";

      # do it
#     ($result, $code) = &TWiki::readFromProcess($cmdTemplate1 . $cmdTemplate2,
# 	BIBTOOLRSC => &TWiki::Func::getPubDir() . "/TWiki/BibtexPlugin/bibtoolrsc",
# 	BIBTOOLARGS => "",
# 	BIBFILES => \@bibfiles,
# 	BIBTOOLSTDERR => $bibtoolStderr,
# 	SELECT => $theSelect? "-c '$theSelect'" : "",
# 	BIB2BIBSTDERR => $bib2bibStderr,
# 	BIB2BIBSTDERR => $bibtexStderr,
# 	BIBTEX2HTMLARGS => $bibtex2HtmlArgs,
# 	BIBTEX2HTMLSTDERR => $bibtex2htmlStderr,
# 	BIBTEXSTDERR => $bibtexStderr
#       );
      # $result = system($cmdTemplate1 . $cmdTemplate2 . 

      &writeDebug("code1 $code");
      open(F,">/tmp/bibtex.bib");
      print F `$code`;
      close(F);

       $code = " /usr/bin/bibtex2html " .
                "-c /usr/share/texmf/bin/bibtex ";
       $code .= $bibtex2HtmlArgs." ";
       $code .= '/tmp/bibtex.bib';
       $code .= ' 2>'.$bibtex2htmlStderr;

      $result = `$code`;

      &writeDebug("result code $code");
      &processBibResult(\$result, $webName, $topicName);
      $result = "<div class=\"bibtex\">" . $result . "</div>"
	if $result;
      $result .= &renderStderror($bibtoolStderr, $bib2bibStderr, $bibtex2htmlStderr, $bibtexStderr)
	if $theErrors eq "on";

      unlink($bibtex2htmlStderr);
      unlink($bibtexStderr);
      unlink($tempBibfile) if $tempBibfile;
    }

    unlink($bib2bibStderr);
    unlink($bibtoolStderr);

    my $count = () = $result =~ /<dt>/g if $theTotal eq "on";
    $result = "<!-- \U$pluginName\E BEGIN --><noautolink>" .  $result;
    $result .= "<br />\n<b>Total</b>: $count<br />\n" if $theTotal eq "on";
    $result .= "<!-- \U$pluginName\E END --></noautolink>";
  }

  # insert into the bibsearch form
  if ($formTemplate) {
    my ($meta, $text) = &TWiki::Func::readTopic($formWebName, $formTopicName);
    writeDebug("reading formTemplate $formWebName.$formTopicName");
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;
    $text =~ s/%BIBFORM%/$formWebName.$formTopicName/g;
    $text =~ s/%BIBTOPIC%/$webName.$topicName/g;
    $text =~ s/%BIBERRORS%/$theErrors/g;
    $text =~ s/%BIBABSTRACT%/$theAbstracts/g;
    $text =~ s/%BIBKEYWORDS%/$theKeywords/g;
    $text =~ s/%BIBTOTAL%/$theTotal/g;
    $text =~ s/%BIBTEXRESULT%/$result/o;
    $result = $text;
  }


  #&writeDebug("result='$result'");
#  &writeDebugTimes("handleBibtex( ) done");
  return $result;
}


###############################################################################
sub processBibResult {
  my ($result, $webName, $topicName) = @_;
  while ($$result =~ s/<\/dl>.+\n/<\/dl>/o) {}; # strip bibtex2html disclaimer

  my $pubUrlPath = &TWiki::Func::getPubUrlPath();
  $$result =~ s/<dl>\s*<\/dl>//go;
  $$result =~ s/\@COMMENT.*\n//go; # bib2bib comments
  $$result =~ s/Keywords: (<b>Keywords<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibkeywords">$1<\/div>$2/gso;
  $$result =~ s/(<b>Abstract<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibabstract">$1<\/div>$2/gso;
  $$result =~ s/(<b>Comment<\/b>.*?)(<(?:b|\/dd)>)/<div class="bibcomment">$1<\/div>$2/gso;
  $$result =~ s/<\/?(p|blockquote|font)\>.*?>//go;
  $$result =~ s/<br \/>\s*\[\s*(.*)\s*\]/ <nobr>($1)<\/nobr>/g; # remove br before url
  $$result =~ s/a href=".\/([^"]*)"/a href="$pubUrlPath\/$webName\/$topicName\/$1"/g; # link to the pubUrlPath
  $$result =~ s/\n\s*\n/\n/g; # emtpy lines
  $$result =~ s/^\s+//go;
  $$result =~ s/\s+$//go;
}

###############################################################################
sub renderStderror {

  my $errors;
  
  foreach my $file (@_) {
    next if ! $file;
    $errors .= &TWiki::Func::readFile($file);
  }
  if ($errors) {
  
    # strip useless stuff
    my $pubDir = &TWiki::Func::getPubDir();
    $errors =~ s/BibTool ERROR: //og;
    $errors =~ s/condition/select/go; # rename bib2bib condition to select
    $errors =~ s/^Fatal error.*Bad file descriptor.*$//gom;
    $errors =~ s/^Sorting\.\.\.done.*$//mo;
    $errors =~ s/^\s+//mo;
    $errors =~ s/\s+$//mo;
    $errors =~ s/\n\s*\n/\n/og;
    $errors =~ s/ in \/tmp\/bibfile.*\)/)/go;
    $errors =~ s/$pubDir\/(.*)\/(.*)\/(.*)/$1.$2:$3/g;
    if ($errors) {
      return "<font color=\"red\"><b>Errors</b>:<br/>\n<pre>\n" . 
	$errors .  "\n</pre>\n</font>";
    }
  }

  return "";
}

###############################################################################
sub getTempFileName {
  my $name = shift;
  $name = "" unless $name;

  my $temp_dir = -d '/tmp' ? '/tmp' : $ENV{TMPDIR} || $ENV{TEMP};
  my $base_name = sprintf("%s/$name-%d-%d-0000", $temp_dir, $$, time());
  my $count = 0;
  while (-e $base_name && $count < 100) {
    $count++;
    $base_name =~ s/-(\d+)$/"-" . (1 + $1)/e;
  }

  if ($count == 100) {
    return undef;
  } else {
    return &TWiki::Sandbox::normalizeFileName($base_name);
  }
}

###############################################################################
sub scanWebTopic {
  my $webTopic = shift;

  my $topicName = $topic; # default to current topic
  my $webName = $web; # default to current web

  my $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');

  if ($webTopic) {
    $webTopic =~ s/^\s+//o;
    $webTopic =~ s/\s+$//o;
    if ($webTopic =~ /^($topicRegex)$/) {
      $topicName = $1;
    } elsif ($webTopic =~ /^($webRegex)\.($topicRegex)$/) {
      $webName = $1;
      $topicName = $2;
    }
  }

  return ($webName, $topicName);
}

###############################################################################
sub getBibfiles {
  my ($webName, $topicName, $bibfile) = @_;
  my @bibfiles = ();

  $bibfile = ".*\.bib" if ! $bibfile;

  my $pubDir = &TWiki::Func::getPubDir() . "/${webName}/${topicName}";
  my ($meta, $text) = &TWiki::Func::readTopic($webName, $topicName);
  
  my @attachments = $meta->find( 'FILEATTACHMENT' );
  foreach my $attachment (@attachments) {
    if ($attachment->{name} =~ /^$bibfile$/) {
      push @bibfiles, &TWiki::Sandbox::normalizeFileName("$pubDir/$attachment->{name}");
    }
  }
    

  return @bibfiles;
}


1;
