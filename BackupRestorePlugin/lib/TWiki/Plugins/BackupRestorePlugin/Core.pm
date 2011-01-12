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

package TWiki::Plugins::BackupRestorePlugin::Core;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

#==================================================================
sub new {
    my $class = shift;
    my $this = {
        BaseTopic  => shift,
        BaseWeb    => shift,
        User       => shift,
        Debug      => $TWiki::cfg{Plugins}{BackupRestorePlugin}{Debug} || 0,
        BackupDir  => $TWiki::cfg{Plugins}{BackupRestorePlugin}{BackupDir} || '/tmp',
        KeepNumBUs => $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups} || '5',
    };
    bless( $this, $class );
    TWiki::Func::writeDebug( "- BackupRestorePlugin constructor" ) if $this->{Debug};
    return $this;
}

#==================================================================
sub BACKUPRESTORE {
    my( $this, $session, $params, $theTopic, $theWeb ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->BACKUPRESTORE" ) if $this->{Debug};

    my $text = "Placeholder for BACKUPRESTORE, user !$this->{User}";

    return $text;
}

#==================================================================
1;
