# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) Evolved Media Network 2005
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
# Author: Crawford Currie http://c-dot.co.uk
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates WebPreferences
# in each affected web.

package TWiki::Plugins::WebPermissionsPlugin;

use strict;

use vars qw( $VERSION $RELEASE );

use TWiki::Func;
use CGI qw( :all );

$VERSION = '$Rev$';

$RELEASE = '1.000';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            'Version mismatch between WebPermissionsPlugin and TWiki::Plugins' );
        return 0;
    }
    if( $TWiki::Plugins::VERSION == 1.1 ) {
        eval 'use TWiki::Contrib::FuncUsersContrib';
    }

    TWiki::Func::registerTagHandler( 'WEBPERMISSIONS', \&_WEBPERMISSIONS );

    return 1;
}

sub _WEBPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;

    return undef unless TWiki::Func::isAdmin();

    my $query = $session->{cgiQuery};
    my $action = $query->param( 'web_permissions_action' );
    my $editing = $action && $action eq 'Edit';
    my $saving =  $action && $action eq 'Save';

    my @modes = split(/[\s,]+/,$TWiki::cfg{Plugins}{WebPermissionsPlugin}{modes} ||
                           'VIEW,CHANGE' );

    my @webs;
    my $chosenWebs = $params->{webs} || $query->param('webs');
    if( $chosenWebs ) {
        @webs = split(/[,\s]+/, $chosenWebs);
    } else {
        @webs = TWiki::Func::getListOfWebs( 'user' );
    }
    my @knownusers;

    my %table;
    foreach $web ( @webs ) {
        my $acls = TWiki::Func::getACLs( \@modes, $web );

        @knownusers = keys %$acls unless scalar( @knownusers );
        if( $saving ) {
            my $changes = 0;
            foreach my $user ( @knownusers ) {
                foreach my $op ( @modes ) {
                    my $onoff = $query->param($user.':'.$web.':'.$op);
                    if( $onoff && !$acls->{$user}->{$op} ||
                          !$onoff && $acls->{$user}->{$op} ) {
                        $changes++;
                        $acls->{$user}->{$op} = $onoff;
                    }
                }
            }
            # Commit changes to ACLs
            if( $changes ) {
                TWiki::Func::setACLs( \@modes, $acls, $web );
            }
        }
        $table{$web} = $acls;
    }

    # Generate the table
    my $tab = '';

    my %images;
    foreach my $op ( @modes ) {
        if( -f TWiki::Func::getPubDir().'/TWiki/WebPermissionsPlugin/'.$op.'.gif' ) {
              $images{$op} =
                CGI::img( { src => TWiki::Func::getPubUrlPath().
                              '/TWiki/WebPermissionsPlugin/'.$op.'.gif' } );
              $tab .= $images{$op}.' '.$op;
        } else {
            $images{$op} = $op;
        }
    }

    $tab .= CGI::start_table( { border => 1, class => 'twikiTable' } );

    my $repeat_heads = $params->{repeatheads} || 0;
    my $repeater = 0;
    my $row;
    foreach my $user ( sort @knownusers ) {
        unless( $repeater ) {
            $row = CGI::th( '' );
            foreach $web ( @webs ) {
                $row .= CGI::th( $web );
            }
            $tab .= CGI::Tr( $row );
            $repeater = $repeat_heads;
        }
        $repeater--;
        $row = CGI::th( ' '.$user.' ' );
        foreach $web ( sort @webs ) {
            my $cell;
            foreach my $op ( @modes ) {
                if( $editing ) {
                    my %attrs = ( type => 'checkbox', name => $user.':'.$web.':'.$op );
                    $attrs{checked} = 'checked' if $table{$web}->{$user}->{$op};
                    $cell .= CGI::label( ($images{$op} || $op).CGI::input( \%attrs ));
                } elsif( $table{$web}->{$user}->{$op} ) {
                    $cell .= $images{$op} || $op;
                }
            }
            $row .= CGI::td( $cell );
        }
        $tab .= CGI::Tr( $row );
    }
    $tab .= CGI::end_table();

    if( $editing ) {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Save' );
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Cancel' );
    } else {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Edit' );
    }
    my $page = CGI::start_form(
        -method => 'POST',
        -action => TWiki::Func::getScriptUrl( $web, $topic, 'view') );

    if( defined $chosenWebs ) {
      $page .= CGI::hidden( -name => 'webs', -value => $chosenWebs );
    }

    $page .= $tab . CGI::end_form();
    return $page;
}

1;
