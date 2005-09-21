# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This is TopicReaders TWiki plugin.
#


# =========================
package TWiki::Plugins::TopicReadersPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug  $DefaultReadersFormat $ToolTipID $ToolTipOpened
    );

$VERSION = '1.12';
$pluginName = 'TopicReadersPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $DefaultReadersFormat = &TWiki::Func::getPreferencesValue ("TOPICREADERSPLUGIN_READERSFORMAT") || "<li> %READERNAME% : %READERDATE%";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    $ToolTipID=0;
    $ToolTipOpened=0;

    return 1;
}

# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%READERS{(.*?)}%/&handleReaders($1)/ge;
    $_[0] =~ s/%READERS%/&handleReaders("")/ge;

}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================



# =========================
sub handleReaders
{
  my $attr = shift;
  use Time::gmtime;
  use Time::Local;

  my ($cgiWeb,$cgiTopic,$cgiDate,$cgiFormat,$cgiTitle,$cgiHeader);
  my $cgi = &TWiki::Func::getCgiQuery();
  if( $cgi ) 
  {
    $cgiWeb   = $cgi->param('readersweb'); 
    $cgiTopic = $cgi->param('readerstopic'); 
    $cgiDate  = $cgi->param('readersdate');
    $cgiFormat= $cgi->param('readersformat');
    $cgiTitle = $cgi->param('readerstitle');
    $cgiHeader= $cgi->param('readersheader');
  }

  my $theWeb    = &TWiki::Func::extractNameValuePair( "$attr", "WEB" )    || $cgiWeb    || "$web"; 
  my $theTopic  = &TWiki::Func::extractNameValuePair( "$attr", "TOPIC" )  || $cgiTopic  || "$topic"; 
  my $theDate   = &TWiki::Func::extractNameValuePair( "$attr", "DATE" )   || $cgiDate   || "1";
  my $theFormat = &TWiki::Func::extractNameValuePair( "$attr", "FORMAT" ) || $cgiFormat || $DefaultReadersFormat;
  my $theTitle  = &TWiki::Func::extractNameValuePair( "$attr", "TITLE" )  || $cgiTitle  || "";
  my $theHeader = &TWiki::Func::extractNameValuePair( "$attr", "HEADER" ) || $cgiHeader || "";


  my ($logfileLimit, $timeLimit) = GetLogTimeInfos("$theDate");
  my $tmp=&TWiki::Func::formatTime($timeLimit, "HTTP", "gmtime");
  $theTitle =~ s/%READERSSINCE%/$tmp/g;


  my %readers=();
  opendir( DIR, "$TWiki::logDir" );

  foreach my $file ( sort readdir DIR )
  {
    if ( $file =~ /^log(\d\d\d\d)(\d\d)\.txt$/ ) 
    {
       my $year=$1;
       my $month=$2-1;
       my $filedate="$1$2";
       if ( $filedate < $logfileLimit ) { next; }

       my $filename="$TWiki::logDir/$file";
       if ( ! -f $filename) { next; }
       open (FILE, "<$filename");

       while (<FILE>)
       {
         my ( undef, $date, $author, $action, $webtopic, $newname, $ip) = split('\|');
         $webtopic =~ s/ //g;

         if (    ("$webtopic" =~ /$theWeb\.$theTopic/) 
              && (  "$action" =~ /view/i) 
              && (    "$date" =~ /(\d+)\s(\w+)\s(\d+)\s-\s(\d+):(\d+)/)
            )
         {
           my $time = timegm("00",$5,$4,$1,$month,$3);
           if ( (defined ($time)) && ($time > $timeLimit ) )
           {          
              my $val = 0;
             my $count = 0;
             if ( defined($author) ) { ($val, $count) = split (' ',$readers{"$author"}); }
             $count++;
             if ( $val < $time ) { $readers{"$author"}="$time $count"; }
           }
         }
       }
       close (FILE);
    }
  }
  closedir( DIR );

  my $out="$theTitle";

  if ( $theHeader ) { $out.="\n$theHeader\n"; }

  foreach my $author (sort keys %readers) 
  {
    my ($time, $count) = split (' ',$readers{"$author"});
    my $date=&TWiki::Func::formatTime($time, "HTTP","gmtime");
    my $tmp="$theFormat";
    $tmp=~s/%READERNAME%/$author/gi;
    $tmp=~s/%READERDATE%/$date/gi;
    $tmp=~s/%READERCOUNT%/$count/gi;
    $tmp=~s/\|$/\|\n/;
    $out="$out $tmp";
  }

  return ("$out");
}



sub GetLogTimeInfos
{

  my $date = shift;

  my $after=0;
  my $timetag;
  my $mon; 
  my $year;

  if ($date =~ /(AFTER|BEFORE|>|<)/i)  
  { 
    my $key=$1;
    $date =~ s/$key//;
    if ( $key =~ /(BEFORE|<)/i) { $after=0; }
    if ( $key =~ /(AFTER|>)/i)  { $after=1; }
  }

  if ( $after ) 
  {                     # AFTER a date 
    $date =~ s#/##g;
    $date =~ s# ##g;

    if ( $date =~ /^\d\d\d\d$/ ) { $date .= "01"; }
    if ( $date =~ /^(\d\d\d\d)(\d\d)$/ ) 
    { 
      $mon  = $2; 
      $year = $1;
      $timetag = timelocal(1,1,1,1,$mon,($year-1900));
    }
  }
  else
  {                         # before an amount of time in days, month or years
    my $value=1;            # One year is default 
    my $timebase=60*60*24;  # One year is default 
    if ($date =~ /(\d+)/i)  { $value=abs($1); }
    if ( $date =~ /D/i)     { $timebase=60*60*24; }
    if ( $date =~ /M/i)     { $timebase=60*60*24*28; }

    $timetag = time()-($timebase*$value);
    my ( $a, $b, $c, $d, $amon, $ayear) = localtime( $timetag );
    $year = sprintf("%.4u", $ayear + 1900);
    $mon = sprintf("%.2u", $amon + 1);
  }

  return ($year.$mon, $timetag);
}



1;
