# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 Meredith Lesly <msnomer@spamcop.net>
# Based in large part on ApprovalPlugin by Thomas Hartkens <thomas@hartkens.de>
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

# =========================
package TWiki::Plugins::WorkflowPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use TWiki::Contrib::FuncUsersContrib;

# =========================
# Standard variables
# $VERSION is the only global variable that *must* exist in this package
#
use vars qw(  $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'WorkflowPlugin';  # Name of this Plugin

use vars qw( 
	    $MODERN
	    $cairoCalled
	    );
use vars qw( 
	    $web
	    $topic
	    $user
            $workflowTopic
            $canDoWorkflow
            $globWorkflow
            $globWebName
            $theCurrentState
            $globWorkflowMessage $globAllowEdit
            $CalledByMyself 
	    %allGroups
            %globPreferences
	    @processedGroups
           );


# =========================
# This is called once per page view (not for %includes!!)
#
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ($TWiki::Plugins::VERSION < 1.021) {
        TWiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    if( defined( &TWiki::Func::normalizeWebTopicName )) {
        $MODERN = 1;
    } else {
	# SMELL: nasty global var needed for Cairo
	$cairoCalled = 0;
    }

    $debug = TWiki::Func::getPreferencesFlag("debug");

    $globWebName = $web;

    $workflowTopic = getWorkflowTopic($web, $topic);

    TWiki::Func::writeDebug(" workflow topic is $workflowTopic") if $debug;

    TWiki::Func::writeDebug(" $pluginName - initPlugin ") if $debug;

    #
    # We can do workflow for this topic iff there's a workflow topic named
    # and if the topic exists.
    #
    $canDoWorkflow = $workflowTopic && TWiki::Func::topicExists($globWebName, $workflowTopic);

    if (usesWorkflow()) {
	($globWorkflow, $theCurrentState, $globWorkflowMessage, $globAllowEdit) = 
	    parseWorkflow($workflowTopic, $user, $theCurrentState);

	TWiki::Func::registerTagHandler("WORKFLOW", \&_WORKFLOW);
	TWiki::Func::registerTagHandler("WORKFLOWNAME", \&_WORKFLOWNAME);
	TWiki::Func::registerTagHandler("WORKFLOWSTATEMESSAGE", \&_WORKFLOWSTATEMESSAGE);
	TWiki::Func::registerTagHandler("WORKFLOWTRANSITION", \&_WORKFLOWTRANSITION);
	TWiki::Func::registerTagHandler("WORKFLOWEDITTOPIC", \&_WORKFLOWEDITTOPIC);
    }
    return 1;
}

#
# $session - a reference to the TWiki session object (may be ignored)
# %params - a reference to a TWiki::Attrs object containing parameters.
# $topic - name of the topic in the query
# $web - name of the web in the query
sub _WORKFLOWNAME {
    return 
}

#
# $session - a reference to the TWiki session object (may be ignored)
# %params - a reference to a TWiki::Attrs object containing parameters.
# $topic - name of the topic in the query
# $web - name of the web in the query
sub _WORKFLOW {
    my ($session, $params, $topic, $web) = @_;
    $debug = 1;

    my $action = $params->{'wfpaction'};
    my $state = $params->{'wfpstate'};

    my $query = TWiki::Func::getCgiQuery();
    if ($query) {
	TWiki::Func::writeDebug("- got query ");

	$action = $query->param('wfpaction');
	$state = $query->param('wfpstate');
    }

    TWiki::Func::writeDebug("_WORKFLOW ") if $debug;
    TWiki::Func::writeDebug("- action is $action, state is $state");

    if ($action) {
        # find out if the user is allowed to perform the action 
        if (($state eq $theCurrentState->{state}) && defined($$globWorkflow{$action})) {
	    #TWiki::Func::writeDebug("Changing state") if $debug;

            # store new status as meta data
            changeWorkflowState($web, $topic, $$globWorkflow{$action});

	    TWiki::Func::writeDebug("After changeWorkflowState") if $debug;

            ($globWorkflow, $theCurrentState, $globWorkflowMessage, $globAllowEdit) = 
		parseWorkflow($workflowTopic, $user, $theCurrentState);
	    TWiki::Func::redirectCgiQuery("", TWiki::Func::getViewUrl($web, $topic));
	}

    }
    return "";
}

sub _WORKFLOWSTATEMESSAGE {
    #my ($session, $params, $topic, $web) = @_;
    return $globWorkflowMessage;
}

sub _WORKFLOWTRANSITION {
    my ($session, $params, $topic, $web) = @_;
    #
    # Build the button to change the current status
    #
    my @actions = keys(%{$globWorkflow});
    return genHTML($web, $topic, @actions);
}

sub _WORKFLOWEDITTOPIC {
    #my ($session, $params, $topic, $web) = @_;

    # replace edit tag if necessary
    if ($globAllowEdit) {
	return "<a href=\"%EDITURL%\"><b>Edit</b></a>";
    } else {
	return "<strike>Edit<\/strike>";
    }
}

sub getWorkflowTopic {
    my( $web, $topic ) = @_;
    my $wft;

    my( $meta, $text ) = TWiki::Func::readTopic($web, $topic);

    if ($theCurrentState = $meta->get('WORKFLOW')) {
	return $theCurrentState->{'workflow'};
    } 

    $wft = getWorkflowFromCGI();
    $wft ||= TWiki::Contrib::FuncUsersContrib->getTopicPreferenceValue($web, $topic, "WORKFLOW");
    my $prefHash = $meta->get('PREFERENCE', "WORKFLOW");
    $wft ||= $prefHash->{value};

    if ($wft) {
	$meta->put("WORKFLOW", { 'workflow' => $wft } );
	return $wft;
    }
    return 0;
}

sub getWorkflowFromCGI {
    if (my $query = TWiki::Func::getCgiQuery()) {
	if (my $workflow = $query->param('workflow')) {
	    return $workflow;
	}
    }
    return 0;
}


# =========================
sub beforeEditHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::beforeEditHandler( $_[2].$_[1] )") if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.

    if (usesWorkflow()) {
        if (!$globAllowEdit) {
            my $url = TWiki::Func::getOopsUrl($web, $topic, "oopsaccesschanged");
            TWiki::Func::redirectCgiQuery(undef, $url);
            return 0;
        }
    }
}

# =========================

sub genHTML {
    my ( $web, $topic, @actions ) = @_;
    
    my $numberOfActions = scalar(@actions);
    my $button;
    my $url = TWiki::Func::getViewUrl($web, $topic);

    if ($numberOfActions == 0) {
	return "";
    }

    #if ($numberOfActions == 1) {
#	$button = '<table><tr><td><div class="twikiChangeFormButton twikiSubmit ">'.
#	    ' <a href="'.$url.'?WORKFLOWACTION='.$actions[0].
#	    '&WORKFLOWSTATE='.$theCurrentState->{state}.'">'.$actions[0].'</a>'.
#	    '</div></td></tr></table>';
#    
#    } else {

	my $select="";
	foreach my $key (@actions) {
	    $select .= "<option value='$key'> $key </option>";
	}
	$button = "<form method=post action='$url'>".
	    "<input type='hidden' name='wfpstate' value='$theCurrentState->{state}'>\n".
	    "<select name='wfpaction'>$select</select> \n".
	    "<input type='submit' value='Change status' class='twikiChangeFormButton twikiSubmit '/>".
	    "</form>";
#    }
    return $button;
} 

sub usesWorkflow {
    return $canDoWorkflow;
}

sub Timestamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
      = localtime(time);
    return sprintf("%d-%02d-%02d %02d:%02d:%02d", 
                   1900+$year, $mon, $mday, $hour, $min, $sec);
}

sub changeWorkflowState {
    my ($web, $topic, $state) = @_;

    TWiki::Func::writeDebug(" web: $web, topic: $topic, state: $state") if $debug;
    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );
    $text = TWiki::Func::expandVariablesOnTopicCreation( $text );
    my ($dat, $author, $version, $comment) = $meta->getRevisionInfo();

    TWiki::Func::writeDebug("changeWorkflowState from $theCurrentState->{state} to $state") if $debug;

    $theCurrentState->{state} = $state;
    $theCurrentState->{"LASTVERSION_$state"} = "1.$version";
    $theCurrentState->{"LASTTIME_$state"} = Timestamp();

    $meta->remove( "WORKFLOW" );
    $meta->put("WORKFLOW", { state => $state, workflow => $theCurrentState->{workflow} });

    $meta->remove("WORKFLOWSTATE", $state);
    $meta->put("WORKFLOWSTATE", { name => $state, lasttime => Timestamp(), version => "1.$version" });

    my $unlock = 1;
    my $dontNotify = 1;
    $CalledByMyself = 1;
    my $error = TWiki::Func::saveTopic( $web, $topic, $meta, $text,
                                        { minor => $dontNotify } );
    if( $error ) {
        my $url = TWiki::Func::oops( $web, $topic, "saveerr", $error );
        TWiki::Func::redirectCgiQuery(undef, $url);
        return 0;
    }
}


sub myDebug {
    my $text = shift;
    TWiki::Func::writeDebug("- ${pluginName}: $text" ) if $debug;
}

#
# return a hash table representing the actions allowed by
# the current user. The hash-key is the possible action
# while the value is the next state.
#
sub parseWorkflow {
    my ($WorkflowTopic, $user, $CurrentState) = @_;
    my %workflow = ();
    my $WorkflowMessage = "";
    my $AllowEdit = 0;

    # take care that $CurrentState is a HASH table
    $CurrentState = { workflow => $workflowTopic } unless defined($CurrentState);

    # the default state is the first row in the state table
    my $defaultState;
    my $CurrentStateIsValid = 0;

    # Read topic that defines the statemachine
    if (TWiki::Func::topicExists($globWebName, $WorkflowTopic)) {
        my ($meta, $text) = TWiki::Func::readTopic( $globWebName, $WorkflowTopic );
	$text = TWiki::Func::expandCommonVariables($text, $WorkflowTopic);

        my $inBlock = 0;
        # | *Current form* | *Next form* | *Next state* | *Action* |
        foreach (split( /\n/, $text)) {
            if (/^\s*\|.*State[^|]*\|.*Action[^|]*\|.*Next State[^|]*\|.*Allowed[^|]*\|/) {
                # from now on, we are in the TRANSITION table
                $inBlock = 1;
            } elsif ( /^\s*\|.*State[^|]*\|.*Allow Edit[^|]*\|.*Message[^|]*\|/ ) {
                # from now on, we are in the STATE table
                $inBlock = 2;
            } elsif ( /^(\t+\*\sSet\s)([A-Za-z]+)(\s\=\s*)(.*)$/ ) {
                # store preferences
                $globPreferences{$2}=$4;
            } elsif (($inBlock == 1) && s/^\s*\|//o) {
                # read row in TRANSITION table
                my ($state, $action, $next, $allowed) = split(/\s*\|\s*/);
                $state = _cleanField($state);
                if (userIsAllowed($user, $allowed) && ($state eq $CurrentState->{state})) { 
                    # store the transition in user's workflow 
		    $debug = 0;
		    myDebug("TRANS: '$next'");
		    $debug = 0;
                    $workflow{$action} = $next;
                }
            } elsif( ($inBlock == 2) && s/^\s*\|//o ) {
                # read row in STATE table
                my( $state, $allowedit, $message) = split( /\s*\|\s*/ );
                $state = _cleanField($state);
                myDebug("STATE: '$state', $allowedit, $message  CurrentState: '$CurrentState->{state}'");

                # the first state in the table defines the default state
                if (!defined($defaultState)) {
                    $defaultState=$state;
                    $CurrentState->{state} = $state unless defined($CurrentState->{state});
                }
                if ($state eq $CurrentState->{state}) {
                    $CurrentStateIsValid=1;
                    $WorkflowMessage=$message;
                    if (userIsAllowed($user, $allowedit)) { 
                        $AllowEdit = 1;
                    }
                }
            } else {
                $inBlock = 0;
            }
        }

        # we need to treat the case that the workflow states have changed and that the 
        # status written in the document is not valid anymore. In this case we go back to 
        # the default status!
        if (!$CurrentStateIsValid && defined($defaultState)) {
            $CurrentState->{state}=$defaultState;
            return parseWorkflow($WorkflowTopic, $user, $CurrentState);
        }
    } else {
        # FIXME - do what if there is an error?
    }

    return ( \%workflow, $CurrentState, $WorkflowMessage, $AllowEdit );
}

# finds out if the user $user is allowed to do something
sub userIsAllowed {
    my ($user, $allow) = @_;

    my $mainWeb  = TWiki::Func::getMainWebname();

    # Always allow members of the admin group to edit
    if (userIsAdmin($user)) {
	return 1;
    }

    if ($allow) {
	TWiki::Func::writeDebug("Allow: $allow") if $debug;
        my @allowed = split(/\s*\,\s*/, $allow);
        #my $wikiName = TWiki::Func::userToWikiName( $user, 1 );  # i.e. "JonDoe"

        foreach my $name (@allowed) {
            $name = _cleanField( $name );
            $name =~ s/$mainWeb\.(.*)/$1/;
	    #TWiki::Func::writeDebug("wikiName: $wikiName;  Name: $name");
	    #TWiki::Func::writeDebug("Checking if user is in $name");
	    if (TWiki::Contrib::FuncUsersContrib::isInGroup($name)) {
		#TWiki::Func::writeDebug("User is allowed");

            #if (userIsInGroup($wikiName, $name) || userIsAdmin($wikiName)) {
                # user IS allowed!
                return 1;
            }
        }
    } else {
        # user IS allowed!
	return 1;
    }
    # user IS NOT allowed!
    return 0;
}

sub _cleanField {
    my( $text ) = @_;
    $text = "" if( ! $text );
    $text =~ s/^\s*//go;
    $text =~ s/\s*$//go;
    $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
    return $text;
}

sub getWebTopicName {
    my( $theWebName, $theTopicName ) = @_;
    $theTopicName =~ s/%MAINWEB%/$theWebName/go;
    $theTopicName =~ s/%TWIKIWEB%/$theWebName/go;
    if( $theTopicName =~ /[\.]/ ) {
        $theWebName = "";  # to suppress warning
    } else {
        $theTopicName = "$theWebName\.$theTopicName";
    }
    return $theTopicName;
}

sub userIsAdmin {
    my $wikiName = shift;
    return userIsInGroup($wikiName, 'TWikiAdminGroup');
}

sub userIsInGroup {
    my( $theUserName, $theGroupTopicName ) = @_;
    my $mainWeb = TWiki::Func::getMainWebname();
    
    my $usrTopic = getWebTopicName( $mainWeb, $theUserName );
    my $grpTopic = getWebTopicName( $mainWeb, $theGroupTopicName );
    my @grpMembers = ();

    if( $grpTopic !~ /.*Group$/ ) {
        # not a group, so compare user to user
        push( @grpMembers, $grpTopic );
    } elsif( ( %allGroups ) && ( exists $allGroups{ $grpTopic } ) ) {
        # group is allready known
        @grpMembers = @{ $allGroups{ $grpTopic } };
    } else {
        @grpMembers = getGroup( $grpTopic, 1 );
    }

    #TWiki::Func::writeDebug("grpMembers: @grpMembers");
    #TWiki::Func::writeDebug("usrTopic: $usrTopic");

    my $isInGroup = grep { /^$usrTopic$/ } @grpMembers;
    return $isInGroup;
}

sub getGroup {
    my( $theGroupTopicName, $theFirstCall ) = @_;

    my @resultList = ();
    # extract web and topic name
    my $topic = $theGroupTopicName;
    my $web = TWiki::Func::getMainWebname();
    $topic =~ /^([^\.]*)\.(.*)$/;
    if( $2 ) {
        $web = $1;
        $topic = $2;
    }
    ##TWiki::writeDebug( "Web is $web, topic is $topic" );

    if( $topic !~ /.*Group$/ ) {
        # return user, is not a group
        return ( "$web.$topic" );
    }

    # check if group topic is already processed
    if( $theFirstCall ) {
        # FIXME: Get rid of this global variable
        @processedGroups = ();
    } elsif( grep { /^$web\.$topic$/ } @processedGroups ) {
        # do nothing, already processed
        return ();
    }
    push( @processedGroups, "$web\.$topic" );

    # read topic
    my ($meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    # reset variables, defensive coding needed for recursion
    (my $baz = "foo") =~ s/foo//;

    # extract users
    my $user = "";
    my @glist = ();
    foreach( split( /\n/, $text ) ) {
        if( /^\s+\*\sSet\sGROUP\s*\=\s*(.*)/ ) {
            if( $1 ) {
                my $theItems = $1;
                $theItems =~ s/\s*([a-zA-Z0-9_\.\,\s\%]*)\s*(.*)/$1/go; # Limit list
                @glist = map { getWebTopicName( TWiki::Func::getMainWebname(), $_ ) }
                  split( /[\,\s]+/, $theItems );
            }
        }
    }
    foreach( @glist ) {
        if( /.*Group$/ ) {
            # $user is actually a group
            my $group = $_;
            if( ( %allGroups ) && ( exists $allGroups{ $group } ) ) {
                # allready known, so add to list
                push( @resultList, @{ $allGroups{ $group } } );
            } else {
                # call recursively
                my @userList = getGroup( $group, 0 );
                # add group to allGroups hash
                $allGroups{ $group } = [ @userList ];
                push( @resultList, @userList );
            }
        } else {
            # add user to list
            push( @resultList, $_ );
        }
    }

    return @resultList;
}
1;
