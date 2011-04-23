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

require TWiki::Sandbox;
use Error qw( :try );

# =========================
sub new {
    my ( $class, $debug ) = @_;

    my $this = {
          Debug     => $debug,
          Sandbox   => $TWiki::sandbox || $TWiki::sharedSandbox,
        };
    bless( $this, $class );

    #$this->{Debug} = 1; # Uncomment to enable debugging just in this file

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

    my ( $logFile, $logDate ) = $this->_getLogFilename( $params->{month} );
    unless( $logFile ) {
        return 'ERROR: No statistics are available for this month.';
    }

    my $systemData = $this->_collectSystemData( );
    my $logData    = $this->_collectLogData( $logFile );
    if( $this->{Debug} ) {
        require Data::Dumper;
        $Data::Dumper::Indent = 1;
        my $text = '<br />Debug system data: <br /><pre>'
                 . Data::Dumper->Dump([$systemData], [qw(systemData)]) . '</pre>';
        $text   .= '<br />Debug log data: <br /><pre>'
                 . Data::Dumper->Dump([$logData], [qw(logData)]) . '</pre>';
        return $text;
    }

    my $text = <<'END_TML';
<table><tr><td valign="top">
---++ Statistics Summary

| %ICON{folder}% Number of webs: |  %S_WEBS% |
| %ICON{viewtopic}% Number of topics: |  %S_TOPICS% |
| %ICON{attachfile}% Number of attachments: |  %S_ATTACHMENTS% |
| %ICON{persons}% Number of users: |  %S_USERS% |
</td><td>&nbsp; &nbsp; &nbsp;</td><td valign="top">
---++ Activity in %S_DATE%

| %ICON{viewtopic}% Number of topic views: |  %S_VIEWS% |
| %ICON{save}% Number of topic updates: |  %S_SAVES% |
| %ICON{attachfile}% Number of file uploads: |  %S_UPLOADS% |
</td></tr></table>
%T% The summary shows statistics of today, not of the selected month.

---++ Web Statistics in %S_DATE%

| *Web* | *Topic<br />views* | *Topic<br />saves* | *File<br />uploads* | *Most popular and, ..., least popular topic views* |
%S_WEBSTATS%

---++ User Statistics in %S_DATE%

| *User* | *Details* | *Topic<br />views* | *Topic<br />saves* | *File<br />uploads* | *Topic contributions* |
%S_USERSTATS%
END_TML
    $text =~ s/%S_WEBS%/$systemData->{webs}/;
    $text =~ s/%S_TOPICS%/$systemData->{topics}/;
    $text =~ s/%S_ATTACHMENTS%/$systemData->{attachments}/;
    $text =~ s/%S_USERS%/scalar @{$systemData->{users}}/e;
    $text =~ s/%S_DATE%/$logDate/g;
    $text =~ s/%S_VIEWS%/$this->_getTotalFromHashRef( $logData->{webs}{views} )/e;
    $text =~ s/%S_SAVES%/$this->_getTotalFromHashRef( $logData->{webs}{saves} )/e;
    $text =~ s/%S_UPLOADS%/$this->_getTotalFromHashRef( $logData->{webs}{uploads} )/e;

    # Web statistics
    my $rows = '';
    foreach( @{$systemData->{weblist}} ) {
        my $web = $_;
        $rows .= '| <span style="white-space: nowrap">%ICON{folder}% '
               . "[[$web.WebHome][$web]]</span>"
               . ' |  ' . ( $logData->{webs}{views}{$web} || 0 )
               . ' |  ' . ( $logData->{webs}{saves}{$web} || 0 )
               . ' |  ' . ( $logData->{webs}{uploads}{$web} || 0 )
               . ' | ';
        my $topicsRef = $logData->{webs}{topicviews}{$web};
        my @topics = ();
        foreach my $topic ( sort { $topicsRef->{$b} <=> $topicsRef->{$a} } keys %{$topicsRef} ) {
            push( @topics, "[[$web.$topic][$topic]]: " . $topicsRef->{$topic} );
        }
        if( scalar @topics > 20 ) {
            # remove elements in the middle of the array, keeping 10 at start and 10 at end
            splice( @topics, 10, scalar @topics - 20, '...' );
        }
        $rows .= join( ', ', @topics ) if( @topics );
        $rows .= " |\n";
    }
    $text =~ s/%S_WEBSTATS%/$rows/g;

    # User statistics
    $rows = '';
    foreach( @{$systemData->{users}} ) {
        $user = $_;
        $rows .= '| <span style="white-space: nowrap">%ICON{person}% [['
               . $TWiki::cfg{UsersWebName} . ".$user][$user]]</span>"
               . ' |  <a href="%SCRIPTURL{view}%/%WEB%/UsageStatisticsByUser?user='
               . $user . '">%ICON{statistics}%</a> '
               . ' |  ' . ( $logData->{users}{views}{$user} || 0 )
               . ' |  ' . ( $logData->{users}{saves}{$user} || 0 )
               . ' |  ' . ( $logData->{users}{uploads}{$user} || 0 )
               . ' | ';
        my @saves = ();
        my $i = 0;
        for my $w ( sort keys( %{$logData->{users}{topicsaves}{$user}} ) ) {
            for my $t ( sort keys( %{$logData->{users}{topicsaves}{$user}{$w}} ) ) {
                push( @saves, "[[$w.$t][$t]]" ) if( $i++ < 10 );
            }
        }
        push( @saves, '...' ) if( scalar @saves == 10 );
        $rows .= join( ', ', @saves ) if( @saves );
        $rows .= " |\n";
    }
    $text =~ s/%S_USERSTATS%/$rows/g;

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

    my ( $logFile, $logDate ) = $this->_getLogFilename( $params->{month} );
    unless( $logFile ) {
        return 'ERROR: No statistics are available for this month.';
    }

    my $logData = $this->_collectLogData( $logFile );

    my $text = <<'END_TML';
---++ Activity by [[%USERSWEB%.%S_USER%][%S_USER%]] in %S_DATE%

| %ICON{viewtopic}% Number of topic views: |  %S_VIEWS% |
| %ICON{save}% Number of topic updates: |  %S_SAVES% |
| %ICON{attachfile}% Number of file uploads: |  %S_UPLOADS% |

---++ Contributions by !%S_USER% in %S_DATE%

| *Web.Topic* | *Updates* |
%S_CONTRIBS%
END_TML
    $text =~ s/%S_USER%/$user/g;
    $text =~ s/%S_DATE%/$logDate/g;
    $text =~ s/%S_VIEWS%/$logData->{users}{views}{$user} || 0/e;
    $text =~ s/%S_SAVES%/$logData->{users}{saves}{$user} || 0/e;
    $text =~ s/%S_UPLOADS%/$logData->{users}{uploads}{$user} || 0/e;

    my $rows = '';
    for my $w ( sort keys( %{$logData->{users}{topicsaves}{$user}} ) ) {
        $rows .= "| \%ICON{folder}\% <b>[[$w.WebHome][$w web]]:</b> ||\n";
        for my $t ( sort keys( %{$logData->{users}{topicsaves}{$user}{$w}} ) ) {
            $rows .= "| \%ICON{empty}\%\%ICON{viewtopic}\% [[$w.$t][$t]] |  "
                   . $logData->{users}{topicsaves}{$user}{$w}{$t} . " |\n";
        }
    }
    $rows = "| No updates this month ||" unless( $rows );
    $text =~ s/%S_CONTRIBS%/$rows/g;

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
sub _getTotalFromHashRef
{
    my ( $this, $hashRef ) = @_;
    my $n = 0;
    while ( my( $key, $val ) = each( %$hashRef ) ) {
        $n += $val;
    }
    return $n;
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
    $logDate =~ s/([0-9]{4})/$1-/o;
    return ( $logFile, $logDate );
}

# =========================
sub _collectSystemData {
    my( $this ) = @_;

    my $systemData;
    # Format:
    # $systemData->{weblist} - array of webs
    # $systemData->{webs} - number of web
    # $systemData->{topics} - number of topics
    # $systemData->{attachments} - number of attachments
    # $systemData->{users} - array of users

    my @weblist = TWiki::Func::getListOfWebs( 'user' );
    @weblist = sort( @weblist );
    $systemData->{weblist} = \@weblist;
    $systemData->{webs} = scalar @weblist;
    $systemData->{topics} = 0; # handled in foreach web loop

    # For performance, use egrep to get the number of attachments instead of a TWiki 
    # internal search. This assumes and takes code from
    # $TWiki::cfg{RCS}{SearchAlgorithm} = 'TWiki::Store::SearchAlgorithms::Forking';
    $systemData->{attachments} = 0;

    my $cmd = $TWiki::cfg{RCS}{EgrepCmd}
            || '/bin/egrep %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';
    $cmd =~ s/%CS{.*?}%//;
    $cmd =~ s/%DET{.*?}%//;
    my $searchString = '[%]META:FILEATTACHMENT{';
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    $maxTopicsInSet = 128 if( $TWiki::cfg{DetailedOS} eq 'MSWin32' );
    foreach my $w ( @weblist ) {
        my @topics = TWiki::Func::getTopicList( $w );
        $systemData->{topics} += scalar @topics;
        my @set = splice( @topics, 0, $maxTopicsInSet );
        while( @set ) {
            @set = map { $TWiki::cfg{DataDir} . "/$w/$_.txt" } @set;
            try {
                my( $output, $exit ) =
                  $this->{Sandbox}->sysCommand( $cmd, TOKEN => $searchString, FILES => \@set );
                unless( $exit ) {
                    $systemData->{attachments} += scalar split( /[\n\r?]/, $output );
                }
            } catch Error::Simple with {
                # ignore errors
            };
            @set = splice( @topics, 0, $maxTopicsInSet );
        }
    }

    # Array of users
    my @users = ();
    my $iterator = TWiki::Func::eachUser();
    while( $iterator->hasNext() ) {
        push( @users, $iterator->next() );
    }
    @users = sort( @users ); 
    $systemData->{users} = \@users;

    return $systemData;
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
    # $logData->{users}{topicsaves}{$user}{$web}{$topic} - number of topic saves for each topic in each web for each user

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
            $logUser = TWiki::Func::getWikiName( $logUser );
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
            $logData->{users}{saves}{$logUser}++;
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
