# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2006 Vasek Opekar at__centrum__cz
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.
#
# SvnPlugin - based on empty plugin

=pod

---+ package SvnPlugin

=cut

package TWiki::Plugins::SvnPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '$Rev$';
$RELEASE = '2011-03-03';

$pluginName = 'SvnPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    TWiki::Func::registerTagHandler( 'SVNTIMELINE', \&_SVNTIMELINE );
    TWiki::Func::registerTagHandler( 'SVNTICKETREF', \&_SVNTICKETREF );    

    return 1;
}

sub trim($)
{
    my $string = shift;
	$string =~ s/^\s+//;
	    $string =~ s/\s+$//;
	return $string;
}

sub _SVNTIMELINE {
    my($session, $params, $theTopic, $theWeb) = @_;
    # %SVNTIMELINE{ ticketprefix="DataVizTicket" svnpath="sv://intranet/subversion/DataViz/" 
    #               limit="3"  format= "| $rev | $author | $time $date | $comment"|}%

    return _SVNTIMELINE_GEN($session, $params, $theTopic, $theWeb, 0,0);
}

sub _SVNTICKETREF {
    my($session, $params, $theTopic, $theWeb) = @_;
    # %SVNTICKETREF{ ticketprefix="DataVizTicket" ticketnum="%CALC{$EVAL(%TOPIC%)}%" svnpath="sv://intranet/subversion/DataViz/" 
    #                webviewPath="" format= "| $rev | $author | $time $date | $comment"|}%

    return _SVNTIMELINE_GEN($session, $params, $theTopic, $theWeb, 1, $params->{ticketnum});
}

sub _SVNTIMELINE_GEN {
    my($session, $params, $theTopic, $theWeb,$TicketRefProcess,$TicketNum) = @_;

my $firsttime = 1;
my $header = 0;
my $message ="";
my $format = $params->{format};
my $timeline = "";
my $ticketPrefix = $params->{ticketprefix};
my $limit ="";

if ($params->{limit} ) {
  $limit = " --limit " . $params->{limit};
}

open (FILE, "svn log ". $params->{svnpath}  . $limit . "  |" );

while (my $buffer = <FILE>) {
  if ($buffer =~ /-----/) 
  {
        $header = 1;
	if ($firsttime) 
	{
	    $firsttime = 0;
        } else {
	    $format =~ s/\$msg/$message/g;
	    $format =~ s/#(\d+)/\[\[$ticketPrefix$1\]\[#$1\]\]/g;

	    if (($TicketRefProcess && ($message =~ /#$TicketNum/)) || ($TicketRefProcess == 0)) 
	    {
		$timeline = $timeline .  $format ."\n";
	    } 
	    $message ="";
	    $format = $params->{format};
	}
  } else 
  {
    if ($header) {
#     $buffer =~ /[r]([0-9]+) \S (\S+?) \| ([0-9]+)-([0-9]+)-([0-9]+) ([0-9]+)-([0-9]+)-([0-9]+)/;
     $buffer =~ /r(\d+) \| (\S+) \| (\d+)-(\d+)-(\d+)/;
     my @a = ($1, $2 , $3, $4, $5);
     
     $format =~ s/\$rev/$a[0]/g;
     $format =~ s/\$author/$a[1]/g;
     
     $header = 0; 
    } else {

      chomp($buffer);
      $message =  $message . trim($buffer) . " ";
    }
  }
  
} 

close(FILE);
    return $timeline;
}

1;
