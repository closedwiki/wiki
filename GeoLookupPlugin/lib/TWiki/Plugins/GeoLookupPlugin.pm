# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2010 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package GeoLookupPlugin

=cut

package TWiki::Plugins::GeoLookupPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $moduleEnum $geoIP $error );

$VERSION = '2010-02-10 (18329)';

$RELEASE = 'TWiki';

$SHORTDESCRIPTION = 'Lookup geolocation by IP address or domain name';

$NO_PREFS_IN_TOPIC = 0;

# Name of this Plugin, only used in this module
$pluginName = 'GeoLookupPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin settings
    $debug = TWiki::Func::getPreferencesFlag( "GEOLOOKUPPLUGIN_DEBUG" );

    $moduleEnum = 0;
    undef $geoIP;
    $error = '';

    TWiki::Func::registerTagHandler( 'GEOLOOKUP', \&_GEOLOOKUP );

    # Plugin correctly initialized
    return 1;
}

=pod

---++ _GEOLOOKUP()

This handles the %GEOLOOKUP{...}% variable

=cut

sub _GEOLOOKUP {
    my( $session, $params, $theTopic, $theWeb ) = @_;

    my $ip = $params->{_DEFAULT};
    my $text = $params->{format} || '$city, $region, $country_name';
    return( 'GEOLOOKUP error: IP address is missing' ) unless( $ip );

    _initGeoData() unless $moduleEnum;

    my $rec = _getGeoDataRecord( $ip );
    return( "GEOLOOKUP error: $error" ) unless $rec;

    $text =~ s/\$country_code/$rec->{country_code}||''/geo;
    $text =~ s/\$country_code3/$rec->{country_code3}||''/geo;
    $text =~ s/\$country_name/_fixCountryName( $rec->{country_name} )/geo;
    $text =~ s/\$region/$rec->{region}||''/geo;
    $text =~ s/\$city/$rec->{city}||''/geo;
    $text =~ s/\$postal_code/$rec->{postal_code}||''/geo;
    $text =~ s/\$latitude/$rec->{latitude}||''/geo;
    $text =~ s/\$longitude/$rec->{longitude}||''/geo;
    $text =~ s/\$metro_code/$rec->{metro_code}||''/geo;
    $text =~ s/\$area_code/$rec->{area_code}||''/geo;

    return $text;
}

=pod

---++ _initGeoData()

Initialize the geo data.
Sets global $moduleEnum
   = -1 if not found,
   = 1 if Geo::IP
   = 2 if Geo::IP::NativePerl
Sets global $geoIP to module if found

=cut

sub _initGeoData {
    return unless( $moduleEnum == 0 );

    my $dataFile = $TWiki::cfg{GeoLookupPlugin}{GeoDataFile} || '/usr/local/share/GeoIP/GeoLiteCity.dat';

    if( eval "require Geo::IP" ) {
        $moduleEnum = 1;
        $geoIP = Geo::IP->open( $dataFile, Geo::IP->GEOIP_STANDARD );
        $error = "Geo data file $dataFile not found" unless( $geoIP );

    } elsif( eval "require Geo::IP::PurePerl" ) {
        $moduleEnum = 2;
        eval {
            local $SIG{'__DIE__'};
            $geoIP = Geo::IP::PurePerl->open( $dataFile, Geo::IP::PurePerl->GEOIP_STANDARD );
        };
        $error = "Geo data file $dataFile not found" unless( $geoIP );

    } else {
        $moduleEnum = 0;
        undef $geoIP;
        $error = 'Module Geo::IP not found';
    }
}

=pod

---++ _getGeoDataRecord()

Get a geo data record

=cut

sub _getGeoDataRecord {
    my( $ip ) = @_;

    my $rec = undef;
    return $rec unless( $geoIP );

    if( $moduleEnum == 1 ) {
        unless( $ip =~ /^[0-9]+\.[0-9]/ ) { # FIXME: What about IPv6?
            $ip = _domainToIP( $ip );
        }
        my $geoRec = $geoIP->record_by_addr( $ip );
        if( $geoRec ) {
            $rec->{country_code}  = $geoRec->country_code;
            $rec->{country_code3} = $geoRec->country_code3;
            $rec->{country_name}  = $geoRec->country_name;
            $rec->{region}        = $geoRec->region;
            $rec->{city}          = $geoRec->city;
            $rec->{postal_code}   = $geoRec->postal_code;
            $rec->{latitude}      = $geoRec->latitude;
            $rec->{longitude}     = $geoRec->longitude;
            $rec->{metro_code}    = $geoRec->metro_code;
            $rec->{area_code}     = $geoRec->area_code;
        } else {
            $rec->{country_code}  = '';
            $rec->{country_code3} = '';
            $rec->{country_name}  = '';
            $rec->{region}        = '';
            $rec->{city}          = '';
            $rec->{postal_code}   = '';
            $rec->{latitude}      = '';
            $rec->{longitude}     = '';
            $rec->{metro_code}    = '';
            $rec->{area_code}     = '';
        }

    } elsif( $moduleEnum == 2 ) {
        # no need to convert domain name to IP address
        ( $rec->{country_code},
          $rec->{country_code3},
          $rec->{country_name},
          $rec->{region},
          $rec->{city},
          $rec->{postal_code},
          $rec->{latitude},
          $rec->{longitude},
          $rec->{metro_code},
          $rec->{area_code}
        ) = $geoIP->get_city_record( $ip );
    }
    return $rec;
}

=pod

---++ _domainToIP()

convert domain name to IP address

=cut

sub _domainToIP {
    my( $ip ) = @_;

    use Socket;
    my $packed_ip = gethostbyname( $ip );
    if (defined $packed_ip) {
        $ip = inet_ntoa($packed_ip);
    }
    return $ip;
}

=pod

---++ _fixCountryName()

=cut

sub _fixCountryName {
    my( $name ) = @_;
    $name = '' unless $name;
    $name =~ s/United States/USA/;
    return $name;
}

1;
