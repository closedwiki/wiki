#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wiki[a-z]+.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you only customize wikicfg.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log

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
    prvGetPrefsList( "$twikiWebname\.$wikiPrefsTopicname" ); # site-level
    prvGetPrefsList( "$theWebName\.$webPrefsTopicname" );    # web-level
    prvGetPrefsList( $theWikiUserName );                     # user-level

    return;
}


# =========================
sub prvGetPrefsList
{
    my ( $theWebTopic ) = @_;
    my $fileName = $theWebTopic;                  # "Main.TopicName"
    $fileName =~ s/([^\.]*)\.(.*)/$1\/$2\.txt/go; # "Main/TopicName.txt"
    my $text = readFile( "$dataDir/$fileName" );  # read topic text
    $text =~ s/\r//go;                            # cut CR
    my $key;
    my $value;
    my $isKey = 0;
    foreach( split( /\n/, $text ) ) {
        if( /^\t+\*\sSet\s([a-zA-Z0-9_]*)\s\=\s*(.*)/ ) {
            if( $isKey ) {
                prvAddToPrefsList( $key, $value );
            }
            $key = $1;
            $value = $2 || "";
            $isKey = 1;
        } elsif ( $isKey ) {
            if( ( /^\t+/ ) && ( ! /^\t+\*/ ) ) {
                # follow up line, extending value
                $value .= "\n";
                $value .= $_;
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

    $theValue =~ s/\t/ /go;     # replace TAB by space
    $theValue =~ s/\\n/\n/go;   # replace \n by new line
    $theValue =~ s/`//go;       # filter out dangerous chars
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
    my $key = extractNameValuePair( $attributes );
    my $attrWeb = extractNameValuePair( $attributes, "web" );
    if( $attrWeb =~ /%[A-Z]+%/ ) {
        &wiki::handleInternalTags( $attrWeb, $defaultWebName, "dummy" );
    }
    my $val = getPreferencesValue( $key, $attrWeb );
    return $val;
}

# =========================
sub handlePreferencesTags
{
    # modify argument directly, e.g. call by reference
    my $x;
    my $cmd;
    for( $x = 0; $x < @wiki::prefsKeys; $x++ ) {
        $cmd = "\$_[0] =~ s/%$prefsKeys[$x]%/&prvHandlePrefsValue($x)/geo;";
        eval( $cmd );
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

    if( ( ! $theWeb ) || ( $theWeb eq $defaultWebName ) ) {
        # search the default web
        for( $x = 0; $x < @prefsKeys; $x++ ) {
            if( $prefsKeys[$x] eq $theKey ) {
                return $prefsValues[$x];
            }
        }
    } elsif( &wiki::webExists( $theWeb ) ) {
        # search the alternate web, rebuild prefs if necessary
        if( $theWeb ne $altWebName ) {
            $altWebName = $theWeb;
            @finalPrefsKeys = ();
            my @saveKeys    = @prefsKeys; # quick hack, this stinks
            my @saveValues  = @prefsValues; # ditto
            prvGetPrefsList( "$twikiWebname\.$wikiPrefsTopicname" );
            prvGetPrefsList( "$altWebName\.$webPrefsTopicname" );
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
# EOF

