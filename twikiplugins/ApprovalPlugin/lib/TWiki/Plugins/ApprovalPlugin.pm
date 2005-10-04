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
#
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::ApprovalPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $pluginName
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

$VERSION = '$Rev$';
$pluginName = 'ApprovalPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
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
sub DISABLE_earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}


# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'


}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the beginning of TWiki::handleCommonTags (for cache Plugins use only)
#      $_[0] =~ s/%EDITTOPIC%/Kak/g;
}

# =========================
sub commonTagsHandler
{
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
sub DISABLE_afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the end of TWiki::handleCommonTags (for cache Plugins use only)
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    
    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;
      
      # This handler is called by getRenderedVersion just before the line loop
      
      # do custom extension rule, like for example:
#      $_[0] =~ s/%APPROVALMESSAGE%/Approval Plugin: $prefApprovalWorkflow/g;


      if (NeedsApproval()) {
	  
	  
      }







}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}

# =========================
sub beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'
      
      if (NeedsApproval()) {
	  if (! $globAllowEdit) {
	      TWiki::UI::oops( $web, $topic, "accesschange");
		return 0;
	    }
      }


}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

      if (NeedsApproval()) {
	  Debug("---------- beforeSaveHandler");
	  if (! $globAllowEdit && !$CalledByMyself) {
	      TWiki::UI::oops( $web, $topic, "accesschange");
		return 0;
	    }
      }
}

# =========================
sub DISABLE_afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'


}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

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
    $text = TWiki::expandVariablesOnTopicCreation( $text );
    $version = TWiki::Store::getRevisionInfoFromMeta( $web, $topic, $meta );

    Debug("changeApprovalState from $globCurrentState->{state} to $state");

    $globCurrentState->{state}=$state;
    $globCurrentState->{"LASTVERSION_$state"}="1.$version";
    $globCurrentState->{"LASTTIME_$state"} = Timestamp();

    $meta->remove( "APPROVAL" );
    $meta->put( "APPROVAL", %{$globCurrentState});
    
    my $unlock=1;
    my $dontNotify=1;
    $CalledByMyself=1;
    my $error = TWiki::Store::saveTopic( $web, $topic, $text, $meta, "", $unlock, $dontNotify );
    if( $error ) {
	TWiki::UI::oops( $web, $topic, "saveerr", $error );
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
	my $wikiName = TWiki::userToWikiName( $User, 1 );  # i.e. "JonDoe"
	foreach my $name (@allowed) {
	    $name = _cleanField( $name );
	    $name =~ s/${TWiki::mainWebname}\.(.*)/$1/;
	    if (&TWiki::Access::userIsInGroup($wikiName, $name)) {
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

sub _cleanField
{
   my( $text ) = @_;
   $text = "" if( ! $text );
   $text =~ s/^\s*//go;
   $text =~ s/\s*$//go;
   $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
   return $text;
}




1;
