# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ UNPUBLISHED package TWiki::Prefs::PrefsCache

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

=cut

package TWiki::Prefs::PrefsCache;

require TWiki;
use TWiki::Prefs::TopicPrefs;
use Assert;

=pod

---++ ClassMethod new( $session, $type, $parent, @target )

Creates a new Prefs object.
| Parameter: =$type= | Type of prefs object to create, see notes. |
| Parameter: =$parent= | Prefs object from which to inherit higher-level settings. |
| Parameter: =@target= | What this object stores preferences for, see notes. |

*Notes:* =$type= should be one of "global", "web", "request", or "copy".

If the type is "global", no parent or target should be specified; the
object will cache sitewide preferences.

If the type is "web", =$parent= should hold global
preferences, and @target should contain only the web's name.

If the type is "request", then $parent should be a "web" preferences object
for the current web, and =@target= should be( $topicName, $user ).
$user should be the user object.

If the type is "copy", the result is a simple copy of =$parent=; no
=@target= is needed.

Call like this: =$mainWebPrefs = Prefs->new("web", "Main");=

=cut

sub new {
    my( $class, $session, $theType, $theParent, @theTarget ) = @_;
    my $self;

    ASSERT(ref($session) eq "TWiki") if DEBUG;

    if( $theType eq "copy" ) {
        $self = { %$theParent };
        $self->{session} = $session;
        bless $self, $class;

        $self->inheritPrefs( $theParent );
    } else {
        $self = {};
        $self->{session} = $session;
        bless $self, $class;

        $self->{type} = $theType;
        $self->{parent} = $theParent;
        $self->{web} = $theTarget[0] if( $theType eq "web" );

        if( $theType eq "request" ) {
            $self->{topic} = $theTarget[0];
            $self->{user} = $theTarget[1];
            ASSERT(ref($self->{user}) eq "TWiki::User") if DEBUG;
        }

        $self->loadPrefs( 1 );
    }

    return $self;
}

sub prefs { my $this = shift; return $this->{session}->{prefs}; }

=pod

---++ ObjectMethod loadPrefs( $allowCache )

Requests for Prefs object to load preferences from its defining topics,
re-cascading the overrides.  If =$allowCache= is set, the topic cache will be
used to load preferences when applicable.  Topics that must be read will be
placed in the cache regardless of the setting of $allowCache.

=cut

sub loadPrefs {
    my( $self, $allowCache ) = @_;
    ASSERT(ref($self) eq "TWiki::Prefs::PrefsCache") if DEBUG;

    $self->{finalHash} = {};

    $self->inheritPrefs( $self->{parent} ) if defined $self->{parent};

    if( $self->{type} eq "global" ) {
        # global prefs
        $self->loadPrefsFromTopic( $TWiki::cfg{SystemWebName},
                                   $TWiki::cfg{SitePrefsTopicName},
                                   "", $allowCache );
        $self->loadPrefsFromTopic( $TWiki::cfg{UsersWebName},
                                   $TWiki::cfg{SitePrefsTopicName},
                                   "", $allowCache );

    } elsif( $self->{type} eq "web" ) {
        # web prefs
        $self->loadPrefsFromTopic( $self->{web},
                                   $TWiki::cfg{WebPrefsTopicName},
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
        $self->loadPrefsFromTopic( $TWiki::cfg{UsersWebName},
                                   $self->{user}->wikiName(),
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

---++ ObjectMethod loadPrefsFromTopic( $web, $topic, $keyPrefix, $allowCache )

Loads preferences from a topic.  If =$allowCache= is set then cached
settings are used where available.  All settings loaded are prefixed
with =$keyPrefix=.

=cut

sub loadPrefsFromTopic {
    my( $self, $theWeb, $theTopic, $theKeyPrefix, $allowCache ) = @_;
    ASSERT(ref($self) eq "TWiki::Prefs::PrefsCache") if DEBUG;

    my $topicPrefs = new TWiki::Prefs::TopicPrefs( $self->{session},
                                                   $theWeb, $theTopic );

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

---++ ObjectMethod inheritPrefs( $otherPrefsObject )

Simply copies the preferences contained in the $otherPrefsObject into the
current one, overwriting anything that may currently be there.

=cut

sub inheritPrefs {
    my( $self, $otherPrefsObject ) = @_;
    ASSERT(ref($self) eq "TWiki::Prefs::PrefsCache") if DEBUG;
    my $key;

    foreach $key( keys %{$otherPrefsObject->{prefs}} ) {
        $self->{prefs}{$key} = $otherPrefsObject->{prefs}{$key};
    }

    foreach $key( keys %{$otherPrefsObject->{finalHash}} ) {
        $self->{finalHash}{$key} = 1;
    }
}

=pod

---++ ObjectMethod loadHash(\%hash)

Loads the passed hash with the "active" preferences. This hash can then
be used for rapid lookups, much faster than refering back to this module.

=cut

sub loadHash {
    my( $self, $hash ) = @_;
    ASSERT(ref($self) eq "TWiki::Prefs::PrefsCache") if DEBUG;
    foreach my $var ( keys %{$self->{prefs}} ) {
        $hash->{$var} = $self->{prefs}{$var};
    }
}

1;
