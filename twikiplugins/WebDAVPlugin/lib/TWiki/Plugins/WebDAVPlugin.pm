#
# Copyright (C) 2004 WindRiver Ltd.
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
# Plugin to cache permission information in a simple cache file that
# can be read by the twiki_dav module. Based on SessionManagerPlugin
# code:
# Copyright (C) 2002 Andrea Sterbini, a.sterbini@flashnet.it
#                    Franco Bagnoli, bagnoli@dma.unifi.it
#
package TWiki::Plugins::WebDAVPlugin;

use strict;

use vars qw(
            $web $topic $user $installWeb $VERSION
            $permDB $initialised
           );

$VERSION = 1.012;

my $pluginName = 'WebDAVPlugin';

my @dependencies =
  (
   { package => 'TWiki::Plugins', constraint => '>= 1.000' },
   { package => 'TDB_File' }
  );

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  return 1;
}

sub beforeSaveHandler {
  my ( $text, $topic, $web ) = @_;

  unless ($initialised) {
      # Late initialisation
      if ( defined( &TWiki::Func::checkDependencies ) ) {
          my $err = TWiki::Func::checkDependencies( $pluginName,
                                                    \@dependencies );
          if( $err ) {
              TWiki::Func::writeWarning( $err );
              print STDERR $err; # print to webserver log file
              return 0; # plugin initialisation failed
          }
      }
      my $twn = TWiki::Func::getTwikiWebname();
      my $pd = TWiki::Func::getPubDir();
      my $pdb = TWiki::Func::getPreferencesValue( "WEBDAVPLUGIN_LOCK_DB" );

      eval 'use TWiki::Plugins::WebDAVPlugin::Permissions';
      if ( $@ ) {
          TWiki::Func::writeWarning( $@ );
          print STDERR $@; # print to webserver log file
          return 0;
      }

      if ($pdb) {
          $permDB = new WebDAVPlugin::Permissions( $pdb );
      }

      if ( ! $permDB ) {
          TWiki::Func::writeWarning( "$pluginName failed to initialize $pdb" );
          print STDERR "$pluginName: failed to initialise $pdb\n";
          return 0;
      }

      $initialised = 1;
  }

  return unless ( $permDB );

  eval {
	$permDB->processText( $web, $topic, $text );
  };

  if ( $@ ) {
    TWiki::Func::writeWarning( "$pluginName: $@" );
    print STDERR "$pluginName: $@\n";
  }
}

1;
