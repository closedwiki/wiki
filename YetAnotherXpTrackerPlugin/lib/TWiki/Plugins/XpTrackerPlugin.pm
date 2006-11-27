# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2004-2006 Thomas Weigert, weigert@comcast.net
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
# =========================
#
#
# For debugging
=pod

# Debug new topic creation
perl -dT view "Trackingtest.OngoingIteration" -user guest -sequence "checked" -topic "MyNew" -parent "OngoingIteration" -templatetopic "StoryTemplate" -xpsave "1"

=cut

# =========================
package TWiki::Plugins::XpTrackerPlugin;

use HTTP::Date;
use TWiki::Plugins::XpTrackerPlugin::Business;
use Time::CTime;
use TWiki::Time;
use TWiki;

use strict;

# Use -any to force creation of functions for unrecognised tags, like del and ins,
# on earlier releases of CGI.pm (pre 2.79)
use CGI qw( -any );

# Too many warnings, temporarily turn these off
# Maybe make that more specific to the individual functions that cause errors
no warnings qw(uninitialized numeric);

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug
    );

use vars qw ( @timeRec %defaults
        $cacheFileName
	$cacheInitialized
        %cachedProjectTeams
        %cachedTeamIterations
        %cachedIterationStories
        $encodeStart $encodeEnd
	@addtlStoryFields $storyCompleteInd
	@statusLiterals
	$teamLbl $projectLbl $addSpacer
	$tableNr
    );

$VERSION = '$Rev: 0$';
$RELEASE = 'Dakar';
$pluginName = 'XpTrackerPlugin';  # Name of this Plugin

$encodeStart = "--EditTableEncodeStart--";
$encodeEnd   = "--EditTableEncodeEnd--";
$cacheFileName = '';

#$debug = 1;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::initPlugin is OK" ) if $debug;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "This version of $pluginName works only with TWiki 4 and greater." );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    my $cachedir = TWiki::Func::getWorkArea($pluginName);
    # Need to make sure multiple tracking directories don't clobber each other.
    # Should have a way of stopping this plugin when there is no tracking in
    # this web.
    $cacheFileName = "$cachedir/${web}_xpcache";

    # reasonable defaults for colouring. By default task and stories
    # have the same colour schemes.
    %defaults = (
        headercolor             => &TWiki::Func::getPreferencesValue("WEBBGCOLOR", $web),
        taskunstartedcolor      => '#FFCCCC',
        taskprogresscolor       => '#FFFF99',
        taskcompletecolor       => '#99FF99',
        storyunstartedcolor     => '#FFCCCC',
        storyprogresscolor      => '#FFFF99',
        storyacceptancecolor    => '#CCFFFF',
        storycompletecolor      => '#99FF99',
	ongoingcolor            => '#FFFFFF',
	sort                    => 'Submitdate'
    );

    # now get defaults from XpTrackerPlugin topic
    my $v;
    foreach my $option (keys %defaults) {
        # read defaults from XpTrackerPlugin topic
        $v = &TWiki::Func::getPreferencesValue("\U$pluginName\E_\U$option\E") || undef;
        $defaults{$option} = $v if defined($v);
    }

    # Get additional story fields
    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );
    # Get plugin field customization flag
    my $addtlStoryFields = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_ADDTLSTORYFIELDS" );
    @addtlStoryFields = split(/[\s,]+/, $addtlStoryFields);
    # Get plugin story complete indication
    $storyCompleteInd = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_STORYACCEPTEDINDICATION" );
    my $storyAcceptLit = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_ACCEPTANCELITERAL" );
    
    # Defaults for status literals
    my %literals = (
        notstartedliteral       => "Not Started",
        inprogressliteral       => "In progress",
        completeliteral         => "Complete",
        acceptanceliteral       => $storyAcceptLit,
        ongoingliteral          => "Ongoing"
    );

    # now get defaults from XpTrackerPlugin topic
    foreach my $option (keys %literals) {
        # read defaults from XpTrackerPlugin topic
        $v = &TWiki::Func::getPreferencesValue("\U$pluginName\E_\U$option\E") || undef;
        $literals{$option} = $v if defined($v);
    }
    @statusLiterals = ( $literals{notstartedliteral}, 
			$literals{inprogressliteral},
			$literals{completeliteral},
			$literals{acceptanceliteral},
			$literals{ongoingliteral} );

    # Change the pregiven names for Team and Project, if needed
    $projectLbl = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_PROJECTLABEL" );
    $teamLbl = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_TEAMLABEL" );

    $addSpacer = 0;

    # Show all projects
    TWiki::Func::registerTagHandler( 'XPSHOWALLPROJECTS', \&xpShowAllProjects,
                                     'context-free' );
    # Show all teams
    TWiki::Func::registerTagHandler( 'XPSHOWALLTEAMS', \&xpShowAllTeams,
                                     'context-free' );
    # Show all iterations
    TWiki::Func::registerTagHandler( 'XPSHOWALLITERATIONS', \&xpShowAllIterations,
                                     'context-free' );
    # Show all teams on this project. Parameters: project
    TWiki::Func::registerTagHandler( 'XPSHOWPROJECTTEAMS', \&xpShowProjectTeams,
                                     'context-free' );
    # Show all project iterations. Parameters: project
    TWiki::Func::registerTagHandler( 'XPSHOWPROJECTITERATIONS', \&xpShowProjectIterations,
                                     'context-free' );
    # Show all project stories. Parameters: project
    TWiki::Func::registerTagHandler( 'XPSHOWPROJECTSTORIES', \&xpShowProjectStories,
                                     'context-free' );
    # Show completion status of project by stories. Parameters: project
    TWiki::Func::registerTagHandler( 'XPSHOWPROJECTCOMPLETIONBYSTORIES', \&xpShowProjectCompletionByStories,
                                     'context-free' );
    # Show completion status of project by tasks. Parameters: project
    TWiki::Func::registerTagHandler( 'XPSHOWPROJECTCOMPLETIONBYTASKS', \&xpShowProjectCompletionByTasks,
                                     'context-free' );
    # Show all team iterations
    TWiki::Func::registerTagHandler( 'XPSHOWTEAMITERATIONS', \&xpShowTeamIterations,
                                     'context-free' );
    # Show iteration status
    TWiki::Func::registerTagHandler( 'XPSHOWITERATION', \&xpShowIteration,
                                     'context-free' );
    # Show iteration status
    TWiki::Func::registerTagHandler( 'XPSHOWITERATIONTERSE', \&xpShowIterationTerse,
                                     'context-free' );
    # Show velocities by iteration
    TWiki::Func::registerTagHandler( 'XPVELOCITIES', \&xpVelocities,
                                     'context-free' );
    # Dumps an iteration for printing
    # TJW: Not currently supported, as it does not consider the task
    #      tables, nor custom templates.
    #TWiki::Func::registerTagHandler( 'XPDUMPITERATION', \&xpDumpIteration,
    #                                 'context-free' );
    # Show open tasks by developer
    TWiki::Func::registerTagHandler( 'XPSHOWDEVELOPERTASKS', \&xpShowDeveloperTasks,
                                     'context-free' );
    # Show workload by developer and project/iteration
    # "all" means all developers; subsumes %XPSHOWLOADALL%
    TWiki::Func::registerTagHandler( 'XPSHOWLOAD', \&xpShowLoad,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'XPSHOWLOADALL', \&xpShowLoadAll,
                                     'context-free' );
    # Service procedure to show current colours
    TWiki::Func::registerTagHandler( 'XPSHOWCOLOURS', \&xpShowColours,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'XPPIVOTBYFIELD', \&xpPivotByField,
                                     'context-free' );
    TWiki::Func::registerTagHandler( 'XPTEAMPIVOTBYFIELD', \&xpTeamPivotByField,
                                     'context-free' );
    # Show cost of quality by iteration
    TWiki::Func::registerTagHandler( 'XPCOQ', \&xpCoq,
                                     'context-free' );
    # Show cost of quality by iteration
    # Flag indicates whether to skip the ongoing tasks
    TWiki::Func::registerTagHandler( 'XPTEAMCOQREPORT', \&xpTeamCoqReport,
                                     'context-free' );
    # 
    TWiki::Func::registerTagHandler( 'XPTEAMVELOCITYREPORT', \&xpTeamVelocityReport,
                                     'context-free' );
    # Show task table for topic
    TWiki::Func::registerTagHandler( 'XPSHOWTASKTABLE', \&xpShowTaskTable,
                                     'context-free' );
    # 
    TWiki::Func::registerTagHandler( 'XPSHOWDEVELOPERTIMESHEET', \&xpShowDeveloperTimeSheet,
                                     'context-free' );
    # 
    TWiki::Func::registerTagHandler( 'XPSHOWDEVELOPERESTIMATE', \&xpShowDeveloperEstimate,
                                     'context-free' );
    #
    TWiki::Func::registerTagHandler( 'XPCREATETOPIC', \&xpCreateTopic,
                                     'context-free' );


    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    $cacheInitialized = 0;

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    my $tableNr = 0;

    if( TWiki::Func::getCgiQuery()->param( 'xpsave' ) ) {
        xpSavePage($web);
        # return; # in case browser does not redirect
    }

}

###########################
# xpGetMetaValue
#
# Return value from field passed in meta with passed in name

sub xpGetMetaValue {
  my $name = $_[1];
  my $field = $_[0]->get( "FIELD", $name );
  return $field->{value} || "";
}


###########################
# xpStoryComplete
#
# Determine whether a story is complete

sub xpStoryComplete {
  my $status = &xpGetMetaValue($_[0], "State");
  return ($status eq $storyCompleteInd)?"Y":"N";
}

###########################
# xpYNtoBool
#

sub xpYNtoBool {
  return (($_[0] eq "Yes") ? 1 : 0);
}

###########################
# xpShowCell
# Make sure an empty cell still has content

sub xpShowCell {
  my ($item, $cond) = @_;
  return '&nbsp;' unless (! defined $cond || $cond);
  return (defined $item && ! ($item eq '')) ? $item : '&nbsp;';
}

sub xpShowRounded {
  my ($item, $cond) = @_;
  return '&nbsp;' unless (! defined $cond || $cond);
  return (defined $item && ! ($item eq '')) ? xpround($item) : '&nbsp;';
}

sub xpround {
    return $_[0] unless $_[0];
    return sprintf( "%.2f", $_[0] );
}

###########################
# xpDumpIteration
#
# Dumps stories and tasks in an iteration.
# TJW: This does not properly render any text that is held in metadata
# TJW: and shown via custom templates

sub xpDumpIteration {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};

    my @allStories = &xpGetIterStories($iterationName, $web);  

    # Iterate over each and build master list

    my $bigList = "";

    foreach my $story (@allStories) {
        my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
        # Patch the embedded "DumpStoryList" name to the real story name
	if(&xpGetMetaValue($meta, "Iteration") eq $iterationName) {
            # TODO: This is a hack!
            # Patch the embedded %TOPIC% before the main TWiki code does
            $storyText =~ s/%TOPIC%/$story/go;
            $bigList .= CGI::h2( "Story: ".$story ) . "\n".$storyText."<br><br><hr> \n";
        }
    }
    
    return $bigList;
}

###########################
# xpShowIteration
#
# Shows the specified iteration broken down by stories and tasks

sub xpShowIteration {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};

    my $list = '';
    my @colors = ();
    $list .= '|*Story<br>&nbsp; Tasks*|*Estimate*|*Who*|*Spent*|*To do*|*Status*|' . "\n";

    my @allStories = &xpGetIterStories($iterationName, $web);  

    # Iterate over each story and add to hash
    my (%targetStories,%targetOrder,%targetMeta) = ();
    foreach my $story (@allStories) {
        my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
        $targetStories{$story} = $storyText;
	$targetMeta{$story} = $meta;
        # Get the ordering and save it
        $targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
    }

    my ($totalSpent,$totalEtc,$totalEst) = 0;

    # Show them
    foreach my $story (sort { $targetOrder{$a} cmp $targetOrder{$b} || $a cmp $b } keys %targetStories) {

        my $storyText = $targetStories{$story};
	my $meta = $targetMeta{$story};
        
        # Get acceptance test status
        my $storyComplete = &xpStoryComplete($meta);
        
        # Set up other story stats
        my ($storySpent,$storyEtc,$storyCalcEst) = 0;
        
        # Suck in the tasks
        my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
        my $taskCount = 0; # Amount of tasks in this story
        my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
  	my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));

	foreach my $theTask ($meta->find("TABLE")) {
	  (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetTaskDetail($theTask);            
            $taskName[$taskCount] = $name;
            $taskEst[$taskCount] = $est;
            $taskWho[$taskCount] = $who;
            $taskSpent[$taskCount] = $spent;
            $taskEtc[$taskCount] = $etc;
            
            $taskStat[$taskCount] = ($storyOngoing) ? 4 : $tstatus;
            $storyStat[$taskStat[$taskCount]]++;
            
            # Calculate spent
            my @spentList = xpRipWords($taskSpent[$taskCount]);
            foreach my $spent (@spentList) {
                $storySpent += $spent;
            }
            
            # Calculate etc
            my @etcList = xpRipWords($taskEtc[$taskCount]);
            foreach my $etc (@etcList) {
                $storyEtc += $etc;
            }
            
            # Calculate est
            my @estList = xpRipWords($taskEst[$taskCount]);
            foreach my $est (@estList) {
                $storyCalcEst += $est;
            }
            $taskCount++;
        }
        
        # Calculate story status
        my $color = "";
        my $storyStatS = "";
        if ($storyOngoing) {
	  $color = "$defaults{ongoingcolor}";
	  $storyStatS = $statusLiterals[4];
	} elsif ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
            $color = "$defaults{storyunstartedcolor}";
            $storyStatS = $statusLiterals[0];
        } elsif ( ($storyStat[0] == 0) and ($storyStat[1] == 0) ) { # All tasks complete
            if ($storyComplete eq "Y") {
                $storyStatS = $statusLiterals[2];
                $color = "$defaults{storycompletecolor}";
            } else {
                $color = "$defaults{storyacceptancecolor}";
                $storyStatS = $statusLiterals[3];
            }
        } else {
            $color = "$defaults{storyprogresscolor}";
            $storyStatS = $statusLiterals[1];
        }
        
        # Show story line
	my $cells = '| '.$story.' | '.xpShowRounded($storyCalcEst).' | &nbsp; | '.xpShowRounded($storySpent).' | '.xpShowRounded($storyOngoing?'':$storyEtc).' | '.$storyStatS. '|';
        if ($color) {
	  push @colors, $color;
        } else {
	  push @colors, 'none';
	}
	$list .= $cells . "\n";
        
        # Show each task
        for (my $i=0; $i<$taskCount; $i++) {
            
            my $taskBG = "";
            if ($taskStat[$i] == 0) {
                $taskBG = $defaults{taskunstartedcolor};
            }
            elsif ($taskStat[$i] == 1) {
                $taskBG = $defaults{taskprogresscolor};
            }
            elsif ($taskStat[$i] == 2) {
                $taskBG = $defaults{taskcompletecolor};
            }
            elsif ($taskStat[$i] == 4) {
                $taskBG = $defaults{ongoingcolor};
            }

            # Line for each engineer
            my $doName = 1;
            my @who = xpRipWords($taskWho[$i]);
            my @est = xpRipWords($taskEst[$i]);
            my @spent = xpRipWords($taskSpent[$i]);
            my @etc = xpRipWords($taskEtc[$i]);
            for (my $x=0; $x<@who; $x++) {
		push @colors, $taskBG;
                $list .= '| '.($doName?'&nbsp;&nbsp;&nbsp; '.$taskName[$i]:'&nbsp;').' | '.xpShowRounded($est[$x]).' | '.$who[$x].' | '.xpShowRounded($spent[$x]).' | '.xpShowRounded($storyOngoing?'':$etc[$x]).' | '.$statusLiterals[$taskStat[$i]]."|\n";
                $doName = 0;
            }
            
        }
        
        # Add a spacer
	push @colors, 'none' if $addSpacer;
        $list .= "| &nbsp; ||||||\n" if $addSpacer;
        
        # Add to totals
        $totalSpent += $storySpent;
        $totalEtc += $storyEtc;
        $totalEst += $storyCalcEst;
        
    }
    
    # Do iteration totals
    
    my $cells = "|*$teamLbl totals*|";
    $cells .= '*'.xpShowRounded($totalEst).'*|*&nbsp;*|*'.xpShowRounded($totalSpent).'*|*'.xpShowRounded($totalEtc).'*|*&nbsp;*|';
    $list .= $cells . "\n";

    unshift @colors, pop @colors;  # defect in TablePlugin
    my $color = join ',', @colors;
    $list = "---+++ Iteration details\n%TABLE{headerrows=\"1\" footerrows=\"1\" dataalign=\"left,center,left,center,center,center\" headeralign=\"left,center,left,center,center,center\" databg=\"$color\"}%\n" . $list;

    return $list;
}

###########################
# gaugeLite
#
# display gauge using html table. Pass in int value for percentange done

sub gaugeLite
{
    my $done = $_[0];
    my $todo = 100 - $done;
    my $line = '';
    if ($done > 0) { $line .= CGI::td( { width=>"$done%", bgcolor=>'#00cc00' }, '&nbsp;' ); }
    if ($todo > 0) { $line .= CGI::td( { width=>"$todo%", bgcolor=>'#cc0000' }, '&nbsp;' ); }
    $line = CGI::table( { height=>'100%', width=>'100%' }, CGI::Tr( $line ) );
    return $line;
}

###########################
# xpShowIterationTerse
#
# Shows the specified iteration broken down by stories and tasks
# Copied from XpShowIteration. Need to refactor!

sub xpShowIterationTerse {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};

    my $showTasks = "N";

    my $list = '';
    my @colors = ();
    my $list = '|*Story*|';
    foreach my $fld (@addtlStoryFields) {
      $list .= "*$fld*|";
    }
    $list .= "*Estimate*|*Spent*|*ToDo*|*Progress*|*Done*|*Overrun*|*Completion*|\n";

    my @allStories = &xpGetIterStories($iterationName, $web);  

    # Iterate over each story and add to hash
    my (%targetStories,%targetOrder,%targetMeta) = ();
    foreach my $story (@allStories) {
    my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
    $targetStories{$story} = $storyText;
    $targetMeta{$story} = $meta;
    # Get the ordering and save it
    $targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
    }

    my ($totalSpent,$totalEtc,$totalEst,$totalOngoing, $totalOngoingEst) = 0;

    # Show them
    foreach my $story (sort { $targetOrder{$a} cmp $targetOrder{$b} || $a cmp $b } keys %targetStories) {
    my $color;
    my $storyText = $targetStories{$story};
    my $meta = $targetMeta{$story};
    
    # Get any additional fields
    my @fldvals = ();
    foreach my $fld (@addtlStoryFields) {
      push (@fldvals, &xpGetMetaValue($meta, $fld));
    }

    # Get story summary
    my $storySummary = &xpGetMetaValue($meta, "Storysummary");

    # Get acceptance test status
    my $storyComplete = &xpStoryComplete($meta);

    my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));

    # Set up other story stats
    my ($storySpent,$storyEtc,$storyCalcEst) = 0;
    
    # still need to parse tasks to track total time estimates
    # Suck in the tasks. Move this code into separate routine
    my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
    my $taskCount = 0; # Amount of tasks in this story
    my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
    my $storyStatS = '';

    foreach my $theTask ( $meta->find("TABLE") ) {
      (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetTaskDetail($theTask); 

        $taskName[$taskCount] = $name;
        $taskEst[$taskCount] = $est;
        $taskWho[$taskCount] = $who;
        $taskSpent[$taskCount] = $spent;
        $taskEtc[$taskCount] = $etc;

        $taskStat[$taskCount] = ($storyOngoing) ? 4 : $tstatus;
        $storyStat[$taskStat[$taskCount]]++;

        # Calculate spent
        my @spentList = xpRipWords($taskSpent[$taskCount]);
        foreach my $spent (@spentList) {
        $storySpent += $spent;
        }

        # Calculate etc
        my @etcList = xpRipWords($taskEtc[$taskCount]);
        foreach my $etc (@etcList) {
            $storyEtc += $etc;
        }
        # Calculate est
        my @estList = xpRipWords($taskEst[$taskCount]);
        foreach my $etc (@estList) {
            $storyCalcEst += $etc;
        }
        $taskCount++;
    }

    # Calculate story status
    if ($storyOngoing) {
        $color = "$defaults{ongoingcolor}";
	$storyStatS = $statusLiterals[4];
	} elsif ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
        # status: not started
        $color = "$defaults{storyunstartedcolor}";
        $storyStatS = $statusLiterals[0];
    } elsif ( ($storyStat[0] == 0) and ($storyStat[1] == 0) ) { # All tasks complete
        if ($storyComplete eq "Y") {
            # status: complete
            $storyStatS = $statusLiterals[2];
            $color = "$defaults{storycompletecolor}";
        } else {
            # status: acceptance
            $color = "$defaults{storyacceptancecolor}";
            $storyStatS = $statusLiterals[3];
        }
    } else {
        # status: in progress
        $color = "$defaults{storyprogresscolor}";
        $storyStatS = $statusLiterals[1];
    }
    
    # Show story line
    my $cells = "| $story <br> $storySummary |";
    foreach my $fld (@fldvals) {
      $cells .= " $fld |";
    }
    $cells .= ' '.xpShowRounded($storyCalcEst).' | '.xpShowRounded($storySpent).' |';
    if ($storyOngoing) {
      $cells .= ' |  |  |  |';
    } else {
    $cells .= ' '.xpShowRounded($storyEtc).' |';
    my $done = 0;
    if(($storySpent + $storyEtc) > 0) {
      $done = int(100 * $storySpent / ($storySpent + $storyEtc));
    } elsif((($storySpent + $storyEtc) == 0) && !($storyStatS eq $statusLiterals[0])) {
      $done = 100;
    }
    $cells .= ' '.gaugeLite($done).' |';

    $cells .= " ${done}% |";

    my $cfEst = 0;
    if($storyCalcEst > 0) {
      $cfEst = int(100*(($storySpent + $storyEtc) / $storyCalcEst) - 100);
    }
    if($cfEst >= 0) {
      $cells .= " +${cfEst}% |";
    } else {
      $cells .= " ${cfEst}% |";
    }
    }
    $cells .= " $storyStatS |";
    push @colors, $color;
    $list .= "$cells\n";

    # Show each task
    if($showTasks eq "Y") {

        for (my $i=0; $i<$taskCount; $i++) {
        
	my $taskBG = "";
	if ($taskStat[$i] == 4) {
	  $taskBG = $defaults{ongoingcolor};
	}
	elsif ($taskStat[$i] == 0) {
	  $taskBG = $defaults{taskunstartedcolor};
	}
	elsif ($taskStat[$i] == 1) {
	  $taskBG = $defaults{taskprogresscolor};
	}
        
        # Line for each engineer
        my $doName = 1;
        my @who = xpRipWords($taskWho[$i]);
        my @est = xpRipWords($taskEst[$i]);
        my @spent = xpRipWords($taskSpent[$i]);
        my @etc = xpRipWords($taskEtc[$i]);
        for (my $x=0; $x<@who; $x++) {
	    push @colors, $taskBG;
	    $list .= '| '.($doName?('&nbsp;&nbsp;&nbsp; '.$taskName[$i]):'&nbsp;').' | '.xpShowRounded($est[$x]).' | '.xpShowRounded($spent[$x]).' | '.xpShowRounded($etc[$x]).' | '.$who[$x].' |||'.$statusLiterals[$taskStat[$i]].' |'."\n";
            $doName = 0; 
        }
        
        }
        
        # Add a spacer if showing tasks
	push @colors, 'none' if $addSpacer;
        $list .= "| &nbsp; ||||||||\n" if $addSpacer;
    }

    # Add to totals
    $totalSpent += $storySpent;
    $totalEtc += $storyEtc;
    $totalEst += $storyCalcEst;
    $totalOngoing += $storySpent if $storyOngoing;
    $totalOngoingEst += $storyCalcEst if $storyOngoing; # defensive, in case estimates where entered for ongoing story
    
    }

    # Do iteration totals

    my $cells = "|*$teamLbl totals*|";
    foreach my $fld (@addtlStoryFields) {
      $cells .= '*&nbsp;*|';
    }
    $cells .= '*'.xpShowRounded($totalEst).'*|*'.xpShowRounded($totalSpent).'*|';

    # refactor this code! (mwatt)
    my $totDone = 0;
    my $totalSpentA = $totalSpent - $totalOngoing;
    if(($totalSpentA + $totalEtc) > 0) {
      $totDone = int(100.0 * $totalSpentA / ($totalSpentA + $totalEtc));
    } elsif(($totalSpentA + $totalEtc) == 0) {
      $totDone = 100;
    }
    my $totLeft = (100 - $totDone);
    my $gaugeTxt = gaugeLite($totDone);

    my $cfTotEst = 0;
    my $totalEstA = $totalEst-$totalOngoingEst;
    if($totalEstA > 0) {
      $cfTotEst = int(100*(($totalSpentA + $totalEtc) / $totalEstA) - 100);
    }

    if (($totalOngoing && $totalOngoing != $totalSpent) || !$totalOngoing) {
      $cells .= '*'.xpShowRounded($totalEtc).'*|*'.$gaugeTxt.'*|*'.$totDone.'%*|';
      if($cfTotEst >= 0) {
	$cells .= '*+'.$cfTotEst.'%*|';
      } else {
	$cells .= '*'.$cfTotEst.'%*|';
      }
      $cells .= '*&nbsp;*|';
      $list .= $cells . "\n";

      # dump summary information into a comment for extraction by xpShowTeamIterations
      $list .= "<!--SUMMARY |  ".xpround($totalEst)."  |  ".xpround($totalSpent)."  |  ".xpround($totalEtc)."  |  ".$gaugeTxt."  |  ".$totDone."%  |  ".$cfTotEst."%  | END -->\n";
    } else {
      $cells .= '*&nbsp;*|*&nbsp;*|*&nbsp;*|*&nbsp;*|*&nbsp;*|';
      $list .= $cells . "\n";

      # dump summary information into a comment for extraction by xpShowTeamIterations
      $list .= "<!--SUMMARY |  ".xpround($totalEst)."  |  ".xpround($totalSpent)."  |  |  |  | | END -->\n";
    }

    unshift @colors, pop @colors;  # defect in TablePlugin
    my $color = join ',', @colors;
    my $list = "---+++ Iteration summary\n%TABLE{headerrows=\"1\" footerrows=\"1\" dataalign=\"left,left,center,center,center,center,center,center,left\" headeralign=\"left,left,center,center,center,center,center,center,left\" databg=\"$color\"}%\n" . $list;

    # append "create new story" form
    $list .= &xpCreateHtmlForm("Story", "---++++ Create new story in this iteration");

    return $list;
}


###########################
# xpShowAllIterations
#
# Shows all the iterations

sub xpShowAllIterations {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $list = "---+++ All iterations\n\n";
    $list .= "| *$projectLbl* | *$teamLbl* | *Iter* | *Summary* |\n";

    my @projects = &xpGetAllProjects($web);
    foreach my $project (@projects) {

        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){ 

            my @teamIters = &xpGetTeamIterations($team, $web);

            # Get date of each iteration
            my %iterKeys = ();
            foreach my $iter (@teamIters) {
                my ( $meta, $iterText ) = &TWiki::Func::readTopic($web, $iter);
		my $iterDate = &xpGetMetaValue($meta, "End");
                my $iterSec = HTTP::Date::str2time( $iterDate ) - time;
                $iterKeys{$iter} = $iterSec;
            }

            # write out all iterations to table
            foreach my $iter (sort { $iterKeys{$a} <=> $iterKeys{$b} } @teamIters) {
              
                # get additional information from iteration
                my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
		my $summary = &xpGetMetaValue($meta, "Summary");
              
                $list .= "| ".$project." | ".$team." | ".$iter." | ".$summary." |\n";
            }
        }
    }
    return $list;
}


###########################
# xpShowProjectIterations
#
# Shows all the iterations for this project

sub xpShowProjectIterations {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $project = $params->{_DEFAULT} || $params->{project};

    my $list = "---+++ All iterations for this ".lcfirst $projectLbl. "\n\n";

    $list .= "| *$teamLbl* | *Iter* | *Summary* | *Start* | *End* | *Est* | *Spent* | *ToDo* | *Progress* | *Done* | *Overrun* |\n";

    my @projTeams = &xpGetProjectTeams($project, $web);
    foreach my $team (@projTeams){ 
      
        my @teamIters = &xpGetTeamIterations($team, $web);

        # Get date of each iteration
        my %iterKeys = ();
	my %iterSkip = ();
        foreach my $iter (@teamIters) {
            my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
            my $iterDate = &xpGetMetaValue($meta, "End");
            my $iterSec = HTTP::Date::str2time( $iterDate ) - time;
            $iterKeys{$iter} = $iterSec;
	    my $iterActual = &xpGetMetaValue($meta, "Actual");
            $iterSkip{$iter} = (&HTTP::Date::str2time($iterActual) - time) if $iterActual;
        }

        # write out all iterations to table
        foreach my $iter (sort { $iterKeys{$a} <=> $iterKeys{$b} } @teamIters) {
	    # skip commpleted iterations (completed here means having 
	    # "actual" field filled in, and curent date being later.
            next if ( $iterSkip{$iter} < 0);

            # get additional information from iteration
            my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
            my $summary = &xpGetMetaValue($meta, "Summary");
            my $start = &xpGetMetaValue($meta, "Start");
            my $end = &xpGetMetaValue($meta, "End");
            
            $list .= "| ".$team." | ".$iter." | ".$summary." | ".$start." | ".$end." ";
            
            # call xpShowIterationTerse, which internally computes totals for
            # est, spent, todo, overrun etc and places them in an html comment for pickup here :-)
            my $iterSummary = &xpShowIterationTerse( $session, { iteration => $iter }, $theTopic, $web );
            $iterSummary =~ /SUMMARY(.*?)END/s;
            $list .= "$1 \n";
        }

    }
    return $list;
}

###########################
# xpShowProjectStories
#
# Shows all the stories for this project

sub xpShowProjectStories {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $project = $params->{_DEFAULT} || $params->{project};

    my $listComplete = "---+++ All completed stories for this ".lcfirst $projectLbl."\n\n";
    $listComplete .= "| *$teamLbl* | *Iteration* | *Story* | *Summary* |";
    foreach my $fld (@addtlStoryFields) {
      $listComplete .= " *".$fld."* |";
    }
    $listComplete .= " *Completion Date* |\n";

    my $listIncomplete = "---+++ All uncompleted stories for this ".lcfirst $projectLbl."\n\n";
    $listIncomplete .= "| *$teamLbl* | *Iteration* | *Story* | *Summary* |";
    foreach my $fld (@addtlStoryFields) {
      $listIncomplete .= " *".$fld."* |";
    }
    $listIncomplete .= "\n";

    my @teams = &xpGetProjectTeams($project, $web);
    foreach my $team (@teams){ 
      
        my @teamIters = &xpGetTeamIterations($team, $web);

        # write out all iterations to table
        foreach my $iter (@teamIters) {
              
            # get additional information from iteration
          my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
          my $end = &xpGetMetaValue($meta, "End");
          
          my @allStories = &xpGetIterStories($iter, $web);
          
          foreach my $story (@allStories) {
              my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
	      unless (&xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"))) {
	      #TW: Not used?
              #$targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
              
              my $storySummary = &xpGetMetaValue($meta, "Storysummary");
	      my @fldvals = ();
	      foreach my $fld (@addtlStoryFields) {
		push (@fldvals, &xpGetMetaValue($meta, $fld));
	      }
              my $storyComplete = &xpStoryComplete($meta);
              if ($storyComplete eq "Y") {
                  $listComplete .= "| ".$team." | ".$iter." | ".$story." | ".$storySummary." | ";
		  foreach my $fld (@fldvals) {
		    $listComplete .= $fld." | ";
		  }
		  $listComplete .= $end. "|\n";
                } else {
                    $listIncomplete .= "| ".$team." | ".$iter." | ".$story." | ".$storySummary." | ";
		  foreach my $fld (@fldvals) {
		    $listIncomplete .= $fld." | ";
		  }
		  $listIncomplete .= "\n";
                }
	      }
            }
        }
    }
    $listComplete .= "\n\n";

    return $listComplete.$listIncomplete;
}


###########################
# xpShowTeamIterations
#
# Shows all the iterations for this team

sub xpShowTeamIterations {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $team = $params->{_DEFAULT} || $params->{team};

    my @teamIters = &xpGetTeamIterations($team, $web);

    my $list = "---+++ All iterations for this ".lcfirst $teamLbl. "\n\n";

    $list .= "| *Iter* | *Summary* | *Start* | *End* | *Est* | *Spent* | *ToDo* | *Progress* | *Done* | *Overrun* |\n";

    # Get date of each iteration
    my %iterKeys = ();
    foreach my $iter (@teamIters) {
        my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
	my $iterDate = &xpGetMetaValue($meta, "End");
        my $iterSec = HTTP::Date::str2time( $iterDate ) - time;
        $iterKeys{$iter} = $iterSec;
    }

    # write out all iterations to table
    foreach my $iter (sort { $iterKeys{$a} <=> $iterKeys{$b} } @teamIters) {

        # get additional information from iteration
        my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
        my $start = &xpGetMetaValue($meta, "Start");
        my $end = &xpGetMetaValue($meta, "End");
        my $summary = &xpGetMetaValue($meta, "Summary");

        $list .= "| ".$iter." | ".$summary." | ".$start." | ".$end." ";

        # call xpShowIterationTerse, which internally computes totals for
        # est, spent, todo, overrun etc and places them in an html comment for pickup here :-)
        my $iterSummary = &xpShowIterationTerse( $session, { iteration => $iter }, $theTopic, $web );
        $iterSummary =~ /SUMMARY(.*?)END/s;
        $list .= "$1 \n";

    }

    # append CreateNewIteration form
    $list .= &xpCreateHtmlForm("Iteration", "---++++ Create new iteration for this " .lcfirst $teamLbl);

    return $list;
}


###########################
# xpShowAllTeams
#
# Shows all the teams

sub xpShowAllTeams {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = "---+++ All ".lcfirst $projectLbl."s and ".lcfirst $teamLbl."s\n\n";
    $list .= "| *$projectLbl* | *$teamLbl* |\n";

    foreach my $project (@projects) {

      my @projTeams = &xpGetProjectTeams($project, $web);
      $list .= "| ".$project." | @projTeams |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm(${projectLbl}, "---++++ Create new ".lcfirst $projectLbl);

    return $list;
}

###########################
# xpShowProjectTeams
#
# Shows all the teams on this project

sub xpShowProjectTeams {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $project = $params->{_DEFAULT} || $params->{project};

    my @projTeams = &xpGetProjectTeams($project, $web);

    my $list = "---+++ All ".lcfirst $teamLbl."s for this ".lcfirst $projectLbl."\n\n";
    $list .= "| *$teamLbl* |\n";

    # write out all teams
    $list .= "| @projTeams |\n";

    # append CreateNewTeam form
    $list .= &xpCreateHtmlForm(${teamLbl}, "---++++ Create new ". lcfirst $teamLbl." for this ".lcfirst $projectLbl);

    return $list;
}


###########################
# xpCreateHtmlForm
#
# Make form to create new subtype

sub xpCreateHtmlForm {

    my ($template, $prompt) = @_;
    my $list = "";

    # append form for new page creation
    $list .= $prompt . "\n";
    $list .= "<form name=\"new\">\n";
    $list .= '<table><tr><td>';
    $list .= "<input type=\"text\" name=\"topic\" size=\"30\" />\n";
    $list .= '</td><td>';
    $list .= "<input type=\"checkbox\" name=\"sequence\" /> Add sequence number&nbsp;\n";
    $list .= '</td><td>';
    $list .= "<input type=\"hidden\" name=\"parent\" value=\"%TOPIC%\" />\n";
#    $list .= "<input type=\"hidden\" name=\"templatetopic\" value=\"".$template."\" />\n";
    $list .= "%CONTROL{\"templatetopic\" topic=\"${template}TemplateOptions\" }%\n";
    $list .= '</td></tr><tr><td>';
    $list .= "<input type=\"submit\" name =\"xpsave\" value=\"Create\" />\n";
    $list .= '</td></tr></table>';
    $list .= "</form>\n";
    $list .= "\n";

    return $list;
}

sub xpCreateTopic {

    my( $session, $params, $theTopic, $web ) = @_;
    my $tmpl = $params->{_DEFAULT} || $params->{template} || 'Story';
    my $prompt = $params->{prompt};
    return xpCreateHtmlForm( $tmpl, $prompt );

}


###########################
# xpGetProjectTeams
#
# Get all the teams on this project

sub xpGetProjectTeams {

    my ($project, $web) = @_;
    return defined($cachedProjectTeams{$project}) ? split( /\s+/, $cachedProjectTeams{$project} ) : ();
}

###########################
# xpShowProjectCompletionByStories
#
# Shows the project completion by release and iteration using stories.

sub xpShowProjectCompletionByStories{

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $project = $params->{_DEFAULT} || $params->{project};

    my @projectStories = &xpGetProjectStories($project, $web);

    # Show the list
    my $list = "---+++ $projectLbl stories status\n\n";

    $list .= "| *Iteration* | *Total Stories* | *Not Started* | *In Progress* | *Completed* | *Accepted* | *Percent accepted* |\n";

    # Iterate over each, and build iteration hash
    my ($unstarted) = 0;
    my ($progress) = 0;
    my ($complete) = 0;
    my ($accepted) = 0;
    my ($total) = 0;

    my (%master,%unstarted,%progress,%complete,%accepted) = ();

    # initialise hash. There must be a better way! (MWATT)
    foreach my $story (@projectStories) {
        my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
        my $iter = &xpGetMetaValue($meta, "Iteration");
        $unstarted{$iter} = 0;
        $progress{$iter} = 0;
        $complete{$iter} = 0;
        $accepted{$iter} = 0;
    }

    foreach my $story (@projectStories) {
    my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
    my $iter = &xpGetMetaValue($meta, "Iteration");
    if (($iter ne "TornUp") && (! &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing")))) {
        $master{$iter}++;
        my $status = &xpGetStoryStatus($storyText, $meta);
        if ($status == 0) {
            # all tasks unstarted
            $unstarted{$iter}++;
            $unstarted++;
        } elsif ($status == 1) {
            # in progress
            $progress{$iter}++;
            $progress++;
        } elsif ($status == 3) {
        # tasks complete but not acceptance tested
        $complete{$iter}++;
        $complete++; 
        } else {
        # 2 - complete and acceptance tested
        $accepted{$iter}++;
        $accepted++;
        }
        $total++;
    }
    }

    # Get date of each iteration
    my %iterKeys = ();
    foreach my $iteration (keys %master) {
        my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iteration);
        my $iterDate = &xpGetMetaValue($meta, "End");
        my $iterSec = HTTP::Date::str2time( $iterDate ) - time;
        $iterKeys{$iteration} = $iterSec;
    }

    # OK, display them
    foreach my $iteration (sort { $iterKeys{$a} <=> $iterKeys{$b} } keys %master) {
    my $pctAccepted = 0;
    if ($accepted{$iteration} > 0) {
        $pctAccepted = sprintf("%u",($accepted{$iteration}/$master{$iteration})*100);
    }
    $list .= "| ".$iteration."  |  ".$master{$iteration}."  |  ".$unstarted{$iteration}."  |  ".$progress{$iteration}."  |  ".$complete{$iteration}."  |  ".$accepted{$iteration}."  |  ".$pctAccepted."\%  | \n";
    }
    my $pctAccepted = 0;
    if ($accepted > 0) {
    $pctAccepted = sprintf("%u",($accepted/$total)*100);
    }
    $list .= "| Totals  |  ".$total."  |  ".$unstarted."  |  ".$progress."  |  ".$complete."  |  ".$accepted."  |  ".$pctAccepted."%  |\n";

    return $list;
}

###########################
# xpShowProjectCompletionByTasks
#
# Shows the project completion using tasks.

sub xpShowProjectCompletionByTasks {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $project = $params->{_DEFAULT} || $params->{project};

    my @projectStories = &xpGetProjectStories($project, $web);

    # Show the list
    my $list = "---+++ $projectLbl tasks status\n\n";
    $list .= "| *Iteration* |  *Total tasks* | *Not Started* | *In progress* | *Complete* | *Percent complete* |\n";

    # Iterate over each, and build iteration hash
    my ($unstarted) = 0;
    my ($progress) = 0;
    my ($complete) = 0;
    my ($total) = 0;
    my (%master,%unstarted,%progress,%complete) = ();

    # initialise hash. There must be a better way! (mwatt)
    foreach my $story (@projectStories) {
        my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
        my $iter = &xpGetMetaValue($meta, "Iteration");
        $unstarted{$iter} = 0;
        $progress{$iter} = 0;
        $complete{$iter} = 0;
    }

    foreach my $story (@projectStories) {
    my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
    my $iter = &xpGetMetaValue($meta, "Iteration");
    if (($iter ne "TornUp") && (! &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing")))) {
	foreach my $theTask ( $meta->find("TABLE") ) {
	  (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $taskStatus) = xpGetTaskDetail($theTask); 
        $master{$iter}++;
        if ($taskStatus == 0) {
            $unstarted{$iter}++;
            $unstarted++;
        } elsif ( ($taskStatus == 1) or ($taskStatus == 3) ) {
            $progress{$iter}++;
            $progress++;
        } else {
            $complete{$iter}++;
            $complete++;
        }
        $total++;
        }
    }
    }

    # Get date of each iteration
    my %iterKeys = ();
    foreach my $iteration (keys %master) {
        my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iteration);
        my $iterDate = &xpGetMetaValue($meta, "End");
        my $iterSec = HTTP::Date::str2time( $iterDate ) - time;
        $iterKeys{$iteration} = $iterSec;
    }

    # OK, display them
    foreach my $iteration (sort { $iterKeys{$a} <=> $iterKeys{$b} } keys %master) {
    my $pctComplete = 0;
    if ($complete{$iteration} > 0) {
        $pctComplete = sprintf("%u",($complete{$iteration}/$master{$iteration})*100);
    }
    $list .= "| ".$iteration."  |  ".$master{$iteration}."  |  ".$unstarted{$iteration}."  |   ".$progress{$iteration}."  |  ".$complete{$iteration}."  |  ".$pctComplete."\%  |\n";
    }
    my $pctComplete = 0;
    if ($complete > 0) {
        $pctComplete = sprintf("%u",($complete/$total)*100);
    }
    $list .= "| Totals |  ".$total."  |  ".$unstarted."  |  ".$progress."  |  ".$complete."  |  ".$pctComplete."%  |";

    return $list;
}

###########################
# xpTaskStatus
#
# Calculates the status of a task.

sub xpTaskStatus {
    my @who = xpRipWords($_[0]);
    my @etc = xpRipWords($_[1]);
    my @spent = xpRipWords($_[2]);

    # status - 0=not started, 1=inprogress, 2=complete

    # anyone assigned?
    return 0 unless @who; # nobody assigned, not started

    foreach my $who (@who) {
    if ($who eq "?") {
        return 0; # not assigned correctly, not started
    }
    }

    # someone is assigned, see if ANY time remaining
    return 0 unless @etc; # no "todo", so still not started
    my $isRemaining = 0;
    foreach my $etc (@etc) {
        if ($etc eq "?") {
            return 0; # no "todo", so still not started
        }
        if ($etc > 0) {
            $isRemaining = 1;
        }
    }
    if (!$isRemaining) {
        return 2; # If no time remaining, must be complete
    }

    # If ANY spent > 0, then in progress, else not started
    foreach my $spent (@spent) {
        if ($spent > 0) {
            return 1; # in progress
        }
    }
    return 0;

}

###########################
# xpShowPivotByField
# Generalized from xpShowVelocities
#
# Shows summary for field data for this iteration
#
# Notes: $doSplit breaks the field into multiple components (if this is
# used for calculating velocities, to allow for multiple developers, each 
# Developer name must be a wiki word (otherwise xpRipWords splits the
# name into its pieces).

sub xpVelocities {
    
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};
    
    return xpShowPivotByField( $session, 
			       $web,
			       $iterationName, 
			       'Developer', 
			       'Developer velocity',
			       1 );
}

sub xpCoq {
    
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};
    
    return xpShowPivotByField( $session, 
			       $web,
			       $iterationName, 
			       'COQ',
			       'Cost of Quality of this iteration',
			       0 );

}

sub xpPivotByField {
    my( $session, $params, $theTopic, $web ) = @_;

    my $iterationName = $params->{_DEFAULT} || $params->{iteration};
    my $fieldName = $params->{field};
    return '' unless $fieldName;
    my $title = $params->{title} || '';
    my $split = $params->{split} || 0;
    
    return xpShowPivotByField( $session, 
			       $web,
			       $iterationName, 
			       $fieldName,
			       $title,
			       $split );

}


sub xpShowPivotByField {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $web, $iteration, $field, $title, $doSplit ) = @_;

    my @allStories = &xpGetIterStories($iteration, $web);

    # title
    my $list = "---+++ $title\n";

    # Show the table
    $list .= '%TABLE{dataalign="left,center,center,center,center,center" headeralign="left,center,center,center,center,center"}%'."\n";
    $list .= "|*Category*|*Ideals*|||*Tasks*||\n";
    $list .= "|^|*Assigned*|*Spent*|*Remaining*|*Assigned*|*Remaining*|\n";

    # Iterate over each story
    my (%whoAssigned,%whoSpent,%whoEtc,%whoTAssigned,%whoTRemaining) = ();
    my ($totalSpent,$totalEtc,$totalAssigned,$totalVelocity,$totalTAssigned,$totalTRemaining) = (0,0,0,0,0,0);
    foreach my $story (@allStories) {
    my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
    if(&xpGetMetaValue($meta, "Iteration") eq $iteration) {
	foreach my $theTask ($meta->find("TABLE")) {
	  (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $taskStatus) = xpGetTaskDetail($theTask);            
        my @who = ($doSplit) ? xpRipWords($theTask->{$field}) : $theTask->{$field};
        my @spent = xpRipWords($taskSpent);
        my @est = xpRipWords($taskEst);
        my @etc = xpRipWords($taskEtc);
        for (my $i=0; $i<@who; $i++) {
            $whoSpent{$who[$i]} += $spent[$i];
            $totalSpent += $spent[$i];

            $whoEtc{$who[$i]} += $etc[$i];
            $totalEtc += $etc[$i];

            $whoAssigned{$who[$i]} += $est[$i];
            $totalAssigned += $est[$i];

            $whoTAssigned{$who[$i]}++;
            $totalTAssigned++;

            if ($etc[$i] > 0) {
            $whoTRemaining{$who[$i]}++;
                $totalTRemaining++;
            } else {
            # ensure these variables always get initialised
            $whoTRemaining{$who[$i]}+= 0;
                $totalTRemaining+= 0;
            }
        }
        }
    }
    }
    
    foreach my $who (sort { $whoEtc{$b} <=> $whoEtc{$a} } keys %whoSpent) {
     $list .= '| '.$who.' | '.xpShowRounded($whoAssigned{$who}).' | '.xpShowRounded($whoSpent{$who}).' | '.xpShowRounded($whoEtc{$who}).' | '.$whoTAssigned{$who}.' | '.$whoTRemaining{$who}." |\n";
    }
    $list .= '|*Total*|*'.xpShowRounded($totalAssigned).'*|*'.xpShowRounded($totalSpent).'*|*'.xpShowRounded($totalEtc).'*|*'.$totalTAssigned.'*|*'.$totalTRemaining."*|\n";

    return $list;
}

###########################
# xpGetAllStories
#
# Returns a list of all stories in this web.

sub xpGetAllStories {

    my $web = $_[0];

    # Read in all stories in this web
    #opendir(WEB,$dataDir."/".$web);
    opendir(WEB,$TWiki::cfg{DataDir}."/".$web);
    my @allStories = grep { s/(.*?Story).txt$/$1/go } readdir(WEB);
    closedir(WEB);
    
    return @allStories;
}

###########################
# xpGetProjectStories
#
# Returns a list of all stories in the given project

sub xpGetProjectStories {

    my ($project,$web) = @_;

    my @matchingStories = ();

    my @teams = &xpGetProjectTeams($project, $web);
    foreach my $team (@teams){ 
      
        my @teamIters = &xpGetTeamIterations($team, $web);
        
        # write out all iterations to table
        foreach my $iter (@teamIters) {
              
            my @allStories = &xpGetIterStories($iter, $web);  
            push @matchingStories, @allStories;
        }
    }
    return @matchingStories;
}

###########################
# xpGetIterStories
#
# Returns a list of all stories in this web in this iteration

sub xpGetIterStories {

    my ($iteration,$web) = @_;
    return defined($cachedIterationStories{$iteration}) ? split( /\s+/, $cachedIterationStories{$iteration} ) : ();
}

###########################
# xpGetStoryStatus
#
# Returns the status of a story

sub xpGetStoryStatus {
    my $storyText = $_[0];
    my $meta = $_[1];

    my @taskStatus = ( 0, 0, 0 );

    # Get acceptance test status
    my $storyComplete = "N";
    $storyComplete = &xpStoryComplete($meta);

    # Run through tasks and get their status
    foreach my $theTask ( $meta->find("TABLE") ) {
	  (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $tStatus) = xpGetTaskDetail($theTask); 
        $taskStatus[$tStatus]++;
    }

    # Calculate story status
    my $storyStatus = 0;
    if ( ($taskStatus[1] == 0) and ($taskStatus[2] == 0) ) { # All tasks are not started
        $storyStatus = 0;
    } elsif ( ($taskStatus[0] == 0) and ($taskStatus[1] == 0) ) { # All tasks complete
        if ($storyComplete eq "Y") {
            $storyStatus = 2;
        } else {
            $storyStatus = 3;
        }
    } else {
        $storyStatus = 1;
    }
    
    return $storyStatus;
}    
    
###########################
# xpRipWords
#
# Parses a bunch of words from TWiki code

sub xpRipWords {
    my $string = $_[0];
    my @out = ();
    foreach my $word (split(/[ \|]/,$string)) {
    if ($word ne '') {
        push @out,$word;
    }
    }
    return @out;
}

###########################
# xpZero2Null
#
# Returns a numeric, or null if zero

sub xpZero2Null {
    if ($_[0] == 0) {
    return "";
    } else {
        return $_[0];
    }
}

###########################
# xpGetNextTask
#
# Return the next task in a story

sub xpGetTaskDetail {
    my $theTask = $_[0];

    my ($taskName, $taskEst, $taskWho, $taskSpent, $taskEtc, $taskStatus)="";

    $taskName = $theTask->{"Taskname"};
    $taskEst = $theTask->{"Est"};
    $taskWho = $theTask->{"Developer"};
    $taskSpent = $theTask->{"Spent"};
    $taskEtc = $theTask->{"Todo"};

    # Calculate status of task ; 0=not started, 1=progress, 2=complete
    $taskStatus = xpTaskStatus($taskWho,$taskEtc,$taskSpent);

    return (1,$taskName,$taskEst,$taskWho,$taskSpent,$taskEtc,$taskStatus);
}

###########################
sub sort_unique(@) {
    my @array = @_;
    my %hash;

    #make the names the keys of a hash, so the keys will be unique
    foreach my $el (@array) {
        $hash{$el}++;
    }

    #now sort the keys
    return (sort keys(%hash));
}


###########################
# xpGetIterDevelopers
#
# Returns a list of all developers in this iteration in this web.

sub xpGetIterDevelopers {

    my ($iteration,$web) = @_;

    my @iterStories = &xpGetIterStories($iteration, $web);

    my @dev = ();
    foreach my $story (@iterStories) {
      my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);      

      foreach my $theTask ( $meta->find("TABLE") ) {
	(my $status,my $name,my $est,my $who) = xpGetTaskDetail($theTask); 
	push @dev, $who;
      }
    }

    @dev = sort_unique(@dev);
    return @dev;
}


###########################
# xpGetTeamIterations
#
# Get all the iterations for this team

sub xpGetTeamIterations {

    my ($team, $web) = @_;
    return defined($cachedTeamIterations{$team}) ? split( /\s+/, $cachedTeamIterations{$team} ) : ();
}

###########################
# xpShowAllProjects
#
# Shows all the projects on this web

sub xpShowAllProjects {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = "---+++ All ".lcfirst $projectLbl."s\n\n";
    $list .= "| *$projectLbl* |\n";

    # write out all iterations to table
    foreach my $project (@projects) {
      $list .= "| $project |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm(${projectLbl}, "---++++ Create new ".lcfirst $projectLbl);

    return $list;
}

###########################
# xpGetAllProjects
#
# Get all the projects for the web

sub xpGetAllProjects {

    return keys %cachedProjectTeams;
}

###########################
# xpGetTableValue
#
# Return value from passed in text with passed in title
# This searches a horizontal table to find the matching field

sub xpGetTableValue {
    my $title = $_[0];
    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
    my $result = "";

    my $pattern2 = "\\|[ \\t]*".$title."[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";

    if ($_[1] =~ /$pattern2/s) {
      $result = $1;
    }
    return $result;
}


###########################
# xpCacheBuild
#
# Take $web and set up the cached info
#
# %cachedProjectTeams
# %cachedTeamIterations
# %cachedIterationStories

sub xpCacheBuild
{
    my $web = shift;
    my ($eachP, $eachI, $eachS, $eachT, $allS, $allI);

    # Put the return in here, and suddenly, no caching.
    # return;


    # Get all the stories and their iterations:
    my @stories = &xpGetAllStories( $web );
    foreach $eachS ( @stories ) {
        my ($meta, $storyText) = &TWiki::Func::readTopic($web, $eachS);

        # To go from iteration -> story (multiple values)
        my $iter = &xpGetMetaValue($meta, "Iteration");
        $cachedIterationStories{$iter} .= "$eachS " if $iter;
    }

    foreach $eachI (keys %cachedIterationStories) {
        my ($meta, $iterText) = &TWiki::Func::readTopic($web, $eachI);

        # To go from team -> iteration (multiple values)
        my $team = &xpGetMetaValue($meta, "$teamLbl");
        $cachedTeamIterations{$team} .= "$eachI " if $team;

    }

    foreach $eachT (keys %cachedTeamIterations) {
        my ($meta, $teamText) = &TWiki::Func::readTopic($web, $eachT);

        # To go from project -> team (multiple values)
        my $project =  &xpGetMetaValue($meta, "$projectLbl");
        $cachedProjectTeams{$project} .= "$eachT " if $project;
    }

    # dump information to disk cache file
    my $projCache = "";
    my $teamCache = "";
    my $iterCache = "";
    my @projects = &xpGetAllProjects($web);

    foreach my $project (@projects) {

        my @teams = &xpGetProjectTeams($project,$web);
        $projCache .= "PROJ : $project : @teams \n";
        foreach my $team (@teams) {

            my @teamIters = &xpGetTeamIterations($team,$web);
            $teamCache .= "TEAM : $team : @teamIters \n";
            foreach my $iter (@teamIters) {

                my @iterStories = &xpGetIterStories($iter,$web);
                $iterCache .= "ITER : $iter : @iterStories \n";
            }
        }
    }

    TWiki::Func::saveFile( $cacheFileName, $projCache.$teamCache.$iterCache );
}

###########################
# xpCacheRead
#
# Read disk cache file created by xpCacheBuild
#
sub xpCacheRead
{
    my $web = shift;

    # if there is no disk cache file, build one
    if (! (-e $cacheFileName )) {
        &TWiki::Func::writeDebug( "NO CACHE, BUILDING DISK CACHE" ) if $debug;
        &xpCacheBuild($web);
    } else {

        # if cache exists but is not most recent file, rebuild it
        # Do this by checking directory timestamp
        # TJW: somehow this does not work, see xpSavePage for workaround
        my @cacheStat = stat("$cacheFileName");
        my @latestStat = stat("$TWiki::cfg{DataDir}/$web");
        # field 9 is the last modified timestamp
        if($cacheStat[9] < $latestStat[9]) {
            &TWiki::Func::writeDebug( "OLD CACHE $cacheStat[9] $latestStat[9]" ) if $debug;
            &xpCacheBuild($web);
        }
    }

    # read disk cache
#    my $cacheText = &TWiki::Func::readTopicText($web, $cacheFileName, undef, 1);
    my $cacheText = &TWiki::Func::readFile( $cacheFileName );
    
    while($cacheText =~ s/PROJ : (.*?) : (.*?)\n//) {
        $cachedProjectTeams{$1} = "$2";
    }

    while($cacheText =~ s/TEAM : (.*?) : (.*?)\n//) {
        $cachedTeamIterations{$1} = "$2";
    }

    while($cacheText =~ s/ITER : (.*?) : (.*?)\n//) {
        $cachedIterationStories{$1} = "$2";
    }

    $cacheInitialized = 1;
}

sub xpSavePage()
{
    my ( $web ) = @_;

    # check the user has entered a non-null string
    my $query = TWiki::Func::getCgiQuery();
    my $title = $query->param( 'topic' );
    $title .= 'XXXXXXXXXX' if $query->param( 'sequence' );

    if($title eq "") {
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getOopsUrl( $web, "Unknown topic", "oopssaveerr", "No topic name." ) );
        return;
    }

    # check topic does not already exist
    if(TWiki::Func::topicExists($web, $title)) {
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getOopsUrl( $web, "Unknown topic", "oopssaveerr", "Topic $topic already exists." ) );
        return;
    }

    # check the user has entered a WIKI name
    if(!TWiki::Func::isValidWikiWord($title)) {
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getOopsUrl( $web, "Unknown topic", "oopssaveerr", "$title is not a topic name." ) );
        return;
    }

## SMELL: Rather than basing this on the name of the template, look into 
## the content of the template for the form name (read form, check $meta)
    # if creating a story, check name ends in *Story
    my $template = $query->param( 'templatetopic' );
    if( ($template =~ /StoryTemplate$/) ) {
        if(!($title =~ /^[\w]*Story$/)) {
	  TWiki::Func::writeWarning("${pluginName} - Story name should end in 'Story'; converting to ${title}Story");
	  $title .= 'Story';
        }
    }

    # load template for page type requested
    my ($meta, $text) = &TWiki::Func::readTopic( $web, $template );

    # determine parent field
    my $ownerName = "";
    if ($template =~ /StoryTemplate$/) {
      $ownerName = "Iteration";
    } elsif ($template =~ /IterationTemplate$/) {
      $ownerName = "$teamLbl";
    } elsif ($template =~ /${teamLbl}Template$/) {
      $ownerName = "$projectLbl";
    }

    if (! $ownerName eq '' ) {
      # write parent name into page
      my $parent = $query->param( 'parent' );
      #$text =~ s/XPPARENTPAGE/$parent/geo;
      $meta->putKeyed( "FIELD", { "name" => $ownerName, "title" => $ownerName, "value" => $parent } );

      # this should be eliminated
      # set TOPICPARENT to known value to eliminate unwanted hits
      # on queries
      $meta->put( "TOPICPARENT", { "name" => "ProjectTopics" } );
      
    }
    
    # write submission time into the page if we have a story page
    if( $ownerName eq "Iteration" ) {
      $meta->putKeyed( "FIELD", { "name" => "Submitdate", "title" => "Submit date", "value" => &TWiki::Time::formatTime(time(), '$day $mon $year', 'gmtime') } );
      $meta->putKeyed( "FIELD", { "name" => "State", "title" => "State", "value" => "Submitted" } );
    }


    # save new page in a temp file and open in browser
    my $tmpFile = TWiki::Sandbox::untaintUnchecked( 'TemporaryTopic' );
    my $error = &TWiki::Func::saveTopic( $web, $tmpFile, $meta, $text );
    # TJW: delete the cache file to work around a problem of cache file being
    # TJW: not read due to timestamp problem
    unlink("$cacheFileName");

    # open in edit mode
    my $url = &TWiki::Func::getScriptUrl ( $web, $title, 'edit' );
    $url .= "\?templatetopic=$tmpFile";
    TWiki::Func::redirectCgiQuery( $query, $url );

}

###########################
# ThomasEschner: xpShowDeveloperTasks
#
# Shows open tasks by developer.

sub xpShowDeveloperTasks {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $developer = $params->{_DEFAULT} || $params->{developer};

    my ($totalSpent,$totalEtc,$totalEst) = (0,0,0);

    my @projects = &xpGetAllProjects($web);

    # Show the list
    my $list = '';
    my @colors = ();
    $list .= "|*Iteration Story<br>&nbsp; Task*|*Estimate*|*Spent*|*To do*|*Status*|*Iteration due*|\n";

    # todo: build a list of projects/iterations sorted by date

    my %iterKeys = ();
    my %iterDates = ();
    my @iterations = ();
    foreach my $project (@projects) {
        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){
            my @teamIters = &xpGetTeamIterations($team, $web);

            # Get date of each iteration
            foreach my $iter (@teamIters) {
                my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
                my $iterDate = &xpGetMetaValue($meta, "End");
                my $iterDays;
		if ( $iterDate ) {
		  $iterDays = HTTP::Date::str2time( $iterDate ) - time;
		} else {
		  # Schedule for out in the future
		  $iterDays = time;
		}
		$iterDays = $iterDays / (24*3600);
                $iterKeys{$iter} = $iterDays;
                $iterDates{$iter} = $iterDate;
		push @iterations, $iter;  # Could build up a sorted data structure
            }
	  }
      }

            # write out all iterations to table
            foreach my $iterationName (sort { $iterKeys{$a} <=> $iterKeys{$b} } @iterations) {

            my $iterDatecolor = "";
	    my $iterDays = $iterKeys{$iterationName};
	    my $iterDate = $iterDates{$iterationName};

            if ($iterDays < 1)
                { $iterDatecolor = '#FF6666'; }
            elsif ($iterDays < 2)
                { $iterDatecolor = '#FFCCCC'; }
            elsif ($iterDays < 3)
                { $iterDatecolor = '#FFFFCC'; }

            my @allStories = &xpGetIterStories($iterationName, $web);

            # Iterate over each story and add to hash
            my (%targetStories,%targetOrder,%targetMeta) = ();
            foreach my $story (@allStories) {
                my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
                $targetStories{$story} = $storyText;
		$targetMeta{$story} = $meta;
                # Get the ordering and save it
                $targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
            }

	    #TW: These appear not used
	    my $iterEst = 0;
	    my $iterSpent = 0;
	    my $iterEtc = 0;

            # Show them
            foreach my $story (sort { $targetOrder{$a} <=> $targetOrder{$b} || $a cmp $b } keys %targetStories) {
#            foreach my $story (sort { $a cmp $b } keys %targetStories) {

                my $storyText = $targetStories{$story};
		my $meta = $targetMeta{$story};

                # Get acceptance test status
                my $storyComplete = &xpStoryComplete($meta);

                # Set up other story stats
                my ($storySpent) = 0;
                my ($storyEtc) = 0;
                my ($storyEst) = 0;

                # Suck in the tasks
                my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
                my $taskCount = 0; # Amount of tasks in this story
                my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
		my $storyStatS = '';
		my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));
		my $storyOngoingInvolved = 0;

		foreach my $theTask ( $meta->find("TABLE") ) {
		    (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetTaskDetail($theTask); 

                    # straighten $who
	            # TJW: if this is done, we must have developer in Main
		    # TJW: could use a flag of whether to do this
                    #$who =~ s/(Main\.)?(.*)/Main\.$2/;  #TJW
                    # no display unless selected
                    my $test = eval { $who =~ /$developer/ };
                    next unless $test;

		    $storyOngoingInvolved = 1 if $storyOngoing;

                    $taskName[$taskCount] = $name;
                    $taskEst[$taskCount] = $est;
                    $taskWho[$taskCount] = $who;
                    $taskSpent[$taskCount] = $spent;
                    $taskEtc[$taskCount] = $etc;

                    $taskStat[$taskCount] = ($storyOngoing) ? 4 : $tstatus;
                    $storyStat[$taskStat[$taskCount]]++;

                    # Calculate spent
                    my @spentList = xpRipWords($taskSpent[$taskCount]);
                    foreach my $spent (@spentList) {
                        $storySpent += $spent;
                    }

                    # Calculate etc
                    my @etcList = xpRipWords($taskEtc[$taskCount]);
                    foreach my $etc (@etcList) {
                        $storyEtc += $etc;
                    }

                    # Calculate est
                    my @estList = xpRipWords($taskEst[$taskCount]);
                    foreach my $etc (@estList) {
                        $storyEst += $etc;
                    }
                    $taskCount++;
                }

                # no display if not involved
                next if (($storyEst == 0) && (! $storyOngoingInvolved));

                # no display if nothing left to do
                next if (($storyEtc == 0) && (! $storyOngoingInvolved));

                # Calculate iter status
                $iterEst += $storyEst;
                $iterSpent += $storySpent;
                $iterEtc += $storyEtc;

                # Calculate story status
                my $color = "";
                if ($storyOngoing) {
                    $color = $defaults{ongoingcolor};
                    $storyStatS = $statusLiterals[4];
		} elsif ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
                    $color = $defaults{storyunstartedcolor};
                    $storyStatS = $statusLiterals[0];
                } elsif ( ($storyStat[0] == 0) and ($storyStat[1] == 0) ) { # All tasks complete
                    if ($storyComplete eq "Y") {
                        $storyStatS = $statusLiterals[2];
			$color = $defaults{storycompletecolor};
                    } else {
                        $color = $defaults{storyacceptancecolor};
                        $storyStatS = $statusLiterals[3];
                    }
                } else {
                    $color = $defaults{storyprogresscolor};
                    $storyStatS = $statusLiterals[1];
                }

		my $iterationcolor = ($iterDate)?$iterDatecolor:$color;

                # Show project / iteration line
		push @colors, $color;
		$list .= "| $iterationName&nbsp; $story | ".xpShowRounded($storyEst).' | '.xpShowRounded($storySpent).' | '.xpShowRounded($storyEtc).' | <div style="white-space:nowrap"> '.$storyStatS." </div> |<div style=\"background:$iterationcolor;margin:0;padding:0;border:0;white-space:nowrap\">".xpShowCell($iterDate, ! $storyOngoing)."</div>|\n";

                # Show each task
                for (my $i=0; $i<$taskCount; $i++) {

                    my $taskBG = "";
                    if ($taskStat[$i] == 4) {
                        $taskBG = $defaults{ongoingcolor};
                    }
                    elsif ($taskStat[$i] == 0) {
                        $taskBG = $defaults{taskunstartedcolor};
                    }
                    elsif ($taskStat[$i] == 1) {
                        $taskBG = $defaults{taskprogresscolor};
                    }

                    # Line for each engineer
                    my $doName = 1;
                    my @who = xpRipWords($taskWho[$i]);
                    my @est = xpRipWords($taskEst[$i]);
                    my @spent = xpRipWords($taskSpent[$i]);
                    my @etc = xpRipWords($taskEtc[$i]);

                    
                    for (my $x=0; $x<@who; $x++) {

                      # taskEtc is an array
                      next if (($etc[$x] == 0) && (! $storyOngoing));

		      ## TW: originally did not differentiate for ongoing stories on $etc
		      push @colors, $taskBG;
		      $list .= '| '.($doName?'&nbsp;&nbsp;&nbsp; '.$taskName[$i]:'&nbsp;').' | '.xpShowRounded($est[$x]).' | '.xpShowRounded($spent[$x]).' | '.xpShowRounded($storyOngoing?'':$etc[$x]).' |<div style="white-space:nowrap"> '.$statusLiterals[$taskStat[$i]]." </div>| &nbsp; |\n";
		      $doName = 0;
                    }
                    
                }
                
                # Add a spacer
		push @colors, 'none' if $addSpacer;
		$list .= "| &nbsp; ||||||\n" if $addSpacer;
    
                # Add to totals
                $totalSpent += $storySpent;
                $totalEtc += $storyEtc;
                $totalEst += $storyEst;

            }

        }

    # Do iteration totals
    $list .= '|*Developer totals*|*'.xpShowRounded($totalEst).'*|*'.xpShowRounded($totalSpent).'*|*'.xpShowRounded($totalEtc)."*|*&nbsp;*|*&nbsp;*|\n";
    unshift @colors, pop @colors;  # defect in TablePlugin
    my $color = join ',', @colors;
    $list = "---+++ Open project tasks by developer $developer\n%TABLE{headerrows=\"1\" footerrows=\"1\" dataalign=\"left,center,center,center,left,center\" headeralign=\"left,center,center,center,left,center\" databg=\"$color\"}%\n" . $list;

    $list .= CGI::start_table();
    $list .= CGI::Tr (
		      CGI::td( 'task' )
		      . CGI::td( { bgcolor=>$defaults{taskunstartedcolor} }, 'not started' )
		      . CGI::td( { bgcolor=>$defaults{taskprogresscolor} }, 'in progress' )
		      . CGI::td( 'due within' )
		      . CGI::td( { bgcolor=>'#FFFFCC' }, '3 days' )
		      . CGI::td( { bgcolor=>'#FFCCCC' }, '2 days' )
		      . CGI::td( { bgcolor=>'#FF6666' }, '1 day' ) );
    $list .= CGI::end_table();
    return $list;
}

###########################
# ThomasEschner: xpShowLoad
#
# Shows workload by developer and project/iteration.
# Table shows load in order to complete all tasks in all projects to the
# left including current project by the deadline of current project
# (might cause miss of earlier project dates).

sub xpShowLoadAll {
    my( $session, $params, $theTopic, $web ) = @_;
    use TWiki::Attrs;
    return xpShowLoad( $session, new TWiki::Attrs('developer="all"'), $theTopic, $web );
}

sub xpShowLoad {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $theTopic, $web ) = @_;

    my $dev = $params->{_DEFAULT} || $params->{developer};
    my $showOngoing = ( $params->{ongoing} eq 'on' ) || 0;
    $dev = 0 if ($dev eq 'all');

    my $now = time;
    my (@projiter, @projiterDate, @projiterSec, @projiterOngoing, %devDays);

    my @projects = &xpGetAllProjects($web);

    # Collect data
    my $count = 0;
    my $who;

    foreach my $project (@projects) {
        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){
            my @teamIters = &xpGetTeamIterations($team, $web);
            foreach my $iterationName (@teamIters) {

            $count++;

            # Get date of iteration
            my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iterationName);
            my $iterDate = &xpGetMetaValue($meta, "End");

            # Set up other story stats
            my ($storySpent) = 0;
            my ($storyEtc) = 0;
            my ($storyEst) = 0;

            my @allStories = &xpGetIterStories($iterationName, $web);  
	    my $onlyOngoing = 1;

            # Iterate over each story and task
            foreach my $story (@allStories) {
                my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
		my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));
		$onlyOngoing = 0 unless $storyOngoing;


                # Suck in the tasks
		foreach my $theTask ( $meta->find("TABLE") ) {
		  (my $status,my $name,my $est,my $taskWho,my $spent,my $taskEtc,my $tstatus) = xpGetTaskDetail($theTask); 

                    my @who = xpRipWords($taskWho);
                    my @etc = xpRipWords($taskEtc);

                    for (my $x=0; $x<@who; $x++) {

                        # straighten $who
		        # TJW: if this is done, we must have developer in Main
		        # TJW: could use a flag of whether to do this
                        #$who[$x] =~ s/(Main\.)?(.*)/Main\.$2/;  #TJW

                        # no display unless selected
		        if ($dev) {
			  my $test = eval { $who[$x] =~ /$dev/ };
			  next unless $test;
			}

                        $devDays{$who[$x]}[$count] = 
                          ($devDays{$who[$x]}[$count] || 0) + $etc[$x];
                        # Calculate est
                        $storyEtc += $etc[$x];
                    }
                }
            }
            
            # no display if nothing left to do
            if ($storyEtc == 0) {
                $count--;
                next;
            }
	    # no display if iterations contains only ongoing stories
	    if ( $onlyOngoing && ! $showOngoing ) {
	        $count--;
		next;
	    }
            
            $projiter[$count] = " $team <br> $iterationName <br> $iterDate ";
	    if ( $iterDate ) {
	      $projiterSec[$count] = 
                HTTP::Date::str2time($iterDate) - $now;
	        #Alternative:
	        #Time::ParseDate::parsedate($iterDate,%pdopt) - $now;
	    } else {
	      # Take some far out date for undefined dates
	      $projiterSec[$count] = $now;
	    }
            $projiterDate[$count] = $iterDate;
        }
    }
    }

    my $list = '';

    # Show the list
    my $cells = '| Developer |';
    for my $pi (sort {$projiterSec[$a] <=> $projiterSec[$b]} (1..$count)) {
      $cells .= ''.$projiter[$pi].'|';
    }
    $list .= $cells . "\n";


    for my $who (sort keys %devDays) {
        my $cumulLoad = 0;
	$cells = "| $who |";
        for my $pi (sort {$projiterSec[$a] <=> $projiterSec[$b]} (1..$count)) {
            my $color = '';
            $cumulLoad += $devDays{$who}[$pi]*24*3600;
	    my $load;
	    my $left;
	    if ( $projiterDate[$pi] ) {
	      my $useBusinessDate = 1;
	      if (! $useBusinessDate) {
		$left = $projiterSec[$pi];
		$left = 0.0001 if ($left==0);
		$load = ($projiterSec[$pi]==0)?0.0001:((7*$cumulLoad) / (5*$left)); 
		$left = $left /(3600*24);
	      } else {
		#alternatively, using business dates
		my $d1 = new TWiki::Plugins::Business();
		my( $sec, $min, $hour, $mday, $mon, $year) = localtime(HTTP::Date::str2time($projiterDate[$pi]));
		my $d2a = sprintf "%4d%2d%2d", 1900+$year, $mon+1, $mday;
		#my $d2a = 1900+$year.(($mon<10)?"0":"").$mon+1 .(($mday<10)?"0":"")."$mday";
		my $d2 = new TWiki::Plugins::Business(DATE => $d2a);
		$left = $d2->diffb($d1);
		$left = 0.0001 if ($left==0);
		$load = $cumulLoad / ($left*(3600*24));
	      }
	    } else {
	      $load = 0;
	    }
            if ($load < 0) {
                $color = '#FF6666';
            } elsif ($load > 1) {
                $color = '#FF6666';
            } elsif ($load > 0.6) {
                $color = '#FFCCCC';
            } elsif ($load > 0.45) {
                $color = '#FFFFCC';
            } elsif ($load > 0.3) {
                $color = '#CCFFCC';
            } else {
                $color = '#CCCCFF';
            }
	    my $cell = $devDays{$who}[$pi];
	    $cell = $cell?xpShowRounded($devDays{$who}[$pi]):'&nbsp;';
	    $cell = " *$cell* ";
	    if ( defined $devDays{$who}[$pi] && ($devDays{$who}[$pi] > 0) ) {
	      if ( $load == 0 ) {
		  $cell .= ' <br> &nbsp; ';
	      } elsif ( $load > 0 ) {
		  $cell .= ' <br> '.sprintf("%d \%",100*$load).' ';
	      } else {
                  $cell .= ' <br> (late!) ';
	      }
	    } else {
	      $cell .= ' <br> &nbsp; ';
	    }
	    $cells .= "<div style=\"background:$color\">$cell</div>|";
	}
	$list .= $cells . "\n";
    }
    $list = "---+++ Workload by developer and project iteration in $web\n%TABLE{headerrows=\"1\" dataalign=\"center\" sort=\"off\"}%\n" . $list;

    $list .= CGI::start_table();
    $list .= CGI::Tr(
		     CGI::td( 'load ranges' )
		     . CGI::td( { bgcolor=>'#CCCCFF' }, '0-30' )
		     . CGI::td( { bgcolor=>'#CCFFCC' }, '30-45' )
		     . CGI::td( { bgcolor=>'#FFFFCC' }, '45-60' )
		     . CGI::td( { bgcolor=>'#FFCCCC' }, '60-100' )
		     . CGI::td( { bgcolor=>'#FF6666' }, '100+' )
		     . CGI::td( 'estimated on a 5/7, 8/24 basis' ) );
    $list .= CGI::end_table();
    return $list;
}

###########################
# xpShowColours
#
# Service method to show current background colours

sub xpShowColours {

    my( $session, $params, $theTopic, $web ) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::xpShowColours( $web ) is OK" ) if $debug;

    my $table = "%TABLE{initsort=\"1\"}%\n";
    $table .= "|*name*|*colour*|\n";
    my ($key, $value);
    while (($key, $value) = each(%defaults)) {
      # read colours and put them in table
      $table .= "|$key| " . CGI::table( { width=>'100%' },
			     CGI::Tr(
			       CGI::td( { bgcolor=>$value }, $value ))) . "|\n";
    }
    return $table;
}

# =========================
# Insert the task table in story topics
#
sub xpShowTaskTable {

  &xpCacheRead( $web ) unless $cacheInitialized;
  my( $session, $params, $theTopic, $web ) = @_;
  my $topic = $params->{_DEFAULT} || $params->{story};
  $topic = "" . $topic;
  if ($topic =~ /^[\w]*Story$/) {
    return "%EDITHIDDENTABLE{template=\"TaskForm\" tablename=\"TaskTable\" topic=\"%TOPIC%\" changerows=\"on\"}%";
  } else { 
    return "";
  }

}

###########################
# ThomasEschner, TJW: xpShowDeveloperTimeSheet
# TJW: WARNING: one timesheet per topic only (if we want more,
# TJW:          need to add a numbering to the table name.
# TJW: WARNING: probably cannot update info on the topic
# TJW:          the timesheet is on? Need to test...
#
# Shows open tasks by developer.

sub xpShowDeveloperTimeSheet {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $topic, $web ) = @_;

    my $query = $session->{cgiQuery};
    my $developer = $params->{_DEFAULT} || $params->{developer};
    $tableNr++;

    my $doEdit = 0;

    my $cgiTableNr = $query->param( 'ettablenr' ) || 0;

    if ($cgiTableNr == $tableNr) {
    if( $query->param( 'etsave' ) ) {
      # [Submit Timesheet] button pressed
      doSaveTable( $session, $web, $topic, $query, $cgiTableNr );   # never return
      $doEdit = 0;
      return; # in case browser does not redirect

    } elsif( $query->param( 'etcancel' ) ) {
      # [Cancel] button pressed
      $doEdit = 0;
      doCancelEdit( $query, $web, $topic );            # never return
      return; # in case browser does not redirect

    } elsif( $query->param( 'etedit' ) ) {
      # [Timesheet] button pressed
      $doEdit = 1;
    }
    }

    my $rowNr = 0;

    my ($totalSpent,$totalEtc,$totalEst) = (0,0,0);

    my @projects = &xpGetAllProjects($web);

    my $viewUrl = &TWiki::Func::getScriptUrl ( $web, $topic, "view" ) ;

    # Show the list
    my $timesheet;
    $timesheet .= "<noautolink>\n" if $doEdit;
    $timesheet .= CGI::a( { name=>"timesheet$tableNr" }, '') . "\n";
    $timesheet .= "<form name=\"timesheet$tableNr\" action=\"$viewUrl\" method=\"post\">\n";
    $timesheet .= "<input type=\"hidden\" name=\"ettablenr\" value=\"$tableNr\" />\n";
    $timesheet .= "<input type=\"hidden\" name=\"etedit\" value=\"on\" />\n" unless $doEdit;

    my $list = '';
    my @colors = ();
    my $list = '|*Iteration Story<br>&nbsp; Task*|*Estimate*|*Spent*|*To do*|'.($doEdit?'*Add to<br>Spent*|*Update<br>To do*|':'*Status*|*Iteration due*|')."\n";

    # todo: build a list of projects/iterations sorted by date, make sort customizable

    my %iterKeys = ();
    my %iterDates = ();
    my @iterations = ();
    foreach my $project (@projects) {
        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){
            my @teamIters = &xpGetTeamIterations($team, $web);

            # Get date of each iteration
            foreach my $iter (@teamIters) {
                my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
                my $iterDate = &xpGetMetaValue($meta, "End");
                my $iterDays;
		if ( $iterDate ) {
		  $iterDays = HTTP::Date::str2time( $iterDate ) - time;
		} else {
		  # Schedule for out in the future
		  $iterDays = time;
		}
		$iterDays = $iterDays / (24*3600);
                $iterKeys{$iter} = $iterDays;
                $iterDates{$iter} = $iterDate;
		push @iterations, $iter;  # Could build up a sorted data structure
            }
	  }
      }

            # write out all iterations to table
            foreach my $iterationName (sort { $iterKeys{$a} <=> $iterKeys{$b} } @iterations) {
            # Get date of iteration
            my $iterDatecolor = "";
	    my $iterDays = $iterKeys{$iterationName};
	    my $iterDate = $iterDates{$iterationName};

            if ($iterDays < 1)
                { $iterDatecolor = '#FF6666'; }
            elsif ($iterDays < 2)
                { $iterDatecolor = '#FFCCCC'; }
            elsif ($iterDays < 3)
                { $iterDatecolor = '#FFFFCC'; }

            my @allStories = &xpGetIterStories($iterationName, $web);

            # Iterate over each story and add to hash
            my (%targetStories,%targetOrder,%targetMeta) = ();
            foreach my $story (@allStories) {
                my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
                $targetStories{$story} = $storyText;
		$targetMeta{$story} = $meta;
                # Get the ordering and save it
                $targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
            }

	    # TW: These appear not used
	    my $iterEst = 0;
	    my $iterSpent = 0;
	    my $iterEtc = 0;

            # Show them
            foreach my $story (sort { $targetOrder{$a} <=> $targetOrder{$b} || $a cmp $b } keys %targetStories) {
#            foreach my $story (sort { $a cmp $b } keys %targetStories) {

                my $storyText = $targetStories{$story};
		my $meta = $targetMeta{$story};

                # Get acceptance test status
                my $storyComplete = &xpStoryComplete($meta);

                # Set up other story stats
                my ($storySpent) = 0;
                my ($storyEtc) = 0;
                my ($storyEst) = 0;

                # Suck in the tasks
                my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
                my $taskCount = 0; # Amount of tasks in this story
                my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
		my $storyStatS = '';
		my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));

		my $storyOngoingInvolved = 0;

		foreach my $theTask ( $meta->find("TABLE") ) {
	  (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetTaskDetail($theTask); 

                    # straighten $who
	            # TJW: if this is done, we must have developer in Main
		    # TJW: could use a flag of whether to do this
                    #$who =~ s/(Main\.)?(.*)/Main\.$2/;  #TJW
                    # no display unless selected
                    my $test = eval { $who =~ /$developer/ };
                    next unless $test;

		    $storyOngoingInvolved = 1 if $storyOngoing;

                    $taskName[$taskCount] = $name;
                    $taskEst[$taskCount] = $est;
                    $taskWho[$taskCount] = $who;
                    $taskSpent[$taskCount] = $spent;
                    $taskEtc[$taskCount] = $etc;

                    $taskStat[$taskCount] = ($storyOngoing) ? 4 : $tstatus;
                    $storyStat[$taskStat[$taskCount]]++;

                    # Calculate spent
                    my @spentList = xpRipWords($taskSpent[$taskCount]);
                    foreach my $spent (@spentList) {
                        $storySpent += $spent;
                    }

                    # Calculate etc
                    my @etcList = xpRipWords($taskEtc[$taskCount]);
                    foreach my $etc (@etcList) {
                        $storyEtc += $etc;
                    }

                    # Calculate est
                    my @estList = xpRipWords($taskEst[$taskCount]);
                    foreach my $etc (@estList) {
                        $storyEst += $etc;
                    }
                    $taskCount++;
                }
                # no display if not involved
                next if (($storyEst == 0) && (! $storyOngoingInvolved));

                # no display if nothing left to do
                next if (($storyEtc == 0) && (! $storyOngoingInvolved));

                # Calculate iter status
                $iterEst += $storyEst;
                $iterSpent += $storySpent;
                $iterEtc += $storyEtc;

                # Calculate story status
                my $color = "";
		if ($storyOngoing) {
                    $color = $defaults{ongoingcolor};
                    $storyStatS = $statusLiterals[4];
		} elsif ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
                    $color = $defaults{storyunstartedcolor};
                    $storyStatS = $statusLiterals[0];
                } elsif ( ($storyStat[0] == 0) and ($storyStat[1] == 0) ) { # All tasks complete
                    if ($storyComplete eq "Y") {
			$color = $defaults{storycompletecolor};
                        $storyStatS = $statusLiterals[2];
                    } else {
                        $color = $defaults{storyacceptancecolor};
                        $storyStatS = $statusLiterals[3];
                    }
                } else {
                    $color = $defaults{storyprogresscolor};
                    $storyStatS = $statusLiterals[1];
                }

                # Get story summary
                my $storysummary = &xpGetMetaValue($meta, "Storysummary") if (! $storyOngoing);
                my $storyiteration = &xpGetMetaValue($meta, "Iteration");
		my $iterationcolor = ($iterDate)?$iterDatecolor:$color;

                # Show project / iteration line
		push @colors, $color;
		$list .= "| $storyiteration&nbsp; $story: $storysummary | ".xpShowRounded($storyEst).' | '.xpShowRounded($storySpent).' | '.xpShowRounded($storyEtc).' |<div style="white-space:nowrap"> '.$storyStatS." </div>|<div style=\"background:$iterationcolor;margin:0;padding:0;border:0;white-space:nowrap\">".xpShowCell($iterDate, ! $storyOngoing)."</div>|\n";

                # Show each task
                for (my $i=0; $i<$taskCount; $i++) {

                    my $taskBG = '';
                    if ($taskStat[$i] == 4) {
                        $taskBG = $defaults{ongoingcolor};
                    }
                    elsif ($taskStat[$i] == 0) {
                        $taskBG = $defaults{taskunstartedcolor};
                    }
                    elsif ($taskStat[$i] == 1) {
                        $taskBG = $defaults{taskprogresscolor};
                    }

                    # Line for each engineer
                    my $doName = 1;
                    my @who = xpRipWords($taskWho[$i]);
                    my @est = xpRipWords($taskEst[$i]);
                    my @spent = xpRipWords($taskSpent[$i]);
                    my @etc = xpRipWords($taskEtc[$i]);

                    
                    for (my $x=0; $x<@who; $x++) {

                      # taskEtc is an array
                      next if (($etc[$x] == 0) && (! $storyOngoing));

		      $rowNr++;

		      my $cells = '| &nbsp;';
		      if ($doEdit) {
			$cells .= "<input type=\"hidden\" name=\"etcell".$rowNr."x0\" value=\"".$story."\" />";
			if ($doName) {
			  $cells .= '&nbsp;&nbsp;&nbsp; '.$taskName[$i]." <input type=\"hidden\" name=\"etcell".$rowNr."x1\" value=\"".$taskName[$i]."\" />";

			}
			$cells .= ' |';

			$cells .= ' '.xpShowRounded($est[$x])." <input type=\"hidden\" name=\"etcell".$rowNr."x2\" value=\"".$est[$x]."\" /> |";
			$cells .= ' '.xpShowRounded($spent[$x])." <input type=\"hidden\" name=\"etcell".$rowNr."x3\" value=\"".$spent[$x]."\" /> |";
			$cells .= ' '.xpShowRounded($etc[$x])." <input type=\"hidden\" name=\"etcell".$rowNr."x4\" value=\"".$etc[$x]."\" /> |";
			$cells .= " <input type=\"text\" name=\"etcell".$rowNr."x5\" size=\"5\" value=\"\" /> |";
			if (! $storyOngoing) {
			  $cells .= ' '.CGI::table( { cellspacing=>'0', cellpadding=>'0' }, CGI::Tr( CGI::td( "<input type=\"text\" name=\"etcell".$rowNr."x6\" size=\"5\" value=\"\" />"), CGI::td( { nowrap=>undef }, "<input type=\"radio\" name=\"etcell".$rowNr."x7\" value=\"1\"  checked />To do" ), CGI::td( { nowrap=>undef }, "<input type=\"radio\" name=\"etcell".$rowNr."x7\" value=\"0\"  />% done" ) ) )." |";
			} else {
			  $cells .= ' &nbsp; |';
			}
		      } else {
			$cells .= ($doName?'&nbsp;&nbsp;&nbsp; '.$taskName[$i]:'&nbsp;').' | '.xpShowRounded($est[$x]).' | '.xpShowRounded($spent[$x]).' | '.xpShowRounded($storyOngoing?'':$etc[$x]).' |<div style="white-space:nowrap"> '.$statusLiterals[$taskStat[$i]].' </div>| &nbsp; |';
		        $doName = 0;
		      }
		      push @colors, $taskBG;
		      $list .= $cells . "\n";
		    }
                    
                }
                
                # Add a spacer
		push @colors, 'none' if $addSpacer;
		$list .= "| &nbsp; ||||||\n" if $addSpacer;
    
                # Add to totals
                $totalSpent += $storySpent;
                $totalEtc += $storyEtc;
                $totalEst += $storyEst;

            }

        }

    # Do developer totals
    $list .= '|*Developer totals*|*'.xpShowRounded($totalEst).'*|*'.xpShowRounded($totalSpent).'*|*'.xpShowRounded($totalEtc)."*|*&nbsp;*|*&nbsp;*|\n";
    unshift @colors, pop @colors;  # defect in TablePlugin
    my $color = join ',', @colors;
    $list = "---+++ Open tasks by developer $developer\n%TABLE{headerrows=\"1\" footerrows=\"1\" dataalign=\"left,center,center,center,left,center\" headeralign=\"left,center,center,center,left,center\" databg=\"$color\"}%\n" . $list;
    $list .= CGI::table( CGI::Tr( CGI::td( 'task' ) . CGI::td( { bgcolor=>$defaults{taskunstartedcolor} }, 'not started' ) . CGI::td( { bgcolor=>$defaults{taskprogresscolor} }, 'in progress' ) . CGI::td('due within') . CGI::td( { bgcolor=>'#FFFFCC' }, '3 days' ) . CGI::td( { bgcolor=>'#FFCCCC' }, '2 days' ) . CGI::td( { bgcolor=>'#FF6666' }, '1 day' ) ) );

    # end the table
    $timesheet .= $list;
    $timesheet .= "<input type=\"hidden\" name=\"etrows\"   value=\"$rowNr\" />\n";
    $timesheet .= "<input type=\"hidden\" name=\"developer\"   value=\"$developer\" />\n";
    if ($doEdit) {
      # Choose units
      # we could use CGI for forms also...
      # CGI::radio_group(-name=>'etunits', -values=>['1', '0'], -default=>'1', -labels=>{ '1' => 'Hours&nbsp;&nbsp;', '0' => 'Days&nbsp;&nbsp;' })
      $timesheet .= "Updates in <input type=\"radio\" name=\"etunits\" value=\"1\" checked />Hours &nbsp;&nbsp;<input type=\"radio\" name=\"etunits\" value=\"0\" />Days &nbsp;&nbsp;<br>";
      $timesheet .= "<input type=\"submit\" name=\"etsave\" value=\"Submit Timesheet\" />\n";
      $timesheet .= "<input type=\"submit\" name=\"etcancel\" value=\"Cancel\" />\n";
      $timesheet .= "&nbsp;&nbsp;<input type=\"checkbox\" name=\"etreport\" value=\"1\" checked />  Generate report\n";
    } else {
      $timesheet .= "<input type=\"submit\" value=\"Create Timesheet\" />\n";
    }
    $timesheet .= "</form>\n";
    $timesheet .= "</noautolink>\n" if $doEdit;

    return $timesheet;
}

sub doCancelEdit
{
    my ( $query, $web, $topic ) = @_;

    TWiki::Func::setTopicEditLock( $web, $topic, 0 );

    &TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );
}

sub doSaveTable
{
    my ( $session, $web, $topic, $query, $theTableNr ) = @_;
    my $units = $query->param('etunits');
    my $wantReport = $query->param('etreport');
    my $foundErrors = 0;
    
    my $errors = "---+++ Failed to update from timesheet\n";
    $errors .= "|*Story*|*Task*|*Add spent*|*Update to do*|*Status*|\n";
    my $updates = "---+++ Successfully updated from timesheet\n";
    $updates .= "|*Story*|*Task*|*Add spent*|*Update to do*|*Status*|\n"; 

    my $row = $query->param('etrows');
    my $developer = $query->param('developer');
    while ($row) {
      my $story = $query->param('etcell'.$row.'x0');
      my $task = $query->param('etcell'.$row.'x1');
      my $spent = $query->param('etcell'.$row.'x5');
      my $etc1 = $query->param('etcell'.$row.'x6');
      my $etc = $etc1 unless ($etc1 eq '');
      my $update = $query->param('etcell'.$row.'x7');

      my ($lockStatus, $lockUser, $editLock, $lockTime) = &xpUpdateTimeSheet($web, $developer, $story, $task, $spent, $etc, $update, $units);
      if ($lockStatus) {
	if ($spent || $etc) {
	  $updates .= "| $story | $task | ".xpShowRounded($spent).' | '.xpShowCell($update ? "$etc to do" : "$etc % done", $etc)." | Entered |\n";
	}
      } else {
	$foundErrors = 1;
	$errors .= "| $story | $task | ".xpShowRounded($spent).' | '.xpShowCell( $update ? "$etc to do" : "$etc % done", $etc).' | '.( ($lockUser)? "Locked by $lockUser for $lockTime more minutes" : "No permission to update $story" )." |\n";
      }
      $row--;
    }
    $errors .= '(in '.(($units)?'hours':'days').')';
    $updates .= '(in '.(($units)?'hours':'days').')';


    #log the submission
    $session->writeLog( 'submit', "$web.$topic", ($foundErrors)?'errors':'' );


    my $url = &TWiki::Func::getViewUrl( $web, $topic );
    # Cause error and report those topics that failed to save...
    if( $foundErrors ) {
        $url = &TWiki::Func::getOopsUrl( $web, $topic, 'oopstimesheet', $developer, $errors . $updates );
      } elsif ($wantReport) {
        $url = &TWiki::Func::getOopsUrl( $web, $topic, 'oopstimesheetreport', $developer, $updates );
      }
    &TWiki::Func::redirectCgiQuery( $query, $url );
}

sub xpUpdateTimeSheet {

  my ($web, $developer, $story, $task, $spent, $etc, $update, $units) = @_;
  my $changed = 0;
  my ($meta, $text) = &TWiki::Func::readTopic($web, $story);
  if ($units) {
    # Should round to 1 digit
    $spent = xpround($spent / 8) if $spent;
    $etc = xpround($etc / 8) if ($etc && $update);
  }

  foreach my $theTask ($meta->find("TABLE")) {
    (my $status,my $name,my $oldest,my $who,my $oldspent,my $oldetc,my $tstatus) = xpGetTaskDetail($theTask);            

    # The cases below are not really necessary...
    # WARNING: MUST NOT HAVE MORE THAN ONE TASKNAMExDEVELOPER TUPLE PER TASK
    if (($task eq $name) && ($developer eq $who)) {
      if ( $spent ) { # Don't update unless needed...
	$theTask->{"Spent"} = $spent+$oldspent;
	my $newetc = $oldetc-$spent;
	if (defined $etc) {
	  if ($update) {
	    $theTask->{"Todo"} = $etc;
	  } else {
	    $theTask->{"Todo"} = ($spent+$oldspent)*(100-$etc)/$etc;
	  }
	} else {
	  if ($newetc < 0) {
	    $theTask->{"Todo"} = 0; 
	  } else { 
	    $theTask->{"Todo"} = $oldetc-$spent; 
	  }
	}
	$meta->putKeyed( "TABLE", $theTask );
	$changed = 1;
      } else {
	  if (defined $etc) {
	    if ($update) {
	      $theTask->{"Todo"} = $etc;
	    } else {
	      $theTask->{"Todo"} = $oldspent*(100-$etc)/$etc;
	    }
	    $meta->putKeyed( "TABLE", $theTask );
	    $changed = 1;
	  }
	}
    }
  }
  if ($changed) {
    $story = TWiki::Sandbox::untaintUnchecked( $story );
    # Need to ensure topic is accessible
    my ($lockStatus, $lockUser, $editLock, $lockTime) = &doEnableEdit($web, $story, 1);
    if ($lockStatus) {
      # unlock topic, don't notify
      my $error = &TWiki::Func::saveTopic( $web, $story, $meta, $text, { dontlog => 1, forcedate => 1, dontNotify => 1 } );
      TWiki::Func::setTopicEditLock( $web, $story, 0 );
      return 1;
    } else {
      return (0, $lockUser, $editLock, $lockTime);
      }
  }
  return 1;
}

# mirrored from EditTablePlugin.pm
sub doEnableEdit
{
    my ( $theWeb, $theTopic, $doCheckIfLocked ) = @_;

    my $wikiUserName = &TWiki::Func::getWikiUserName();
    if( ! &TWiki::Func::checkAccessPermission( "change", $wikiUserName, "", $theTopic, $theWeb ) ) {
        # user has not permission to change the topic
        return 0;
    }

    my( $oopsUrl, $lockUser, $lockTime ) = &TWiki::Func::checkTopicEditLock( $theWeb, $theTopic );
    if( ( $doCheckIfLocked ) && ( $lockUser ) ) {
        # warn user that other person is editing this topic
        $lockUser = &TWiki::Func::userToWikiName( $lockUser );
        use integer;
        $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
###        my $editLock = $TWiki::editLockTime / 60;
	my $editLock = 60;
        return (0, $lockUser, $editLock, $lockTime);
    }
    &TWiki::Func::setTopicEditLock( $web, $theTopic, 1 );

    return 1;
}

###########################
# xpTeamReportByField
#
# Summarizes the data in indicated fiedl per team member for this team
# See also xpShowPivotByField()
# Can we factor out the common core for this and xpShowPivotByField?
# Would be nice to be able to also to it for all projects, i.e., one level up
# Another need would be to have a table of iteration wise data

sub xpTeamCoqReport {
    
    my( $session, $params, $theTopic, $web ) = @_;

    my $teamName = $params->{_DEFAULT} || $params->{team};
    
    return xpTeamReportByField( $session, 
				$web,
				$teamName,
				"COQ",
				"Cost of Quality of this team",
				0 );

}

sub xpTeamVelocityReport {
    
    my( $session, $params, $theTopic, $web ) = @_;

    my $teamName = $params->{_DEFAULT} || $params->{team};
    
    return xpTeamReportByField( $session, 
				$web,
				$teamName,
				"Developer",
				"Developer velocity",
				1, 1 );

}

sub xpTeamPivotByField {
    
    my( $session, $params, $theTopic, $web ) = @_;

    my $teamName = $params->{_DEFAULT} || $params->{team};
    my $fieldName = $params->{field};
    return '' unless $fieldName;
    my $title = $params->{title} || '';
    my $split = $params->{split} || 0;
    my $skip = $params->{skip} || 0;
    
    
    return xpTeamReportByField( $session, 
				$web,
				$teamName,
				$fieldName,
				$title,
				$split,
			        $skip );

}

## SMELL: How is this different from xpShowPivotByField?
sub xpTeamReportByField {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my ($session,$web,$team,$field,$title,$doSplit,$skipOngoing) = @_;

    my @teamIters = &xpGetTeamIterations($team, $web);

    my $list = "---+++ $title\n";
    
    # Show the table
    $list .= '%TABLE{dataalign="left,center,center,center,center,center" headeralign="left,center,center,center,center,center"}%'."\n";
    $list .= "|*Category*|*Ideals*|||*Tasks*||\n";
    $list .= "|^|*Assigned*|*Spent*|*Remaining*|*Assigned*|*Remaining*|\n";

    my (%whoAssigned,%whoSpent,%whoEtc,%whoTAssigned,%whoTRemaining) = ();
    my ($totalSpent,$totalEtc,$totalAssigned,$totalVelocity,$totalTAssigned,$totalTRemaining) = (0,0,0,0,0,0);

    # Get data of each iteration
    foreach my $iter (@teamIters) {

      my @allStories = &xpGetIterStories($iter, $web);
      
      # Get data of each story
      foreach my $story (@allStories) {

	my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
        if ($skipOngoing) { next if(&xpGetMetaValue($meta, "Ongoing") eq "Yes"); };
	if(&xpGetMetaValue($meta, "Iteration") eq $iter) {
	  foreach my $theTask ($meta->find("TABLE")) {
	    (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $taskStatus) = xpGetTaskDetail($theTask);            
	    my @who = ($doSplit) ? xpRipWords($theTask->{$field}) : $theTask->{$field};
	    my @spent = xpRipWords($taskSpent);
	    my @est = xpRipWords($taskEst);
	    my @etc = xpRipWords($taskEtc);
	    for (my $i=0; $i<@who; $i++) {

	      $whoSpent{$who[$i]} += $spent[$i];
	      $totalSpent += $spent[$i];
	      
	      $whoEtc{$who[$i]} += $etc[$i];
	      $totalEtc += $etc[$i];

	      $whoAssigned{$who[$i]} += $est[$i];
	      $totalAssigned += $est[$i];
	      
	      $whoTAssigned{$who[$i]}++;
	      $totalTAssigned++;

	      if ($etc[$i] > 0) {
		$whoTRemaining{$who[$i]}++;
                $totalTRemaining++;
	      } else {
		# ensure these variables always get initialised
		$whoTRemaining{$who[$i]}+= 0;
                $totalTRemaining+= 0;
	      }
	    }
	  }
	}
      }

    }

    # Show them
    foreach my $who (sort { $whoEtc{$b} <=> $whoEtc{$a} } keys %whoSpent) {
     $list .= '| '.$who.' | '.xpShowRounded($whoAssigned{$who}).' | '.xpShowRounded($whoSpent{$who}).' | '.xpShowRounded($whoEtc{$who}).' | '.$whoTAssigned{$who}.' | '.$whoTRemaining{$who}." |\n";
    }
    $list .= '|*Total*|*'.xpShowRounded($totalAssigned).'*|*'.xpShowRounded($totalSpent).'*|*'.xpShowRounded($totalEtc).'*|*'.$totalTAssigned.'*|*'.$totalTRemaining."*|\n";

    return $list;
}

# -------------------- Estimates -----------------------

###########################
# ThomasEschner, TJW: xpShowDeveloperEstimate
# Shows open tasks by developer.

sub xpShowDeveloperEstimate {

    &xpCacheRead( $web ) unless $cacheInitialized;
    my( $session, $params, $topic, $web ) = @_;

    my $query = $session->{cgiQuery};
    my $developer = $params->{_DEFAULT} || $params->{developer};
    $tableNr++;

    my $doEdit = 0;

    my $cgiTableNr = $query->param( 'ettablenr' ) || 0;

    if ($cgiTableNr == $tableNr) {
    if( $query->param( 'etsave' ) ) {
      # [Submit Estimates] button pressed
      doSaveEstimate( $session, $web, $topic, $query, $cgiTableNr );   # never return
      $doEdit = 0;
      return; # in case browser does not redirect

    } elsif( $query->param( 'etcancel' ) ) {
      # [Cancel] button pressed
      $doEdit = 0;
      doCancelEdit( $query, $web, $topic );            # never return
      return; # in case browser does not redirect

    } elsif( $query->param( 'etedit' ) ) {
      # [Estimates] button pressed
      $doEdit = 1;
    }
    }

    my $rowNr = 0;

    my @projects = &xpGetAllProjects($web);

    my $viewUrl = &TWiki::Func::getScriptUrl ( $web, $topic, "view" ) ;

    # Show the list
    my $timesheet = '';
    $timesheet .= "<noautolink>\n" if $doEdit;
    $timesheet .= CGI::a( { name=>"estimates$tableNr" } ) . "\n";
    $timesheet .= "<form name=\"estimates$tableNr\" action=\"$viewUrl\" method=\"post\">\n";
    $timesheet .= "<input type=\"hidden\" name=\"ettablenr\" value=\"$tableNr\" />\n";
    $timesheet .= "<input type=\"hidden\" name=\"etedit\" value=\"on\" />\n" unless $doEdit;

    my $list = '';
    my @colors = ();
    $list .= '|*Iteration Story<br>&nbsp; Task*|*'.($doEdit?'Estimate':'Iteration due')."*|\n";

    # todo: build a list of projects/iterations sorted by date

    my %iterKeys = ();
    my %iterDates = ();
    my @iterations = ();
    foreach my $project (@projects) {
        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){
            my @teamIters = &xpGetTeamIterations($team, $web);

            # Get date of each iteration
            foreach my $iter (@teamIters) {
                my ($meta, $iterText) = &TWiki::Func::readTopic($web, $iter);
                my $iterDate = &xpGetMetaValue($meta, "End");
                my $iterDays;
		if ( $iterDate ) {
		  $iterDays = HTTP::Date::str2time( $iterDate ) - time;
		} else {
		  # Schedule for out in the future
		  $iterDays = time;
		}
		$iterDays = $iterDays / (24*3600);
                $iterKeys{$iter} = $iterDays;
                $iterDates{$iter} = $iterDate;
		push @iterations, $iter;  # Could build up a sorted data structure
            }
	  }
      }

            # write out all iterations to table
            foreach my $iterationName (sort { $iterKeys{$a} <=> $iterKeys{$b} } @iterations) {

            # Get date of iteration
            my $iterDatecolor = "";
	    my $iterDays = $iterKeys{$iterationName};
	    my $iterDate = $iterDates{$iterationName};

            if ($iterDays < 1)
                { $iterDatecolor = '#FF6666'; }
            elsif ($iterDays < 2)
                { $iterDatecolor = '#FFCCCC'; }
            elsif ($iterDays < 3)
                { $iterDatecolor = '#FFFFCC'; }

            my @allStories = &xpGetIterStories($iterationName, $web);

            # Iterate over each story and add to hash
            my (%targetStories,%targetOrder,%targetMeta) = ();
            foreach my $story (@allStories) {
                my ($meta, $storyText) = &TWiki::Func::readTopic($web, $story);
                $targetStories{$story} = $storyText;
		$targetMeta{$story} = $meta;
                # Get the ordering and save it
                $targetOrder{$story} = substr(&xpGetMetaValue($meta, $defaults{sort}),0,1);
            }

            # Show them
            foreach my $story (sort { $targetOrder{$a} <=> $targetOrder{$b} || $a cmp $b } keys %targetStories) {
#            foreach my $story (sort { $a cmp $b } keys %targetStories) {

                my $storyText = $targetStories{$story};
		my $meta = $targetMeta{$story};

                # Get acceptance test status
                my $storyComplete = &xpStoryComplete($meta);

                # Suck in the tasks
                my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
                my $taskCount = 0; # Amount of tasks in this story
		my $storyOngoing = &xpYNtoBool(&xpGetMetaValue($meta, "Ongoing"));

		my $storyInvolved = 0;

		foreach my $theTask ( $meta->find("TABLE") ) {
	  (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetTaskDetail($theTask); 

                    # straighten $who
	            # TJW: if this is done, we must have developer in Main
		    # TJW: could use a flag of whether to do this
                    #$who =~ s/(Main\.)?(.*)/Main\.$2/;  #TJW
	            # no display if ongoing
	            next if $storyOngoing;
                    # no display unless selected
                    my $test = eval { $who =~ /$developer/ };
                    next unless $test;
                    # no display unless selected
		    next unless ((($est eq "") && !($est eq "0")) || ($est eq "?"));

                    $taskName[$taskCount] = $name;
                    $taskWho[$taskCount] = $who;

                    $taskCount++;
	            $storyInvolved++;
                }

                # no display if not involved
                next if ($storyInvolved == 0);

                my $color = "";

                # Get story summary
                my $storysummary = &xpGetMetaValue($meta, "Storysummary") if (! $storyOngoing);
                my $storyiteration = &xpGetMetaValue($meta, "Iteration");
		my $iterationcolor = ($iterDate)?$iterDatecolor:$color;

                # Show project / iteration line
		push @colors, $color;
                $list .= "| $storyiteration&nbsp; $story: $storysummary | <div style=\"background:$iterationcolor;margin:0;padding:0;border:0;white-space:nowrap\">".xpShowCell($iterDate, ! $storyOngoing)."</div>|\n";

                # Show each task
                for (my $i=0; $i<$taskCount; $i++) {

                    my $taskBG = $defaults{ongoingcolor};

                    # Line for each engineer
                    my $doName = 1;
                    my @who = xpRipWords($taskWho[$i]);
                    
                    for (my $x=0; $x<@who; $x++) {

		      $rowNr++;

		      
		      my $cells = '| &nbsp;';
		      if ($doEdit) {
			$cells .= "<input type=\"hidden\" name=\"etcell".$rowNr."x0\" value=\"".$story."\" />";
			if ($doName) {
			  $cells .= '&nbsp;&nbsp;&nbsp; '.$taskName[$i]." <input type=\"hidden\" name=\"etcell".$rowNr."x1\" value=\"".$taskName[$i]."\" />";
			    
			}
			$cells .= ' |';

			$cells .= " <input type=\"text\" name=\"etcell".$rowNr."x5\" size=\"5\" value=\"\" /> |";
		      } else {
			$cells .= ($doName?'&nbsp;&nbsp;&nbsp; '.$taskName[$i]:'&nbsp;').' |  &nbsp; |';
		        $doName = 0;
		      }
		      push @colors, $taskBG;
		      $list .= $cells . "\n";
		    }
                    
                }
                
                # Add a spacer
		push @colors, 'none' if $addSpacer;
		$list .= "| &nbsp; ||||||\n" if $addSpacer;
    
            }

        }

    # Do iteration totals
    unshift @colors, pop @colors;  # defect in TablePlugin
    my $color = join ',', @colors;
    $list = "---+++ Missing estimates for developer $developer\n%TABLE{headerrows=\"1\" dataalign=\"left,center\" headeralign=\"left,center\" databg=\"$color\"}%\n" . $list;
    $list .= CGI::table( CGI::Tr( CGI::td( 'due within' ) . CGI::td( { bgcolor=>'#FFFFCC' }, '3 days' ) . CGI::td( { bgcolor=>'#FFCCCC' }, '2 days' ) . CGI::td( { bgcolor=>'#FF6666' }, '1 day' ) ) );

    # end the table
    $timesheet .= $list;
    $timesheet .= "<input type=\"hidden\" name=\"etrows\"   value=\"$rowNr\" />\n";
    $timesheet .= "<input type=\"hidden\" name=\"developer\"   value=\"$developer\" />\n";
    if ($doEdit) {
      # Choose units
      $timesheet .= "Updates in <input type=\"radio\" name=\"etunits\" value=\"1\" checked />Hours &nbsp;&nbsp;<input type=\"radio\" name=\"etunits\" value=\"0\" />Days &nbsp;&nbsp;<br>";
      $timesheet .= "<input type=\"submit\" name=\"etsave\" value=\"Submit Estimate\" />\n";
      $timesheet .= "<input type=\"submit\" name=\"etcancel\" value=\"Cancel\" />\n";
      $timesheet .= "&nbsp;&nbsp;<input type=\"checkbox\" name=\"etreport\" value=\"1\" checked />  Generate report\n";
    } else {
      $timesheet .= "<input type=\"submit\" value=\"Create Estimate\" />\n";
    }
    $timesheet .= "</form>\n";
    $timesheet .= "</noautolink>\n" if $doEdit;

    return $timesheet;
}

sub doSaveEstimate
{
    my ( $session, $web, $topic, $query, $theTableNr ) = @_;
    my $units = $query->param('etunits');
    my $wantReport = $query->param('etreport');
    my $foundErrors = 0;
    
    my $errors = "---+++ Failed to update estimate\n";
    $errors .= "*Story*|*Task*|*Estimate*|*Status*|\n";
    my $updates = "---+++ Successfully updated estimate\n";
    $updates .= "*Story*|*Task*|*Estimate*|\n";

    my $row = $query->param('etrows');
    my $developer = $query->param('developer');
    while ($row) {
      my $story = $query->param('etcell'.$row.'x0');
      my $task = $query->param('etcell'.$row.'x1');
      my $estimate = $query->param('etcell'.$row.'x5');

      my ($lockStatus, $lockUser, $editLock, $lockTime) = &xpUpdateEstimate($web, $developer, $story, $task, $estimate, $units);
      if ($lockStatus) {
	if ($estimate) {
	  $updates .= "| $story | $task | ".xpShowRounded($estimate)."|\n";
	}
      } else {
	$foundErrors = 1;
	$errors = "| $story | $task | ".xpShowRounded($estimate)." |";
	if ($lockUser) {
	  $errors .= " Locked by $lockUser for $lockTime more minutes |\n";
	} else {
	  $errors .= " No permission to update $story |\n";
	}
      }
      $row--;
    }
    $updates .= '(in '.(($units)?'hours':'days').')';
    $errors .= '(in '.(($units)?'hours':'days').')';   # For error reporting during update

    #log the submission
    $session->writeLog( 'estimate', "$web.$topic", ($foundErrors)?'errors':'' );

    # TJW: why lock?
    #&TWiki::Func::setTopicEditLock( $web, $topic, 1 );
    my $url = &TWiki::Func::getViewUrl( $web, $topic );
    # Cause error and report those topics that failed to save...
    if( $foundErrors ) {
        $url = &TWiki::Func::getOopsUrl( $web, $topic, 'oopstimesheet', $developer, $errors . $updates );
      } elsif ($wantReport) {
        $url = &TWiki::Func::getOopsUrl( $web, $topic, 'oopstimesheetreport', $developer, $updates );
      }
    &TWiki::Func::redirectCgiQuery( $query, $url );
}

sub xpUpdateEstimate {

  my ($web, $developer, $story, $task, $est, $units) = @_;
  my $changed = 0;
  my ($meta, $text) = &TWiki::Func::readTopic($web, $story);
  if ($units) {
    # Should round to 1 digit
    $est = xpround($est / 8);
  }

  foreach my $theTask ($meta->find("TABLE")) {
    (my $status,my $name,my $oldest,my $who,my $oldspent,my $oldetc,my $tstatus) = xpGetTaskDetail($theTask);            

    # The cases below are not really necessary...
    # WARNING: MUST NOT HAVE MORE THAN ONE TASKNAMExDEVELOPER TUPLE PER TASK
    if (($task eq $name) && ($developer eq $who)) {
      if ( $est ) { # Don't update unless needed...
	$theTask->{"Est"} = $est+$oldest;
	$theTask->{"Todo"} = $est+$oldetc;
	$meta->putKeyed( "TABLE", $theTask );
	$changed = 1;
      }
    }
  }
  if ($changed) {
    # Need to ensure topic is accessible
    my ($lockStatus, $lockUser, $editLock, $lockTime) = &doEnableEdit($web, $story, 1);
    if ($lockStatus) {
      # unlock topic, don't notify
      my $error = &TWiki::Func::saveTopic( $web, $story, $meta, $text, { dontlog => 1, forcedate => 1, unlock => 1, dontNotify => 1 } );
    } else {
      return (0, $lockUser, $editLock, $lockTime);
      }
  }
  return 1;
}

sub createTimesheet {

  my $session = shift;
  $TWiki::Plugins::SESSION = $session;

  my $query = $session->{cgiQuery};
  my $webName = $session->{webName};
  my $topic = $session->{topicName};
  my $user = $session->{user};

  my $tmpl = ""; 
  my $text = "";
  my $ptext = "";
  my $meta = "";
  my $formFields = "";
  my $wikiUserName = &TWiki::Func::userToWikiName( $user );

  TWiki::UI::checkWebExists( $session, $webName, $topic, 'view' );
  TWiki::UI::checkMirror( $session, $webName, $topic );

  my $row = $query->param('etrows');
  my $developer = $query->param('developer');
  while ($row) {
    my $story = $query->param("etcell".$row."x1");
    my $task = $query->param("etcell".$row."x2");
    my $spent = $query->param("etcell".$row."x4");
    my $etc = $query->param("etcell".$row."x5");
    my $update = $query->param("etcell".$row."x6");
    xpUpdateTimeSheet($webName, $developer, $story, $task, $spent, $etc, $update);
    $row--;
  }
  TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( "", $topic ) );
  return;

}

1;
