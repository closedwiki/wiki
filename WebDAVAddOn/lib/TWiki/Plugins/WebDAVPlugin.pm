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
use  TWiki::Plugins::WebDAVPlugin::Permissions;

use vars qw(
            $web $topic $user $installWeb $VERSION
            $permDB
           );

$VERSION = '1.010';
my $pluginName = 'WebDAVPlugin';

my @dependencies =
  (
   { package => 'TDB_File' }
 };

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between WebDAVPlugin and Plugins.pm" );
    return 0;
  }

  my $depsOK = 1;
  foreach my $dep ( @dependencies ) {
    my ( $ok, $ver ) = ( 0, 0 );
    eval "use $dep->{package}";
    unless ( $@ ) {
	  if ( defined( $dep->{constraint} )) {
		eval "\$ver = \$$dep->{package}::VERSION;\$ok = (\$ver $dep->{constraint})";
	  } else {
		$ok = 1;
	  }
	}
	unless ( $ok ) {
	  my $mess = "$dep->{package} ";
	  $mess .= "version $dep->{constraint} " if ( $dep->{constraint} );
	  $mess .= "is required for $pluginName version $VERSION. ";
	  $mess .= "$dep->{package} $ver is currently installed. " if ( $ver );
	  $mess .= "Please check the plugin installation documentation. ";
	  TWiki::Func::writeWarning( $mess );
	  print STDERR "$mess\n";
	  $depsOK = 0;
	}
  }
  return 0 unless $depsOK;

  my $twn = TWiki::Func::getTwikiWebname();
  my $pd = TWiki::Func::getPubDir();
  my $pdb = TWiki::Func::getPreferencesValue( "WEBDAVPLUGIN_LOCK_DB" );
  if ($pdb) {
	$permDB = new WebDAVPlugin::Permissions( $pdb );
  }

  if ( ! $permDB ) {
    TWiki::Func::writeWarning( "$pluginName failed to initialize $pdb" );
    return 0;
  }

  return 1;
}

sub beforeSaveHandler {
  my ( $text, $topic, $web ) = @_;

  return unless ( $permDB );

  eval {
	$permDB->processText( $web, $topic, $text );
  }; if ( $@ ) {
    TWiki::Func::writeWarning( "$pluginName: $@" );
  }
}

1;
