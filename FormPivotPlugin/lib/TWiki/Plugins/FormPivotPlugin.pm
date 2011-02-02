# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001 John talintyre, jet@cheerful.com for Dresdner Kleinwort Wasserstein
# Copyright (C) 2007-2011 TWiki Contributors. All Rights Reserved.
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
# TODO:
#   1. Only read information once
#   2. Don't analyse text fields by default
#   3. Watch out for rendering of data in tables e.g. in hrefs
#   4. Pivot on two fields

# =========================
package TWiki::Plugins::FormPivotPlugin;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE $debug );

$VERSION = '$Rev$';
$RELEASE = '2011-02-01';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between FormPivotPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "FORMPIVOTPLUGIN_DEBUG" ) || 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::FormPivotPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag
    # This is the place to define customized rendering rules

    $_[0] =~ s/%FORMPIVOT{([^}]+)}%/&pivot( $1 )/geo;
}

# =========================
sub pivot
{
   my( $args ) = @_;

   my $form    = TWiki::Func::extractNameValuePair( $args, "form" )   || '';
   my $fieldsp = TWiki::Func::extractNameValuePair( $args, "fields" ) || '';
   my $type    = TWiki::Func::extractNameValuePair( $args, "type" )   || '';

   TWiki::Func::writeDebug( "- TWiki::Plugins::FormPivotPlugin FORMPIVOT{ "
     . "form=\"$form\" fields=\"$fieldsp\" type=\"$type\" }" ) if $debug;

   my @fields = split( /, */, $fieldsp );
   if( ! @fields ) {
       @fields = getFormDefinition( $web, $form );
   }
   TWiki::Func::writeDebug( "- TWiki::Plugins::FormPivotPlugin fields: "
     . join( ', ', @fields ) ) if $debug;

   # Find all topics with this form.
   my $searchRegex = "%META:FORM\{.*name=\\\"$form\\\".*\}%";

   my @topicList = TWiki::Func::getTopicList( $web );
   my $grep = TWiki::Func::searchInWebContent( $searchRegex, $web, \@topicList,
        {
            type                => 'regex',
            casesensitive       => 1,
            files_without_match => 1
        }
   );

   if( ref( $grep ) eq 'HASH' ) {
      @topicList = keys %$grep;
   } else {
      @topicList = ();
      while( $grep->hasNext() ) {
         my $webtopic = $grep->next();
         my ($foundWeb, $topic) = TWiki::Func::normalizeWebTopicName($web, $webtopic);
         push( @topicList, $topic );
      }
   }
   TWiki::Func::writeDebug( "- TWiki::Plugins::FormPivotPlugin topic list: "
     . join( ', ', @topicList ) ) if $debug;

   my $pivot = "";
   my @found = ();
   my @foundTopic = ();

   for( my $i=0; $i<=$#fields; $i++ ) {
       my %hash = ();
       my %hashTopic = ();
       $found[$i] = \%hash;
       $foundTopic[$i] = \%hashTopic;
   }

   foreach my $formTopic ( @topicList ) {
       my( $meta, $text ) = TWiki::Func::readTopic( $web, $formTopic );
       for( my $i=0; $i<=$#fields; $i++ ) {
           my $name = $fields[$i];
           $name =~ s/\s*//go;
           my $field0 = $meta->get( "FIELD", $name );

           my @values = split( /,/, $field0->{value} );
           foreach my $value ( @values ) {
               $value =~ s/^\s*//go; # Trim left
               $value =~ s/\s*$//go; # Trim right
               if( ! $found[$i]->{$value} ) {
                   $found[$i]->{$value} = 1;
               } else {
                   $found[$i]->{$value} += 1;
               }
               if( ! $foundTopic[$i]->{$value} ) {
                   my %topics = ();
                   $foundTopic[$i]->{$value} = \%topics;
               }
               $foundTopic[$i]->{$value}->{$formTopic} = 1;
           }
       }
   }

   if( $type ne "grid" ) {
       for( my $i=0; $i<=$#fields; $i++ ) {
           my $field = $fields[$i];
           $pivot .= "---++ $field\n";

           my $table = "| *Field* | *Count* |\n";
           my $found1 = $found[$i];
           foreach my $key ( keys %$found1 ) {
               my $title = $key || "blank";
               # FIXME should use field name not title without spaces
               $field =~ s/\s*//go;
               # Problems passing = and " to URL
               my $searchVal = "%META:FIELD\{.*name..$field..*value..$key.*\}%";
               $title = "<a href=\"" . &TWiki::Func::getScriptUrl( $web, "", "search" )
                      . "?regex=on&search=$searchVal&nosearch=on\">$title</a>";
               $table .= "| $title | " . $found[$i]->{$key} . " |\n";
           }
           $pivot .= "$table";
       }
   }
      
   if( $type eq "grid") {
       my $fieldCol = $fields[1];
       my $hashCol  = $foundTopic[1];
       my $fieldRow = $fields[0];
       my $hashRow  = $foundTopic[0];
       $pivot .= "| |";
       foreach my $valueCol ( keys %$hashCol ) {
           $pivot .= " *$valueCol* |";
       }
       $pivot .= "\n";
       foreach my $valueRow ( keys %$hashRow ) {
           $pivot .= "| *$valueRow*  |";
           foreach my $valueCol ( keys %$hashCol ) {
              my $count = 0;
              my $hashRowTopics = $hashRow->{$valueRow};
              my $hashColTopics = $hashCol->{$valueCol};
              foreach my $rowTopic ( keys %$hashRowTopics ) {
                 $count++ if( $hashColTopics->{$rowTopic} );
              }
              my $searchVal = "%META:FIELD\{.*name%3D.$fieldRow..*value..$valueRow.*\}%%3B" .
                              "%META:FIELD\{.*name%3D.$fieldCol..*value..$valueCol.*\}%";
              #my $searchVal = "FIELD,$fieldRow,value,$valueRow,FIELD,$fieldCol,value,$valueCol";
              my $link = "<a href=\"" . &TWiki::Func::getScriptUrl( $web, "", "search" )
                       . "?regex=on&search=$searchVal&nosearch=on\">$count</a>";
              $pivot .= " $link |";
           }
           $pivot .= "\n";
       }
   }
   
   $pivot = &TWiki::Func::renderText( $pivot, $web );
   
   return $pivot;
}

# =========================
sub getFormDefinition
{
    my ( $web, $topic ) = @_;

    my @fields = ();
    ( $web, $topic ) = TWiki::Func::normalizeWebTopicName( $web, $topic );
    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    # code borrowed from TWiki::Form::_parseFormDefinition
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g; # remove trailing '\' and join continuation lines

    # | *Name:* | *Type:* | *Size:* | *Value:* |
    foreach my $line ( split( /\n/, $text ) ) {
        if( $line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
            next;
        }
        if( $inBlock && $line =~ s/^\s*\|\s*// ) {
            $line =~ s/\\\|/\007/g; # protect \| from split
            my( $name, $type, $size, $vals, $tooltip, $attributes ) =
              map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );
            $name ||= '';
            if( $name =~ /\[\[(.+)\]\[(.+)\]\]/ )  {
                $name = $2;
            }
            $name =~ s/<nop>//g; # support <nop> character in title
            $name =~ s/[^A-Za-z0-9_\.]//g;
            push( @fields, $name ) if( $name );

        } else {
            $inBlock = 0;
        }
    }
    return @fields;
}

# =========================
1;
