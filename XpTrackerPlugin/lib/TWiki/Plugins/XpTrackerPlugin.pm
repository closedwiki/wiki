
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::XpTrackerPlugin;

#  $Revision$ $Date$
# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $exampleCfgVar $dataDir
    );

use vars qw ( @timeRec
        $cachedWebName
        %cachedProjectTeams
        %cachedTeamIterations
        %cachedIterationStories
    );

$VERSION = '3.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::initPlugin is OK" ) if $debug;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between XpTrackerPlugin and Plugins.pm" );
        return 0;
    }

    $query = &TWiki::Func::getCgiQuery();
    if( ! $query ) {
        return 0;
    }

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "XPTRACKERPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "XPTRACKERPLUGIN_DEBUG" );

    # reasonable defaults for colouring. By default task and stories have similar colour schemes. 
    %defaults = (
        # colors
        headercolor             => $webColor,
        taskwaitcolor           => '#FFCCCC',
        taskprogresscolor       => '#99FF99',
        taskcompletecolor       => '#FFFFFF',
        storywaitcolor          => '#FFCCCC',
        storyprogresscolor      => '#CCFFFF',
        storycompletecolor      => '#99FF99',
        storyacceptancecolor    => '#FFFFFF'
    );

    # now get defaults from XpTrackerPlugin topic
    my $v;
    foreach $option (keys %defaults) {
        # read defaults from XpTrackerPlugin topic
        $v = &TWiki::Func::getPreferencesValue("XPTRACKERPLUGIN_\U$option\E") || undef;
        $defaults{$option} = $v if defined($v);
    }

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    &xpCacheBuild( $web );

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # &TWiki::Func::writeDebug( "- XpTrackerPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # for compatibility for earlier TWiki versions:
    # $_[0]=~ s/%INCLUDE:"(.*?)"%/&handleIncludeFile($1)/geo;
    # $_[0]=~ s/%INCLUDE:"(.*?)"%/&handleIncludeFile($1)/geo;  # allow two level includes

    # do custom extension rule, like for example:
    # $_[0]=~ s/%WIKIWEB%/$wikiToolName.$web/go;

    # ========================== START XP TAGS ========================== RJB 2001.03.13

    # search for create new page link
    if( $query->param( 'xpsave' ) ) {
        xpSavePage($web);
        # return; # in case browser does not redirect
    }

    # %XPSHOWALLPROJECTS% - Show all projects
    $_[0] =~ s/%XPSHOWALLPROJECTS%/&xpShowAllProjects($web)/geo;

    # %XPSHOWALLTEAMS% - Show all teams
    $_[0] =~ s/%XPSHOWALLTEAMS%/&xpShowAllTeams($web)/geo;

    # %XPSHOWALLITERATIONS% - Show all iterations
    $_[0] =~ s/%XPSHOWALLITERATIONS%/&xpShowAllIterations($web)/geo;

    # %XPSHOWPROJECTTEAMS% - Show all teams on this project
    $_[0] =~ s/%XPSHOWPROJECTTEAMS\{(.*?)\}%/&xpShowProjectTeams($1, $web)/geo;

    # %XPSHOWPROJECTITERATIONS% - Show all project iterations
    $_[0] =~ s/%XPSHOWPROJECTITERATIONS\{(.*?)\}%/&xpShowProjectIterations($1, $web)/geo;

    # %XPSHOWPROJECTSTORIES% - Show all project stories
    $_[0] =~ s/%XPSHOWPROJECTSTORIES\{(.*?)\}%/&xpShowProjectStories($1, $web)/geo;

    # %XPSHOWPROJECTCOMPLETIONBYSTORIES% - Show completion status of project by stories
    $_[0] =~ s/%XPSHOWPROJECTCOMPLETIONBYSTORIES\{(.*?)\}%/&xpShowProjectCompletionByStories($1, $web)/geo;

    # %XPSHOWPROJECTCOMPLETIONBYTASKS% - Show completion status of project by tasks
    $_[0] =~ s/%XPSHOWPROJECTCOMPLETIONBYTASKS\{(.*?)\}%/&xpShowProjectCompletionByTasks($1, $web)/geo;

    # %XPSHOWTEAMITERATIONS% - Show all team iterations
    $_[0] =~ s/%XPSHOWTEAMITERATIONS\{(.*?)\}%/&xpShowTeamIterations($1, $web)/geo;

    # %XPSHOWITERATION% - Show iteration status
    $_[0] =~ s/%XPSHOWITERATION\{(.*?)\}%/&xpShowIteration($1,$web)/geo;

    # %XPSHOWITERATIONTERSE% - Show iteration status
    $_[0] =~ s/%XPSHOWITERATIONTERSE\{(.*?)\}%/&xpShowIterationTerse($1,$web)/geo;

    # %XPVELOCITIES% - Show velocities by iteration
    $_[0] =~ s/%XPVELOCITIES\{(.*?)\}%/&xpShowVelocities($1,$web)/geo;

    # %XPDUMPITERATION% - Dumps an iteration for printing
    $_[0] =~ s/%XPDUMPITERATION\{(.*?)\}%/&xpDumpIteration($1,$web)/geo;

    # %XPSHOWCOLOURS% - Service procedure to show current colours
    $_[0] =~ s/%XPSHOWCOLOURS%/&xpShowColours($web)/geo;

    # ========================== END XP TAGS ==========================

    return $_[0];
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    &TWiki::Func::writeDebug( "- XpTrackerPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- XpTrackerPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- XpTrackerPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

###########################
# xpGetValue
#
# Return value from passed in text with passed in title

sub xpGetValue {
    my $title = $_[0];
    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
    my $oldStyle = $_[2];
    my $result = "";

    my $pattern1 = "<!--".$oldStyle."--> *(.*?) *<!--\\/".$oldStyle."-->";
    my $pattern2 = "\\|[ \\t]*".$title."[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";

    if ($_[1] =~ /$pattern1/s) {
        $result = $1;
    }
    elsif ($_[1] =~ /$pattern2/s) {
        $result = $1;
    }
    return $result;
}

###########################
# xpGetValueAndRemove
#
# Return value from passed in text with passed in title. Remove line from text

sub xpGetValueAndRemove {
    my $title = $_[0];
    # my $text = $_[1]; # DONT MAKE COPY for performance reasons
    my $oldStyle = $_[2];
    my $result = "";

    my $pattern1 = "<!--".$oldStyle."--> *(.*?) *<!--\\/".$oldStyle."-->";
    my $pattern2 = "\\|[ \\t]*".$title."[ \\t]*\\|[ \\t]*(.*?)[ \\t]*\\|";

    if ($_[1] =~ s/$pattern1//s) {
        $result = $1;
    }
    elsif ($_[1] =~ s/$pattern2//s) {
        $result = $1;
    }
    return $result;
}


###########################
# xpDumpIteration
#
# Dumps stories and tasks in an iteration.

sub xpDumpIteration {
    my ($iteration,$web) = @_;

    my @allStories = &xpGetIterStories($iteration, $web);  

    # Iterate over each and build master list

    my $bigList = "";

    foreach my $story (@allStories) {
        my $storyText = &TWiki::Store::readTopic($web, $story);
        # TODO: This is a hack!
        # Patch the embedded "DumpStoryList" name to the real story name
        if(&xpGetValue("\\*Iteration\\*", $storyText, "storyiter") eq $iteration) {
            # TODO: This is a hack!
            # Patch the embedded %TOPIC% before the main TWiki code does
            $storyText =~ s/%TOPIC%/$story/go;
            $bigList .= "<h2>Story: ".$story."</h2>\n".$storyText."<br><br><hr> \n";
        }
    }
    
    return $bigList;
}

###########################
# xpShowIteration
#
# Shows the specified iteration broken down by stories and tasks

sub xpShowIteration {

    my ($iterationName,$web) = @_;

    my @statusLiterals = ("Not Started", "In progress", "Complete", "Acceptance");

    my $list = "<h3>Iteration details</h3>";
    $list .= "<table border=\"1\">";
    $list .= "<tr bgcolor=\"#CCCCCC\"><th align=\"left\">Story<br>&nbsp; Tasks </th><th>Estimate</th><th>Who</th><th>Spent</th><th>To do</th><th>Status</th></tr>";

    my @allStories = &xpGetIterStories($iterationName, $web);  

    # Iterate over each story and add to hash
    my (%targetStories,%targetOrder) = ();
    foreach my $story (@allStories) {
        my $storyText = &TWiki::Store::readTopic($web, $story);
        $targetStories{$story} = $storyText;
        # Get the ordering and save it
        $targetOrder{$story} = &xpGetValue("\\*Development order\\*", $storyText, "order");
    }

    my ($totalSpent,$totalEtc,$totalEst) = 0;

    # Show them
    foreach my $story (sort { $targetOrder{$a} cmp $targetOrder{$b} || $a cmp $b } keys %targetStories) {

        my $storyText = $targetStories{$story};
        
        # Get acceptance test status
        my $storyComplete = "N";
        my $ret = &xpGetValue("\\*Passed acceptance test\\*", $storyText, "complete");
        $storyComplete = uc(substr($ret,0,1));  
        
        # Get story lead
        my $storyLead = &xpGetValue("\\*Story Lead\\*", $storyText, "storyLead");
        
        # Set up other story stats
        my ($storySpent,$storyEtc,$storyCalcEst) = 0;
        
        # Suck in the tasks
        my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
        my $taskCount = 0; # Amount of tasks in this story
        my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
    
        while(1) {
            (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetNextTask($storyText);
            if (!$status) {
                last;
            }
            
            $taskName[$taskCount] = $name;
            $taskEst[$taskCount] = $est;
            $taskWho[$taskCount] = $who;
            $taskSpent[$taskCount] = $spent;
            $taskEtc[$taskCount] = $etc;
            
            $taskStat[$taskCount] = $tstatus;
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
        my $color = "";
        my $storyStatS = "";
        if ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
            $color = "$defaults{storywaitcolor}";
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
        $list .= "<tr";
        if ($color) {
            $list .= " bgcolor=$color";
        }
        $list .= "><td> ".$story." </td><td align=\"center\"><b>".$storyCalcEst."</b></td><td> ".$storyLead." </td><td align=\"center\"><b>".$storySpent."</b></td><td align=\"center\">";
        $list .= "<b>".$storyEtc."</b>";
        $list .= "</td><td nowrap>".$storyStatS."</td></tr>";
        
        # Show each task
        for (my $i=0; $i<$taskCount; $i++) {
            
            my $taskBG = "";
            if ($taskStat[$i] == 0) {
                $taskBG = " bgcolor=\"$defaults{taskwaitcolor}\"";
            }
            elsif ($taskStat[$i] == 1) {
                $taskBG = " bgcolor=\"$defaults{taskprogresscolor}\"";
            }
            elsif ($taskStat[$i] == 2) {
                $taskBG = " bgcolor=\"$defaults{taskcompletecolor}\"";
            }

            # Line for each engineer
            my $doName = 1;
            my @who = xpRipWords($taskWho[$i]);
            my @est = xpRipWords($taskEst[$i]);
            my @spent = xpRipWords($taskSpent[$i]);
            my @etc = xpRipWords($taskEtc[$i]);
            for (my $x=0; $x<@who; $x++) {
                $list .= "<tr".$taskBG."><td>&nbsp;";
                if ($doName) {
                    $list .= "&nbsp;&nbsp;&nbsp;".$taskName[$i];
                }
                $list .= "</td><td align=\"center\">".$est[$x]."</td><td> ".$who[$x]." </td><td align=\"center\">".$spent[$x]."</td><td align=\"center\">".$etc[$x]."</td><td nowrap>";
                
                $list .= $statusLiterals[$taskStat[$i]];
                
                $list .= "</td></tr>";
                $doName = 0;
            }
            
        }
        
        # Add a spacer
        $list .= "<tr><td colspan=\"6\">&nbsp;</td></tr>";
        
        # Add to totals
        $totalSpent += $storySpent;
        $totalEtc += $storyEtc;
        $totalEst += $storyCalcEst;
        
    }
    
    # Do iteration totals
    
    $list .= "<tr bgcolor=\"#CCCCCC\"><td><b>Team totals</b></td><td align=\"center\"><b>".$totalEst."</b></td><td></td><td align=\"center\"><b>".$totalSpent."</b></td><td align=\"center\"><b>".$totalEtc."</b></td><td> </td></tr>";
    $list .= "</table>";
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
    my $line="<table height=100% width=100%><tr>";
    if ($done > 0) { $line .= "<td width=$done% bgcolor=\"#00cc00\">&nbsp;</td>"; }
    if ($todo > 0) { $line .= "<td width=$todo% bgcolor=\"#cc0000\">&nbsp;</td>"; }
    $line .= "</tr></table>";
    return $line;
}

###########################
# xpShowIterationTerse
#
# Shows the specified iteration broken down by stories and tasks
# Copied from XpShowIteration. Need to refactor!

sub xpShowIterationTerse {

    my ($iterationName,$web) = @_;

    my $showTasks = "N";

    my @statusLiterals = ("Not Started", "In progress", "Complete", "Acceptance");

    my $list = "<h3>Iteration summary</h3>";
    $list .= "<table border=\"1\">";
    $list .= "<tr bgcolor=\"#CCCCCC\"><th align=\"left\">Story</th><th>FEA</th><th>Estimate</th><th>Spent</th><th>ToDo</th><th>Progress</th><th>Done</th><th>Overrun</th><th>Completion</th></tr>";

    my @allStories = &xpGetIterStories($iterationName, $web);  

    # Iterate over each story and add to hash
    my (%targetStories,%targetOrder) = ();
    foreach my $story (@allStories) {
    my $storyText = &TWiki::Store::readTopic($web, $story);
    $targetStories{$story} = $storyText;
    # Get the ordering and save it
    $targetOrder{$story} = &xpGetValue("\\*Development order\\*", $storyText, "order");
    }

    my ($totalSpent,$totalEtc,$totalEst) = 0;

    # Show them
    foreach my $story (sort { $targetOrder{$a} cmp $targetOrder{$b} || $a cmp $b } keys %targetStories) {
    my $storyText = $targetStories{$story};
    
    # Get FEA
    my $fea = &xpGetValue("\\*FEA\\*", $storyText, "notagsforthis");

    # Get story summary
    my $storySummary = &xpGetValue("\\*Story summary\\*", $storyText, "notagsforthis");

    # Get acceptance test status
    my $storyComplete = "N";
    my $ret = &xpGetValue("\\*Passed acceptance test\\*", $storyText, "complete");
    if($ret) {
        $storyComplete = uc(substr($ret,0,1));
    }

    # Set up other story stats
    my ($storySpent,$storyEtc,$storyCalcEst) = 0;
    
    # still need to parse tasks to track total time estimates
    # Suck in the tasks. Move this code into separate routine
    my (@taskName, @taskStat, @taskEst, @taskWho, @taskSpent, @taskEtc) = (); # arrays for each task
    my $taskCount = 0; # Amount of tasks in this story
    my @storyStat = ( 0, 0, 0 ); # Array of counts of task status
    my $storyStatS = '';

    while(1) {
        (my $status,my $name,my $est,my $who,my $spent,my $etc,my $tstatus) = xpGetNextTask($storyText);
        if (!$status) {
        last;
        }

        $taskName[$taskCount] = $name;
        $taskEst[$taskCount] = $est;
        $taskWho[$taskCount] = $who;
        $taskSpent[$taskCount] = $spent;
        $taskEtc[$taskCount] = $etc;

        $taskStat[$taskCount] = $tstatus;
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
    if ( ($storyStat[1] == 0) and ($storyStat[2] == 0) ) { # All tasks are unstarted
        # status: not started
        $color = "$defaults{storywaitcolor}";
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
    $list .= "<tr";
    # if ($storyComplete ne "Y") {
        $list .= " bgcolor=$color";
    # }
    $list .= "><td> ".$story."<br> ".$storySummary." </td>\n";
    $list .= "<td align=\"center\"> ".$fea." </td>\n";
    $list .= "<td align=\"center\"><b>".$storyCalcEst."</b></td>\n";
    $list .= "<td align=\"center\"><b>".$storySpent."</b></td>\n";
    $list .= "<td align=\"center\"><b>".$storyEtc."</b></td>";
    my $done = 0;
    if(($storySpent + $storyEtc) > 0) {
        $done = int(100.0 * $storySpent / ($storySpent + $storyEtc));
        }
    $list .= "<td>";
    $list .= gaugeLite($done);
    $list .= "</td>";

    $list .= "<td align=right>".$done."%</td>";

    my $cfEst = 0;
    if($storyCalcEst > 0) {
      $cfEst = int(100*(($storySpent + $storyEtc) / $storyCalcEst) - 100);
    }
    if($cfEst >= 0) {
      $list .= "<td align=right> +".$cfEst."%</td>";
    } else {
      $list .= "<td align=right>".$cfEst."%</td>";  
    }

    $list .= "<td>".$storyStatS."</td>";

        $list .= "</tr>";

    # Show each task
    if($showTasks eq "Y") {

        for (my $i=0; $i<$taskCount; $i++) {
        
        my $taskBG = "";
        if ($taskStat[$i] != 2) {
            $taskBG = " bgcolor=\"#FFCCCC\"";
        }
        
        # Line for each engineer
        my $doName = 1;
        my @who = xpRipWords($taskWho[$i]);
        my @est = xpRipWords($taskEst[$i]);
        my @spent = xpRipWords($taskSpent[$i]);
        my @etc = xpRipWords($taskEtc[$i]);
        for (my $x=0; $x<@who; $x++) {
            $list .= "<tr".$taskBG."><td>&nbsp;";
            if ($doName) {
            $list .= "&nbsp;&nbsp;&nbsp;".$taskName[$i];
            }
            $list .= "</td><td align=\"center\">".$est[$x]."</td><td> ".$who[$x]." </td><td align=\"center\">".$spent[$x]."</td><td align=\"center\">".$etc[$x]."</td><td nowrap>";
            $list .= $statusLiterals[$taskStat[$i]];
            $list .= "</td></tr>";
            $doName = 0;
        }
        
        }
        
        # Add a spacer if showing tasks
        $list .= "<tr><td colspan=\"6\">&nbsp;</td></tr>";
    }

    # Add to totals
    $totalSpent += $storySpent;
    $totalEtc += $storyEtc;
    $totalEst += $storyCalcEst;
    
    }

    # Do iteration totals

    $list .= "<tr bgcolor=\"#CCCCCC\"><td><b>Team totals</b></td><td></td><td align=\"center\"><b>".$totalEst."</b></td><td align=\"center\"><b>".$totalSpent."</b></td><td align=\"center\"><b>".$totalEtc."</b></td>";

    # refactor this code! (mwatt)
    my $totDone = 0;
    if(($totalSpent + $totalEtc) > 0) {
    $totDone = int(100.0 * $totalSpent / ($totalSpent + $totalEtc));
    }
    my $totLeft = (100 - $totDone);
    my $gaugeTxt = gaugeLite($totDone);
    $list .= "<td>";
    $list .= $gaugeTxt;
    $list .= "</td>";
    $list .= "<td align=right>".$totDone."%</td>";

    my $cfTotEst = 0;
    if($totalEst > 0) {
      $cfTotEst = int(100*(($totalSpent + $totalEtc) / $totalEst) - 100);
    }
    if($cfTotEst >= 0) {
      $list .= "<td align=right> +".$cfTotEst."%</td>";
    } else {
      $list .= "<td align=right> ".$cfTotEst."%</td>";  
    }

    $list .= "<td></td></tr>\n";

    $list .= "</table>\n";


    # dump summary information into a comment for extraction by xpShowTeamIterations
    $list .= "<!--SUMMARY |  ".$totalEst."  |  ".$totalSpent."  |  ".$totalEtc."  |  ".$gaugeTxt."  |  ".$totDone."%  |  ".$cfTotEst."%  | END -->\n";

    # append "create new story" form
    $list .= &xpCreateHtmlForm("NewnameStory", "StoryTemplate", "Create new story in this iteration");

    return $list;
}


###########################
# xpShowAllIterations
#
# Shows all the iterations

sub xpShowAllIterations {

    my ($web) = @_;

    my $list = "<h3>All iterations</h3>\n\n";
    $list .= "| *Project* | *Team* | *Iter* | *Summary* |\n";

    my @projects = &xpGetAllProjects($web);
    foreach my $project (@projects) {

        my @teams = &xpGetProjectTeams($project, $web);
        foreach my $team (@teams){ 

            my @teamIters = &xpGetTeamIterations($team, $web);

            # write out all iterations to table
            foreach my $iter (@teamIters) {
              
                # get additional information from iteration
                my $iterText = &TWiki::Store::readTopic($web, $iter);
                my $summary = &xpGetValueAndRemove("\\*Summary\\*", $iterText);
              
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

    my ($project, $web) = @_;

    my $list = "<h3>All iterations for this project</h3>\n\n";

    $list .= "| *Team* | *Iter* | *Summary* | *Start* | *End* | *Est* | *Spent* | *ToDo* | *Progress* | *Done* | *Overrun* |\n";

    my @projTeams = &xpGetProjectTeams($project, $web);
    foreach my $team (@projTeams){ 
      
        my @teamIters = &xpGetTeamIterations($team, $web);

        # write out all iterations to table
        foreach my $iter (@teamIters) {
          
            # get additional information from iteration
            my $iterText = &TWiki::Store::readTopic($web, $iter);
            my $summary = &xpGetValueAndRemove("\\*Summary\\*", $iterText, "notagsforthis");
            my $start = &xpGetValueAndRemove("\\*Start\\*", $iterText, "notagsforthis");
            my $end = &xpGetValueAndRemove("\\*End\\*", $iterText, "notagsforthis");
            
            $list .= "| ".$team." | ".$iter." | ".$summary." | ".$start." | ".$end." ";
            
            # call xpShowIterationTerse, which internally computes totals for
            # est, spent, todo, overrun etc and places them in an html comment for pickup here :-)
            my $iterSummary = &xpShowIterationTerse($iter, $web);
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

    my ($project, $web) = @_;

    my $listComplete = "<h3>All completed stories for this project</h3>\n\n";
    $listComplete .= "| *Team* | *Iteration* | *Story* | *Summary* | *FEA* | *Completion Date* |\n";

    my $listIncomplete = "<h3>All uncompleted stories for this project</h3>\n\n";
    $listIncomplete .= "| *Team* | *Iteration* | *Story* | *Summary* | *FEA* |\n";


    my @teams = &xpGetProjectTeams($project, $web);
    foreach my $team (@teams){ 
      
        my @teamIters = &xpGetTeamIterations($team, $web);

        # write out all iterations to table
        foreach my $iter (@teamIters) {
              
            # get additional information from iteration
          my $iterText = &TWiki::Store::readTopic($web, $iter);
          my $end = &xpGetValueAndRemove("\\*End\\*", $iterText, "notagsforthis");
          
          my @allStories = &xpGetIterStories($iter, $web);
          
          foreach my $story (@allStories) {
              my $storyText = &TWiki::Store::readTopic($web, $story);
              $targetOrder{$story} = &xpGetValue("\\*Development order\\*", $storyText, "order");
              
              my $storySummary = &xpGetValue("\\*Story summary\\*", $storyText, "notagsforthis");
              my $fea = &xpGetValue("\\*FEA\\*", $storyText, "notagsforthis");
              my $ret = &xpGetValue("\\*Passed acceptance test\\*", $storyText, "complete");            
              my $storyComplete = uc(substr($ret,0,1));
              if ($storyComplete eq "Y") {
                  $listComplete .= "| ".$team." | ".$iter." | ".$story." | ".$storySummary." | ".$fea." | " .$end. "|\n";
                } else {
                    $listIncomplete .= "| ".$team." | ".$iter." | ".$story." | ".$storySummary." | ".$fea. "|\n";
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

    my ($team, $web) = @_;

    my @teamIters = &xpGetTeamIterations($team, $web);

    my $list = "<h3>All iterations for this team</h3>\n\n";

    $list .= "| *Iter* | *Summary* | *Start* | *End* | *Est* | *Spent* | *ToDo* | *Progress* | *Done* | *Overrun* |\n";

    # write out all iterations to table
    foreach my $iter (@teamIters) {

        # get additional information from iteration
        my $iterText = &TWiki::Store::readTopic($web, $iter);
        my $start = &xpGetValueAndRemove("\\*Start\\*", $iterText, "notagsforthis");
        my $end = &xpGetValueAndRemove("\\*End\\*", $iterText, "notagsforthis");
        my $summary = &xpGetValueAndRemove("\\*Summary\\*", $iterText, "notagsforthis");

        $list .= "| ".$iter." | ".$summary." | ".$start." | ".$end." ";

        # call xpShowIterationTerse, which internally computes totals for
        # est, spent, todo, overrun etc and places them in an html comment for pickup here :-)
        my $iterSummary = &xpShowIterationTerse($iter, $web);
        $iterSummary =~ /SUMMARY(.*?)END/s;
        $list .= "$1 \n";

    }

    # append CreateNewIteration form
    $list .= &xpCreateHtmlForm("ItNewname", "IterationTemplate", "Create new iteration for this team");

    return $list;
}


###########################
# xpShowAllTeams
#
# Shows all the teams

sub xpShowAllTeams {

    my ($web) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = "<h3>List of all projects and teams:</h3>\n\n";
    $list .= "| *Project* | *Project Teams* |\n";

    foreach my $project (@projects) {

      my @projTeams = &xpGetProjectTeams($project, $web);
      $list .= "| ".$project." | @projTeams |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm("NewnameProj", "ProjectTemplate", "Create new project");

    return $list;
}

###########################
# xpShowProjectTeams
#
# Shows all the teams on this project

sub xpShowProjectTeams {

    my ($project, $web) = @_;

    my @projTeams = &xpGetProjectTeams($project, $web);

    my $list = "<h3>All teams for this project</h3>\n\n";
    $list .= "| *Teams* |\n";

    # write out all teams
    $list .= "| @projTeams |\n";

    # append CreateNewTeam form
    $list .= &xpCreateHtmlForm("NewnameTeam", "TeamTemplate", "Create new team for this project");

    return $list;
}


###########################
# xpGetWebForm
#
# Make form to create new subtype

sub xpCreateHtmlForm {

    my ($value, $template, $prompt) = @_;
    my $list = "";

    # append form for new page creation
    $list .= "<p>\n";
    $list .= "<form name=\"new\">\n";
    $list .= "<input type=\"text\" name=\"topic\" size=\"30\" />\n";
    $list .= "<input type=\"hidden\" name=\"templatetopic\" value=\"".$template."\" />\n";
    $list .= "<input type=\"hidden\" name=\"parent\" value=\"%TOPIC%\" />\n";
    $list .= "<input type=\"submit\" name =\"xpsave\" value=\"".$prompt."\" />\n";
    $list .= "</form>\n";
    $list .= "\n";

    return $list;
}

###########################
# xpGetProjectTeams
#
# Get all the teams on this project

sub xpGetProjectTeams {

    my ($project, $web) = @_;

    if( $web eq $cachedWebName ) {
        return split( /,/, $cachedProjectTeams{$project} );
    }
}

###########################
# xpShowProjectCompletionByStories
#
# Shows the project completion by release and iteration using stories.

sub xpShowProjectCompletionByStories{

    my ($project, $web) = @_;

    my @projectStories = &xpGetProjectStories($project, $web);

    # Show the list
    my $list = "<h3>Project stories status</h3>\n\n";

    $list .= "| *Iteration* | *Total Stories* | *Not Started* | *In Progress* | *Completed* | *Accepted* | *Percent accepted* |\n";

    # Iterate over each, and build iteration hash
    my ($waiting) = 0;
    my ($progress) = 0;
    my ($complete) = 0;
    my ($accepted) = 0;
    my ($total) = 0;

    my (%master,%progress,%complete,%accepted) = ();

    # initialise hash. There must be a better way! (MWATT)
    foreach my $story (@projectStories) {
        my $storyText = &TWiki::Store::readTopic($web, $story);
        my $iter = &xpGetValue("\\*Iteration\\*", $storyText, "storyiter");
        $waiting{$iter} = 0;
        $progress{$iter} = 0;
        $complete{$iter} = 0;
        $accepted{$iter} = 0;
    }

    foreach my $story (@projectStories) {
    my $storyText = &TWiki::Store::readTopic($web, $story);
    my $iter = &xpGetValue("\\*Iteration\\*", $storyText, "storyiter");
    if ($iter ne "TornUp") {
        $master{$iter}++;
        my $status = &xpGetStoryStatus($storyText);
        if ($status == 0) {
            # all tasks waiting
            $waiting{$iter}++;
            $waiting++;
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
        my $iterText = &TWiki::Store::readTopic($web, $iteration);
        $iterText =~ /\<!--START *(.*?) *--\>/s;
        $iterKeys{$iteration} = $1;
    }

    # OK, display them
    foreach my $iteration (sort { $iterKeys{$a} <=> $iterKeys{$b} } keys %master) {
    my $pctAccepted = 0;
    if ($accepted{$iteration} > 0) {
        $pctAccepted = sprintf("%u",($accepted{$iteration}/$master{$iteration})*100);
    }
    $list .= "| ".$iteration."  |  ".$master{$iteration}."  |  ".$waiting{$iteration}."  |  ".$progress{$iteration}."  |  ".$complete{$iteration}."  |  ".$accepted{$iteration}."  |  ".$pctAccepted."\%  | \n";
    }
    my $pctAccepted = 0;
    if ($accepted > 0) {
    $pctAccepted = sprintf("%u",($accepted/$total)*100);
    }
    $list .= "| Totals  |  ".$total."  |  ".$waiting."  |  ".$progress."  |  ".$complete."  |  ".$accepted."  |  ".$pctAccepted."%  |\n";

    return $list;
}

###########################
# xpShowProjectCompletionByTasks
#
# Shows the project completion using tasks.

sub xpShowProjectCompletionByTasks {

    my ($project, $web) = @_;

    my @projectStories = &xpGetProjectStories($project, $web);

    # Show the list
    my $list = "<h3>Project tasks status</h3>\n\n";
    $list .= "| *Iteration* |  *Total tasks* | *Not Started* | *In progress* | *Complete* | *Percent complete* |\n";

    # Iterate over each, and build iteration hash
    my ($waiting) = 0;
    my ($progress) = 0;
    my ($complete) = 0;
    my ($total) = 0;
    my (%master,%waiting,%progress,%complete) = ();

    # initialise hash. There must be a better way! (mwatt)
    foreach my $story (@projectStories) {
    my $storyText = &TWiki::Store::readTopic($web, $story);
    my $iter = &xpGetValue("\\*Iteration\\*", $storyText, "storyiter");
    $waiting{$iter} = 0;
    $progress{$iter} = 0;
    $complete{$iter} = 0;
    }

    foreach my $story (@projectStories) {
    my $storyText = &TWiki::Store::readTopic($web, $story);
    my $iter = &xpGetValue("\\*Iteration\\*", $storyText, "storyiter");
    if ($iter ne "TornUp") {
        while (1) {
        (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $taskStatus) = xpGetNextTask($storyText);
        if (!$status) {
            last;
        }
        $master{$iter}++;
        if ($taskStatus == 0) {
            $waiting{$iter}++;
            $waiting++;
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
        my $iterText = &TWiki::Store::readTopic($web, $iteration);
        $iterText =~ /\<!--START *(.*?) *--\>/s;
        $iterKeys{$iteration} = $1;
    }

    # OK, display them
    foreach my $iteration (sort { $iterKeys{$a} <=> $iterKeys{$b} } keys %master) {
    my $pctComplete = 0;
    if ($complete{$iteration} > 0) {
        $pctComplete = sprintf("%u",($complete{$iteration}/$master{$iteration})*100);
    }
    $list .= "| ".$iteration."  |  ".$master{$iteration}."  |  ".$waiting{$iteration}."  |   ".$progress{$iteration}."  |  ".$complete{$iteration}."  |  ".$pctComplete."\%  |\n";
    }
    my $pctComplete = 0;
    if ($complete > 0) {
    $pctComplete = sprintf("%u",($complete/$total)*100);
    }
    $list .= "| Totals |  ".$total."  |  ".$waiting."  |  ".$progress."  |  ".$complete."  |  ".$pctComplete."%  |";

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
    if (@who == 0) {
    return 0; # nobody assigned, not started
    }
    foreach my $who (@who) {
    if ($who eq "?") {
        return 0; # not assigned correctly, not started
    }
    }

    # someone is assigned, see if ANY time remaining
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
# xpShowVelocities
#
# Shows velocities of resources in an iteration.

sub xpShowVelocities {
    my ($iteration,$web) = @_;

    my @allStories = &xpGetIterStories($iteration, $web);

    # title
    my $list = "<h3>Developer velocity</h3>\n";

    # Show the list
    $list .= "<table border=\"1\"><tr bgcolor=\"#CCCCCC\"><th rowspan=\"2\">Who</th><th colspan=\"3\">Ideals</th><th colspan=\"2\">Tasks</th></tr><tr bgcolor=\"#CCCCCC\"><th>Assigned</th><th>Spent</th><th>Remaining</th><th>Assigned</th><th>Remaining</th></tr>";

    # Iterate over each story
    my (%whoAssigned,%whoSpent,%whoEtc,%whoTAssigned,%whoTRemaining) = ();
    my ($totalSpent,$totalEtc,$totalAssigned,$totalVelocity,$totalTAssigned) = 0;
    foreach my $story (@allStories) {
    my $storyText = &TWiki::Store::readTopic($web, $story);
    if(&xpGetValue("\\*Iteration\\*", $storyText, "storyiter") eq $iteration) {
        while (1) {
        (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $taskStatus) = xpGetNextTask($storyText);
        if (!$status) {
            last;
        }
        my @who = xpRipWords($taskWho);
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
    
    # Show them
    foreach my $who (sort { $whoEtc{$b} <=> $whoEtc{$a} } keys %whoSpent) {
    $list .= "<tr><td> ".$who." </td><td align=\"center\">".$whoAssigned{$who}."</td><td align=\"center\">".$whoSpent{$who}."</td><td align=\"center\">".$whoEtc{$who}."</td><td align=\"center\">".$whoTAssigned{$who}."</td><td align=\"center\">".$whoTRemaining{$who}."</td></tr>";
    }
    $list .= "<tr bgcolor=\"#CCCCCC\"><th align=\"left\">Total</th><th>".$totalAssigned."</th><th>".$totalSpent."</th><th>".$totalEtc."</th><th>".$totalTAssigned."</th><th>".$totalTRemaining."</th></tr>";

    # Close it off
    $list .= "</table>";

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
    opendir(WEB,$TWiki::dataDir."/".$web);
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

    if( $web eq $cachedWebName ) {
        return split( /,/, $cachedIterationStories{$iteration} );

    }
}

###########################
# xpGetStoryStatus
#
# Returns the status of a story

sub xpGetStoryStatus {
    my $storyText = $_[0];

    my @taskStatus = ();

    # Get acceptance test status
    my $storyComplete = "N";
    my $ret = &xpGetValue("\\*Passed acceptance test\\*", $storyText, "complete");
    if($ret) {
      $storyComplete = uc(substr($ret,0,1));
    }

    # Run through tasks and get their status
    while (1) {
    (my $status,my $taskName,my $taskEst,my $taskWho,my $taskSpent,my $taskEtc,my $tStatus) = xpGetNextTask($storyText);
    if (!$status) {
        last;
    }
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
    if ($word ne "") {
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

sub xpGetNextTask {

    # use reference to text to avoid large copy
    #my $storyText = $_[0];

    my ($taskName, $taskEst, $taskWho, $taskSpent, $taskEtc, $taskStatus)="";

    # first look for new-style task (horizontally laid out)
    if ($_[0] =~ s/(\|[ \t]*Task[ \t]*\|.*\n)//) { # get to eol, so no newline in search
      my @fields = split /[ \t]*\|[ \t]*/, $1; # split by "|", allowing surrounding whitespace and tab too

      $taskName = $fields[8];
      $taskEst = $fields[2];
      $taskWho = $fields[7];
      $taskSpent = $fields[3];
      $taskEtc = $fields[4];

    } else {
      $taskName = &xpGetValueAndRemove("\\*Task name\\*", $_[0], "taskname");
      if(! $taskName) {
    return 0;
      }
      
      $taskEst = &xpGetValueAndRemove("\\*Original estimate\\*", $_[0], "est");
      $taskWho = &xpGetValueAndRemove("\\*Assigned to\\*", $_[0], "who");
      $taskSpent = &xpGetValueAndRemove("\\*Time spent\\*", $_[0], "spent");
      $taskEtc = &xpGetValueAndRemove("\\*Est\\. time to go\\*", $_[0], "etc");
    }

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
    my $storyText = &TWiki::Store::readTopic($web, $story);      

    # search for text matching a developer
    my $ret = "";
    while ($ret = &xpGetValueAndRemove("\\*Assigned to\\*", $storyText, "who")) {
        push @dev, $ret;
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

    if( $web eq $cachedWebName ) {
        return split( /,/, $cachedTeamIterations{$team} );
    }
}

###########################
# xpShowAllProjects
#
# Shows all the projects on this web

sub xpShowAllProjects {

    my ($web) = @_;

    my @projects = &xpGetAllProjects($web);

    my $list = "<h3>All projects</h3>\n\n";
    $list .= "| *Project* |\n";

    # write out all iterations to table
    foreach my $project (@projects) {
      $list .= "| $project |\n";
    }

    # append form to allow creation of new projects
    $list .= &xpCreateHtmlForm("NewnameProj", "ProjectTemplate", "Create new project");

    return $list;
}

###########################
# xpGetAllProjects
#
# Get all the projects for the web

sub xpGetAllProjects {

    my ($web) = @_;

    if( $web eq $cachedWebName ) {
        return keys %cachedProjectTeams;
    }
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

    $cachedWebName = "";
    # Put the return in here, and suddenly, no cacheing.
    # return;

    $cachedWebName = $web;

    # Get all the stories and their iterations:
    my @stories = &xpGetAllStories( $web );
    foreach $eachS ( @stories ) {
        my $storyText = &TWiki::Store::readTopic($web, $eachS);

        # To go from iteration -> story (multiple values)
        my $iter = &xpGetValue("\\*Iteration\\*", $storyText, "storyiter");
        $cachedIterationStories{$iter} .= "$eachS,";
    }

    foreach $eachI (keys %cachedIterationStories) {
        my $iterText = &TWiki::Store::readTopic($web, $eachI);

        # To go from team -> iteration (multiple values)
        my $team = &xpGetValue("\\*Team\\*", $iterText, "notagsforthis");
        $cachedTeamIterations{$team} .= "$eachI,";

    }

    foreach $eachT (keys %cachedTeamIterations) {
        my $teamText = &TWiki::Store::readTopic($web, $eachT);

        # To go from project -> team (multiple values)
        my $project = &xpGetValue("\\*Project\\*", $teamText, "notagsforthis");
        $cachedProjectTeams{$project} .= "$eachT,";
    }
}

sub xpSavePage()
{
    my ( $web ) = @_;

    # check the user has entered a non-null string
    my $title = $query->param( 'topic' );
    if($title eq "") {
        TWiki::redirect( $query, &TWiki::getViewUrl( "", "NewPageError" ) );
        return;
    }

    # check topic does not already exist
    if(TWiki::Func::topicExists($web, $title)) {
        TWiki::redirect( $query, &TWiki::getViewUrl( "", "NewPageError" ) );
        return;
    }

    # check the user has entered a WIKI name
    if(!TWiki::isWikiName($title)) {
        TWiki::redirect( $query, &TWiki::getViewUrl( "", "NewPageError" ) );
        return;
    }

    # if creating a story, check name ends in *Story
    my $template = $query->param( 'templatetopic' );
    if($template eq "StoryTemplate") {
        if(!($title =~ /^[\w]*Story$/)) {
            TWiki::redirect( $query, &TWiki::getViewUrl( "", "NewPageError" ) );
            return;
        }
    }

    # load template for page type requested
    my( $meta, $text ) = &TWiki::Store::readTopic( $web, $template );

    # write parent name into page
    my $parent = $query->param( 'parent' );
    $text =~ s/XPPARENTPAGE/$parent/geo;

    # save new page and open in browser
    my $error = &TWiki::Store::saveTopic( $web, $title, $text, $meta );
    TWiki::redirect( $query, &TWiki::getViewUrl( "", $topic ) );
    
    &TWiki::Store::lockTopic( $theTopic, "on" );
    if( $error ) {
        $url = &TWiki::Func::getOopsUrl( $theWeb, $theTopic, "oopssaveerr", $error );
        TWiki::redirect( $query, $url );
    }
}

###########################
# xpShowColours
#
# Service method to show current background colours

sub xpShowColours {

    my ($web) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::XpTrackerPlugin::xpShowColours( $web ) is OK" ) if $debug;

    my $table = "%TABLE{initsort=\"1\"}%\n";
    $table .= "|*name*|*colour*|\n";
    my ($key, $value);
    while (($key, $value) = each(%defaults)) {
    # read colours and put them in table
    $table .= "|$key| <table width=\"100%\"><tr><td bgcolor=\"$value\">$value</td></tr></table>|\n";
    }
    return $table;
}


# =========================

1;
