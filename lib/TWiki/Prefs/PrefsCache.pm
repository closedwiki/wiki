# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Prefs::PrefsCache

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

=cut

package TWiki::Prefs::PrefsCache;

use TWiki::Prefs::Parser;
use Assert;

=pod

---++ ClassMethod new( $prefs, $type, $web, $topic, $prefix )

Creates a new Prefs object.
   * =$prefs= - controlling TWiki::Prefs object
   * =$type= - Type of prefs object to create, see notes.
   * =$web= - web containing topic to load from (required is =$topic= is set)
   * =$topic= - topic to load from
   * =$prefix= - key prefix for all preferences (used for plugins)

If the specified topic is not found, returns an empty object.

=cut

sub new {
    my( $class, $prefs, $type, $web, $topic, $prefix ) = @_;

    ASSERT($prefs->isa( 'TWiki::Prefs')) if DEBUG;
    ASSERT($type) if DEBUG;

    my $this = bless( {}, $class );
    $this->{MANAGER} = $prefs;
    $this->{TYPE} = $type;

    if( $web && $topic ) {
        $this->loadPrefsFromTopic( $web, $topic, $prefix );
    }

    return $this;
}

=pod

---++ ObjectMethod loadPrefsFromTopic( $web, $topic, $keyPrefix )

Loads preferences from a topic. All settings loaded are prefixed
with the key prefix (default '').

=cut

sub loadPrefsFromTopic {
    my( $this, $web, $topic, $keyPrefix ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs::PrefsCache')) if DEBUG;

    $keyPrefix ||= '';

    $this->{SOURCE} = $web.'.'.$topic;

    my $session = $this->{MANAGER}->{session};
    if( $session->{store}->topicExists( $web, $topic )) {
        my( $meta, $text ) =
          $session->{store}->readTopic( undef, $web, $topic, undef );
        my $parser = new TWiki::Prefs::Parser();
        $parser->parseText( $text, $this, $keyPrefix );
        $parser->parseMeta( $meta, $this, $keyPrefix );
    }
}

=pod

---++ ObjectMethod insert($type, $key, $val)
Adds a key-value pair of the given type to the object. Type is Set or Local.
Callback used for the Prefs::Parser object, or can be used to add
arbitrary new entries to a prefs cache.

Note that final preferences can't be set this way, they can only
be set in the context of a full topic read, because they cannot
be finalised until after the whole topic has been read.

=cut

sub insert {
    my( $this, $type, $theKey, $theValue ) = @_;

    $theValue =~ s/\t/ /g;                 # replace TAB by space
    $theValue =~ s/([^\\])\\n/$1\n/g;      # replace \n by new line
    $theValue =~ s/([^\\])\\\\n/$1\\n/g;   # replace \\n by \n
    $theValue =~ s/`//g;                   # filter out dangerous chars
    if ( $theKey eq 'FINALPREFERENCES' ) {
        foreach ( split( /[\s,]+/, $theValue ) ) {
            $this->{final}{$_} = 1;
        }
    } else {
        $this->{$type}{$theKey} = $theValue;
    }
}

=pod

---++ ObjectMethod stringify($html, \%shown) -> $text
Generate an (HTML if $html) representation of the content of this cache.

=cut

sub stringify {
    my( $this, $html, $shown ) = @_;
    my $res;

    if( $html ) {
        $res = CGI::Tr( {style=>'background-color: yellow'},
                   CGI::Th( {colspan=>2}, $this->{TYPE}.' '.
                              $this->{SOURCE} ))."\n";
    } else {
        $res = '******** '.$this->{TYPE}.' '.$this->{SOURCE}."\n";
    }

    my %shown;

    foreach my $type qw( Set Local ) {
        foreach my $key ( sort keys %{$this->{$type}} ) {

            #next if $shown->{$type.$key};

            my $final = '';
            if ( $this->{final}{$key}) {
                $final = ' *final* ';
            }
            my $val = $this->{$type}{$key};
            $val =~ s/^(.{32}).*$/$1..../s;
            if( $html ) {
                $val = "\n<verbatim>\n$val\n</verbatim>\n" if $val;
                $res .= CGI::Tr( {valign=>'top'},
                                 CGI::td(" $type $final $key").
                                     CGI::td( $val ))."\n";
            } else {
                $res .= "$type $final $key = $val\n";
            }
            $shown->{$type.$key} = 1;
        }
    }
    return $res;
}

1;
