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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wiki[a-z]+.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you only customize wikicfg.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log

=begin twiki

---+ TWiki::Prefs Module

This module reads TWiki preferences of site-level, web-level and user-level
topics and implements routines to access those preferences.

=cut

package TWiki::Prefs;

use strict;

use vars qw(
    $globalPrefs %webPrefs $requestPrefs $requestWeb
    $finalPrefsName
);

$finalPrefsName = "FINALPREFERENCES";

=pod

---++ Prefs object

This defines an object used internally by the functions in this module to hold
a web's preferences.

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
web, and =@target= should be ( $topicName, $userName ).  $userName should be
just the WikiName, with no web specifier.  If the type is "copy", the result is
a simple copy of =$parent=; no =@target= is needed.

Call like this: =$mainWebPrefs = TWiki::Prefs->new("web", "Main");=

=cut

sub new
{
    my ($theClass, $theType, $theParent, @theTarget) = @_;
    
    my $self;
    
    if ($theType eq "copy") {
	$self = { %$theParent };
	bless $self, $theClass;

	$self->inheritPrefs($theParent);
    } else {
	$self = {};
	bless $self, $theClass;

	$self->{type} = $theType;
	$self->{parent} = $theParent;
	$self->{web} = $theTarget[0] if ($theType eq "web");
	
	if ($theType eq "request") {
	    $self->{topic} = $theTarget[0];
	    $self->{user} = $theTarget[1];
	}

	$self->readPrefs();	
    }

    return $self;
}

=pod

---+++ sub readPrefs()

Requests for Prefs object to read preferences, refreshing its values in case
they had changed.

=cut

sub readPrefs
{
    my ($self) = @_;
    
    $self->{prefsKeys} = [];
    $self->{prefsVals} = [];
    $self->{prefsHash} = {};
    $self->{finalHash} = {};

    $self->inheritPrefs($self->{parent}) if defined $self->{parent};
    
    if (exists($self->{web})) {
	# web prefs
	$self->readPrefsFromTopic( $self->{web}, $TWiki::webPrefsTopicname);
    } elsif (exists($self->{topic})) {
	#$self->readPrefsFromTopic( $self->{parent}{web}, $self->{topic} ); # topic-level prefs
	$self->readPrefsFromTopic( $TWiki::mainWebname, $self->{user} );   # user-level prefs
    } else {
	# global prefs
        $self->readPrefsFromTopic( $TWiki::twikiWebname, $TWiki::wikiPrefsTopicname);
        $self->readPrefsFromTopic( $TWiki::mainWebname, $TWiki::wikiPrefsTopicname);
    }
}

=pod

---+++ sub inheritPrefs( $otherPrefsObject )

Simply copies the preferences contained in the $otherPrefsObject into the
current one, discarding anything that may currently be there.

=cut

sub inheritPrefs
{
    my ($self, $otherPrefsObject) = @_;
    $self->{prefsKeys} = [ @{ $otherPrefsObject->{prefsKeys} } ];
    $self->{prefsVals} = [ @{ $otherPrefsObject->{prefsVals} } ];
    $self->{finalHash} = { %{ $otherPrefsObject->{finalHash} } };
    
    for (my $i = 0; $i < @{ $self->{prefsKeys} }; $i++) {
	$self->{prefsHash}{$self->{prefsKeys}[$i]} = \$self->{prefsVals}[$i];
    }
}

=pod

---+++ sub readPrefsFromTopic( $theWeb, $theTopic, $theKeyPrefix )

Reads preferences out of the specified topic and stores them in the Prefs
object.  If the optional =$theKeyPrefix= parameter is specified, then this
is prepended to all keys read from the topic.

=cut

sub readPrefsFromTopic
{
    my ($self, $theWeb, $theTopic, $theKeyPrefix) = @_;

    my( $meta, $text ) = &TWiki::Store::readTopic( $theWeb, $theTopic, 1 );
    $text =~ s/\r/\n/g;
    $text =~ s/\n+/\n/g;

    my $keyPrefix = $theKeyPrefix || "";
    my $key = "";
    my $value ="";
    my $isKey = 0;
    foreach( split( /\n/, $text ) ) {
        if( /^\t+\*\sSet\s([a-zA-Z0-9_]*)\s\=\s*(.*)/ ) {
            if( $isKey ) {
                $self->insertPrefsValue( $key, $value );
            }
            $key = "$keyPrefix$1";
            $value = defined $2 ? $2 : "";
            $isKey = 1;
        } elsif ( $isKey ) {
            if( ( /^\t+/ ) && ( ! /^\t+\*/ ) ) {
                # follow up line, extending value
                $value .= "\n$_";
            } else {
                $self->insertPrefsValue( $key, $value );
                $isKey = 0;
            }
        }
    }
    if( $isKey ) {
        $self->insertPrefsValue( $key, $value );
    }
    
    my %form = $meta->findOne( "FORM" );
    if( %form ) {
        my @fields = $meta->find( "FIELD" );
        foreach my $field ( @fields ) {
            $key = $field->{"name"};
            $value = $field->{"value"};
            my $attributes = $field->{"attributes"};
            if( $attributes && $attributes =~ /[S]/o ) {
                $self->insertPrefsValue( $key, $value );
            }
        }
    }

    my @finalPrefsKeys = split( /[\,\s]+/, getPreferencesValue( $finalPrefsName ) );
    for my $finalPref (@finalPrefsKeys) {
	$self->{finalHash}{$finalPref} = 1;
    }
}

=pod

---+++ sub insertPrefsValue( $key, $value )

Adds a key-value pair to the Prefs object.

=cut

sub insertPrefsValue {
    my ( $self, $theKey, $theValue ) = @_;

    return if exists $self->{finalHash}{$theKey}; # key is final, may not be overridden

    $theValue =~ s/\t/ /g;                 # replace TAB by space
    $theValue =~ s/([^\\])\\n/$1\n/g;      # replace \n by new line
    $theValue =~ s/([^\\])\\\\n/$1\\n/g;   # replace \\n by \n
    $theValue =~ s/`//g;                   # filter out dangerous chars

    if (exists $self->{prefsHash}{$theKey}) {
	# key exists, need to deal with existing preference
	my $valueRef = $self->{prefsHash}{$theKey};
	if ($theKey eq $finalPrefsName) {
	    $$valueRef .= ", $theValue"; # merge final preferences lists
	} else {
	    $$valueRef = $theValue; # simply replace all other values
	}
    } else {
	# new preference setting, no previous value
	my $newIndex = scalar @{ $self->{prefsKeys} };
	$self->{prefsKeys}[$newIndex] = $theKey;
	$self->{prefsVals}[$newIndex] = $theValue;
	$self->{prefsHash}{$theKey} = \$self->{prefsVals}[$newIndex];
    }
}

=pod

---+++ sub replacePreferencesTags( $text )

Substitutes preferences values for %PREF% tags in $text, modifying that parameter in-place.

=cut

sub replacePreferencesTags
{
    my $self = shift;

    my $x;
    my $term;

    my $keys = $self->{prefsKeys};
    my $vals = $self->{prefsVals};
    
    for( $x = 0; $x < @$keys; $x++ ) {
        $term = '%' . $keys->[$x] . '%';
        $_[0] =~ s/$term/$vals->[$x]/ge;
    }
}

=pod

---+++ sub getPreferenceValue( $key )

Returns the stored preference with key $key, or "" if no such preference exists.

=cut

sub getPreferenceValue
{
    my ($self, $theKey) = @_;
    if (exists($self->{prefsHash}{$theKey})) {
	return ${ $self->{prefsHash}{$theKey} }; #double dereference
    } else {
	return "";
    }
}

# =============================================================================
=pod

---++ Non-member functions

The below functions are designed to be used without reference to a Prefs object.

---+++ sub initializePrefs( $webName )

Resets all preference globals (for mod_perl compatibility), and reads
preferences from TWiki::TWikiPreferences, Main::TWikiPreferences, and
$webName::WebPreferences.

=cut

sub initializePrefs
{
    my( $theWebName ) = @_;

    $requestWeb = $theWebName;
    $globalPrefs = TWiki::Prefs->new("global");
    $webPrefs{$requestWeb} = TWiki::Prefs->new("web", $globalPrefs, $requestWeb);
    $requestPrefs = TWiki::Prefs->new("copy", $webPrefs{$requestWeb});

    return;
}

# =========================
=pod
---++ initializeUserPrefs( $userPrefsTopic )

Called after user is known (potentially by Plugin), this function reads
preferences from the user's personal topic.  The parameter is the topic to read
user-level preferences from (Generally "Main.CurrentUserName").

=cut

sub initializeUserPrefs
{
    my( $theWikiUserName ) = @_;

    $theWikiUserName = "Main.TWikiGuest" unless $theWikiUserName;

    if( $theWikiUserName =~ /^(.*)\.(.*)$/ ) {
	$requestPrefs = TWiki::Prefs->new("request", $webPrefs{$requestWeb}, $TWiki::topicName, $2);
    }

    return;
}


# =========================
=pod

---+++ sub getPrefsFromTopic (  $theWeb, $theTopic, $theKeyPrefix  )

Reads preferences from the topic at =$theWeb.$theTopic=, prefixes them with
$theKeyPrefix if one is provided, and adds them to the preference cache.

=cut

sub getPrefsFromTopic
{
    $requestPrefs->readPrefsFromTopic(@_);
}

# =========================
=pod

---+++ sub updateSetFromForm (  $meta, $text  )
Return value: $newText

If there are any settings "Set SETTING = value" in =$text= for a setting
that is set in form metadata in =$meta=, these are changed so that the
value in the =$text= setting is the same as the one set in the =$meta= form.
=$text= is not modified; rather, a new copy with these changes is returned.

=cut

sub updateSetFromForm
{
    my( $meta, $text ) = @_;
    my( $key, $value );
    my $ret = "";
    
    my %form = $meta->findOne( "FORM" );
    if( %form ) {
        my @fields = $meta->find( "FIELD" );
        foreach my $line ( split( /\n/, $text ) ) {
            foreach my $field ( @fields ) {
                $key = $field->{"name"};
                $value = $field->{"value"};
                my $attributes = $field->{"attributes"};
                if( $attributes && $attributes =~ /[S]/o ) {
                    $value =~ s/\n/\\\n/o;
                    TWiki::writeDebug( "updateSetFromForm: \"$key\"=\"$value\"" );
                    # Worry about verbatim?  Multi-lines
                    if ( $line =~ s/^(\t+\*\sSet\s$key\s\=\s*).*$/$1$value/g ) {
                        last;
                    }
                }
            }
            $ret .= "$line\n";
        }
    } else {
        $ret = $text;
    }
    
    return $ret;
}

# =========================
=pod

---+++ sub handlePreferencesTags ( $text )

Replaces %PREF% and %VAR{"pref"}% syntax in $text, modifying that parameter in-place.

=cut

sub handlePreferencesTags
{
    my $textRef = \$_[0];

    $requestPrefs->replacePreferencesTags($$textRef);
    
    if( $$textRef =~ /\%VAR{(.*?)}\%/ ) {
        # handle web specific variables
        $$textRef =~ s/\%VAR{(.*?)}\%/prvGetWebVariable($1)/ge;
    }
}

=pod

---+++ sub prvGetWebVariable( $attributeString )

Returns the value for a %VAR{"foo" web="bar"}% syntax, given the stuff inside the {}'s.

=cut

sub prvGetWebVariable
{
    my ( $attributeString ) = @_;
    
    my $key = &TWiki::extractNameValuePair( $attributeString );
    my $attrWeb = &TWiki::extractNameValuePair( $attributeString, "web" );
    if( $attrWeb =~ /%[A-Z]+%/ ) { # handle %MAINWEB%-type cases 
        &TWiki::handleInternalTags( $attrWeb, $requestWeb, "dummy" );
    }
    
    return getPreferencesValue( $key, $attrWeb);
}

# =========================
=pod

---+++ sub getPreferencesValue (  $theKey, $theWeb  )

Returns the value of the preference =$theKey=.  If =$theWeb= is also specified,
looks up the value with respect to that web instead of the current one; also,
in this case user/topic preferences are not considered.

In any case, if a plugin supports sessions and provides a value for =$theKey=,
this value overrides all preference settings in any web.

=cut

sub getPreferencesValue
{
    my ( $theKey, $theWeb ) = @_;

    my $sessionValue = &TWiki::getSessionValue( $theKey );
    if( defined( $sessionValue ) ) {
        return $sessionValue;
    }

    if ($theWeb) {
	if (!exists $webPrefs{$theWeb}) {
	    $webPrefs{$theWeb} = TWiki::Prefs->new("web", $globalPrefs, $theWeb);
	}
	return $webPrefs{$theWeb}->getPreferenceValue($theKey);
    } else {
	return $requestPrefs->getPreferenceValue($theKey) if defined $requestPrefs;
	if (exists $webPrefs{$requestWeb}) {
	  return $webPrefs{$requestWeb}->getPreferenceValue($theKey); # user/topic prefs not yet init'd
	}
    }    
}

# =========================
=pod

---+++ sub getPreferencesFlag (  $theKey, $theWeb  )

Returns 1 if the preference =$theKey= from =$theWeb= as defined above is set
to something other than "off" or "no", and 0 otherwise.

=cut

sub getPreferencesFlag
{
    my ( $theKey, $theWeb ) = @_;

    my $flag = getPreferencesValue( $theKey, $theWeb );
    $flag =~ s/^\s*(.*?)\s*$/$1/gi;
    $flag =~ s/off//gi;
    $flag =~ s/no//gi;
    if( $flag ) {
        return 1;
    } else {
        return 0;
    }
}

# =========================

1;

=end twiki

=cut

# EOF

