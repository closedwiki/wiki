# FormFieldListPlugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Bernd Raichle, bernd.raichle@gmx.de
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# =========================
#
# FormFieldListPlugin
#
# The plugin can be used to format a sequence of FORMFIELD values.
#
# Syntax:
#   %FORMFIELDLIST{ "comma-separated sequence of form field names"
#                    topic="..."     (optional: default is %TOPIC%)
#                    alttext="..."   (optional: default '')
#                    default="..."   (optional: default '')
#                    separator="..." (optional: default is $n)
#                    format="..."    (optional: default is $title=$value)
#                 }%
#
#   This text string expression must appear on one line.
#
#   =format= will be inserted for all existing fields with
#   non-empty values.
#   =alttext= will be inserted for all existing fields with
#   empty values.
#   =default= will be inserted for all non-existing fields.
#   =separator= will be inserted between all non-empty output
#   records.
#
#   Inside =format= the variable =$value= will expand to the
#   field value.
#   Inside =format= and =default= the variables =$name= and
#   =$title= will expand to the field name (without spaces)
#   and the field title (field name as specified in the form).
#   Inside =alttext= the variables =$name= and
#   =$title= will both expand to the given but non-existing
#   form field name.
#
#   The variable $n will expand to newline in the parameters
#   =alttext=, =default=, =separator=, and =format=.
#
#
#
# Change history:
# r1.000 2004/10/01 - initial revision
#


# =========================
package TWiki::Plugins::FormFieldListPlugin;

# =========================
use strict;

# Unless this code is not integrated into TWiki::Render, use the same form cache.
# WARNING: This can break if the use of $ffCache in TWiki::Render::getFormField() will change.
use TWiki::Render qw(%ffCache);

use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
	$debug
    );

$VERSION = '1.000';
$pluginName = 'FormFieldListPlugin';   # Name of this Plugin

# =========================



# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        &TWiki::Func::writeWarning( "Version mismatch between ${pluginName} and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPluginPreferencesValue( "DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}



=pod

---++ sub getFormFieldList ( $web, $topic, $args )

+Returns the expansion of a %FORMFIELDLIST{}% tag.

=cut

sub getFormFieldList
{
    my( $web, $topic, $args ) = @_;

    &TWiki::Func::writeDebug( "- getFormFieldList(web $web, topic $topic, args $args)" ) if $debug;

    my $formFieldList = TWiki::extractNameValuePair( $args );   # CHANGED $formField -> $formFieldList
    my $formTopic = TWiki::extractNameValuePair( $args, "topic" );
    my $altText   = TWiki::extractNameValuePair( $args, "alttext" );
    my $default   = TWiki::extractNameValuePair( $args, "default" ) || undef;
    my $format    = TWiki::extractNameValuePair( $args, "format" );

    # BEGIN NEW
    my $separator = TWiki::extractNameValuePair( $args, "separator" );
    unless ( $separator ) {
	if ( $args =~ m/separator\s*=/o ) {
	    # If empty separator explicitly set, use it
	    $separator = '';
	} else {
	    # Otherwise default to newline ($n)
	    $separator = '$n';
	}
    }
    # END NEW

    unless ( $format ) {
	# if null format explicitly set, return empty
	return "" if ( $args =~ m/format\s*=/o);
	# Otherwise default to value
	$format = '$title=$value ';   # CHANGED
    }

    # BEGIN NEW
    &TWiki::Func::writeDebug( "- getFormFieldList() topic=$formTopic, alttext=$altText, default=$default, format=$format, separator=$separator.." ) if $debug;
    # END NEW

    my $formWeb;
    if ( $formTopic ) {
	if ($topic =~ /^([^.]+)\.([^.]+)/o) {
	    ( $formWeb, $topic ) = ( $1, $2 );
	} else {
         # SMELL: Undocumented feature, "web" parameter
	    $formWeb = TWiki::extractNameValuePair( $args, "web" );
	}
	$formWeb = $web unless $formWeb;
    } else {
	$formWeb = $web;
	$formTopic = $topic;
    }

    my $meta = $TWiki::Render::ffCache{"$formWeb.$formTopic"};
    unless ( $meta ) {
	my $dummyText;
       ( $meta, $dummyText ) =
	   TWiki::Store::readTopic( $formWeb, $formTopic );
	$TWiki::Render::ffCache{"$formWeb.$formTopic"} = $meta;
    }

    # BEGIN CHANGE
    my $text = "";
    my $outputSeparator = 0;
    if ( $meta ) {
	my @fields = $meta->find( "FIELD" );

	# Split the comma-separated list of form field names
	# removing leading and trailing white-spaces.
	foreach my $formField ( split( /\s*,\s*/, $formFieldList) ) {

	    &TWiki::Func::writeDebug( "- search for field $formField." ) if $debug;

	    $text .= $separator if ( $outputSeparator );
	    $outputSeparator = 1;

	    my $found = 0;
	    foreach my $field ( @fields ) {
		my $title = $field->{"title"};
		my $name = $field->{"name"};
		if( $title eq $formField || $name eq $formField ) {
		    $found = 1;
		    my $value = $field->{"value"};
		    my $newtext = '';
		    if (length $value) {
			$newtext = $format;
			$newtext =~ s/\$value/$value/go;  # expand "$value" to value of field
		    } elsif ( defined $default ) {
			$newtext = $default;
		    }
		    $newtext =~ s/\$name/$name/go;
		    $newtext =~ s/\$title/$title/go;

		    &TWiki::Func::writeDebug( "- search for field $formField: $newtext." ) if $debug;

		    $outputSeparator = 0 if (! $newtext);
		    $text .= $newtext;
		    last; #one hit suffices
		}
	    }
	    unless ( $found ) {
		my $newtext = $altText;
		$newtext =~ s/\$name/$formField/go;
		$newtext =~ s/\$title/$formField/go;

		$outputSeparator = 0 if (! $newtext);
		$text .= $newtext;
	    }


	    &TWiki::Func::writeDebug( "- result = $text." ) if $debug;
	}
    }

    return "" unless $text;

    &TWiki::Func::writeDebug( "- before expansion = $text." ) if $debug;

    $text =~ s/\$n/\n/gos;       # expand "$n" to new line
    $text =~ s/\$percnt/\%/gos;  # expand "$n" to new line
    $text =~ s/\$dollar/\$/gos;  # expand "$n" to new line

    &TWiki::Func::writeDebug( "- after expansion = $text." ) if $debug;
    # END CHANGE

    return &TWiki::Render::getRenderedVersion( $text, $web );
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%FORMFIELDLIST{(.*?)}%/&getFormFieldList($_[2], $_[1], $1)/ge;
}


1;
