# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 TWikiContributors
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

# Still do to:
# Handle continuation lines (see Prefs::parseText). These should always
# go into a text area.

package TWiki::Plugins::PreferencesPlugin;

use strict;
use CGI ( -any );

use vars qw(
            $web $topic $user $installWeb $VERSION $pluginName
            $query @shelter
           );

$VERSION = '1.025';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    $pluginName = 'PreferencesPlugin';

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between '.$pluginName.' and Plugins.pm' );
        return 0;
    }
    @shelter = ();

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $map ) = @_;

    if ( $_[0] =~ m/%EDITPREFERENCES{\s*\"(.*?)\"\s*}%/ ) {
        my $insideVerbatim = 0;
        my $formWeb = $web;
        my $form = $1;
        $form = TWiki::Func::expandCommonVariables( $form, $topic, $web );
        if( $form =~ m/(.*?)\.(.*)/ ) {
            $formWeb = $1;
            $form = $2;
        }
        $query = TWiki::Func::getCgiQuery();

        $_[0] = handlePrefsStart( $web, $topic ) . $_[0] . handlePrefsEnd();
        my $action = lc $query->param( 'prefsaction' );

        # SMELL: Unpublished API. No choice, though :-(
        my $formDef = new TWiki::Form( $TWiki::Plugins::SESSION,
                                       $formWeb, $form );

        if ( $action eq 'edit' ) {

            TWiki::Func::setTopicEditLock( $web, $topic, 1 );

            $_[0] =~ s/^(\t+\*\sSet\s)(\w+)\s\=(.*)$/$1.handleSet($web, $topic, $2, $3, $formDef)/gem;
            $_[0] =~ s/%EDITPREFERENCES.*%/handleEditButton($web, $topic, 0)/eo;
        } elsif ( $action eq 'cancel' ) {
            TWiki::Func::setTopicEditLock( $web, $topic, 0 );
            my $url = TWiki::Func::getViewUrl( $web, $topic );
            TWiki::Func::redirectCgiQuery( $query, $url );
            return 0;

        } elsif ( $action eq 'save' ) {

            my $text = TWiki::Func::readTopicText( $web, $topic );
            $text =~ s/^(\t+\*\sSet\s)(\w+)\s\=(.*)$/$1.handleSave($web, $topic, $2, $3, $formDef)/mgeo;

            my $error = TWiki::Func::saveTopicText( $web, $topic, $text, '' );
            TWiki::Func::setTopicEditLock( $web, $topic, 0 );
            my $url = TWiki::Func::getViewUrl( $web, $topic );
            if( $error ) {
                $url = TWiki::Func::getOopsUrl( $web, $topic, 'oopssaveerr', $error );
            }
            TWiki::Func::redirectCgiQuery( $query, $url );
            return 0;

        } else {
            $_[0] =~ s/%EDITPREFERENCES.*%/handleEditButton($web, $topic, 1)/ge;
        }
    }
}

# Use the post-rendering handler to plug our pre-formatted editor units
# into the text
sub postRenderingHandler {
    ### my ( $text ) = @_;

    $_[0] =~ s/SHELTER\007(\d+)/$shelter[$1]/g;
}

sub getField {
    my( $formDef, $name ) = @_;
    foreach my $f ( @{$formDef->{fields}} ) {
        if( $f->{name} eq $name ) {
            return $f;
        }
    }
    return undef;
}

sub handleSet {
    my( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $fieldDef = getField( $formDef, $name );

    my $extras;

    # SMELL: use of unpublished core function
    ( $extras, $value ) =
      $formDef->renderFieldForEdit( $fieldDef, $web, $topic, $value);

    push( @shelter, $value );

    return $name.' = SHELTER'."\007$#shelter\n";
}

sub handlePrefsStart {
    my( $web, $topic ) = @_;

    my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, 'viewauth' );

    return CGI::start_form(-name=>'editpreferences', -method=>'post',
                           -action=>$viewUrl );
}

sub handlePrefsEnd {
    return '</form>';
}

sub handleEditButton {
    my( $web, $topic, $doEdit ) = @_;

    my $text = '';
    if ( $doEdit ) {
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Edit');
    } else {
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Save');
        $text .= '&nbsp;&nbsp;';
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Cancel');
    }
    return $text;
}

sub handleSave {
    my( $web, $topic, $name, $value, $formDef ) = @_;

    my $newValue = $query->param( $name );

    my $fieldDef = getField( $formDef, $name );
    my $type = $fieldDef->{type};
    my $size = $fieldDef->{size};
    my $vals = $fieldDef->{value};

    if( $type =~ /^checkbox/ ) {
        $value = '';
        foreach my $item ( @$vals ) {
            my $cvalue = $query->param( $name.$item );
            if( defined( $cvalue ) ) {
                if( ! $value ) {
                    $value = '';
                } else {
                    $value .= ', ' if( $cvalue );
                }
                $value .= $item if( $cvalue );
            }
        }
        $newValue = $value;
    } elsif ( $type eq 'textarea' ) {
        $newValue =~ s/\r*\n/ /geo;
    }

    return $name.' = '.$newValue;
}

1;
