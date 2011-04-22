# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 e-Ecosystems Inc
# Copyright (C) 1999-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 1999-2011 TWiki Contributors
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
    #$this->{Debug} = 1;

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
        return $this->_monthList( $params );
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

    my $logData = $this->_collectLogData( $logFile );
    if( $this->{Debug} ) {
        require Data::Dumper;
        $Data::Dumper::Indent = 1;
        return 'Debug log data: <br /><pre>' . Data::Dumper->Dump([$logData], [qw(logData)]) . '</pre>';
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
    my ( $this, $params ) = @_;

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
sub _collectLogData {
    my( $this, $logFile ) = @_;

    # Code of this method largely copied from TWiki::UI::Statistics

    # Log file format:
    # | date | user | operation | web.topic | notes | ip address |
    # date, such as "2011-04-17 - 02:43" (or "03 Feb 2000 - 02:43" up to TWiki-4.2)
    # user, such as "Main.PeterThoeny" (legacy)
    # user, such as "PeterThoeny" (TWiki internal authentication)
    # user, such as "peter" (intranet login)
    # operation, such as "view", "edit", "save"
    # web.topic, such as "MyWeb.MyTopic"
    # notes, such as "minor", "not on thursdays"
    # ip address, such as "127.0.0.5"

    my $logData;
    # Format:
    # $logData->{webs}{views}{$web} - number of topic views for each web
    # $logData->{webs}{saves}{$web} - number of topic saves for each web
    # $logData->{webs}{uploads}{$web} - number of file uploads for each web
    # $logData->{webs}{topicviews}{$web}{$topic} - number of topic views for each topic in each web 
    # $logData->{users}{views}{$user} - number of topic views for each user
    # $logData->{users}{saves}{$user} - number of topic saves for each user
    # $logData->{users}{uploads}{$user} - number of file uploads for each user
    # $logData->{users}{topicsaves}{$user}{$web}{$topic} - number of topic saves for each topic for each user

    # Copy the log file to temp file, since analysis could take some time
    my $tmpFileHandle = new File::Temp(
        DIR      => TWiki::Func::getWorkArea( 'UsageStatisticsPlugin' ),
        TEMPLATE => 'usage-stats-XXXXXXXXXX',
        SUFFIX   => '.txt',
        # UNLINK => 0         # To debug, uncomment this to keep the temp file
      );
    File::Copy::copy( $logFile, $tmpFileHandle )
        or throw Error::Simple( 'Cannot backup log file: '.$! );
    # Seek to start of temp file
    $tmpFileHandle->seek( 0, SEEK_SET );

    # main log file loop, line by line
    while ( my $line = <$tmpFileHandle> ) {
        my @fields = split( /\s*\|\s*/, $line );

        my( $date, $logUser );
        while( !$date && scalar( @fields )) {
            $date = shift @fields;
        }
        while( !$logUser && scalar( @fields )) {
            $logUser = shift @fields;
#            $logUser = TWiki::Func::getCanonicalUserID( $logUser );
        }

        my( $opName, $webTopic, $notes, $ip ) = @fields;

        # ignore minor changes - not statistically helpful
        next if( $notes && $notes =~ /(minor|dontNotify)/ );

        # ignore op names we don't need
        next unless( $opName && $opName =~ /^(view|save|upload|rename)$/ );

        # .+ is used because topics name can contain stuff like !, (, ), =, -, _ and they should have stats anyway
        next unless( $opName && $webTopic =~ /(^$TWiki::regex{webNameRegex})\.(.+)/ );

        my $webName = $1;
        my $topicName = $2;

        if( $opName eq 'view' ) {
            next if( $topicName eq 'WebRss' );
            next if( $topicName eq 'WebAtom' );
            next if( $notes && $notes =~ /\(not exist\)/ );
            $logData->{webs}{views}{$webName}++;
            $logData->{webs}{topicviews}{$webName}{$topicName}++;
            $logData->{users}{views}{$logUser}++;

        } elsif( $opName eq 'save' ) {
            $logData->{webs}{saves}{$webName}++;
            $logData->{users}{views}{$logUser}++;
            $logData->{users}{topicsaves}{$logUser}{$webName}{$topicName}++;

        } elsif( $opName eq 'upload' ) {
            $logData->{webs}{uploads}{$webName}++;
            $logData->{users}{uploads}{$logUser}++;

        } elsif( $opName eq 'rename' ) {
            # Pick up the old and new topic names
            $notes =~/moved to ($TWiki::regex{webNameRegex})\.($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}|\w+)/o;
            my $newTopicWeb = $1;
            my $newTopicName = $2;

            # Get number of views for old topic this month (may be zero)
            my $oldViews = $logData->{webs}{topicviews}{$webName}{$topicName} || 0;

            # Transfer views from old to new topic
            $logData->{webs}{views}{$newTopicWeb}{$newTopicName} = $oldViews;
            delete $logData->{webs}{topicviews}{$webName}{$topicName};

            # Transfer views from old to new web
            if ( $newTopicWeb ne $webName ) {
                $logData->{webs}{views}{$webName} -= $oldViews;
                $logData->{webs}{views}{$newTopicWeb} += $oldViews;
            }
        }
    }

    # Note: No need to close $tmpFileHandle, temp file is removed by destructor

    return $logData;
}

# =========================
1;
