# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2002 Richard Donkin, rdonkin@bigfoot.com
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
=begin twiki

---+ TWiki::UI::Statistics
Statistics extraction and presentation

=cut
package TWiki::UI::Statistics;

use strict;
use File::Copy qw(copy);
use IO::File;
use Error qw( :try );

use constant ISOMONTH => qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

my $debug = 0;

=pod

---++ statistics( $session )
Generate statistics topic.
If a web is specified in the session object, generate WebStatistics
topic update for that web. Otherwise do it for all webs

=cut
sub statistics {
    my $session = shift;

    my $webName = $session->{webName};

    my $tmp = "";
    my $destWeb = $TWiki::cfg{UsersWebName}; #web to redirect to after finishing
    my $logDate = "".$session->{cgiQuery}->param( 'logdate' );
    $logDate =~ s/[^0-9]//g;  # remove all non numerals
    $debug = $session->{cgiQuery}->param( 'debug' );

    if( !$session->{scripted} ) {
        # running from CGI
        my $mess =
          "<html>\n<head>\n<title>TWiki: Create Usage Statistics</title>\n" .
            "</head>\n<body>\n";
        $session->writePageHeader();
        print $mess;
    }

    # Initial messages
    _printMsg( "TWiki: Create Usage Statistics", $session );
    _printMsg( "!Do not interrupt this script!" );
    _printMsg( "(Please wait until page download has finished)" );

    unless( $logDate ) {
        # get current local time and format to "yyyymm" format:
        my ( $sec, $min, $hour, $mday, $mon, $year) = localtime( time() );
        $year = sprintf("%.4u", $year + 1900);  # Y2K fix
        $mon = $mon+1;
        $logDate = sprintf("%.4u%.2u", $year, $mon);
    }

    my $logMonth;
    my $logYear;
    $tmp = $logDate;
    $tmp =~ s/([0-9]{4})(.*)/$2/g;
    if( $tmp && $tmp < 13 ) {
        $logMonth = (ISOMONTH)[$tmp-1];
    } else {
        $logMonth = "Date error";
    }
    $logYear = $logDate;
    $logYear =~ s/([0-9]{4})(.*)/$1/g;
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
    if ( $TWiki::cfg{OS} eq "UNIX" ) { 
        $tmpDir = $ENV{'TEMP'} || "/tmp"; 
    } elsif ( $TWiki::cfg{OS} eq "WINDOWS" ) {
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

=pod
    # DEBUG ONLY
    _debugPrintHash($viewRef);
    _debugPrintHash($contribRef);
    print "statViews tests===========\n";
    print "Views in Main = " . ${$statViewsRef}{'Main'} . "\n";
    print "hash stats (used/avail) = " . %{$statViewsRef}."\n";
    foreach my $web (keys %{$statViewsRef}) {
        print "Web summary for $web\n";
        print $statViewsRef->{$web}."\n";
        print $statSavesRef->{$web}."\n";
        print $statUploadsRef->{$web}."\n";
    }
=cut

    my @weblist;

    if( $session->{webName} ) {
        # do a particular web:
        push( @weblist, $session->{webName} );
    } else {
        # do all webs:
        @weblist = grep{ /^[^\.\_]/ } $session->{store}->getAllWebs( "" );
    }
    my $firstTime = 1;
    foreach my $web ( @weblist ) {
        if( $session->{store}->webExists( $web ) ) {
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
        } else {
            _printMsg( "!Error: $web does not exist", $session );
        }
    }

    close $TMPFILE;		# Shouldn't be necessary with 'my'
    unlink $tmpFilename;# FIXME: works on Windows???  Unlink before
    # usage to ensure deleted on crash?

    if( !$session->{scripted} ) {
        $tmp = $TWiki::cfg{Stats}{TopicName};
        my $url = $session->getScriptUrl( $destWeb, $tmp, "view" );
        _printMsg( "* Go back to <a href=\"$url\">$tmp</a> topic", $session );
    }
    _printMsg( "End creating usage statistics", $session );
    print "</body></html>\n" unless( $session->{scripted} );
}

# Debug only
# Print all entries in a view or contrib hash, sorted by web and item name
sub _debugPrintHash {
    my ($statsRef) = @_;
    # print "Main.WebHome views = " . ${$statsRef}{'Main'}{'WebHome'}."\n";
    # print "Main web, TWikiGuest contribs = " . ${$statsRef}{'Main'}{'Main.TWikiGuest'}."\n";
    foreach my $web ( sort keys %$statsRef) {
        my $count = 0;
        print "$web web:\n";
        # Get reference to the sub-hash for this web
        my $webhashref = ${$statsRef}{$web};
		# print "webhashref is " . ref ($webhashref) ."\n";
        # Items can be topics (for view hash) or users (for contrib hash)
        foreach my $item ( sort keys %$webhashref ) {
            print "  $item = ";
            print "" . ( ${$webhashref}{$item} || 0 ) ."\n";
            $count += ${$webhashref}{$item};
        }
        print "  WEB TOTAL = $count\n";
    }
}


# =========================
# Process the whole log file and collect information in hash tables.
# Must build stats for all webs, to handle case of renames into web
# requested for a single-web statistics run.
#
# Main hash tables are divided by web:
#
#   $view{$web}{$TopicName} == number of views, by topic
#   $contrib{$web}{"Main.".$WikiName} == number of saves/uploads, by user

sub _collectLogData
{
    my( $session, $TMPFILE, $theLogMonthYear ) = @_;

    # Examples of log file format:
    # | 03 Feb 2000 - 02:43 | Main.PeterThoeny | view | Know.WebHome |  |
    # | 03 Feb 2000 - 02:43 | Main.PeterThoeny | save | Know.WebHome |  |
    # | 03 Feb 2000 - 02:53 | Main.PeterThoeny | save | Know.WebHome | repRev 1.7 Main.PeterThoeny 2000/02/03 02:43:22 |
    # | 23 Feb 2002 - 11:07 | Main.TWikiGuest | search | Main | Office *Locations[^A-Za-z] | 127.0.0.1 |
    #   	Note: there's no topic name on search log entry
    # | 23 Feb 2002 - 11:07 | Main.guest | search | Main | Office *Locations[^A-Za-z] | 127.0.0.1 |
    # | 28 Mar 2002 - 07:11 | Main.FredBloggs | rename | Test.TestTopic7 | moved to Test.TestTopic7New  | 127.0.0.1 |

    
    my %view;		# Hash of hashes, counts topic views by <web, topic>
    my %contrib;	# Hash of hashes, counts uploads/saves by <web, user>

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
    my $userRegex = qr/(?:$intranetUserRegex|$wikiWordRegex)/; 
    my $opRegex = qr/[a-z0-9]+/;        	# Operation, no i18n needed
    # my $topicRegex = qr/(?:$wikiWordRegex|$abbrevRegex)/; 	# Strict topic names only
    my $topicRegex = qr/[^ ]+/; 	# Relaxed topic names - any non-space OK
    # but won't be auto-linked in WebStatistics
    my $errorRegex = qr/\(not exist\)/; 	# Match '(not exist)' flag

    my ($webName, $opName, $topicName, $userName, $newTopicName, $newTopicWeb);
    binmode $TMPFILE;
    while ( <$TMPFILE> ) {
        my $line = $_;
        $line =~ s/\r*\n$//;		# Clean out line endings

        $line =~ /^\|[^\|]*\| ($webNameRegex\.$userRegex) \| ($opRegex) \| ($webNameRegex)[. ]/o;
        $userName = $1 || "";		# Main.FredBloggs
        $opName = $2 || "";
        $webName = $3 || "";

        # Skip bad logfile lines and warn if necessary
        unless ($userName && $opName && $webName) {
            if( $debug ) {
                $session->writeDebug("Invalid log file line = '$line'");
                $session->writeDebug("userName = '$userName'");
                $session->writeDebug("opName = '$opName'");
                $session->writeDebug("webName = '$webName'");
            }
            next;
        }

        my $logContrib = 0;

        if ($opName eq 'view' ) {
            $statViews{$webName}++;
            # Pick up the topic name and any error string
            $line =~ /^\|[^\|]*\| ($webNameRegex\.$userRegex) \| ($opRegex) \| ($webNameRegex)\.($topicRegex) \| +(${errorRegex}?) */o;
            $topicName = $4 || "";
            my $noSuchTopic = $5 || "";		# Set if '(not exist)' matched

            unless( $topicName ) {
                if( $debug ) {
                    $session->writeDebug("Invalid log file line = '$line'");
                    $session->writeDebug("userName = '$userName'");
                    $session->writeDebug("opName = '$opName'");
                    $session->writeDebug("webName = '$webName'");
                    $session->writeDebug("topicName = '$topicName'");
                }
                next;
            }

            # Skip accesses to non-existent topics
            if ($noSuchTopic) {
                next;
            } else {
                # Count this topic access
                $view{$webName}{$topicName}++;
            }

        } elsif ($opName eq 'save' ) {
            $statSaves{$webName}++;
            $logContrib = 1;

        } elsif ($opName eq 'upload' ) {
            $statUploads{$webName}++;
            $logContrib = 1;

        } elsif ($opName eq 'rename' ) {
            # Pick up the old and new topic names
            $line =~ /^\|[^\|]*\| ($webNameRegex\.$userRegex) \| ($opRegex) \| ($webNameRegex)\.($topicRegex) \| moved to ($webNameRegex)\.($topicRegex) /o;
            $topicName = $4 || "";
            $newTopicWeb = $5 || "";
            $newTopicName = $6 || "";
            ## session->writeDebug("$topicName renamed to $newTopicWeb.$newTopicName");

            unless ($topicName && $newTopicWeb && $newTopicName) {
                if( $debug ) {
                    $session->writeDebug("Invalid log file line (rename) = '$line'");
                    $session->writeDebug("userName = '$userName'");
                    $session->writeDebug("opName = '$opName'");
                    $session->writeDebug("webName = '$webName'");
                    $session->writeDebug("topicName= '$topicName'");
                    $session->writeDebug("newTopicWeb= '$newTopicWeb'");
                    $session->writeDebug("newTopicName = '$newTopicName'");
                }
                next;
            }
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
        # Record saves and uploads
        if ($logContrib) {
            # Record the contribution by user name
            $contrib{$webName}{$userName}++;
        }
=pod
        # DEBUG
        $. <= 5 && print "$line\n";
        print "$line\n";
        print "$.: $userName did $opName on $webName";
        print ".$topicName" if (defined $topicName);
        print "\n";
=cut

}

=pod

    print "Main.WebHome views = " . $view{'Main'}{'WebHome'}."\n";
    print "Main web's contribs = " . $contrib{'Main'}{'Main.RichardDonkin'}."\n";
    _debugPrintHash(\%view);
    _debugPrintHash(\%contrib);
=cut
    return \%view, \%contrib, \%statViews, \%statSaves, \%statUploads;
}

# =========================
sub _processWeb {
    my( $session, $thePathInfo, $theLogMonthYear, $viewRef, $contribRef,
        $statViewsRef, $statSavesRef, $statUploadsRef, $isFirstTime ) = @_;

    # We create a new session object to parse the path info
    $session =
      new TWiki( $thePathInfo, $session->{user}->login(),
                 $session->{topicName}, "", $session->{cgiQuery} );

    my ( $topic, $webName, $user ) =
      ( $session->{topicName}, $session->{webName}, $session->{user} );

    if( $isFirstTime ) {
        my $tmp = $user->wikiName();
        $tmp .= " as shell script" unless( $session );
        _printMsg( "* Executed by $tmp", $session );
    }

    _printMsg( "* Reporting on TWiki.$webName web", $session );

    if( ! $session->{store}->webExists( $webName ) ) {
        _printMsg( "! Error: Web $webName does not exist", $session );
        return $TWiki::cfg{UsersWebName};
    }

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
    my $statTopViews = "";
    my $statTopContributors = "";
    if( @topViews ) {
        $statTopViews = join( "<br /> ", @topViews );
        $topViews[0] =~ s/[\[\]]*//g;
        _printMsg( "  - top view: $topViews[0]", $session );
    }
    if( @topContribs ) {
        $statTopContributors = join( "<br /> ", @topContribs );
        _printMsg( "  - top contributor: $topContribs[0]", $session );
    }

    # Update the WebStatistics topic

    my $tmp;
    my $statsTopic = $TWiki::cfg{Stats}{TopicName};
    # DEBUG
    # $statsTopic = "TestStatistics";		# Create this by hand
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
            $statLine = "| <!--statDate--> | <!--statViews--> | <!--statSaves--> | <!--statUploads--> | <!--statTopViews--> | <!--statTopContributors--> |";
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
                                      { dontnotify => 1,
                                        dontlog => 1 } );

        _printMsg( "  - Topic $statsTopic updated", $session );

    } else {
        _printMsg( "! Warning: No updates done, topic $webName.$statsTopic does not exist", $session );
    }

    return $webName;
}

# =========================
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
        $statValue = sprintf "%7d", $statValue;	
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
            $msg = "<h4><font color=\"red\"><span class=\"twikiAlert\">$msg</span></font>";

        } elsif( $msg =~ /^[A-Z]/ ) {
            # SMELL: does not support internationalised script messages
            $msg =~ s/^([A-Z].*)/<h3>$1<\/h3>/go;
        } else {
            $msg =~ s/(\*\*\*.*)/<font color=\"#FF0000\"><span class=\"twikiAlert\">$1<\/span><\/font>/go;
            $msg =~ s/^\s\s/&nbsp;&nbsp;/go;
            $msg =~ s/^\s/&nbsp;/go;
            $msg .= "<br />";
        }
        $msg =~ s/==([A-Z]*)==/<font color=\"#FF0000\"><span class=\"twikiAlert\">==$1==<\/span><\/font>/go;
    }
    print "$msg\n";
}

1;
