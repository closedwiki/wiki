# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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
use strict;

=pod

---++ PrefsCache Static Package Functions

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

=cut

package TWiki::Prefs::PrefsCache;

require TWiki;
use TWiki::Prefs::TopicPrefs;

=pod

---+++ sub resetCache()

This STATIC function clears cached topic preferences, forcing all settings
to be reread.

=cut

sub resetCache {
    undef $TWiki::T->{prefs}->{TOPICCACHE};
}

=pod

---+++ sub invalidateCache( $web, $topic )

This STATIC function invalidates the cache on a particular topic.

=cut

sub invalidateCache {
    delete $TWiki::T->{prefs}->{TOPICCACHE}{$_[0]}{$_[1]};
}

=pod

---++ PrefsCache Object

This defines an object used internally by the functions in Prefs to hold
preferences.  This object handles the cascading of preferences from site, to
web, to topic/user.

---+++ sub new( $type, $parent, @target )

| Description: | Creates a new Prefs object. |
| Parameter: =$type= | Type of prefs object to create, see notes. |
| Parameter: =$parent= | Prefs object from which to inherit higher-level settings. |
| Parameter: =@target= | What this object stores preferences for, see notes. |

*Notes:* =$type= should be one of "global", "web", "request", or "copy". If the
type is "global", no parent or target should be specified; the object will
cache sitewide preferences.  If the type is "web", =$parent= should hold global
preferences, and @target should contain only the web's name.  If the type is
"request", then $parent should be a "web" preferences object for the current
web, and =@target= should be( $topicName, $userName ).  $userName should be
just the WikiName, with no web specifier.  If the type is "copy", the result is
a simple copy of =$parent=; no =@target= is needed.

Call like this: =$mainWebPrefs = Prefs->new("web", "Main");=

=cut

sub new {
    my( $theClass, $theType, $theParent, @theTarget ) = @_;

    my $self;

    if( $theType eq "copy" ) {
        $self = { %$theParent };
        bless $self, $theClass;

        $self->inheritPrefs( $theParent );
    } else {
        $self = {};
        bless $self, $theClass;

        $self->{type} = $theType;
        $self->{parent} = $theParent;
        $self->{web} = $theTarget[0] if( $theType eq "web" );

        if( $theType eq "request" ) {
            $self->{topic} = $theTarget[0];
            $self->{user} = $theTarget[1];
        }

        $self->loadPrefs( 1 );
    }

    return $self;
}

=pod

---+++ sub loadPrefs( $allowCache )

Requests for Prefs object to load preferences from its defining topics,
re-cascading the overrides.  If =$allowCache= is set, the topic cache will be
used to load preferences when applicable.  Topics that must be read will be
placed in the cache regardless of the setting of $allowCache.

=cut

sub loadPrefs {
    my( $self, $allowCache ) = @_;

    $self->{finalHash} = {};

    $self->inheritPrefs( $self->{parent} ) if defined $self->{parent};

    if( $self->{type} eq "global" ) {
        # global prefs
        $self->loadPrefsFromTopic( $TWiki::twikiWebname,
                                   $TWiki::wikiPrefsTopicname,
                                   "", $allowCache );
        $self->loadPrefsFromTopic( $TWiki::mainWebname,
                                   $TWiki::wikiPrefsTopicname,
                                   "", $allowCache );

    } elsif( $self->{type} eq "web" ) {
        # web prefs
        $self->loadPrefsFromTopic( $self->{web},
                                   $TWiki::webPrefsTopicname,
                                   "", $allowCache);

    } elsif( $self->{type} eq "request" ) {
        # request prefs - read topic and user
        my $parent = $self->{parent};
        my $topicPrefsSetting =
          TWiki::Prefs::_flag( $parent->{prefs}{READTOPICPREFS} );
        my $topicPrefsOverride =
          TWiki::Prefs::_flag( $parent->{prefs}{TOPICOVERRIDESUSER} );

        if( $topicPrefsSetting && !$topicPrefsOverride ) {
            # topic prefs overridden by user prefs
            $self->loadPrefsFromTopic( $parent->{web},
                                       $self->{topic},
                                       "", $allowCache);
        }
        $self->loadPrefsFromTopic( $TWiki::mainWebname,
                                   $self->{user},
                                   "", $allowCache );
        if( $topicPrefsSetting && $topicPrefsOverride ) {
            # topic prefs override user prefs
            $self->loadPrefsFromTopic( $parent->{web},
                                       $self->{topic},
                                       "", $allowCache );
        }
    }
}

=pod

---+++ sub loadPrefsFromTopic( $web, $topic, $keyPrefix, $allowCache )

Loads preferences from a topic.  If =$allowCache= is set then cached
settings are used where available.  All settings loaded are prefixed
with =$keyPrefix=.

=cut

sub loadPrefsFromTopic {
    my( $self, $theWeb, $theTopic, $theKeyPrefix, $allowCache ) = @_;

    my $topicPrefs;

    if( $allowCache && $TWiki::T->{prefs} && 
        exists( $TWiki::T->{prefs}->{TOPICCACHE}{$theWeb}{$theTopic} )) {
        $topicPrefs = $TWiki::T->{prefs}->{TOPICCACHE}{$theWeb}{$theTopic};
    } else {
        $topicPrefs = new TWiki::Prefs::TopicPrefs( $theWeb, $theTopic );
    }

    $theKeyPrefix = "" unless defined $theKeyPrefix;

    foreach my $key ( keys %{$topicPrefs->{prefs}} ) {
        $self->_insertPreference( $theKeyPrefix . $key,
                                  $topicPrefs->{prefs}{$key} );
    }

    if ( defined( $self->{prefs}{FINALPREFERENCES} )) {
        my $finalPrefs = $self->{prefs}{FINALPREFERENCES};
        my @finalPrefsList = split /[\s,]+/, $finalPrefs;
        $self->{finalHash} = { map { $_ => 1 } @finalPrefsList };
    }
}

# Private function to insert a value into a PrefsCache object
sub _insertPreference {
    my( $self, $theKey, $theValue ) = @_;

    return if (exists $self->{finalHash}{$theKey}); # $theKey is in FINALPREFERENCES, don't update it
    if ( $theKey eq "FINALPREFERENCES" && defined( $self->{prefs}{$theKey} )) {

        # key exists, need to deal with existing preference
        # merge final preferences lists
        $theValue = $self->{prefs}{$theKey} . ", $theValue";
    }
    $self->{prefs}{$theKey} = $theValue;
}

=pod

---+++ sub inheritPrefs( $otherPrefsObject )

Simply copies the preferences contained in the $otherPrefsObject into the
current one, overwriting anything that may currently be there.

=cut

sub inheritPrefs {
    my( $self, $otherPrefsObject ) = @_;
    my $key;

    foreach $key( keys %{$otherPrefsObject->{prefs}} ) {
        $self->{prefs}{$key} = $otherPrefsObject->{prefs}{$key};
    }

    foreach $key( keys %{$otherPrefsObject->{finalHash}} ) {
        $self->{finalHash}{$key} = 1;
    }
}

=pod

---+++ sub loadHash(\%hash)

Loads the passed hash with the "active" preferences. This hash can then
be used for rapid lookups, much faster than refering back to this module.

=cut

sub loadHash {
    my( $self, $hash ) = @_;
    foreach my $var ( keys %{$self->{prefs}} ) {
        $hash->{$var} = $self->{prefs}{$var};
    }
}

1;
