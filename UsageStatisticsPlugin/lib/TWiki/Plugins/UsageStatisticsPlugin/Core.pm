# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 e-Ecosystems Inc
# Copyright (C) 2011 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Plugins::UsageStatisticsPlugin::Core;

# =========================
sub new {
    my ( $class, $debug ) = @_;

    my $this = {
          Debug          => $debug,
        };
    bless( $this, $class );
    TWiki::Func::writeDebug( "- UsageStatisticsPlugin Core constructor" ) if $this->{Debug};

    return $this;
}

# =========================
sub VarUSAGESTATISTICS
{
    my ( $this, $session, $params ) = @_;

    my $action = $params->{action} || '';
    TWiki::Func::writeDebug( "- UsageStatisticsPlugin USAGESTATISTICS{\"$action\"}" ) if $this->{Debug};
    if( $action eq 'overview' ) {
        return $this->_overviewStats( $session, $params );
    } elsif( $action eq 'user' ) {
        return $this->_userStats( $session, $params );
    } elsif( $action eq 'monthlist' ) {
        return $this->_monthList( $session, $params );
    } elsif( $action ) {
        return "%<nop>USAGESTATISTICS{}% ERROR: Parameter =action=\"$action\"= is not supported"; 
    } else {
        return "%<nop>USAGESTATISTICS{}% ERROR: Parameter =action= is required";
    }
}

# =========================
sub _overviewStats
{
    my ( $this, $session, $params ) = @_;

    my $text = "FIXME: Overview Stats";

    return $text;
}

# =========================
sub _userStats
{
    my ( $this, $session, $params ) = @_;
    
    my $text = "FIXME: User Stats";
    
    return $text;
}

# =========================
sub _monthList
{
    my ( $this, $session, $params ) = @_;
    
    my $text = "FIXME: Month List";
    
    return $text;
}

# =========================
1;
