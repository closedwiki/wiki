# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2002 TWiki:Main.CharlieReitsma
# Copyright (C) 2007-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Plugins::SablotronPlugin;

use vars qw( $web $topic $user $installWeb $VERSION $RELEASE $debug );

use XML::Sablotron;

my ($self, $processor, $code, $level, @fields, $error);

$VERSION = '$Rev$';
$RELEASE = '2011-02-01';

sub initPlugin {
 ( $topic, $web, $user, $installWeb ) = @_;

 # check for Plugins.pm versions
 if( $TWiki::Plugins::VERSION < 1 ) {
  &TWiki::Func::writeWarning( "Version mismatch between SablotronPlugin and Plugins.pm" );
  return 0;
 }

 # Get plugin debug flag
 $debug = &TWiki::Func::getPreferencesFlag( "SABLOTRONPLUGIN_DEBUG" ) || 0;

 # Plugin correctly initialized
 &TWiki::Func::writeDebug( "- TWiki::Plugins::SablotronPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

 return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

 &TWiki::Func::writeDebug( "- SablotronPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

 $_[0] =~ s/%XSLTRANSFORM{xsl="(.*?)",xml=(.*?)}%/&applySablotron($1, $2)/gseo;
}

sub applySablotron {
 my $xsl = $_[0];
 my $xml = $_[1];

 my $sab = new XML::Sablotron;
 my $sit = new XML::Sablotron::Situation();
 $sab->RegHandler(0, { MHMakeCode => \&myMHMakeCode,
                       MHLog => \&myMHLog,
                       MHError => \&myMHError });

 $xml =~ s/^\s+//; # trim leading white space
 $xml =~ s/\s+$//; # trim trailing white space
 $sab->addArg($sit, 'input', $xml);

 #get the web name and the topic name
 my ($xslWeb, $xslTopic) = TWiki::Func::normalizeWebTopicName( $wev, $xsl );
 #check if the topic exists
 if (&TWiki::Func::topicExists($xslWeb, $xslTopic)) {
  #the topic does exist so read from the file
  my ($xslMeta, $xslText) = &TWiki::Func::readTopic($xslWeb, $xslTopic);
  $xslText =~ s/^\s+//; # trim leading white space
  $xslText =~ s/\s+$//; # trim trailing white space
  $sab->addArg($sit, 'template', $xslText);
 } else {
  return "<verbatim>XSL source: ".$xsl." does not exist.\n".
         $xml."\n</verbatim>";
 }

 $error = 0;
 $sab->process($sit, 'arg:/template', 'arg:/input', 'arg:/output');

 return "<verbatim>Sablotron Plugin Error Report:\n".
        join("\n","level:$level",@fields)."\n</verbatim>" if $error;
 return $sab->getResultArg('arg:/output');
}

sub myMHMakeCode {
 my ($self, $processor, $severity, $facility, $code) = @_;
 return $code if $severity; # I can deal with internal numbers
}

sub myMHLog {
 ($self, $processor, $code, $level, @fields) = @_;
 $error = 1 if $level > 1;
}

sub myMHError {
 ($self, $processor, $code, $level, @fields) = @_;
 $error = 1;
}

1;
