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

---+ package TWiki::Prefs::PrefsCache

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

=cut

package TWiki::Prefs::PrefsCache;

use TWiki::Prefs::Parser;
use Assert;

=pod

---++ ClassMethod new( $session, $type, $parent )

Creates a new Prefs object.
| Parameter: =$type= | Type of prefs object to create, see notes. |
| Parameter: =$parent= | Prefs object which contains higher-level settings. |

=cut

sub new {
    my( $class, $session, $parent ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    my $self = bless( {}, $class );
    $self->{session} = $session;
    $self->{keyPrefix} = "";

    # initialise the final prefs from the parent, so they don't get
    # overwritten when loading prefs at this level. The final hash
    # will be rewritten when the prefs have been loaded.
    if( $parent ) {
        ASSERT(ref($parent) eq "TWiki::Prefs::PrefsCache") if DEBUG;
        $self->{final} = $parent->{final};
        $self->{prefs}{FINALPREFERENCES} =
          join(",", keys( %{$self->{final}} ));
    } else {
        $self->{final} = ();
    }

    return $self;
}

=pod

---++ ObjectMethod loadPrefsFromTopic( $web, $topic )

Loads preferences from a topic. All settings loaded are prefixed
with the key prefix set in setKeyPrefix (default "").

=cut

sub loadPrefsFromTopic {
    my( $self, $theWeb, $theTopic ) = @_;
    ASSERT(ref($self) eq "TWiki::Prefs::PrefsCache") if DEBUG;

    my $session = $self->{session};
    if( $session->{store}->topicExists( $theWeb, $theTopic )) {
        my( $meta, $text ) =
          $session->{store}->readTopic( undef,
                                         $theWeb, $theTopic,
                                         undef );
        my $parser = new TWiki::Prefs::Parser();
        $parser->parseText( $text, $self );
        $parser->parseMeta( $meta, $self );
    }

    my $finalPrefs = $self->{prefs}{FINALPREFERENCES};
    if ( defined( $finalPrefs )) {
        my @finalPrefsList = split /[\s,]+/, $finalPrefs;
        $self->{final} = { map { $_ => 1 } @finalPrefsList };
    }
}

=pod

---++ ObjectMethod setKeyPrefix( $pfx )
Set the key prefix to be prepended to any key added to the cache
from now on.

=cut

sub setKeyPrefix {
    my( $this, $pfx ) = @_;
    $this->{keyPrefix} = $pfx;
}

=pod

---++ ObjectMethod insertPrefsValue($key, $val)
Adds a key-value pair to the object.
Callback used for the Prefs::Parser object, or can be used to add
arbitrary new entries to a prefs cache. Note that the last
keyPrefix set in a call to setKeyPrefix is automatically prepended
to the key.

Note that final preferences can't be set this way, they can only
be set in the context of a full topic read, because they cannot
be finalised until after the whole topic has been read.

=cut

sub insertPrefsValue {
    my( $self, $theKey, $theValue ) = @_;

    $theKey = $self->{keyPrefix} . $theKey;

    # key is final, may not be overridden
    return if exists $self->{final}{$theKey};

    $theValue =~ s/\t/ /g;                 # replace TAB by space
    $theValue =~ s/([^\\])\\n/$1\n/g;      # replace \n by new line
    $theValue =~ s/([^\\])\\\\n/$1\\n/g;   # replace \\n by \n
    $theValue =~ s/`//g;                   # filter out dangerous chars

    if ( defined( $self->{prefs}{$theKey} ) &&
         $theKey eq "FINALPREFERENCES" ) {
        # merge final preferences lists
        $self->{prefs}{$theKey} .= ",$theValue";
    } else {
        $self->{prefs}{$theKey} = $theValue;
    }
}

#sub stringify {
#    my $this = shift;
#    my $res = "";
#
#    foreach my $key ( keys %{$this->{prefs}} ) {
#        $res .= "$key => $this->{prefs}{$key}\n";
#    }
#    return $res;
#}

1;
