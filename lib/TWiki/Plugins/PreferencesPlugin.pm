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

my $MARKER = "\007";

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

    return unless ( $_[0] =~ m/%EDITPREFERENCES{\s*\"(.*?)\"\s*}%/ );
    my $form = $1;
    my $insideVerbatim = 0;
    my $formWeb = $web;
    $form = TWiki::Func::expandCommonVariables( $form, $topic, $web );
    if( $form =~ m/(.*?)\.(.*)/ ) {
        $formWeb = $1;
        $form = $2;
    }
    $query = TWiki::Func::getCgiQuery();

    my $action = lc $query->param( 'prefsaction' );

    # SMELL: Unpublished API. No choice, though :-(
    my $formDef = new TWiki::Form( $TWiki::Plugins::SESSION,
                                   $formWeb, $form );

    if ( $action eq 'edit' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 1 );

        $_[0] =~ s(^(\t+\*\sSet\s)(\w+)\s\=(.*$(\n[ \t]+[^\s*].*$)*))
          ($1._generateEditField($web, $topic, $2, $3, $formDef))gem;
        $_[0] =~ s(%EDITPREFERENCES.*%)
          (_generateButtons($web, $topic, 0))eo;

    } elsif ( $action eq 'cancel' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );
        my $url = TWiki::Func::getViewUrl( $web, $topic );
        TWiki::Func::redirectCgiQuery( $query, $url );
        return 0;

    } elsif ( $action eq 'save' ) {

        my $text = TWiki::Func::readTopicText( $web, $topic );
        $text =~ s(^(\t+\*\sSet\s)(\w+)\s\=(.*)$)
          ($1._saveSet($web, $topic, $2, $3, $formDef))mgeo;

        my $error = TWiki::Func::saveTopicText( $web, $topic, $text, '' );
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );
        my $url;
        if( $error ) {
            $url = $error;
        } else {
            $url = TWiki::Func::getViewUrl( $web, $topic );
        }
        TWiki::Func::redirectCgiQuery( $query, $url );
        return 0;

    } else {
        # implicit action="view"
        $_[0] =~ s(%EDITPREFERENCES.*%)
          (_generateButtons($web, $topic, 1))ge;
    }

    my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, 'viewauth' );
    $_[0] = CGI::start_form(-name => 'editpreferences', -method => 'post',
                            -action => $viewUrl ).
                              $_[0].
                                CGI::end_form();
}

# Use the post-rendering handler to plug our formatted editor units
# into the text
sub postRenderingHandler {
    ### my ( $text ) = @_;

    $_[0] =~ s/SHELTER$MARKER(\d+)/$shelter[$1]/g;
}

# Pluck the default value of a named field from a form definition
sub _getField {
    my( $formDef, $name ) = @_;
    foreach my $f ( @{$formDef->{fields}} ) {
        if( $f->{name} eq $name ) {
            return $f;
        }
    }
    return undef;
}

# Generate a field suitable for editing this type. Use of the core
# function 'renderFieldForEdit' ensures that we will pick up
# extra edit types defined in other plugins.
sub _generateEditField {
    my( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $fieldDef = _getField( $formDef, $name );

    my $extras;

    # SMELL: use of unpublished core function
    ( $extras, $value ) =
      $formDef->renderFieldForEdit( $fieldDef, $web, $topic, $value);

    push( @shelter, $value );

    return CGI::span({class=>'twikiAlert'},
                    $name.' = SHELTER'.$MARKER.$#shelter);
}

# Generate the buttons that replace the EDITPREFERENCES tag, depending
# on the mode
sub _generateButtons {
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

# Given a Set in the topic being saved, look in the query to see
# if there is a new value for the Set and generate a new
# Set statement.
sub _saveSet {
    my( $web, $topic, $name, $value, $formDef ) = @_;

    my $newValue = $query->param( $name ) || $value;

    my $fieldDef = _getField( $formDef, $name );
    my $type = $fieldDef->{type} || '';

    if( $type && $type =~ /^checkbox/ ) {
        $value = '';
        my $vals = $fieldDef->{value};
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
    }

    return $name.' = '.$newValue;
}

1;
