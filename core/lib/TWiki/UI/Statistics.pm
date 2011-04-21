# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2011 Peter Thoeny, peter[at]thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2002 Richard Donkin, rdonkin@bigfoot.com
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

=begin twiki

---+ package TWiki::UI::Statistics

Statistics extraction and presentation

=cut

package TWiki::UI::Statistics;

use strict;
use Assert;
use File::Copy qw(copy);
use IO::File;
use Error qw( :try );

require TWiki;
require TWiki::Sandbox;

my $debug = 0;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=pod

---++ StaticMethod statistics( $session )

=statistics= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generate statistics topic.
If a web is specified in the session object, generate WebStatistics
topic update for that web. Otherwise do it for all webs

=cut

#===========================================================
sub statistics {
    my $session = shift;

    my $webName = $session->{webName};

    # web to redirect to after finishing
    my $logDate = $session->{request}->param( 'logdate' ) || '';
    $logDate =~ s/[^0-9]//g;  # remove all non numerals
    $debug = $session->{request}->param( 'debug' );

    unless( $session->inContext( 'command_line' )) {
        # running from CGI
        $session->generateHTTPHeaders();
        $session->{response}->body(
            CGI::start_html( -title => 'TWiki: Create Usage Statistics' ) );
    }
    # Initial messages
    _printMsg( $session, 'TWiki: Create Usage Statistics' );
    _printMsg( $session, '!Do not interrupt this script!' );
    _printMsg( $session, '(Please wait until page download has finished)' );

    require TWiki::Time;
    my $currentMonth = TWiki::Time::formatTime( time(), '$year$mo', 'servertime' );
    unless( $logDate ) {
        $logDate = $currentMonth;
    }

    my $logMon;
    my $logMo;
    my $logYear;
    if ( $logDate =~ /^(\d\d\d\d)(\d\d)$/ ) {
        $logYear = $1;
        $logMo = $2;
        $logMon = $TWiki::Time::ISOMONTH[ ( $logMo % 12 ) - 1 ];
        $currentMonth = ( $logDate eq $currentMonth ) ? 1 : 0;
    } else {
        _printMsg( $session, "!Error in date $logDate - must be YYYY-MM or YYYYMM" );
        return;
    }

    my $logMonYear = "$logMon $logYear";
    my $logYearMo = "$logYear-$logMo";
    _printMsg( $session, "* Statistics for $logYearMo" );
    _printMsg( $session, '* Executed by ' . $session->{users}->getWikiName( $session->{user} ) );

    my $logFile = $TWiki::cfg{LogFileName};
    $logFile =~ s/%DATE%/$logDate/g;

    unless( -e $logFile ) {
        _printMsg( $session, "!Log file $logFile does not exist; aborting" );
        return;
    }

    # Copy the log file to temp file, since analysis could take some time

    # FIXME move the temp dir stuff to TWiki.cfg
    my $tmpDir;
    if ( $TWiki::cfg{OS} eq 'UNIX' ) { 
        $tmpDir = $ENV{'TEMP'} || "/tmp"; 
    } elsif ( $TWiki::cfg{OS} eq 'WINDOWS' ) {
        $tmpDir = $ENV{'TEMP'} || "c:/"; 
    } else {
        # FIXME handle other OSs properly - assume Unix for now.
        $tmpDir = "/tmp";
    }
    my $randNo = int ( rand 1000);	# For mod_perl with threading...
    my $tmpFilename = TWiki::Sandbox::untaintUnchecked( "$tmpDir/twiki-stats.$$.$randNo" );

    File::Copy::copy ($logFile, $tmpFilename)
        or throw Error::Simple( 'Cannot backup log file: '.$! );

    my $TMPFILE = new IO::File;
    open $TMPFILE, $tmpFilename
      or throw Error::Simple( 'Cannot open backup file: '.$! );

    # Do a single data collection pass on the temporary copy of logfile,
    # then process each web once.
    my ($viewRef, $contribRef, $statViewsRef, $statSavesRef, $statUploadsRef) =
      _collectLogData( $session, $TMPFILE );

    my @weblist;
    my $webSet = TWiki::Sandbox::untaintUnchecked($session->{request}->param( 'webs' ))
               || $session->{requestedWebName};
    if( $webSet) {
        # do specific webs
        push( @weblist, split( /,\s*/, $webSet ));

    } else {
        # otherwise do all user webs:
        @weblist = $session->{store}->getListOfWebs( 'user' );
    }

    # do site statistics (only if no specific webs selected, or if force update from SiteStatistics)
    my $siteStatsTopic = $TWiki::cfg{Stats}{SiteStatsTopicName} || 'SiteStatistics';
    if( !$webSet || $session->{topicName} eq $siteStatsTopic ) {
        try {
            my $siteStats = _collectSiteStats( $session, $currentMonth, $logYearMo, $contribRef,
                                               $statViewsRef, $statSavesRef, $statUploadsRef );
            _processSiteStats( $session, $logYearMo, $logMonYear, $siteStats );
        } catch TWiki::AccessControlException with  {
            _printMsg( $session, '  - ERROR: no permission to CHANGE site statistics topic');
        }
    }

    foreach my $web ( @weblist ) {
        try {
            _processWeb( $session, $web, $logYearMo, $logMonYear,
                        $viewRef, $contribRef,
                        $statViewsRef, $statSavesRef, $statUploadsRef );
        } catch TWiki::AccessControlException with  {
            _printMsg( $session, '  - ERROR: no permission to CHANGE statistics topic in '.$web);
        }
    }

    close $TMPFILE;		# Shouldn't be necessary with 'my'
    unlink $tmpFilename;# FIXME: works on Windows???  Unlink before
    # usage to ensure deleted on crash?

    if( !$session->inContext( 'command_line' ) ) {
        my $web   = $session->{webName};
        my $topic = $session->{topicName};
        if( $topic eq $TWiki::cfg{HomeTopicName} ) {
            $web   = $TWiki::cfg{UsersWebName};
            $topic = $siteStatsTopic;
        }
        my $url = $session->getScriptUrl( 0, 'view', $web, $topic );
        _printMsg( $session, '* Go to '
                   . CGI::a( { href => $url,
                               rel => 'nofollow' }, "$web.$topic") );
    }
    _printMsg( $session, 'End creating usage statistics' );
    $session->{response}->body( $session->{response}->body . CGI::end_html() )
        unless ( $session->inContext('command_line') );
}

#===========================================================
# Debug only
# Print all entries in a view or contrib hash, sorted by web and item name
#===========================================================
sub _debugPrintHash {
    my ($statsRef) = @_;
    # print "Main.WebHome views = " . ${$statsRef}{'Main'}{'WebHome'}."\n";
    # print "Main web, TWikiGuest contribs = " . ${$statsRef}{'Main'}{'Main.TWikiGuest'}."\n";
    foreach my $web ( sort keys %$statsRef) {
        my $count = 0;
        print $web,' web:',"\n";
        # Get reference to the sub-hash for this web
        my $webhashref = ${$statsRef}{$web};
        # print 'webhashref is ' . ref ($webhashref) ."\n";
        # Items can be topics (for view hash) or users (for contrib hash)
        foreach my $item ( sort keys %$webhashref ) {
            print "  $item = ",( ${$webhashref}{$item} || 0 ),"\n";
            $count += ${$webhashref}{$item};
        }
        print "  WEB TOTAL = $count\n";
    }
}

#===========================================================
# Process the whole log file and collect information in hash tables.
# Must build stats for all webs, to handle case of renames into web
# requested for a single-web statistics run.
#
# Main hash tables are divided by web:
#
#   $view{$web}{$TopicName} == number of views, by topic
#   $contrib{$web}{"Main.".$WikiName} == number of saves/uploads, by user
#===========================================================
sub _collectLogData {
    my( $session, $TMPFILE ) = @_;

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

    my %view;		# Hash of hashes, counts topic views by (web, topic)
    my %contrib;	# Hash of hashes, counts uploads/saves by (web, user)

    # Hashes for each type of statistic, one hash entry per web
    my %statViews;
    my %statSaves;
    my %statUploads;
    my $users = $session->{users};

    binmode $TMPFILE;
    while ( my $line = <$TMPFILE> ) {
        my @fields = split( /\s*\|\s*/, $line );

        my( $date, $logFileUserName );
        while( !$date && scalar( @fields )) {
            $date = shift @fields;
        }
        while( !$logFileUserName && scalar( @fields )) {
            $logFileUserName = shift @fields;
            $logFileUserName = TWiki::Func::getCanonicalUserID($logFileUserName);
        }

        my( $opName, $webTopic, $notes, $ip ) = @fields;

        # ignore minor changes - not statistically helpful
        next if( $notes && $notes =~ /(minor|dontNotify)/ );

        # ignore op names we don't need
        next unless( $opName && $opName =~ /^(view|save|upload|rename)$/ );

        # .+ is used because topics name can contain stuff like !, (, ), =, -, _ and they should have stats anyway
        if( $opName && $webTopic =~ /(^$TWiki::regex{webNameRegex})\.(.+)/ ) {
            my $webName = $1;
            my $topicName = $2;

            if( $opName eq 'view' ) {
	    	next if ($topicName eq 'WebRss');
	    	next if ($topicName eq 'WebAtom');
                $statViews{$webName}++;
                unless( $notes && $notes =~ /\(not exist\)/ ) {
                    $view{$webName}{$topicName}++;
                }

            } elsif( $opName eq 'save' ) {
                $statSaves{$webName}++;
                $contrib{$webName}{$users->webDotWikiName($logFileUserName)}++;

            } elsif( $opName eq 'upload' ) {
                $statUploads{$webName}++;
                $contrib{$webName}{$users->webDotWikiName($logFileUserName)}++;

            } elsif( $opName eq 'rename' ) {
                # Pick up the old and new topic names
                $notes =~/moved to ($TWiki::regex{webNameRegex})\.($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}|\w+)/o;
                my $newTopicWeb = $1;
                my $newTopicName = $2;

                # Get number of views for old topic this month (may be zero)
                my $oldViews = $view{$webName}{$topicName} || 0;

                # Transfer views from old to new topic
                $view{$newTopicWeb}{$newTopicName} = $oldViews;
                delete $view{$webName}{$topicName};

                # Transfer views from old to new web
                if ( $newTopicWeb ne $webName ) {
                    $statViews{$webName} -= $oldViews;
                    $statViews{$newTopicWeb} += $oldViews;
                }
            }
        } else {
            $session->writeDebug('WebStatistics: Bad logfile line '.$line);
        }
    }

    return \%view, \%contrib, \%statViews, \%statSaves, \%statUploads;
}

#===========================================================
sub _getDiskUse {
    my( $session, $dir ) = @_;
    my $diskUse = 0;
    my $cmd = $TWiki::cfg{Stats}{dfCmd} || 'df %DIRECTORY|F%';
    my( $output, $exit );
    try {
        ( $output, $exit ) = $TWiki::sandbox->sysCommand( $cmd, DIRECTORY => $dir );
        if( $exit ) {
            _printMsg( $session, "  - ERROR: $cmd of $dir failed: $exit $output" );
            return 0;
        } elsif( $output =~ /^.*[ \t]([0-9\.]+)\%.*?$/s ) {
            return $1;
        }
        return 0;

    } catch Error::Simple with {
        my $message =  shift->{-text};
        _printMsg( $session, "  - ERROR: $cmd of $dir failed: $message" );
        return 0;
    }
}

#===========================================================
sub _getDirSize {
    my( $dir ) = @_;
    my $size = 0;

    opendir( DIR, $dir ) || return $size;
    my @files = map { $dir . '/' . $_ } # create full path
                grep { !/^\.\.?$/ }     # omit . and .. files
                readdir( DIR );
    closedir( DIR );
    foreach my $f ( @files ) {
        if( -d $f ) {
            $size += _getDirSize( $f );
        } else {
            $size += ( -s $f || 0 );
        }
    }
    return $size;
}

#===========================================================
sub _collectSiteStats {
    my( $session, $currentMonth, $logYearMo, $contribRef,
        $statViewsRef, $statSavesRef, $statUploadsRef ) = @_;

    _printMsg( $session, '* Reporting overall statistics' );

    my $siteStats;

    my $site = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{ScriptUrlPath};
    my $ff = chr(255) x length( $site );
    $site = $site ^ $ff; # obfuscate site name
    $siteStats->{statSite} = uc( unpack( "H*", $site ) ); # hex encode

    $siteStats->{statVersion} = $TWiki::VERSION;
    $siteStats->{statVersion} =~ s/[, ].*//;
    $siteStats->{statVersion} = '' unless( $currentMonth );

    $siteStats->{statDate} = $logYearMo;

    my @weblist = $session->{store}->getListOfWebs( 'user' );
    $siteStats->{statWebs} = scalar @weblist;
    $siteStats->{statWebs} = 0 unless( $currentMonth );

    $siteStats->{statTopics} = 0;
    if( $currentMonth ) {
        foreach my $w ( @weblist ) {
            $siteStats->{statTopics} += scalar $session->{store}->getTopicNames( $w );
        }
        _printMsg( $session, "  - webs: " . $siteStats->{statWebs} . 
                             ", topics: " . $siteStats->{statTopics} );
    }

    $siteStats->{statViews} = 0;
    foreach my $w ( sort keys %$statViewsRef) {
        $siteStats->{statViews} += ( $statViewsRef->{$w} || 0 );
    }

    $siteStats->{statSaves} = 0;
    foreach my $w ( sort keys %$statSavesRef) {
        $siteStats->{statSaves} += ( $statSavesRef->{$w} || 0 );
    }

    $siteStats->{statUploads} = 0;
    foreach my $w ( sort keys %$statUploadsRef) {
        $siteStats->{statUploads} += ( $statUploadsRef->{$w} || 0 );
    }
    _printMsg( $session, "  - view: " . $siteStats->{statViews} .
                         ", save: "   . $siteStats->{statSaves} .
                         ", upload: " . $siteStats->{statUploads} );

    $siteStats->{statUsers} = 0;
    if( $currentMonth ) {
        my $it = $session->{users}->eachUser();
        $it->{process} = sub { return 1; };
        while( $it->hasNext() ) {
            $siteStats->{statUsers} += $it->next();
        }
        _printMsg( $session, "  - users: " . $siteStats->{statUsers} );
    }

    $siteStats->{statDataSize} = 0;
    $siteStats->{statPubSize} = 0;
    if( $currentMonth ) {
        my $size = _getDirSize( $TWiki::cfg{DataDir} ) / ( 1024 * 1024 );
        $siteStats->{statDataSize} = sprintf("%0.1f", $size );
        $size    = _getDirSize( $TWiki::cfg{PubDir} ) / ( 1024 * 1024 );
        $siteStats->{statPubSize}  = sprintf("%0.1f", $size );
        _printMsg( $session, "  - data size: " . $siteStats->{statDataSize} .
                             " MB, pub size: " . $siteStats->{statPubSize} . " MB" );
    }

    $siteStats->{statDiskUse} = 0;
    if( $currentMonth ) {
        my $dataUse = _getDiskUse( $session, $TWiki::cfg{DataDir} );
        my $pubUse  = _getDiskUse( $session, $TWiki::cfg{PubDir} );
        if( $pubUse > $dataUse ) {
            # pub is mounted on different disk, report this one as the more critical one
            $dataUse = $pubUse;
        }
        $siteStats->{statDiskUse} = $dataUse . '%';
        _printMsg( $session, "  - disk use: " . $siteStats->{statDiskUse} );
    }

    $siteStats->{statPlugins} = 0;
    if( $currentMonth ) {
        $siteStats->{statPlugins} = scalar @{$session->{plugins}{plugins}};
        unless( $TWiki::cfg{Stats}{DontContactTWikiOrg} ) {
            my $url = 'http://twiki.org/cgi-bin/pluginstats?';
            while ( my( $key, $val ) = each( %$siteStats ) ) {
                $val = TWiki::urlEncode( $val );
                $url .= "$key=" . $val . ";";
            }
            my $response = TWiki::Func::getExternalResource( $url );
            if( $response->is_error() ) {
                my $msg = "Code " . $response->code() . ": " . $response->message();
                $msg =~ s/[\n\r]/ /gos;
                _printMsg( $session, "! ERROR: $msg" );
            } else {
                my $text = $response->content();
                if( $text =~ /plugins: ?([0-9]+)/ ) {
                    $siteStats->{statPlugins} .= " of $1";
                }
            }
        }
        _printMsg( $session, "  - plugins: " . $siteStats->{statPlugins} );
    }

    $siteStats->{statTopContributors} = '';
    my ( @topContribs ) = _getTopList( $TWiki::cfg{Stats}{TopContrib}, undef, $contribRef );
    if( @topContribs ) {
        $siteStats->{statTopContributors} = join( CGI::br(), @topContribs );
        $topContribs[0] =~ s/^.*\]\[([^\]]*).*$/$1/;
        _printMsg( $session, '  - top contributor: '.$topContribs[0] );
    }

    # use Data::Dumper;
    # print STDERR "=====\n" . Dumper($siteStats) . "=====\n";

    return $siteStats;
}

#===========================================================
sub _processSiteStats {
    my( $session, $logYearMo, $logMonYear, $siteStats ) = @_;

    # Update the SiteStatistics topic
    my $web = $TWiki::cfg{UsersWebName}; 
    my $statsTopic = $TWiki::cfg{Stats}{SiteStatsTopicName} || 'SiteStatistics';
    my( $meta, $text );
    if( $session->{store}->topicExists( $web, $statsTopic ) ) {
        ( $meta, $text ) = $session->{store}->readTopic( undef, $web, $statsTopic );
    } else {
        ( $meta, $text ) = $session->{store}->readTopic(
            undef, $TWiki::cfg{SystemWebName}, 'SiteStatisticsTemplate' );
        $text = $session->expandVariablesOnTopicCreation( $text, $session->{user} );
    }

    my $line;
    my @lines = split( /\r?\n/, $text );
    my $statLine;
    my $idxStat = -1;
    my $idxTmpl = -1;
    my $oldStats;
    for( my $x = 0; $x < @lines; $x++ ) {
        $line = $lines[$x];
        # Check for existing line for this month+year in new and legacy format
        if( $line =~ /^\| ($logYearMo|$logMonYear) / ) {
            my @items = split( / *\| */, $line );
            if( scalar @items >= 12 ) {
                $oldStats->{statWebs}     = $items[2];
                $oldStats->{statTopics}   = $items[3];
                $oldStats->{statUsers}    = $items[7];
                $oldStats->{statDataSize} = $items[8];
                $oldStats->{statPubSize}  = $items[9];
                $oldStats->{statDiskUse}  = $items[10];
                $oldStats->{statPlugins}  = $items[11];
            }
            $idxStat = $x;
        } elsif( $line =~ /<\!\-\-statDate\-\->/ ) {
            $statLine = $line;
            $idxTmpl = $x;
        }
    }
    if( ! $statLine ) {
        $statLine = '| <!--statDate--> |  <!--statWebs--> |  <!--statTopics--> '
                  . '|  <!--statViews--> |  <!--statSaves--> |  <!--statUploads--> '
                  . '|  <!--statUsers--> |  <!--statDataSize--> |  <!--statPubSize--> '
                  . '|  <!--statDiskUse--> |  <!--statPlugins--> | <!--statTopContributors--> |';
    }

    # update statistics line with collected values
    $statLine =~ s/<\!\-\-([^\-]+)\-\->/$siteStats->{$1} || $oldStats->{$1} || 0/ge;

    if( $idxStat >= 0 ) {
        # entry already exists, need to update
        $lines[$idxStat] = $statLine;

    } elsif( $idxTmpl >= 0 ) {
        # entry does not exist, add after <!--statDate--> line
        $lines[$idxTmpl] = "$lines[$idxTmpl]\n$statLine";

    } else {
        # entry does not exist, add at the end
        $lines[@lines] = $statLine;
    }
    $text = join( "\n", @lines );
    $text .= "\n";
    $session->{store}->saveTopic( $session->{user}, $web, $statsTopic,
                                  $text, $meta,
                                  { minor => 1,
                                    dontlog => 1 } );

    _printMsg( $session, "  - Topic $web.$statsTopic updated" );
}

#===========================================================
sub _processWeb {
    my( $session, $web, $logYearMo, $logMonYear, $viewRef, $contribRef,
        $statViewsRef, $statSavesRef, $statUploadsRef ) = @_;

    _printMsg( $session, "* Reporting on $web web" );

    # Handle null values, print summary message to browser/stdout
    my $statViews = $statViewsRef->{$web};
    my $statSaves = $statSavesRef->{$web};
    my $statUploads = $statUploadsRef->{$web};
    $statViews ||= 0;
    $statSaves ||= 0;
    $statUploads ||= 0;
    _printMsg( $session, "  - view: $statViews, save: $statSaves, upload: $statUploads" );
    
    # Get the top N views and contribs in this web
    my (@topViews) = _getTopList( $TWiki::cfg{Stats}{TopViews}, $web, $viewRef );
    my (@topContribs) = _getTopList( $TWiki::cfg{Stats}{TopContrib}, $web, $contribRef );

    # Print information to stdout
    my $statTopViews = '';
    my $statTopContributors = '';
    if( @topViews ) {
        $statTopViews = join( CGI::br(), @topViews );
        $topViews[0] =~ s/[\[\]]*//g;
        _printMsg( $session, '  - top view: '.$topViews[0] );
    }
    if( @topContribs ) {
        $statTopContributors = join( CGI::br(), @topContribs );
        $topContribs[0] =~ s/^.*\]\[([^\]]*).*$/$1/;
        _printMsg( $session, '  - top contributor: '.$topContribs[0] );
    }

    # Update the WebStatistics topic

    my $line;
    my $statsTopic = $TWiki::cfg{Stats}{TopicName};
    my( $meta, $text );
    if( $session->{store}->topicExists( $web, $statsTopic ) ) {
        ( $meta, $text ) = $session->{store}->readTopic( undef, $web, $statsTopic );
    } else {
        ( $meta, $text ) = $session->{store}->readTopic( undef, '_default', $statsTopic );
    }

    my @lines = split( /\r?\n/, $text );
    my $statLine;
    my $idxStat = -1;
    my $idxTmpl = -1;
    for( my $x = 0; $x < @lines; $x++ ) {
        $line = $lines[$x];
        # Check for existing line for this month+year in new and legacy format
        if( $line =~ /^\| ($logYearMo|$logMonYear) / ) {
            $idxStat = $x;
        } elsif( $line =~ /<\!\-\-statDate\-\->/ ) {
             $statLine = $line;
             $idxTmpl = $x;
        }
    }
    if( ! $statLine ) {
        $statLine = '| <!--statDate--> | <!--statViews--> | <!--statSaves--> | <!--statUploads--> '
                  . '| <!--statTopViews--> | <!--statTopContributors--> |';
    }
    $statLine =~ s/<\!\-\-statDate\-\->/$logYearMo/;
    $statLine =~ s/<\!\-\-statViews\-\->/ $statViews/;
    $statLine =~ s/<\!\-\-statSaves\-\->/ $statSaves/;
    $statLine =~ s/<\!\-\-statUploads\-\->/ $statUploads/;
    $statLine =~ s/<\!\-\-statTopViews\-\->/$statTopViews/;
    $statLine =~ s/<\!\-\-statTopContributors\-\->/$statTopContributors/;

    if( $idxStat >= 0 ) {
        # entry already exists, need to update
        $lines[$idxStat] = $statLine;

    } elsif( $idxTmpl >= 0 ) {
        # entry does not exist, add after <!--statDate--> line
        $lines[$idxTmpl] = "$lines[$idxTmpl]\n$statLine";

    } else {
        # entry does not exist, add at the end
        $lines[@lines] = $statLine;
    }
    $text = join( "\n", @lines );
    $text .= "\n";
    $session->{store}->saveTopic( $session->{user}, $web, $statsTopic,
                                  $text, $meta,
                                  { minor => 1,
                                    dontlog => 1 } );

    _printMsg( $session, "  - Topic $statsTopic updated" );
}

#===========================================================
# Get the items with top N frequency counts
# Items can be topics (for view hash) or users (for contrib hash)
#===========================================================
sub _getTopList
{
    my( $theMaxNum, $webName, $statsRef ) = @_;

    my @webs = ( $webName );
    @webs = sort keys %$statsRef unless( $webName );

    my @list = ();
    my $topicName;
    my $statValue;
    my $topicsRef;

    foreach my $web ( @webs ) {
        # Get reference to the sub-hash for this web
        my $webhashref = $statsRef->{$web};

        # print "Main.WebHome views = " . $statsRef->{$web}{'WebHome'}."\n";
        # print "Main web, TWikiGuest contribs = " . ${$statsRef}{$web}{'Main.TWikiGuest'}."\n";

        while( ( $topicName, $statValue ) = each( %$webhashref ) ) {
            $topicsRef->{$topicName} += $statValue;
        }
    }

    # Convert sub hash of item=>statsvalue pairs into an array, @list, 
    # of '$statValue $topicName', ready for sorting.
    while( ( $topicName, $statValue ) = each( %$topicsRef ) ) {
        # Right-align statistic value for sorting
        $statValue = sprintf '%7d', $statValue;
        # Fix Web.TopicName to [[Web.TopicName][TopicName]]
        if( $topicName =~ /^(.*)\.(.*)$/ ) {
            $topicName = "$1.$2][$2";
        }
        # Add new array item at end of array
        push( @list, "$statValue [[$topicName]]");
    }

    # Sort @list by frequency and pick the top N entries
    if( @list ) {
        my $i = 0;
        @list =
          # Limit the array size
          grep{ $i++ < $theMaxNum}
          # Prepend spaces depending on number of digits
          map{ s/^([0-9][0-9][^0-9])/\&nbsp\;$1/; $_ }
          map{ s/^([0-9][^0-9])/\&nbsp\;\&nbsp\;$1/; $_ }
          # Sort numerically, descending order
          sort { (split / /, $b)[0] <=> (split / /, $a)[0] }
          # Strip initial spaces
          map{ s/^\s*//; $_ } @list;
    }
    return @list;
}

#===========================================================
sub _printMsg {
    my( $session, $msg ) = @_;

    if( $session->inContext('command_line') ) {
        $msg =~ s/&nbsp;/ /go;
    } else {
        if( $msg =~ s/^\!// ) {
            $msg = CGI::h4( CGI::span( { class=>'twikiAlert' }, $msg ));
        } elsif( $msg =~ /^[A-Z]/ ) {
            # SMELL: does not support internationalised script messages
            $msg =~ s/^([A-Z].*)/CGI::h3($1)/ge;
        } else {
            $msg =~ s/(\*\*\*.*)/CGI::span( { class=>'twikiAlert' }, $1 )/ge;
            $msg =~ s/^\s\s/&nbsp;&nbsp;/go;
            $msg =~ s/^\s/&nbsp;/go;
            $msg .= CGI::br();
        }
        $msg =~ s/==([A-Z]*)==/'=='.CGI::span( { class=>'twikiAlert' }, $1 ).'=='/ge;
    }
    $session->{response}->body( ($session->{response}->body || '') . $msg . "\n" );
}

#===========================================================
1;
