# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 FIXME
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
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

package TWiki::Plugins::ExternalLinkTrackerPlugin::Core;

use strict;

our $defTopic = 'ExternalLinkTrackerDefinition';

#==================================================================
sub new {
    my ( $class, $this ) = @_;

    $this->{Debug} = $TWiki::cfg{Plugins}{ExternalLinkTrackerPlugin}{Debug} || 0;

    bless( $this, $class );

    $this->_loadLinkDefinition();
    $this->_writeDebug( "constructor" );

    return $this;
}

#==================================================================
sub _loadLinkDefinition {
    my( $this ) = @_;

    my $text = TWiki::Func::readTopic( $TWiki::cfg{UsersWebName}, $defTopic );
    foreach my $line ( split ( /\n/, $text ) ) {
        if( $line =~ /^ *\| *([A-Za-z0-9\-_\.]+) * \| *(.*?) *\| *(.*?) *\|/ ) {
            my $id = lc( $1 );
            $this->{Def}{$id}{Name} = $2;
            $this->{Def}{$id}{URL} = $3;
        }
    }
    if( $this->{Debug} ) {
        require Data::Dumper;
        $this->_writeDebug( 'Link definition: ' . Data::Dumper::Dumper( $this->{Def} ) );
    }
}

#==================================================================
sub EXLINK {
    my( $this, $params, $topic, $web ) = @_;

    my $action = $params->{action} || '';
    my $text = '';

    if( ! $action ) {
        my $id = lc( $params->{_DEFAULT} );
        if( $this->{Def}{$id} ) {
            # Link to redirect URL
            $text = '[[%SCRIPTURL{viewauth}%/%SYSTEMWEB%/ExternalLinkTrackerPlugin?'
                  . 'exlink_action=redirect;'
                  . "exlink_id=$id;"
                  . "exlink_web=$web;"
                  . "exlink_topic=$topic"
                  . ']['
                  . $this->{Def}{$id}{Name}
                  . ']]';
            $this->_writeDebug( " Link changed to '$text'" );

        } else {
            $text = '(EXLINK: ID "' . $id . '" not found)';
            $this->_writeDebug($text );
        }

    } elsif( $action eq 'redirect' ) {
        my $id     = $params->{exlink_id} || '';
        $this->_writeDebug( "action: 'redirect', id: '$id'" );

        if( $id && $this->{Def}{$id} ) {
            # TODO: record link action

            # Redirect to link target
            $text = "DEBUG: Redirect to '" . $this->{Def}{$id}{URL} . "'";
            $this->_writeDebug( $text );
            unless( $this->{Debug} ) {
                TWiki::Func::redirectCgiQuery( undef, $this->{Def}{$id}{URL} );
            }
        } else {
            $text = "EXLINK: id '$id' not found for action 'redirect'";
        }
    }
    return $text;
}

#==================================================================
sub _writeDebug {
    my( $this, $text ) = @_;

    return unless( $this->{Debug} );
    if( $this->{ScriptType} eq 'cli' ) {
        print "DEBUG ExternalLinkTrackerPlugin: $text\n";
    } else {
        TWiki::Func::writeDebug( "- ExternalLinkTrackerPlugin: $text" );
    }
}

#==================================================================
1;
