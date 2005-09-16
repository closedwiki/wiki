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

---+ package TWiki::Prefs

The Prefs class is a singleton that implements management of preferences.
It uses a stack of TWiki::Prefs::PrefsCache objects to store the
preferences for global, web, user and topic contexts, and provides
the means to look up preferences in these.

Preferences from different places stack on top of each other, so there
are global preferences, then site, then web (and subweb and subsubweb),
then topic, included topic and so on. Each level of the stack is tagged with
a type identifier.

The module also maintains a separate of the preferences found in every topic
and web it reads. This supports the lookup of preferences for webs and topics
that are not on the stack, and must not be chained in (you can't allow
a user to override protections from their home topic!)

=cut

package TWiki::Prefs;

use TWiki::Prefs::PrefsCache;
use Assert;

=pod

---++ ClassMethod new( $session [, $cache] )

Creates a new Prefs object. If $cache is defined, it will be
pushed onto the stack.

=cut

sub new {
    my( $class, $session, $cache ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;
    push( @{$this->{PREFS}}, $cache ) if defined( $cache );
    # $this->{CACHE} - hash of TWiki::Prefs objects, for other topics and webs

    return $this;
}

=pod

---++ ObjectMethod pushGlobalPreferences()
Add global preferences to this preferences stack.

=cut

sub pushGlobalPreferences {
    my $this = shift;

    # Default prefs first, from read-only web
    my $prefs = $this->pushPreferences(
        $TWiki::cfg{SystemWebName},
        $TWiki::cfg{SitePrefsTopicName},
        'DEFAULT' );

    # Then local site prefs
    if( $TWiki::cfg{LocalSitePreferences} ) {
        my( $lweb, $ltopic ) = $this->{session}->normalizeWebTopicName(
            undef, $TWiki::cfg{LocalSitePreferences} );
        $this->pushPreferences( $lweb, $ltopic, 'SITE' );

    }
}

sub _newCache {
    my( $this, $type, $web, $topic, $prefix ) = @_;

    my $req =
      new TWiki::Prefs::PrefsCache( $this, $type, $web, $topic, $prefix );

    $this->{CACHE}{$web.'.'.$topic} =
      new TWiki::Prefs( $this->{session}, $req );

    return $req;
}

=pod

---++ ObjectMethod pushPreferences( $web, $topic, $type )
   * =$web= - web to read from
   * =$topic= - topic to read
   * =$type= - DEFAULT, SITE, USER, WEB, TOPIC or PLUGIN
   * =$prefix= - key prefix for all preferences (used for plugins)
Reads preferences from the given topic, and pushes them onto the
preferences stack.

=cut

sub pushPreferences {
    my( $this, $web, $topic, $type, $prefix ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    my $req = $this->_newCache($type, $web, $topic, $prefix );
    push( @{$this->{PREFS}}, $req ) if $req;
}

=pod

---++ ObjectMethod pushWebPreferences( $web )

Pushes web preferences. Web preferences for a particular web depend
on the preferences of all containing webs.

=cut

sub pushWebPreferences {
    my( $this, $web ) = @_;

    my @webPath = split( /[\/\.]/, $web );
    my $path = '';
    foreach my $tmp ( @webPath ) {
        $path .= '/' if $path;
        $path .= $tmp;
        $this->pushPreferences(
            $path, $TWiki::cfg{WebPrefsTopicName}, 'WEB' );
    }
}

=pod

---++ ObjectMethod mark()
Return a marker representing the current top of the preferences
stack. Used to remember the stack when new web and topic preferences
are pushed during a topic include.

=cut

sub mark {
    my $this = shift;
    return scalar( @{$this->{PREFS}} );
}

=pod

---++ ObjectMethod resetTo( $mark )
Resets the preferences stack to the given mark, to recover after a topic
include.

=cut

sub restore {
    my( $this, $where ) = @_;
    ASSERT( $where ) if DEBUG;
    splice( @{$this->{PREFS}}, $where );
}

=pod

---++ ObjectMethod getPreferencesValue( $key ) -> $value
   * =$key - key to look up

Returns the value of the preference =$key=, or undef.

Looks up local preferences when the level
topic is the same as the current web,topic in the session.

=cut

sub getPreferencesValue {
    my( $this, $key ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    # establish the 'local' level
    my $local = $this->{session}->{webName}.'.'.
      $this->{session}->{topicName};

    # is there a final value?
    my $final = $this->_getFinalValue( $key );

    return $final if defined $final;
    my $val;
    foreach my $level ( reverse @{$this->{PREFS}} ) {
        # If we get as high as User level, check for cookie values.
        if( $level->{TYPE} =~ /^USER/ ) {
            # if the key was finalised somewhere higher on the stack,
            # then we can't take it from the cookie.
            $val = $this->{session}->{client}->getSessionValue( $key );
            return $val if defined( $val );
        }
        if( $local && $level->{SOURCE} eq $local ) {
            $val = $level->{Local}{$key};
        }
        unless( defined $val ) {
            $val = $level->{Set}{$key};
        }
        return $val if defined( $val );
    }

    return undef;
}

=pod

---++ ObjectMethod getTopicPreferencesValue( $key, $web, $topic ) -> $value

Recover a preferences value that is defined in a specific topic. Does
not recover web, user or global settings.

Intended for use in protections mechanisms.

=cut

sub getTopicPreferencesValue {
    my( $this, $key, $web, $topic ) = @_;
    my $wtn = $web.'.'.$topic;

    unless( $this->{CACHE}{$wtn} ) {
        $this->_newCache( 'TOPIC', $web, $topic );
    }

    return $this->{CACHE}{$wtn}->getPreferencesValue( $key );
}

=pod

---++ ObjectMethod getWebPreferencesValue( $key, $web ) -> $value

Recover a preferences value that is defined in the webhome topic of
a specific web.. Does not recover user or global settings, but
does recover settings from containing webs.

Intended for use in protections mechanisms.

=cut

sub getWebPreferencesValue {
    my( $this, $key, $web ) = @_;
    my $wtn = $web.'.'.$TWiki::cfg{WebPrefsTopicName};

    unless( $this->{CACHE}{$wtn} ) {
        $this->{CACHE}{$wtn} = new TWiki::Prefs( $this->{session} );
        $this->{CACHE}{$wtn}->pushWebPreferences( $web );
    }
    return $this->{CACHE}{$wtn}->getPreferencesValue( $key );
}

# The the key is finalised somewhere in the stack, then return the
# final value. If the key is finalised, return a value even if
# a value isn't defined, to block lower level definition. If it
# isn't final, return undef.
sub _getFinalValue {
    my( $this, $key ) = @_;
    my $finalVal;

    foreach my $level ( @{$this->{PREFS}} ) {
        if( $level->{final}{$key} ) {
            $finalVal = '';
        }
        if( defined $finalVal ) {
            my $val = $level->{Set}{$key};
            return $val if defined $val;
        }
    }

    return $finalVal;
}

=pod

---++ObjectMethod stringify() -> $text

Generate a TML-formatted version of the current preferences

=cut

sub stringify {
    my( $this, $html ) = @_;
    my $s = '';

    my %shown;
    $html = 1 unless defined $html;

    foreach my $ptr ( reverse @{$this->{PREFS}} ) {
        $s .= $ptr->stringify($html, \%shown);
    }

    if( $html ) {
        return CGI::table({style=>'width: 100%',class=>'twikiTable'}, $s);
    } else {
        return $s;
    }
}

1;
