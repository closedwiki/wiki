# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter@thoeny.org
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

package TWiki::Plugins::BackupRestorePlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw(
    $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC $pluginName
    $debug $backupDir $keepNumBUs
  );

$VERSION = '$Rev$';
$RELEASE = '2011-01-10';
$SHORTDESCRIPTION = 'Backup, restore and upgrade a TWiki site';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'BackupRestorePlugin';

#==================================================================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get preferences
    $debug      = $TWiki::cfg{Plugins}{BackupRestorePlugin}{Debug} || 0;
    $backupDir  = $TWiki::cfg{Plugins}{BackupRestorePlugin}{BackupDir} || '/tmp';
    $keepNumBUs = $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups} || '5';

    TWiki::Func::registerTagHandler( 'BACKUPRESTORE', \&_BACKUPRESTORE );

    # Plugin correctly initialized
    return 1;
}

#==================================================================
sub _BACKUPRESTORE {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $text = "Placeholder for BACKUPRESTORE";

    return $text;
}

#==================================================================
1;
