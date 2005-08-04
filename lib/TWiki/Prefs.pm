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

---+ package TWiki::Prefs

The Prefs class is a singleton that implements management of preferences.
It uses a number of TWiki::Prefs::PrefsCache objects to store the
preferences for global, web, user and topic contexts, and provides
the means to look up preferences in these. It handles loading from
files, finalisation of preferences, and is able to populate a
caller-provided hash for fast lookups.

=cut

package TWiki::Prefs;

use TWiki::Prefs::PrefsCache;
use Assert;

=pod

---++ ClassMethod new( $session )

Creates a new Prefs object, reading
preferences from TWiki::TWikiPreferences, Main::TWikiPreferences, and
WebPreferences. User and topic preferences are not read until the
user is initialised using =initializeUser=.

=cut

sub new {
    my( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;

    my $web = $session->{webName};

    my $globs =  new TWiki::Prefs::PrefsCache( $session, undef );
    $this->{GLOBAL} = $globs;

    # TWiki.TWikiPreferences first
    $globs->loadPrefsFromTopic( $TWiki::cfg{SystemWebName},
                                $TWiki::cfg{SitePrefsTopicName} );

    # Then local prefs
    my $local = $TWiki::cfg{LocalSitePreferences};
    if( $local && $local =~ /^(\w+)\.(\w+)$/ ) {
        $globs->loadPrefsFromTopic( $1, $2 );
    }

    my @webPath = split( /[\/\.]/, $web );
    my $tmpWebPath = '';
    my $prevWebPrefs = $globs;
    foreach my $tmp ( @webPath ) {
        $tmpWebPath .= '/' if $tmpWebPath;
        $tmpWebPath .= $tmp;
        $this->{WEBS}{$tmpWebPath} =
          new TWiki::Prefs::PrefsCache($session, $prevWebPrefs);
        $this->{WEBS}{$tmpWebPath}->loadPrefsFromTopic(
            $tmpWebPath, $TWiki::cfg{WebPrefsTopicName} );
        $prevWebPrefs=$this->{WEBS}{$tmpWebPath};
    }
    $this->{WEB} = $this->{WEBS}{$web};

    return $this;
}

=pod

---++ ObjectMethod loadUserAndTopicPreferences()

Reads preferences from the current user's personal topic, and
read topic prefs if required.

=cut

sub loadUserAndTopicPreferences {
    my( $this, $web, $topic, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    my $req = new TWiki::Prefs::PrefsCache($this->{session}, $this->{WEB} );

    my $topicPrefsSetting =
      $this->getPreferencesFlag( 'READTOPICPREFS', $web );
    my $topicPrefsOverride =
      $this->getPreferencesFlag( 'TOPICOVERRIDESUSER', $web );

    if( $topicPrefsSetting && !$topicPrefsOverride ) {
        # topic prefs overridden by user prefs
        $req->loadPrefsFromTopic( $web, $topic );
    }
    $req->loadPrefsFromTopic( $TWiki::cfg{UsersWebName},
                              $user->wikiName() );

    if( $topicPrefsSetting && $topicPrefsOverride ) {
        # topic prefs override user prefs
        $req->loadPrefsFromTopic( $web, $topic );
    }
    $this->{REQUEST} = $req;
}

=pod

---++ ObjectMethod getPrefsFromTopic( $web, $topic, $keyPrefix )

Reads preferences from the topic at =$web.$topic=, prefixes them with
=$keyPrefix= if one is provided, and adds them to the request preferences.

This is provided for late initialisation of preferences by modules such
as plugins. Note that any preference values loaded this way are still
subject to finalisation, and may be overridden by =getSessionValueHandler=.

=cut

sub getPrefsFromTopic {
    my( $this, $web, $topic, $keyPrefix ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;
    $this->{REQUEST}->setKeyPrefix( $keyPrefix ) if $keyPrefix;
    $this->{REQUEST}->loadPrefsFromTopic( $web, $topic );
    $this->{REQUEST}->setKeyPrefix( '' ) if $keyPrefix;
}

=pod

---++ ObjectMethod loadHash( \%hash )
Loads the top level of all the preferences into the passed
hash, in order to accelerate substitutions.

=cut

sub loadHash {
    my ( $this, $hash ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    foreach my $set qw( REQUEST WEB GLOBAL ) {
        foreach my $key ( keys %{$this->{$set}->{prefs}} ) {
            unless( defined( $hash->{$key} )) {
                my $value = $this->getPreferencesValue( $key );
                $hash->{$key} = $value;
            }
        }
    }
}

=pod

---++ ObjectMethod getPreferencesValue( $key, $web ) -> $value
   * =$key - key to look up
   * =$web= - if specified, ignores request preferences and looks up the key in the given web instead.

Returns the value of the preference =$key=.

In all cases, if a plugin supports sessions and provides a value for =$key=,
this value overrides all other preference settings.

Always returns a string value, never undef.

=cut

sub getPreferencesValue {
    my( $this, $key, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    my $val = $this->{session}->{plugins}->getSessionValueHandler( $key );
    return $val if defined( $val );

    if( $web ) {
        unless( defined( $this->{WEBS}{$web} )) {
            my $webs = new TWiki::Prefs::PrefsCache( $this->{session} );
            $webs->loadPrefsFromTopic( $web,
                                       $TWiki::cfg{WebPrefsTopicName} );
            $this->{WEBS}{$web} = $webs;
        }
        $val = $this->{WEBS}{$web}->{prefs}{$key};
        return $val if defined( $val );
    } else {
        if( defined( $this->{REQUEST} )) {
            $val = $this->{REQUEST}->{prefs}{$key};
            return $val if defined( $val );
        }

        if( defined( $this->{WEB} )) {
            $val = $this->{WEB}->{prefs}{$key};
            return $val if defined( $val );
        }
    }

    unless( defined($val) ) {
        $val = $this->{GLOBAL}->{prefs}{$key};
    }

    return $val || '';
}

=pod

---++ ObjectMethod getPreferencesFlag( $key, $web ) -> $boolean

Returns the preference =$key= from =$web= as a flag.  See
=getPreferencesValue= for the semantics of the parameters.
Returns 1 if the pref value is 'on', and 0 otherwise.  'On' means set to
something with a true Perl-truth-value, with the special cases that 'off' and
'no' are forced to false.  (Both of the latter are case-insensitive.)  Note
also that leading and trailing whitespace on the pref value will be stripped
prior to this conversion.

=cut

sub getPreferencesFlag {
    my( $this, $key, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    my $value = $this->getPreferencesValue( $key, $web );
    return TWiki::isTrue( $value );
}

=pod

---++ ObjectMethod getPreferencesNumber( $key, $web ) -> $number

Returns the preference =$key= from =$web= as a flag.  See
=getPreferencesValue= for the semantics of the parameters.
Converts the string =$prefValue= to a number.  First any whitespace and commas
are removed.  *L10N note: assumes thousands separator is comma and decimal
point is period.*  Then, if the first character is a zero, the value is
passed to oct(), which will interpret hex (0x prefix), octal (leading zero
only), or binary (0b prefix) numbers.  If the first character is a digit
greater than zero, the value is assumed to be a decimal number and returned.
If the =$prefValue= is empty or not a number, zero is returned.  Finally, if
=$prefValue= is undefined, an undefined value is returned.  *Undefined
preferences are automatically converted to empty strings, and so this function
will always return zero for these, rather than 'undef'.*

=cut

sub getPreferencesNumber {
    my( $this, $key, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;

    my $value = $this->getPreferencesValue( $key, $web );

    return undef unless defined( $value );

    $value =~ s/[,\s]+//g;

    if( $value =~ /^0(\d|x|b)/i ) {
        return oct( $value ); # octal, 0x hex, 0b binary
    } elsif( $value =~ /^\d(\.\d+)?/) {
        return $value;      # decimal
    }
    return 0;              # empty/non-numeric
}

#sub stringify {
#    my $this = shift;
#    ASSERT($this->isa( 'TWiki::Prefs')) if DEBUG;
#    my $res = '';
#
#    foreach my $set qw( REQUEST WEB GLOBAL ) {
#        foreach my $key ( keys %{$this->{$set}->{prefs}} ) {
#            my $value = $this->getPreferencesValue( $key );
#            $res .= "$set: $key => $value\n";
#        }
#    }
#    return $res;
#}

1;
