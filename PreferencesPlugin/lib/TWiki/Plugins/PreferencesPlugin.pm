# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, Peter@Thoeny.com
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

# =========================
package TWiki::Plugins::PreferencesPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $pluginName
        $query $encodeStart $encodeEnd $len
    );

$VERSION = '1.024';
$encodeStart = "--EditTableEncodeStart--";
$encodeEnd   = "--EditTableEncodeEnd--";

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

$pluginName = 'PreferencesPlugin';

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "PREFERENCESPLUGIN_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    if ( $_[0] =~ m/%EDITPREFERENCES{\s*\"(.*?)\"\s*}%/ ) {
      my $insideVerbatim = 0;
      my $formWeb = $web;
      my $form = $1;
      $form = TWiki::Func::expandCommonVariables( $form, $topic, $web );
      if( $form =~ m/(.*?)\.(.*)/ ) {
	$formWeb = $1;
	$form = $2;
      }
      $query = &TWiki::Func::getCgiQuery();

      $_[0] = &handlePrefsStart( $_[2], $_[1] ) . $_[0] . &handlePrefsEnd();
      my $action = lc $query->param( 'prefsaction' );

      my @fieldsInfo = &TWiki::Form::getFormDef( $formWeb, $form );
      my %fields = ();
      foreach my $c ( @fieldsInfo ) {
	my @fieldInfo = @$c;
	my $fieldName = shift @fieldInfo;
	my $name = $fieldName;
	my $title = shift @fieldInfo;
	my $type = shift @fieldInfo;
	my $size = shift @fieldInfo;
	my $tooltip = shift @fieldInfo;
	my $attributes = shift @fieldInfo;
	$fields{$name} = [ $type, $size, @fieldInfo ];
      }

      if ( $action eq 'edit' ) {

	$len = TWiki::Func::getPluginPreferencesValue( "DEFAULTLENGTH" ) || "30";
	TWiki::Func::setTopicEditLock( $web, $topic, 1 );

	my $result = "";
	my $verbatim = "";

	foreach( split( /\r?\n/, $_[0] ) ) {

	  if ( /<verbatim>/ ) {
	    $insideVerbatim = 1;
	    $verbatim = "";
	    $result .= $_;
	    $result .= "\n";
	  } elsif ( /<\/verbatim>/ ) {
	    $insideVerbatim = 0;
            $result .= $_;
	    $result .= "\n";
            $result .= $verbatim;
	    $result .= "\n";
	  } else {
	    if ( /^(\t+)\*\sSet\s(\w+)\s\=(.*)$/ ) {
	      if( $insideVerbatim ) {
                 $verbatim .= &handleSet($_[2], $_[1], $2, $3, $1, %fields);
	         $verbatim .= "\n";
              } else {
                 $result .= &handleSet($_[2], $_[1], $2, $3, $1, %fields);
	         $result .= "\n";
              }
            } else {
              $result .= $_;
   	      $result .= "\n";
            }
          }
        }
        $_[0] = $result;
	$_[0] =~ s/%EDITPREFERENCES.*%/&handleEditButton($_[2], $_[1], 0)/eo;
      } elsif ( $action eq 'cancel' ) {
	 TWiki::Func::setTopicEditLock( $web, $topic, 0 );  # unlock Topic
	 my $url = &TWiki::Func::getViewUrl( $web, $topic );
	 &TWiki::Func::redirectCgiQuery( $query, $url );
	 return 0;
	
      } elsif ( $action eq 'save' ) {

	$text = &TWiki::Func::readTopicText( $web, $topic );
	$text =~ s/^(\t+)\*\sSet\s(\w+)\s\=(.*)$/&handleSave($_[2], $_[1], $2, $3, $1, %fields)/mgeo;

	my $error = &TWiki::Func::saveTopicText( $web, $topic, $text, "" );
	TWiki::Func::setTopicEditLock( $web, $topic, 0 );  # unlock Topic
	my $url = &TWiki::Func::getViewUrl( $web, $topic );
	if( $error ) {
	  $url = &TWiki::Func::getOopsUrl( $web, $topic, "oopssaveerr", $error );
	}
	&TWiki::Func::redirectCgiQuery( $query, $url );
	return 0;

      } else {
	$_[0] =~ s/%EDITPREFERENCES.*%/&handleEditButton($_[2], $_[1], 1)/ge;
      }
      
    }

}

# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

    return unless $_[0] =~ /$encodeStart/os;

    $_[0] =~ s/$encodeStart(.*?)$encodeEnd/&decodeValue($1)/geos;
}

# =========================

sub handleSet {
  my( $web, $topic, $name, $value, $pre, %fields ) = @_;
  $value =~ s/^\s*(.*?)\s*$/$1/ge;
  my @fld = @{$fields{$name}};
  my $type = shift @fld || "";
  my $size = shift @fld || "";
  $text = "$pre* Set $name = <noautolink>";
  if( $type eq "text" ) {
    $value = $encodeStart . encodeValue( $value ) . $encodeEnd unless( $value eq "" );
    $text .= "<input type = \"text\" size=\"$size\" name=\"$name\" value=\"$value\" />\n";
  } elsif( $type eq "textarea" ) {
    my $cols = 40;
    my $rows = 5;
    if( my $size =~ /([0-9]+)x([0-9]+)/ ) {
      $cols = $1;
      $rows = $2;
    }
    $value = $encodeStart . encodeValue( $value ) . $encodeEnd unless( $value eq "" );
    $text .= "<textarea cols=\"$cols\" rows=\"$rows\" name=\"$name\">$value</textarea>";
  } elsif( $type eq "select" ) {
    my $val = "";
    my $matched = "";
    my $defaultMarker = "%DEFAULTOPTION%";
    foreach my $item ( @fld ) {
      my $selected = $defaultMarker;
      if( $item eq $value ) {
	$selected = ' selected="selected"';
	$matched = $item;
      }
      $defaultMarker = "";
      $item =~ s/<nop/&lt\;nop/go;
      $val .= "   <option$selected>$item</option>";
    }
    if( ! $matched ) {
      $val =~ s/%DEFAULTOPTION%/ selected="selected"/go;
    } else {
      $val =~ s/%DEFAULTOPTION%//go;
    }
    $value = $encodeStart . encodeValue( $val ) . $encodeEnd unless( $val eq "" );
    $text .= "<select name=\"$name\" size=\"$size\">$val</select>";
  } elsif( $type =~ "^checkbox" ) {
    my $val ="<table cellspacing=\"0\" cellpadding=\"0\"><tr>";
    my $lines = 0;
    foreach my $item ( @fld ) {
      my $flag = "";
      my $expandedItem = &TWiki::Func::expandCommonVariables( $item, $topic );
      if( $value =~ /(^|,\s*)\Q$item\E(,|$)/ ) {
	$flag = ' checked="checked"';
      }
      $expandedItem = $encodeStart . encodeValue( $expandedItem ) . $encodeEnd unless( $expandedItem eq "" );
      $val .= "\n<td><input type=\"checkbox\" name=\"$name$item\"$flag />$expandedItem &nbsp;&nbsp;</td>";
      if( $size > 0 && ($lines % $size == $size - 1 ) ) {
	$val .= "\n</tr><tr>";
      }
      $lines++;
    }
    $val =~ s/\n<\/tr><tr>$//;
    $text .= "$val\n</tr></table>\n";
  } elsif( $type eq "radio" ) {
    my $lines = 0;
    foreach my $item ( @fld ) {
      my $selected = $defaultMarker;
      my $expandedItem = &TWiki::Func::expandCommonVariables( $item, $topic );
      if( $item eq $value ) {
	$selected = ' checked="checked"';
	$matched = $item;
      }
      $defaultMarker = "";
      $expandedItem = $encodeStart . encodeValue( $expandedItem ) . $encodeEnd unless( $expandedItem eq "" );
      $val .= "\n<td><input type=\"radio\" name=\"$name\" value=\"$item\" $selected />$expandedItem &nbsp;&nbsp;</td>";
      if( $size > 0 && ($lines % $size == $size - 1 ) ) {
	$val .= "\n</tr><tr>";
      }
      $lines++;
    }
    if( ! $matched ) {
      $val =~ s/%DEFAULTOPTION%/ checked="checked"/go;
    } else {
      $val =~ s/%DEFAULTOPTION%//go;
    }
    $val =~ s/\n<\/tr><tr>$//;
    $value = "$val\n</tr></table>\n";
  } elsif( $type eq "date" ) {
    my $ifFormat = TWiki::Func::getPreferencesValue("JSCALENDARDATEFORMAT", "$web") || "%d %b %Y";
    my $ifOptions = TWiki::Func::getPreferencesValue("JSCALENDAROPTIONS", "$web") || "";
    my $size = 10 if ($size < 1);
    $text .= "<input type=\"text\" name=\"$name\" id=\"id$name\"size=\"$size\" value=\"$value\" /><button type=\"reset\" id=\"trigger$name\">...</button><script type=\"text/javascript\">Calendar.setup({inputField : \"id$name\", ifFormat : \"$ifFormat\", button : \"trigger$name\", singleClick : true $ifOptions });</script>";
    $query->{'jscalendar'} = 1;
  } else {
    # Treat like text, make it reasonably long
    $value = $encodeStart . encodeValue( $value ) . $encodeEnd unless( $value eq "" );
    $text .= "<input type=\"text\" name=\"$name\" size=\"$len\" value=\"$value\" />";
  }

  $text .= "</noautolink>";

  return $text;

}

# =========================
sub encodeValue
{
    my( $theText ) = @_;

    # FIXME: *very* crude encoding to escape Wiki rendering inside form fields
    $theText =~ s/\./%dot%/gos;
    $theText =~ s/(.)/\.$1/gos;

    return $theText;
}

# =========================
sub decodeValue
{
    my( $theText ) = @_;

    $theText =~ s/\.(.)/$1/gos;
    $theText =~ s/%dot%/\./gos;
    $theText =~ s/\&([^#a-z])/&amp;$1/go; # escape non-entities
    $theText =~ s/</\&lt;/go;             # change < to entity
    $theText =~ s/>/\&gt;/go;             # change > to entity
    $theText =~ s/\"/\&quot;/go;          # change " to entity

    return $theText;
}

sub handlePrefsStart {
    my( $web, $topic ) = @_;

    my $viewUrl = &TWiki::Func::getScriptUrl( $web, $topic, "viewauth" );

    return "<form name=\"editpreferences\" method=\"post\" action=\"$viewUrl\"  />\n";
    
}

sub handlePrefsEnd {
    return "</form>\n";
}

sub handleEditButton
{
    my( $web, $topic, $doEdit ) = @_;

    my $text = "";
    if ( $doEdit ) {
      $text .= "<input type=\"submit\" name=\"prefsaction\" value=\"Edit\" />\n";
    } else {
      $text .= "<input type=\"submit\" name=\"prefsaction\" value=\"Save\" />\n";
      $text .= "&nbsp;&nbsp;";
      $text .= "<input type=\"submit\" name=\"prefsaction\" value=\"Cancel\" />\n";
    }
    return $text;
}

sub handleSave {
    my( $web, $topic, $name, $value, $pre, %fields ) = @_;

    my $newValue = $query->param( "$name" );

    my @fld = @{$fields{$name}};
    my $type = shift @fld;
    my $size = shift @fld;

    if( $type =~ "^checkbox" ) {
      $value = "";
      foreach my $item ( @fld ) {
	my $cvalue = $query->param( "$name$item" );
	if( defined( $cvalue ) ) {
	  if( ! $value ) {
	    $value = "";
	  } else {
	    $value .= ", " if( $cvalue );
	  }
	  $value .= "$item" if( $cvalue );
	}
      }
      $newValue = $value;
    } elsif ( $type eq "textarea" ) {
      $newValue =~ s/\r*\n/ /geo;
    }


    return $pre . "* Set $name = $newValue";
}

1;
