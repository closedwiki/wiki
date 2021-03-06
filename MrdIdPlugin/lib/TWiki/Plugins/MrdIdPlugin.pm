# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2005 TWiki:Main.BrianSpinar
# Copyright (C) 2006-2010 TWiki:TWiki.TWikiContributor
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

# =========================
package TWiki::Plugins::MrdIdPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $initialIdValue
    );

$VERSION = '$Rev$';
$RELEASE = '2010-12-12';

$pluginName = 'MrdIdPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
   ( $topic, $web, $user, $installWeb ) = @_;

   # check for versions
   if( $TWiki::Plugins::VERSION < 1.021 ) {
      TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
      return 0;
   }
   
   # Get plugin debug flag
   $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

   # Get the initial ID value for new ID tags.
   $initialIdValue = TWiki::Func::getPluginPreferencesValue( "STARTINGIDVALUE" ) || "1";

   # Plugin correctly initialized
   TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
   return 1;
}


sub _getNextId {
   my $tag = shift;

   my $id = $initialIdValue;

   # The file locking stuff is stolen from the ActionTrackerPlugin
   my $uidRegister = TWiki::Func::getDataDir() . "/mrdIdReg";
   my $lockFile = "$uidRegister.lock";

   # Could do this using flock but it's not guaranteed to be implemented on all systems.
   # COVERAGE OFF lock file wait
   while (-f $lockFile) {
      sleep(1);
   }
   # COVERAGE ON

   open(FH, ">$lockFile") or die "Locking $lockFile: $!";
   print FH "locked\n";
   close(FH);

   my $ids = "";
   if (-f $uidRegister) {
      open(FH, "<$uidRegister") or die "Reading $uidRegister: $!";
      $ids = <FH>;
      chomp($ids);
      close(FH);
   }

   # The ids is a single line of colon separated IDs of the form :TAGAnum:TAGBnum:...
   # where TAGX is the TAG and num is the last assigned number.
   if ($ids =~ /(.*:$tag)(\d+)(.*)/) {
      # found the ID, increment the count
      $id = $2 + 1;
      $ids = "$1$id$3";
   }
   else {
      # A new ID, add it to the end
      $ids .= ":$tag$id";
   }

   open(FH, ">$uidRegister") or die "Writing $uidRegister: $!";
   print FH "$ids\n";
   close(FH);
   unlink($lockFile) or die "Unlocking $lockFile: $!";

   return $id;
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

   TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

   # This is the place to define customized tags and variables
   # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

   $_[0] =~ s/%MRDID{\s*[iI][dD]=\"(.*?)\"\s*}%/$1/g;
}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

   TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

   # This handler is called by TWiki::Store::saveTopic just before the save action.
   # New hook in TWiki::Plugins $VERSION = '1.010'

   my $id;
   my $tag;
   my $rest;
   my $text = "";
   foreach my $line (split(/\r?\n/, $_[0])) {
      if ($line =~ /^(.*?%MRDID{)(.*?)(}%.*)$/) {
         $text .= $1;
         $id    = $2;
         $rest  = $3;
         # if the ID contains a number, we're done
         if ($id !~ /\d+/o) {
            # no number so generate one
            $tag = $id;
            # the tag can take two forms depending on where it occurs. If it is in the
            # main part of the page it will look like id="NNN". If it occurs in the meta
            # data (like a form), it will look like id=%_Q_%NNN%_Q_%
            if ($tag =~ /"/) {
               $tag =~ s/.*?\s*[iI][dD]=\"(.*)\"\s*.*/$1/;
               $id = _getNextId($tag);
               $id = " id=\"$tag$id\" ";
            }
            else {
               $tag =~ s/.*?\s*[iI][dD]=%_Q_%(.*)%_Q_%\s*.*/$1/;
               $id = _getNextId($tag);
               $id = " id=%_Q_%$tag$id%_Q_% ";
            }
         }
         $text .= "$id$rest\n";
      }
      elsif ($line =~ /^(.*?%MRDID)(%.*)$/) {
         $text .= $1;
         $rest  = $2;
         $tag = "";
         $id = _getNextId($tag);
         $id = "id=\"$tag$id\"";
         $text .= "{ $id }$rest\n";
      }
      else {
         $text .= "$line\n";
      }
   }
   $_[0] = $text;
}

1;
