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
        return "%<nop>USAGESTATISTICS{}% ERROR: Parameter =action=\"$action\"= is not supported."; 
    } else {
        return "%<nop>USAGESTATISTICS{}% ERROR: Parameter =action= is required.";
    }
}

# =========================
sub _overviewStats
{
    my ( $this, $session, $params ) = @_;

    my $logFile = $this->_getLogFilename( $params->{month} );
    unless( $logFile ) {
        return 'ERROR: No statistics are available for this month.';
    }

    my $text = "FIXME: Overview Stats";

    return $text;
}

# =========================
sub _userStats
{
    my ( $this, $session, $params ) = @_;

    my $user = $params->{user};
    $user =~ s/[^A-Za-z0-9_]//go;
    unless( $user ) {
        return 'ERROR: Please specify a user';
    }

    my $logFile = $this->_getLogFilename( $params->{month} );
    unless( $logFile ) {
        return 'ERROR: No statistics are available for this month.';
    }

    my $text = "FIXME: User Stats";
    
    return $text;
}

# =========================
sub _monthList
{
    my ( $this, $session, $params ) = @_;

    my $format    = $params->{format} || '$month';
    my $separator = $params->{separator} || '$n';

    my $dir = $TWiki::cfg{LogFileName} || "$TWiki::cfg{DataDir}/log%DATE%.txt";
    $dir =~ s/\/[^\/]*$//; # remove file to get just the path
    opendir( DIR, $dir ) || return "%<nop>USAGESTATISTICS{}% ERROR: Can't read log directory $dir.";
    my @logMonths =
         map {
           # reformat to 'YYYY-MM'
           s/^log([0-9]{4})([0-9]{2})\.txt$/$1-$2/;
           # apply format
           my $month = $_;
           $_ = $format;
           s/\$month/$month/go;
           s/\$n/\n/go;
           $_;
         }
         sort
         grep { /^log[0-9]{6}\.txt$/ } # get all log files
         readdir( DIR );
    closedir( DIR );

    $separator =~ s/\$n/\n/go;
    my $text = '';
    $text = join( $separator, @logMonths ) if( @logMonths );

    return $text;
}

# =========================
sub _getLogFilename
{
    my ( $this, $logDate ) = @_;

    $logDate = TWiki::Func::formatTime( time(), '$year$mo', 'servertime' ) unless( $logDate );
    $logDate =~ s/[^0-9]//go;

    my $logFile = $TWiki::cfg{LogFileName};
    $logFile =~ s/%DATE%/$logDate/g;
    return '' unless( -e $logFile );
    return $logFile;
}

# =========================
1;
