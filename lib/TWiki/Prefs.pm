# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
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

package TWiki::Prefs;

use strict;

use vars qw(
    $finalPrefsName @finalPrefsKeys @prefsKeys @prefsValues
    $defaultWebName $altWebName @altPrefsKeys @altPrefsValues
);

$finalPrefsName = "FINALPREFERENCES";


# =========================
sub initializePrefs
{
    my( $theWikiUserName, $theWebName ) = @_;

    # (Note: Do not use a %hash, because order is significant)
    @prefsKeys = ();
    @prefsValues = ();
    @altPrefsKeys = ();
    @altPrefsValues = ();
    $defaultWebName = $theWebName;
    $altWebName = "";
    @finalPrefsKeys = ();
    getPrefsFromTopic( $TWiki::twikiWebname, $TWiki::wikiPrefsTopicname ); # site-level
    getPrefsFromTopic( $TWiki::mainWebname,  $TWiki::wikiPrefsTopicname ); # alternate site-level
    getPrefsFromTopic( $theWebName, $TWiki::webPrefsTopicname );           # web-level
    if( $theWikiUserName =~ /^(.*)\.(.*)$/ ) {
        getPrefsFromTopic( $1, $2 );                                       # user-level
    }

    return;
}


# =========================
sub getPrefsFromTopic
{
    my ( $theWeb, $theTopic, $theKeyPrefix ) = @_;

    my( $meta, $text ) = &TWiki::Store::readTopic( $theWeb, $theTopic, 1 );
    $text =~ s/\r/\n/go;
    $text =~ s/\n+/\n/go;

    my $keyPrefix = $theKeyPrefix || "";  # prefix is for plugin prefs
    my $key = "";
    my $value ="";
    my $isKey = 0;
    foreach( split( /\n/, $text ) ) {
        if( /^\t+\*\sSet\s([a-zA-Z0-9_]*)\s\=\s*(.*)/ ) {
            if( $isKey ) {
                prvAddToPrefsList( $key, $value );
            }
            $key = "$keyPrefix$1";
            $value = defined $2 ? $2 : "";
            $isKey = 1;
        } elsif ( $isKey ) {
            if( ( /^\t+/ ) && ( ! /^\t+\*/ ) ) {
                # follow up line, extending value
                $value .= "\n$_";
            } else {
                prvAddToPrefsList( $key, $value );
                $isKey = 0;
            }
        }
    }
    if( $isKey ) {
        prvAddToPrefsList( $key, $value );
    }
    @finalPrefsKeys = split( /[\,\s]+/, getPreferencesValue( $finalPrefsName ) );
}

# =========================
sub prvAddToPrefsList
{
    my ( $theKey, $theValue ) = @_;

    my $final;
    foreach $final ( @finalPrefsKeys ) {
        if( $theKey eq $final ) {
            # this key is final, may not be overridden
            return;
        }
    }

    $theValue =~ s/\t/ /go;                 # replace TAB by space
    $theValue =~ s/([^\\])\\n/$1\n/go;      # replace \n by new line
    $theValue =~ s/([^\\])\\\\n/$1\\n/go;   # replace \\n by \n
    $theValue =~ s/`//go;                   # filter out dangerous chars
    my $x;
    my $found = 0;
    for( $x = 0; $x < @prefsKeys; $x++ ) {
        if( $prefsKeys[$x] eq $theKey ) {
            if( ( $theKey eq $finalPrefsName ) && ( $prefsValues[$x] ) ) {
                # merge the values of existing key
                $prefsValues[$x] .= ", $theValue";
            } else {
                # replace value of existing key
                $prefsValues[$x] = $theValue;
            }
            $found = "1";
            last;
        }
    }
    if( ! $found ) {
        # append to list
        $prefsKeys[@prefsKeys] = $theKey;
        $prefsValues[@prefsValues] = $theValue;
    }
}

# =========================
sub prvHandlePrefsValue
{
    my( $theIdx ) = @_;
    # dummy sub needed because eval can't have multiple
    # lines in s/../../go
    return $prefsValues[$theIdx];
}

# =========================
sub prvHandleWebVariable
{
    my( $attributes ) = @_;
    my $key = &TWiki::extractNameValuePair( $attributes );
    my $attrWeb = &TWiki::extractNameValuePair( $attributes, "web" );
    if( $attrWeb =~ /%[A-Z]+%/ ) {
        &TWiki::handleInternalTags( $attrWeb, $defaultWebName, "dummy" );
    }
    my $val = getPreferencesValue( $key, $attrWeb );
    return $val;
}

# =========================
sub handlePreferencesTags
{
    # modify argument directly, e.g. call by reference
    my $x;
    my $term;
    for( $x = 0; $x < @prefsKeys; $x++ ) {
        $term = "\%$prefsKeys[$x]\%";
        $_[0] =~ s/$term/&prvHandlePrefsValue($x)/ge;
    }

    if( $_[0] =~ /%VAR{(.*?)}%/ ) {
        # handle web specific variables
        $_[0] =~ s/%VAR{(.*?)}%/&prvHandleWebVariable($1)/geo;
    }
}

# =========================
sub getPreferencesValue
{
    my ( $theKey, $theWeb ) = @_;

    my $x;
    
    my $sessionValue = &TWiki::getSessionValue( $theKey );
    if( defined( $sessionValue ) ) {
        return $sessionValue;
    }

    if( ( ! $theWeb ) || ( $theWeb eq $defaultWebName ) ) {
        # search the default web
        for( $x = 0; $x < @prefsKeys; $x++ ) {
            if( $prefsKeys[$x] eq $theKey ) {
                return $prefsValues[$x];
            }
        }
    } elsif( &TWiki::Store::webExists( $theWeb ) ) {
        # search the alternate web, rebuild prefs if necessary
        if( $theWeb ne $altWebName ) {
            $altWebName = $theWeb;
            @finalPrefsKeys = ();
            my @saveKeys    = @prefsKeys; # quick hack, this stinks
            my @saveValues  = @prefsValues; # ditto
            getPrefsFromTopic( $TWiki::twikiWebname, $TWiki::wikiPrefsTopicname );
            getPrefsFromTopic( $altWebName, $TWiki::webPrefsTopicname );
            @altPrefsKeys   = @prefsKeys; # quick hack, this stinks
            @altPrefsValues = @prefsValues; # quick hack, this stinks
            @prefsKeys      = @saveKeys; # quick hack, this stinks
            @prefsValues    = @saveValues; # quick hack, this stinks

        }
        for( $x = 0; $x < @altPrefsKeys; $x++ ) {
            if( $altPrefsKeys[$x] eq $theKey ) {
                return $altPrefsValues[$x];
            }
        }
    }
    return "";
}

# =========================
sub getPreferencesFlag
{
    my ( $theKey, $theWeb ) = @_;

    my $flag = getPreferencesValue( $theKey, $theWeb );
    $flag =~ s/^\s*(.*?)\s*$/$1/goi;
    $flag =~ s/off//goi;
    $flag =~ s/no//goi;
    if( $flag ) {
        return 1;
    } else {
        return 0;
    }
}

# =========================

1;

# EOF

