# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
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
use File::Copy qw(copy);
use IO::File;
use Error qw( :try );

my $debug = 0;

=pod

---++ StaticMethod statistics( $session )
=statistics= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Generate statistics topic.
If a web is specified in the session object, generate WebStatistics
topic update for that web. Otherwise do it for all webs

=cut

sub statistics {
    my $session = shift;

    my $webName = $session->{webName};

    my $tmp = '';
    my $destWeb = $TWiki::cfg{UsersWebName}; #web to redirect to after finishing
    my $logDate = $session->{cgiQuery}->param( 'logdate' ) || '';
    $logDate =~ s/[^0-9]//g;  # remove all non numerals
    $debug = $session->{cgiQuery}->param( 'debug' );

    if( !$session->{scripted} ) {
        # running from CGI
        $session->writePageHeader();
        print CGI::start_html(-title=>'TWiki: Create Usage Statistics');
    }

    # Initial messages
    _printMsg( 'TWiki: Create Usage Statistics', $session );
    _printMsg( '!Do not interrupt this script!' );
    _printMsg( '(Please wait until page download has finished)' );

    unless( $logDate ) {
        $logDate =
          TWiki::Time::formatTime( time(), '$year$mo', 'servertime' );
    }

    my $logMonth;
    my $logYear;
    if ( $logDate =~ /^(\d\d\d\d)(\d\d)$/ ) {
        $logYear = $1;
        $logMonth = $TWiki::Time::ISOMONTH[ ( $2 % 12 ) - 1 ];
    } else {
        _printMsg( "!Error in date $logDate - must be YYYYMM", $session );
        return;
    }

    my $logMonthYear = "$logMonth $logYear";
    _printMsg( "* Statistics for $logMonthYear", $session );

    my $logFile = $TWiki::cfg{LogFileName};
    $logFile =~ s/%DATE%/$logDate/g;

    unless( -e $logFile ) {
        _printMsg( "!Log file $logFile does not exist; aborting", $session );
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
        or throw Error::Simple( "Can't copy $logFile to $tmpFilename - $!" );

    my $TMPFILE = new IO::File;
    open $TMPFILE, $tmpFilename
      or throw Error::Simple( "Can't open $tmpFilename - $!" );

    # Do a single data collection pass on the temporary copy of logfile,
    # then process each web once.
    my ($viewRef, $contribRef, $statViewsRef, $statSavesRef, 
        $statUploadsRef) = _collectLogData( $session, $TMPFILE, $logMonthYear );

#    # DEBUG ONLY
#    _debugPrintHash($viewRef);
#    _debugPrintHash($contribRef);
#    print "statViews tests===========\n";
#    print "Views in Main = " . ${$statViewsRef}{'Main'} . "\n";
#    print "hash stats (used/avail) = " . %{$statViewsRef}."\n";
#    foreach my $web (keys %{$statViewsRef}) {
#        print "Web summary for $web\n";
#        print $statViewsRef->{$web}."\n";
#        print $statSavesRef->{$web}."\n";
#        print $statUploadsRef->{$web}."\n";
#    }

    my @weblist;

    if( $session->{webName} ) {
        # do a particular web:
        push( @weblist, $session->{webName} );
    } else {
        # do all user webs:
        @weblist = $session->{store}->getListOfWebs( 'user' );
    }
    my $firstTime = 1;
    foreach my $web ( @weblist ) {
        $destWeb = _processWeb( $session,
                                "/$web",
                                $logMonthYear,
                                $viewRef,
                                $contribRef,
                                $statViewsRef,
                                $statSavesRef,
                                $statUploadsRef,
                                $firstTime );
        $firstTime = 0;
    }

    close $TMPFILE;		# Shouldn't be necessary with 'my'
    unlink $tmpFilename;# FIXME: works on Windows???  Unlink before
    # usage to ensure deleted on crash?

    if( !$session->{scripted} ) {
        $tmp = $TWiki::cfg{Stats}{TopicName};
        my $url = $session->getScriptUrl( $destWeb, $tmp, 'view' );
        _printMsg( '* Go back to '
                   . CGI::a( { href => $url,
                               rel => 'nofollow' }, $tmp), $session );
    }
    _printMsg( 'End creating usage statistics', $session );
    print CGI::end_html() unless( $session->{scripted} );
}

# Debug only
# Print all entries in a view or contrib hash, sorted by web and item name
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


# Process the whole log file and collect information in hash tables.
# Must build stats for all webs, to handle case of renames into web
# requested for a single-web statistics run.
#
# Main hash tables are divided by web:
#
#   $view{$web}{$TopicName} == number of views, by topic
#   $contrib{$web}{"Main.".$WikiName} == number of saves/uploads, by user

sub _collectLogData {
    my( $session, $TMPFILE, $theLogMonthYear ) = @_;

    # Log file format:
    # | date | user | op | web.topic | notes | ip |
    # date = e.g. 03 Feb 2000 - 02:43
    # user = e.g. Main.PeterThoeny
    # user = e.g. PeterThoeny
    # user = e.g. peter (intranet login)
    # web.topic = e.g MyWeb.MyTopic
    # notes = e.g. minor
    # notes = e.g. not on thursdays
    # ip = e.g. 127.0.0.5

    my %view;		# Hash of hashes, counts topic views by (web, topic)
    my %contrib;	# Hash of hashes, counts uploads/saves by (web, user)

    # Hashes for each type of statistic, one hash entry per web
    my %statViews;
    my %statSaves;
    my %statUploads;

    # Imported regex objects, supporting I18N
    my $webNameRegex = $TWiki::regex{webNameRegex};
    my $wikiWordRegex = $TWiki::regex{wikiWordRegex};
    my $abbrevRegex = $TWiki::regex{abbrevRegex};

    # Script regexes
    my $intranetUserRegex = qr/[a-z0-9]+/;	# FIXME: should centralise this
    my $userRegex = qr/(?:$intranetUserRegex|$wikiWordRegex)/o;
    my $opRegex = qr/[a-z0-9]+/;        	# Operation, no i18n needed
    # my $topicRegex = qr/(?:$wikiWordRegex|$abbrevRegex)/; 	# Strict topic names only
    my $topicRegex = qr/[^ ]+/; 	# Relaxed topic names - any non-space OK
    # but won't be auto-linked in WebStatistics
    my $errorRegex = qr/\(not exist\)/; 	# Match '(not exist)' flag

    binmode $TMPFILE;
    while ( my $line = <$TMPFILE> ) {
        my @fields = split( /\s*\|\s*/, $line );

        my( $date, $userName );
        while( !$date && scalar( @fields )) {
            $date = shift @fields;
        }
        while( !$userName && scalar( @fields )) {
            $userName = shift @fields;
        }
        my( $opName, $webTopic, $notes, $ip ) = @fields;

        # ignore minor changes - not statistically helpful
        next if( $notes && $notes =~ /(minor|dontNotify)/ );

        if( $opName && $webTopic =~ /($webNameRegex)\.($wikiWordRegex)/ ) {
            my $webName = $1;
            my $topicName = $2;

            if( $opName eq 'view' ) {
                $statViews{$webName}++;
                unless( $notes =~ /\(not exist\)/ ) {
                    $view{$webName}{$topicName}++;
                }

            } elsif( $opName eq 'save' ) {
                $statSaves{$webName}++;
                $contrib{$webName}{$userName}++;

            } elsif( $opName eq 'upload' ) {
                $statUploads{$webName}++;
                $contrib{$webName}{$userName}++;

            } elsif( $opName eq 'rename' ) {
                # Pick up the old and new topic names
                $notes =~/moved to ($webNameRegex)\.($topicRegex)/o;
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
            $session->writeDebug('Bad logfile line '.$line);
        }
    }

    return \%view, \%contrib, \%statViews, \%statSaves, \%statUploads;
}

sub _processWeb {
    my( $session, $thePathInfo, $theLogMonthYear, $viewRef, $contribRef,
        $statViewsRef, $statSavesRef, $statUploadsRef, $isFirstTime ) = @_;

    # We create a new session object to parse the path info
    $session =
      new TWiki( $thePathInfo, $session->{user}->login(),
                 $session->{topicName}, '', $session->{cgiQuery} );

    my ( $topic, $webName, $user ) =
      ( $session->{topicName}, $session->{webName}, $session->{user} );

    if( $isFirstTime ) {
        my $tmp = $user->wikiName();
        $tmp .= ' as shell script' unless( $session );
        _printMsg( "* Executed by $tmp", $session );
    }

    _printMsg( "* Reporting on TWiki.$webName web", $session );

    # Handle null values, print summary message to browser/stdout
    my $statViews = $statViewsRef->{$webName};
    my $statSaves = $statSavesRef->{$webName};
    my $statUploads = $statUploadsRef->{$webName};
    $statViews ||= 0;
    $statSaves ||= 0;
    $statUploads ||= 0;
    _printMsg( "  - view: $statViews, save: $statSaves, upload: $statUploads", $session );

    
    # Get the top N views and contribs in this web
    my (@topViews) = _getTopList( $TWiki::cfg{Stats}{TopViews}, $webName, $viewRef );
    my (@topContribs) = _getTopList( $TWiki::cfg{Stats}{TopContrib}, $webName, $contribRef );

    # Print information to stdout
    my $statTopViews = '';
    my $statTopContributors = '';
    if( @topViews ) {
        $statTopViews = join( CGI::br(), @topViews );
        $topViews[0] =~ s/[\[\]]*//g;
        _printMsg( '  - top view: '.$topViews[0], $session );
    }
    if( @topContribs ) {
        $statTopContributors = join( CGI::br(), @topContribs );
        _printMsg( '  - top contributor: '.$topContribs[0], $session );
    }

    # Update the WebStatistics topic

    my $tmp;
    my $statsTopic = $TWiki::cfg{Stats}{TopicName};
    # DEBUG
    # $statsTopic = 'TestStatistics';		# Create this by hand
    if( $session->{store}->topicExists( $webName, $statsTopic ) ) {
        my( $meta, $text ) =
          $session->{store}->readTopic( undef, $webName, $statsTopic, undef );
        my @lines = split( /\n/, $text );
        my $statLine;
        my $idxStat = -1;
        my $idxTmpl = -1;
        for( my $x = 0; $x < @lines; $x++ ) {
            $tmp = $lines[$x];
            # Check for existing line for this month+year
            if( $tmp =~ /$theLogMonthYear/ ) {
                $idxStat = $x;
            } elsif( $tmp =~ /<\!\-\-statDate\-\->/ ) {
                $statLine = $tmp;
                $idxTmpl = $x;
            }
        }
        if( ! $statLine ) {
            $statLine = '| <!--statDate--> | <!--statViews--> | <!--statSaves--> | <!--statUploads--> | <!--statTopViews--> | <!--statTopContributors--> |';
        }
        $statLine =~ s/<\!\-\-statDate\-\->/$theLogMonthYear/;
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

        $session->{store}->saveTopic( $user, $webName, $statsTopic,
                                      $text, $meta,
                                      { minor => 1,
                                        dontlog => 1 } );

        _printMsg( "  - Topic $statsTopic updated", $session );

    } else {
        _printMsg( "! Warning: No updates done, topic $webName.$statsTopic does not exist", $session );
    }

    return $webName;
}

# Get the items with top N frequency counts
# Items can be topics (for view hash) or users (for contrib hash)
sub _getTopList
{
    my( $theMaxNum, $webName, $statsRef ) = @_;

    # Get reference to the sub-hash for this web
    my $webhashref = $statsRef->{$webName};

    # print "Main.WebHome views = " . $statsRef->{$webName}{'WebHome'}."\n";
    # print "Main web, TWikiGuest contribs = " . ${$statsRef}{$webName}{'Main.TWikiGuest'}."\n";

    my @list = ();
    my $topicName;
    my $statValue;

    # Convert sub hash of item=>statsvalue pairs into an array, @list, 
    # of '$statValue $topicName', ready for sorting.
    while( ( $topicName, $statValue ) = each( %$webhashref ) ) {
        # Right-align statistic value for sorting
        $statValue = sprintf '%7d', $statValue;	
        # Add new array item at end of array
        if( $topicName =~ /\./ ) {
            $list[@list] = "$statValue $topicName";
        } else {
            $list[@list] = "$statValue [[$topicName]]";
        }
    }

    # DEBUG
    # print " top N list for $webName\n";
    # print join "\n", @list;

    # Sort @list by frequency and pick the top N entries
    if( @list ) {
        # Strip initial spaces
        @list = map{ s/^\s*//; $_ } @list;

        @list = # Prepend spaces depending on no. of digits
          map{ s/^([0-9][0-9][^0-9])/\&nbsp\;$1/; $_ }
            map{ s/^([0-9][^0-9])/\&nbsp\;\&nbsp\;$1/; $_ }
              # Sort numerically, descending order
              sort { (split / /, $b)[0] <=> (split / /, $a)[0] }  @list;

        if( $theMaxNum >= @list ) {
            $theMaxNum = @list - 1;
        }
        return @list[0..$theMaxNum];
    }
    return @list;
}

sub _printMsg {
    my( $msg, $session ) = @_;

    if( $session->{scripted} ) {
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
    print $msg,"\n";
}

1;
