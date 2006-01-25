# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
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
package TWiki::Plugins::ApprovalPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
            $web $topic $user $installWeb $VERSION $RELEASE $pluginName
            $debug 
            $prefApprovalWorkflow
            $prefNeedsApproval
            $globWorkflow
            $globWebName
            $globCurrentState
            $globApprovalMessage $globAllowEdit
            $CalledByMyself 
            %globPreferences
           );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ApprovalPlugin';  # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
    $debug =1;

    $globWebName=$web;

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    #    $prefApprovalWorkflow = TWiki::Func::getPluginPreferencesValue( "APPROVALWORKFLOW" ) || "Lopt nicht";
    if (($prefApprovalWorkflow = TWiki::Func::getPreferencesValue( "APPROVALWORKFLOW" )) &&
          &TWiki::Func::topicExists( $globWebName, $prefApprovalWorkflow)) {

        # get preferences
        $prefNeedsApproval=1;

        $globCurrentState=getApprovalState($meta);
        Debug("initPlugin State in the document: '$globCurrentState'");
        ($globWorkflow, $globCurrentState, $globApprovalMessage, $globAllowEdit) = 
          parseApprovalWorkflow($prefApprovalWorkflow,$user,$globCurrentState);

    } else {
        $prefNeedsApproval=0;
    }

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    if (NeedsApproval() && (my $query = TWiki::Func::getCgiQuery())) {
        my $action = $query->param( 'APPROVALACTION' );
        my $state = $query->param( 'APPROVALSTATE' );

        # find out if the user is allowed to perform the action 
        if ($action && ($state eq $globCurrentState->{state}) && defined($$globWorkflow{$action})) {
            # store new status as meta data
            changeApprovalState($$globWorkflow{$action});

            # we need to parse the workflow again since the state of the document has
            # changed which will effect the actions the user can do now. 
            ($globWorkflow, $globCurrentState, $globApprovalMessage, $globAllowEdit) = 
              parseApprovalWorkflow($prefApprovalWorkflow,$user,$globCurrentState);
        }

        # replace edit tag
        if ($globAllowEdit) {
            $_[0] =~ s!%APPROVALEDITTOPIC%!<a href=\"%EDITURL%\"><b>Edit</b></a>!g;
        } else {
            $_[0] =~ s!%APPROVALEDITTOPIC%! <strike>Edit<\/strike> !g;
        }


        # show all tags defined by the preferences
        foreach my $key (keys %globPreferences) {
            if ($key =~ /^APPROVAL/) {
                $_[0] =~ s!%$key%!$globPreferences{$key}!g;
            }
        }

        # show last version tags
        foreach my $key (keys %{$globCurrentState}) {
            if ($key =~ /^LASTVERSION_/) {
                my $url = TWiki::Func::getScriptUrl( $web,$topic,"view" );
                my $foo = "<a href='$url'?rev=".$globCurrentState->{$key}.">revision ".
                  $globCurrentState->{$key}."</a>";
                $_[0] =~ s!%APPROVAL$key%!$foo!g;
            }
        }

        # show last time tags
        foreach my $key (keys %{$globCurrentState}) {
            if ($key =~ /^LASTTIME_/) {
                $_[0] =~ s!%APPROVAL$key%!$globCurrentState->{$key}!g;
            }
        }

        # display the message for current status
        $_[0] =~ s!%APPROVALSTATEMESSAGE%!$globApprovalMessage!g;

        #
        # Build the button to change the current status
        #
        my @actions = keys(%{$globWorkflow});
        my $NumberOfActions = scalar(@actions);
        if ($NumberOfActions > 0) {
            my $button;
            my $url = TWiki::Func::getScriptUrl( $web,$topic,"view" );

            if ($NumberOfActions == 1) {
                $button = '<table><tr><td><div class="twikiChangeFormButton twikiSubmit ">'.
                  ' <a href="'.$url.'?APPROVALACTION='.$actions[0].
                    '&APPROVALSTATE='.$globCurrentState->{state}.'">'.$actions[0].'</a>'.
                      '</div></td></tr></table>';
                #		  $button = ' <a href="'.$url.'?APPROVALACTION='.$actions[0].
                #		      '&APPROVALSTATE='.$globCurrentState->{state}.' class="twikiChangeFormButton twikiSubmit ">'.
                #		      $actions[0].'</a>';
            } else {
                my $select="";
                foreach my $key (@actions) {
                    $select .= "<option value='$key'> $key </option>";
                }
                $button = "<FORM METHOD=POST ACTION='$url'>".
                  "<input type='hidden' name='APPROVALSTATE' value='$globCurrentState->{state}'>".
                    "<select name='APPROVALACTION'>$select</select> ".
                      "<input type='submit' value='Change status' class='twikiChangeFormButton twikiSubmit '/>".
                        "</FORM>";
            }

            # build the final form
            #	      my $form = '<div style="text-align:right;">'.
            #		  '<table width="100%" border="0" cellspacing="0" cellpadding="0" class="twikiChangeFormButtonHolder">'.
            #		  '<tr>'.
            #		  "<td align='right'>".$globPreferences{"TEXTBEFORECHANGEBUTTON"}." &nbsp; </td>".
            #		  '<td align="right"> '.$button .' </td></tr></table></div>';
            $_[0] =~ s!%APPROVALTRANSITION%!$button!g;
        }

    } else {
        $_[0] =~ s!%APPROVALEDITTOPIC%!<a href=\"%EDITURL%\"><b>Edit</b></a>!g;
    }

    # delete all tags which start with the word APPROVAL
    $_[0] =~ s!%APPROVAL([a-zA-Z_]*)%!!g;

    #	  $_[0] =~ s!%APPROVALMESSAGE%!This document needs approval ($prefApprovalWorkflow)!g;
}


# =========================
sub beforeEditHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.

    if (NeedsApproval()) {
        if (! $globAllowEdit) {
            my $url = TWiki::Func::getOopsUrl($web, $topic, "accesschange");
            TWiki::Func::redirectCgiQuery(undef, $url);
            return 0;
        }
    }
}

# =========================
sub beforeSaveHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.

    if (NeedsApproval()) {
        Debug("---------- beforeSaveHandler");
        if (! $globAllowEdit && !$CalledByMyself) {
            my $url = TWiki::Func::getOopsUrl($web, $topic, "accesschange");
            TWiki::Func::redirectCgiQuery(undef, $url);
            return 0;
	    }
    }
}


# =========================


sub NeedsApproval {
    return $prefNeedsApproval;
}

sub DocumentIsApproved {
    return ($globCurrentState eq "approved");
}

sub Timestamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
      = localtime(time);
    return sprintf("%d-%02d-%02d %02d:%02d:%02d", 
                   1900+$year, $mon, $mday, $hour, $min, $sec);
}

sub changeApprovalState {
    my $state = shift;

    my ($meta, $text) = &TWiki::Func::readTopic( $web, $topic );
    $text = TWiki::Func::expandVariablesOnTopicCreation( $text );
    $version = $meta->getRevision();

    Debug("changeApprovalState from $globCurrentState->{state} to $state");

    $globCurrentState->{state}=$state;
    $globCurrentState->{"LASTVERSION_$state"}="1.$version";
    $globCurrentState->{"LASTTIME_$state"} = Timestamp();

    $meta->remove( "APPROVAL" );
    $meta->put( "APPROVAL", %{$globCurrentState});

    my $unlock=1;
    my $dontNotify=1;
    $CalledByMyself=1;
    my $error = TWiki::Func::saveTopic( $web, $topic, $meta, $text,
                                        { minor => $dontNotify } );
    if( $error ) {
        my $url = TWiki::Func::oops( $web, $topic, "saveerr", $error );
        TWiki::Func::redirectCgiQuery(undef, $url);
        return 0;
    }
}

sub getApprovalState {
    my $meta = shift;
    if (my $foo = $meta->{"APPROVAL"} ) {
        return $foo->[0] if defined($foo->[0]);
    }
    return undef;
}

sub Debug {
    my $text = shift;
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}
#
# return a hash table representing the actions alowed by
# the current user. The hash-key is the possible action
# while the value is the next state.
#
sub parseApprovalWorkflow {
    my ($WorkflowTopic, $User, $CurrentState) = @_;
    my %workflow=();
    my $ApprovalMessage="";
    my $AllowEdit=0;

    # take care that $CurrentState is a HASH table
    $CurrentState={} unless defined($CurrentState);

    # the default state is the first row in the state table
    my $defaultState;
    my $CurrentStateIsValid=0;

    # Read topic that defines the statemachine
    if( &TWiki::Func::topicExists( $globWebName, $WorkflowTopic ) ) {
        my( $meta, $text ) = &TWiki::Func::readTopic( $globWebName, $WorkflowTopic );

        my $inBlock = 0;
        # | *Current form* | *Next form* | *Next state* | *Action* |
        foreach( split( /\n/, $text ) ) {
            if ( /^\s*\|.*State[^|]*\|.*Action[^|]*\|.*Next State[^|]*\|.*Allowed[^|]*\|/ ) {
                # from now on, we are in the TRANSITION table
                $inBlock = 1;
            } elsif ( /^\s*\|.*State[^|]*\|.*Allow Edit[^|]*\|.*Message[^|]*\|/ ) {
                # from now on, we are in the STATE table
                $inBlock = 2;

            } elsif ( /^(\t+\*\sSet\s)([A-Za-z]+)(\s\=\s*)(.*)$/ ) {
                # store preferences
                $globPreferences{$2}=$4;
            } elsif( ($inBlock == 1) && s/^\s*\|//o ) {
                # read row in TRANSITION table
                my( $state, $action, $next, $allowed) = split( /\s*\|\s*/ );
                $state = _cleanField($state);
                if (UserIsAllowed($User, $allowed) && ($state eq $CurrentState->{state})) { 
                    # store the transition in user's workflow 
                    $workflow{$action} = $next;
                }

            } elsif( ($inBlock == 2) && s/^\s*\|//o ) {
                # read row in STATE table
                my( $state, $allowedit, $message) = split( /\s*\|\s*/ );
                $state = _cleanField($state);
                Debug("STATE: '$state', $allowedit, $message  CurrentState: '$CurrentState->{state}'");

                # the first state in the table defines the default state
                if (!defined($defaultState)) {
                    $defaultState=$state;
                    $CurrentState->{state} = $state unless defined($CurrentState->{state});
                }
                if ($state eq $CurrentState->{state}) {
                    $CurrentStateIsValid=1;
                    $ApprovalMessage=$message;
                    if (UserIsAllowed($User, $allowedit)) { 
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
            return parseApprovalWorkflow($WorkflowTopic, $User, $CurrentState);
        }
    } else {
        # FIXME - do what if there is an error?
    }

    return ( \%workflow, $CurrentState, $ApprovalMessage, $AllowEdit );
}

# finds out if the user $User is allowed to do something
sub UserIsAllowed {
    my ($User, $allow) = @_;

    if ($allow) {
        my @allowed = split(/\s*\,\s*/, $allow);
        my $wikiName = TWiki::Func::userToWikiName( $User, 1 );  # i.e. "JonDoe"
        foreach my $name (@allowed) {
            $name = _cleanField( $name );
            $name =~ s/${TWiki::mainWebname}\.(.*)/$1/;
            if (userIsInGroup($wikiName, $name)) {
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

sub userIsInGroup {
    my( $theUserName, $theGroupTopicName ) = @_;

    my $usrTopic = getWebTopicName( TWiki::Func::getMainWebname(), $theUserName );
    my $grpTopic = getWebTopicName( TWiki::Func::getMainWebname(), $theGroupTopicName );
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
    my ($meta, $text ) = &TWiki::Func::readTopic( $web, $topic );

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
