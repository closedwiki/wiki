# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# Copyright (c) Vaclav Opekar  at__centrum__cz

=pod

---+ package SvnPlugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::SvnPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 9813$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 0.3$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'SvnPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
#    my $exampleCfgVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );
    # There is also an equivalent:
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( 'EXAMPLE' );
    # that may _only_ be called from the main plugin package.

#    $exampleCfgVar ||= 'default'; # make sure it has a value

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
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    


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
