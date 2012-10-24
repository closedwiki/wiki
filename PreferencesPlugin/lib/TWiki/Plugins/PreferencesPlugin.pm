# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2012  TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the
# AUTHORS file in the root of this distribution.
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

# Still do to:
# Handle continuation lines (see Prefs::parseText). These should always
# go into a text area.

package TWiki::Plugins::PreferencesPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version
use Error qw(:try);

our $VERSION = '$Rev$';
our $RELEASE = '2012-10-24';

my @shelter;
my $MARKER = "\007";

# Markers used during form generation
my $START_MARKER  = $MARKER.'STARTPREF'.$MARKER;
my $END_MARKER    = $MARKER.'ENDPREF'.$MARKER;

my $SET_REGEX     =
    qr{^(((?:\t|   )+)\*\s+Set\s+)(\w+)\s*\=(.*$(\n(   |\t)+ *[^\s*].*$)*)}m;


sub initPlugin {
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between PreferencesPlugin and Plugins.pm' );
        return 0;
    }
    @shelter = ();

    return 1;
}

sub beforeCommonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;
    my $topic = $_[1];
    my $web = $_[2];
    return unless ( $_[0] =~ m/%EDITPREFERENCES(?:{(.*?)})?%/ );

    require CGI;
    require TWiki::Attrs;
    my $formDef;
    my $attrs = new TWiki::Attrs( $1 );
    if( defined( $attrs->{_DEFAULT} )) {
        my( $formWeb, $form ) = TWiki::Func::normalizeWebTopicName(
            $web, $attrs->{_DEFAULT} );

        # SMELL: Unpublished API. No choice, though :-(
        require TWiki::Form;    # SMELL
        $formDef =
          new TWiki::Form( $TWiki::Plugins::SESSION, $formWeb, $form );
    }
    my $editButton = $attrs->{editbutton} || 'Edit Preferences';

    my $query = TWiki::Func::getCgiQuery();

    my $action = lc $query->param( 'prefsaction' );
    $query->Delete( 'prefsaction' );
    $action =~ s/\s.*$//;

    if ( $action eq 'edit' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 1 );
        
        # Item7008
        TWiki::Func::addToHEAD('PreferencesPlugin', <<'END');
<!--[if IE]>
<style type='text/css'>
.twikiPrefFieldTable {display: inline}
.twikiPrefFieldDiv {display: inline}
</style>
<![endif]-->
<!--[if !IE]> -->
<style type='text/css'>
.twikiPrefFieldTable {display: inline-table}
.twikiPrefFieldDiv {display: inline}
</style>
<!-- <![endif]-->
END

        # Replace setting values by form fields but not inside comments Item4816
        my $outtext = '';
        my $insidecomment = 0;
        foreach my $token ( split/(<!--|-->)/, $_[0] ) {
            if ( $token =~ /<!--/ ) {
                $insidecomment++;
            } elsif ( $token =~ /-->/ ) {
                $insidecomment-- if ( $insidecomment > 0 );
            } elsif ( !$insidecomment ) {
                $token =~ s{$SET_REGEX}
                    {$1._generateEditField($web, $topic, $3, $4, $formDef)}ge;
            }
            $outtext .= $token;
        }
        $_[0] = $outtext;

        $_[0] =~ s/%EDITPREFERENCES({.*?})?%/
          _generateControlButtons($web, $topic)/ge;
        my $script = TWiki::Func::getContext()->{authenticated} ?
            'view' : 'viewauth';
        my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, $script );
        my $startForm = CGI::start_form(
            -name => 'editpreferences',
            -method => 'post',
            -action => $viewUrl );
        $startForm =~ s/\s+$//s;
        my $endForm = CGI::end_form();
        $endForm =~ s/\s+$//s;
        $_[0] =~ s/^(.*?)$START_MARKER(.*)$END_MARKER(.*?)$/$1$startForm$2$endForm$3/s;
        $_[0] =~ s/$START_MARKER|$END_MARKER//gs;
    }

    if( $action eq 'cancel' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );

    } elsif( $action eq 'save' ) {

        # save can only be used with POST method, not GET
        unless( $query && $query->request_method() !~ /^POST$/i ) {
            my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
            $text =~ s{$SET_REGEX}
                {$1._saveSet($query, $web, $topic, $3, $4, $formDef, $2)}ge;
            TWiki::Func::saveTopic( $web, $topic, $meta, $text );
        }
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );
        # Finish with a redirect so that the *new* values are seen
        my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, 'view' );
        TWiki::Func::redirectCgiQuery( undef, $viewUrl );
        return;
    }
    # implicit action="view", or drop through from "save" or "cancel"
    $_[0] =~ s/%EDITPREFERENCES({.*?})?%/_generateEditButton($web, $topic, $editButton)/ge;
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

# Item7008
sub _prefFieldClass {
    return "class='" .
        ($_[0] =~ /table/ ? 'twikiPrefFieldTable' : 'twikiPrefFieldDiv') .
        "'";
}

# Generate a field suitable for editing this type. Use of the core
# function 'renderFieldForEdit' ensures that we will pick up
# extra edit types defined in other plugins.
sub _generateEditField {
    my( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/gs;
    $value =~ s/\n[ \t]+/\n/g;

    my ($extras, $html);

    if( $formDef ) {
        my $fieldDef;
        if (defined(&TWiki::Form::getField)) {
            # TWiki 4.2 and later
            $fieldDef = $formDef->getField( $name );
        } else {
            # TWiki < 4.2
            $fieldDef = _getField( $formDef, $name );
        }
        if ( $fieldDef ) {
            if( defined(&TWiki::Form::renderFieldForEdit)) {
                # TWiki < 4.2 SMELL: use of unpublished core function
                ( $extras, $html ) =
                  $formDef->renderFieldForEdit( $fieldDef, $web, $topic, $value);
            } else {
                # TWiki 4.2 and later SMELL: use of unpublished core function
                ( $extras, $html ) =
                  $fieldDef->renderForEdit( $web, $topic, $value );
            }
        }
    }
    if ( $html ) {
        # Item7008
        $html =~ s/(<(table|div))\b/"$1 " . _prefFieldClass($1)/ie;
    }
    else {
        # No form definition, default to text field.
        $html = CGI::textfield( -class=>'twikiEditFormError twikiInputField',
                                -name => $name,
                                -size => 80, -value => $value );
    }

    push( @shelter, $html );

    return $START_MARKER.
      CGI::span({class=>'twikiAlert',
                 style=>'font-weight:bold;'},
                $name . ' = SHELTER' . $MARKER . $#shelter).$END_MARKER;
}

# Generate the button that replaces the EDITPREFERENCES tag in view mode
sub _generateEditButton {
    my( $web, $topic, $buttonLabel ) = @_;

    my $script = TWiki::Func::getContext()->{authenticated} ?
        'view' : 'viewauth';
    my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, $script );
    my $text = CGI::start_form(
        -name => 'editpreferences',
        -method => 'post',
        -action => $viewUrl . '#EditPreferences' );
    $text .= CGI::input({
        type => 'hidden',
        name => 'prefsaction',
        value => 'edit'});
    $text .= CGI::submit(-name => 'edit',
                         -value=> $buttonLabel,
                         -class=> 'twikiButton');
    $text .= CGI::end_form();
    $text =~ s/\n//sg;
    return $text;
}

# Generate the buttons that replace the EDITPREFERENCES tag in edit mode
sub _generateControlButtons {
    my( $web, $topic ) = @_;

    my $text = "#EditPreferences\n";
    $text .= $START_MARKER.CGI::submit( -name=>'prefsaction',
                                        -value=>'Save new settings',
                                        -class=>'twikiSubmit',
                                        -accesskey=>'s' );
    $text .= '&nbsp;';
    $text .= CGI::submit(-name=>'prefsaction', -value=>'Cancel',
                         -class=>'twikiButton',
                         -accesskey=>'c').$END_MARKER;
    return $text;
}

# Given a Set in the topic being saved, look in the query to see
# if there is a new value for the Set and generate a new
# Set statement.
sub _saveSet {
    my( $query, $web, $topic, $name, $value, $formDef, $indent ) = @_;

    my $newValue = $query->param( $name );
    $newValue = $value unless ( defined($newValue) );
    $newValue =~ s/^\s*(.*?)\s*$/$1/s;
    $newValue =~ s/\n/\n$indent/g;
    if( $formDef ) {
        my $fieldDef = _getField( $formDef, $name );
        my $type = $fieldDef->{type} || '';
        if( $type && $type =~ /^(checkbox|select\+multi)/ ) {
            my $val = '';
            foreach my $item ( $query->param( $name ) ) {
                if( defined $item && $item ne '' ) {
                    $val .= ', ' if( $val ne '' );
                    $val .= $item;
                }
            }
            $newValue = $val;
        }
    }
    # if no form def, it's just treated as text

    return $name.' = '.$newValue;
}

1;
