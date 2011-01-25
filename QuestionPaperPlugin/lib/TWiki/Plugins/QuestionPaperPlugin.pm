# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Author: Sopan Shewale (sopan.shewale@gmail.com)
#
# Copyright (C) 2009-2010 TWiki:Main.SopanShewale
# Copyright (C) 2009-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Plugins::QuestionPaperPlugin;

use strict;

require TWiki::Func;       # The plugins API
require TWiki::Plugins;    # For the API version

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2011-01-24';

$SHORTDESCRIPTION =
  'Define and print question paper/assignments, helpful for school teachers and parents';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'QuestionPaperPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{QuestionPaper}{Debug} || 0;

    return 1;
}

sub commonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # do custom extension rule, like for example:
    $_[0] =~ s/%QUESTIONPAPER%/&questionPaper()/ge;
    $_[0] =~ s/%QUESTIONPAPER{(.*?)}%/&_questionPaper($1)/ge;
}

sub _questionPaper {
    my $arguments = shift;
    my %attrs     = TWiki::Func::extractParameters($arguments);

    my $type = $attrs{'type'} || undef;
    if ( $type eq 'short' ) {
        my $result = _shortDescription( \%attrs );
        return $result;
    }
    elsif ( $type eq 'multiplechoice' ) {
        my $result = _multipleChoice( \%attrs );
        return $result;
    }
    elsif ( $type eq 'matching' ) {
        my $result = _matching( \%attrs );
        return $result;
    }
    elsif ( $type eq 'fillblanks' ) {

        my $result = _fillBlanks( \%attrs );
        return $result;

    }
    else { }

    return "Please format the question properly\n";

}

sub _multipleChoice {
    my $attrs    = shift;
    my $question = $attrs->{'question'};

    my $qtag = $attrs->{'questiontag'} || 'Q. ';
    my $atag = $attrs->{'answertag'}   || 'Ans. ';
    my %choices;

    foreach ( 1 .. 10 ) {
        if ( defined $attrs->{$_} ) { $choices{$_} = $attrs->{$_}; }
    }

    my $form = '<form><BR>';
    foreach ( 1 .. 10 ) {
        if ( defined $choices{$_} ) {
            $form =
                $form
              . "$_. $choices{$_}"
              . '<input type="checkbox" name="choice" value="" /><BR>';
        }

    }
    $form = $form . '</form>';

    $question =
      '<b>' . $qtag . '</b>' . $question . '<BR><b>' . $atag . '</b>' . $form;

    return $question;

}

sub _shortDescription {
    my $attrs     = shift;
    my $formatedQ = '';
    my $question  = $attrs->{'question'} || 'Question Not Defined\n';
    my $qtag      = $attrs->{'questiontag'} || 'Q. ';
    $formatedQ = $formatedQ . '<b>' . $qtag . '</b>';
    $formatedQ = $formatedQ . $question . "<BR>";

    my $atag = $attrs->{'answertag'} || 'Ans. ';

    my $nolines = $attrs->{'lines'} || 4;
    my $space =
'&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;';
    $formatedQ = $formatedQ . '<b>' . $atag . '</b>' . '<u> ' . $space . '</u>';
    my $lines = ( $space . '<BR>' ) x $nolines;
    $formatedQ = $formatedQ . "<BR>" . '<u>' . $lines . '</u>';

    return $formatedQ;

}

sub _fillBlanks {
    my $attrs = shift;
    my $width = $attrs->{'width'} || 2;
    my $space = '&nbsp; &nbsp; &nbsp; &nbsp; ';
    $space = ($space) x $width;
    $space = '<u>' . $space . '</u>';

    my $question = $attrs->{'question'};
    $question =~ s/\$blank/$space/g;
    return $question;

}

sub _matching {
    my $attrs    = shift;
    my $question = $attrs->{'question'};

    my $qtag = $attrs->{'questiontag'} || 'Q. ';
    my $atag = $attrs->{'answertag'}   || 'Ans. ';
    my %A_side;
    my %B_side;

    foreach ( 1 .. 10 ) {
        my $key = 'A_' . $_;
        if ( defined $attrs->{$key} ) {
            $A_side{$_} = $attrs->{$key};
        }
    }

    foreach ( 1 .. 10 ) {
        my $key = 'B_' . $_;
        if ( defined $attrs->{$key} ) {
            $B_side{$_} = $attrs->{$key};
        }
    }

    my $table = '<table>';
    foreach ( 1 .. 10 ) {
        if ( $A_side{$_} && $B_side{$_} ) {
            $table =
                $table . '<tr> ' . '<td> '
              . $A_side{$_}
              . ' </td>' . '<td>'
              . ' &nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp;'
              . '<td>'
              . $B_side{$_} . '</td>' . '</tr>';
        }
    }

    $table = $table . '</table>';

    return '<b>' 
      . $qtag . '</b>'
      . $question . '<BR>' . '<b>'
      . $atag . '</b>'
      . $table;
}

1;
