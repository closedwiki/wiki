# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 Peter Thoeny, peter@thoeny.org
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
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Prefs::PrefsCache

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

As each cache level is built, the values are copied down from the parent
cache level. This sounds monstrously inefficient, but in fact perl does
this a lot better than doing a multi-level lookup when a value is referenced.
This is especially important when many prefs lookups may be done in a
session, for example when searching.

---++ Exported instance variables
   * {locals} Contains all locals at this level. Locals are values that
     only apply when the current topic is the topic where the local is
     defined. The variable names are decorated with the locality where
     they apply.
   * {values} contains all sets, locals, and all values inherited from
     the parent level
   * {final} Boolean hash, maps to true if {final}{key} is true at this level

=cut

package TWiki::Prefs::PrefsCache;

@TWiki::Prefs::PrefsCache::ISA = qw( TWiki::Disposable );

use TWiki::Prefs::Parser;
use Assert;

=pod

---++ ClassMethod new( $prefs, $parent, $type, $web, $topic, $prefix )

Creates a new Prefs object.
   * =$prefs= - controlling TWiki::Prefs object
   * =$parent= - the PrefsCache object to use to initialise values from
   * =$type= - Type of prefs object to create, see notes.
   * =$web= - web containing topic to load from (required is =$topic= is set)
   * =$topic= - topic to load from
   * =$prefix= - key prefix for all preferences (used for plugins)
If the specified topic is not found, returns an empty object.

=cut

sub new {
    my( $class, $prefs, $parent, $type, $web, $topic, $prefix) = @_;

    ASSERT($prefs->isa( 'TWiki::Prefs')) if DEBUG;
    ASSERT($type) if DEBUG;

    my $this = bless( {}, $class );
    $this->{_manager} = $prefs;
    $this->{_type} = $type;
    $this->{_source} = '';
    $this->{_context} = $prefs;

    if( $parent && $parent->{values} ) {
        %{$this->{values}} = %{$parent->{values}};
    }
    if( $parent && $parent->{locals} ) {
        %{$this->{locals}} = %{$parent->{locals}};
    }

    if( $web && $topic ) {
        $this->loadPrefsFromTopic( $web, $topic, $prefix );
    }

    return $this;
}

# Clean up this object
sub cleanUp {
    my $this = shift;

    %$this = ();
}

=pod

---++ ObjectMethod finalise( $parent )
Finalise preferences in this cache, by freezing any preferences
listed in FINALPREFERENCES at their current value.
   * $parent = object that supports getPreferenceValue

=cut

sub finalise {
    my $this = shift;

    my $value = $this->{values}{FINALPREFERENCES};
    if( $value ) {
        foreach ( split( /[\s,]+/, $value ) ) {
            # Note: cannot refinalise an already final value
            unless( $this->{_context}->isFinalised( $_ )) {
                $this->{final}{$_} = 1;
            }
        }
    }
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

    $this->{_source} = $web.'.'.$topic;

    my $session = $this->{_manager}->{session};
    if( $session->{store}->topicExists( $web, $topic )) {
        my( $meta, $text ) =
          $session->{store}->readTopic( undef, $web, $topic, undef );

        my $parser = new TWiki::Prefs::Parser();
        $parser->parseText( $text, $this, $keyPrefix );
        $parser->parseMeta( $meta, $this, $keyPrefix );
    }
}

=pod

---++ ObjectMethod loadPrefsFromText( $text, $web, $topic )

Loads preferences from a topic. All settings loaded are prefixed
with the key prefix (default '').

=cut

# SMELL: this is required because TWiki stores access control
# information in topic text; a dreadful idea, but one we are
# stuck with.

sub loadPrefsFromText {
    my( $this, $text, $web, $topic ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs::PrefsCache')) if DEBUG;

    $this->{_source} = $web.'.'.$topic;

    my $session = $this->{_manager}->{session};
    my $meta = new TWiki::Meta( $session, $web, $topic );
    $session->{store}->extractMetaData( $meta, \$text );

    my $parser = new TWiki::Prefs::Parser();
    $parser->parseText( $text, $this, '' );
    $parser->parseMeta( $meta, $this, '' );
}

=pod

---++ ObjectMethod insert($type, $key, $val)
Adds a key-value pair of the given type to the object. Type is Set or Local.
Callback used for the Prefs::Parser object, or can be used to add
arbitrary new entries to a prefs cache.

Note that attempts to redefine final preferences will be ignored.

=cut

sub insert {
    my( $this, $type, $key, $value ) = @_;

    return if $this->{_context}->isFinalised( $key );

    $value =~ s/\t/ /g;                 # replace TAB by space
    $value =~ s/([^\\])\\n/$1\n/g;      # replace \n by new line
    $value =~ s/([^\\])\\\\n/$1\\n/g;   # replace \\n by \n
    $value =~ s/`//g;                   # filter out dangerous chars
    if( $type eq 'Local' ) {
        $this->{locals}{$this->{_source}.'-'.$key} = $value;
    } else {
        $this->{values}{$key} = $value;
    }
    $this->{_setHere}{$key} = 1;
}

=pod

---++ ObjectMethod stringify($html, \%shown) -> $text
Generate an (HTML if $html) representation of the content of this cache.

=cut

sub stringify {
    my( $this, $html ) = @_;
    my $res;

    if( $html ) {
        $res = CGI::Tr( {style=>'background-color: yellow'},
                   CGI::th( {colspan=>2}, $this->{_type}.' '.
                              $this->{_source} ))."\n";
    } else {
        $res = '******** '.$this->{_type}.' '.$this->{_source}."\n";
    }

    foreach my $key ( sort keys %{$this->{values}} ) {
        next unless $this->{_setHere}{$key};
        my $final = '';
        if ( $this->{final}{$key}) {
            $final = ' *final* ';
        }
        my $val = $this->{values}{$key};
        $val =~ s/^(.{32}).*$/$1..../s;
        if( $html ) {
            $val = "\n<verbatim>\n$val\n</verbatim>\n" if $val;
            $res .= CGI::Tr( {valign=>'top'},
                             CGI::td(" Set $final $key").
                                 CGI::td( $val ))."\n";
        } else {
            $res .= "Set $final $key = $val\n";
        }
    }
    foreach my $key ( sort keys %{$this->{locals}} ) {
        next unless $this->{_setHere}{$key};
        my $final = '';
        my $val = $this->{locals}{$key};
        $val =~ s/^(.{32}).*$/$1..../s;
        if( $html ) {
            $val = "\n<verbatim>\n$val\n</verbatim>\n" if $val;
            $res .= CGI::Tr( {valign=>'top'},
                             CGI::td(" Local $key").
                                 CGI::td( $val ))."\n";
        } else {
            $res .= "Local $key = $val\n";
        }
    }
    return $res;
}

1;
