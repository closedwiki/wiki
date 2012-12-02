# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
# Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
# Copyright (C) 2008-2010 Crawford Currie http://c-dot.co.uk
# Copyright (C) 2005-2012 TWiki:TWiki.TWikiContributor
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

# TODO
# 1. Create initial values based on form when attaching a form for
#    the first time.
# 2. Allow appearance of button to be given in preference.

# =========================
package TWiki::Plugins::WorkflowPlugin;

use strict;

use Error ':try';
use Assert;

use TWiki::Func ();
use TWiki::Plugins::WorkflowPlugin::Workflow ();
use TWiki::Plugins::WorkflowPlugin::ControlledTopic ();
use TWiki::OopsException ();
use TWiki::Sandbox ();

our $VERSION          = '$Rev$';
our $RELEASE          = '2012-12-02';
our $SHORTDESCRIPTION = 'Associate a "state" with a topic and then control the work flow that the topic progresses through as content is added.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName       = 'WorkflowPlugin';
our %cache;
our $isStateChange;

sub initPlugin {
    my ( $topic, $web ) = @_;

    %cache = ();

    TWiki::Func::registerRESTHandler(
        'changeState', \&_changeState,
        authenticate => 1, http_allow => 'POST' );
    TWiki::Func::registerRESTHandler(
        'fork', \&_restFork,
        authenticate => 1, http_allow => 'POST' );

    TWiki::Func::registerTagHandler(
        'WORKFLOWSTATE', \&_WORKFLOWSTATE );
    TWiki::Func::registerTagHandler(
        'WORKFLOWEDITTOPIC', \&_WORKFLOWEDITTOPIC );
    TWiki::Func::registerTagHandler(
        'WORKFLOWATTACHTOPIC', \&_WORKFLOWATTACHTOPIC );
    TWiki::Func::registerTagHandler(
        'WORKFLOWSTATEMESSAGE', \&_WORKFLOWSTATEMESSAGE );
    TWiki::Func::registerTagHandler(
        'WORKFLOWHISTORY', \&_WORKFLOWHISTORY );
    TWiki::Func::registerTagHandler(
        'WORKFLOWTRANSITION', \&_WORKFLOWTRANSITION );
    TWiki::Func::registerTagHandler(
        'WORKFLOWFORK', \&_WORKFLOWFORK );

    return 1;
}

# Tag handler
sub _initTOPIC {
    my ( $web, $topic ) = @_;

    ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( $web, $topic );

    my $controlledTopic = $cache{"$web.$topic"};
    return $controlledTopic if $controlledTopic;

    if (defined &TWiki::Func::isValidTopicName) {
        # Allow non-wikiwords
        return undef unless TWiki::Func::isValidTopicName( $topic, 1 );
    } else {
        # (tm)wiki doesn't have isValidTopicName
        # best we can do
        return undef unless TWiki::Func::isValidWikiWord( $topic );
    }

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    TWiki::Func::pushTopicContext( $web, $topic );
    my $workflowName = TWiki::Func::getPreferencesValue('WORKFLOW');
    TWiki::Func::popTopicContext( $web, $topic );

    if ($workflowName) {
        ( my $wfWeb, $workflowName ) =
          TWiki::Func::normalizeWebTopicName( $web, $workflowName );

        return undef unless TWiki::Func::topicExists(
            $wfWeb, $workflowName );

        my $workflow = new TWiki::Plugins::WorkflowPlugin::Workflow( $wfWeb,
            $workflowName );

        if ($workflow) {
            $controlledTopic =
              new TWiki::Plugins::WorkflowPlugin::ControlledTopic( $workflow,
                $web, $topic, $meta, $text );
        }
    }

    $cache{"$web.$topic"} = $controlledTopic;

    return $controlledTopic;
}

sub _getTopicName {
    my ($attributes, $web, $topic) = @_;

    return TWiki::Func::normalizeWebTopicName(
        $attributes->{web} || $web,
        $attributes->{_DEFAULT} || $topic );
}

# Tag handler
sub _WORKFLOWEDITTOPIC {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    # replace edit tag
    if ( $controlledTopic->canEdit() ) {
        return CGI::a(
            {
                href => TWiki::Func::getScriptUrl(
                    $web, $topic, 'edit',
                    t => time() ),
            }, CGI::strong("Edit") );
    }
    else {
        return CGI::strike("Edit");
    }
}

# Tag handler
sub _WORKFLOWSTATEMESSAGE {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    return $controlledTopic->getStateMessage();
}

# Tag handler
sub _WORKFLOWATTACHTOPIC {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    # replace attach tag
    if ( $controlledTopic->canAttach() ) {
        return CGI::a(
            {
                href => TWiki::Func::getScriptUrl(
                    $web, $topic, 'attach', t => time()
                )
            },
            CGI::strong("Attach")
        );
    }
    else {
        return CGI::strike("Attach");
    }
}

# Tag handler
sub _WORKFLOWHISTORY {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    return $controlledTopic->getHistoryText();
}

# Tag handler
sub _WORKFLOWTRANSITION {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    #
    # Build the button to change the current status
    #
    my @actions         = $controlledTopic->getActions();
    my $numberOfActions = scalar(@actions);
    my $cs              = $controlledTopic->getState();

    unless ($numberOfActions) {
        return '<span class="twikiAlert">NO AVAILABLE ACTIONS in state '
          .$cs.'</span>' if $controlledTopic->debugging();
        return '';
    }

    my @fields = (
        "<input type='hidden' name='WORKFLOWSTATE' value='$cs' />",
        # Can't use CGI because a top parameter could defeat the value we need
        "<input type='hidden' name='topic' value='$web.$topic' />",
        
        # Use a time field to help defeat the cache
        "<input type='hidden' name='t' value='".time()."' />"
       );
    
    my $buttonClass =
      TWiki::Func::getPreferencesValue('WORKFLOWTRANSITIONCSSCLASS')
          || 'twikiChangeFormButton twikiSubmit"';
    
    if ( $numberOfActions == 1 ) {
        push( @fields,
              "<input type='hidden' name='WORKFLOWACTION' value='"
                .$actions[0]."' />" );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => $actions[0]
            )
        );
    }
    else {
        push(
            @fields,
            CGI::popup_menu(
                -name   => 'WORKFLOWACTION',
                -values => \@actions
            )
        );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => 'Change status'
            )
        );
    }

    my $url = TWiki::Func::getScriptUrl(
        $pluginName, 'changeState', 'rest' );
    my $form =
        CGI::start_form( -method => 'POST', -action => $url )
      . join( '', @fields )
      . CGI::end_form();

    $form =~ s/\r?\n//g;    # to avoid breaking TML
    return $form;
}

# Tag handler
sub _WORKFLOWSTATE {
    my ( $session, $attributes, $topic, $web ) = @_;

    ($web, $topic) = _getTopicName($attributes, $web, $topic);
    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    return $controlledTopic->getState();
}

# Tag handler
sub _WORKFLOWFORK {
    my ( $session, $attributes, $topic, $web ) = @_;

    my $controlledTopic = _initTOPIC( $web, $topic );
    return '' unless $controlledTopic;

    # Check we can fork
    return '' unless ($controlledTopic->canFork());

    my $newnames;
    if (!defined $attributes->{newnames}) {
        # Old interpretation, for compatibility
        $newnames = $attributes->{_DEFAULT};
        $topic = $attributes->{topic} || $topic;
    } else {
        ($web, $topic) = _getTopicName($attributes, $web, $topic);
        $newnames = $attributes->{newnames};
    }
    return '' unless $newnames;
    my $lockdown = TWiki::Func::isTrue($attributes->{lockdown});

    if (!TWiki::Func::topicExists($web, $topic)) {
        return "<span class='twikiAlert'>WORKFLOWFORK: '$topic' does not exist</span>";
    }
    my $errors = '';
    foreach my $newname ( split(',', $newnames ) ) {
        my ($w, $t) =
          TWiki::Func::normalizeWebTopicName( $web, $newname );
        if (TWiki::Func::topicExists($w, $t)) {
            $errors .= "<span class='twikiAlert'>WORKFLOWFORK: $w.$t exists</span><br />";
        }
    }
    return $errors if $errors;

    my $label = $attributes->{label} || 'Fork';
    my $buttonClass =
      TWiki::Func::getPreferencesValue('WORKFLOWTRANSITIONCSSCLASS')
      || 'twikiChangeFormButton twikiSubmit"';
    my $url = TWiki::Func::getScriptUrl( 'WorkflowPlugin', 'fork', 'rest');
    return <<HTML;
<form name='forkWorkflow' action='$url' method="POST">
<input type='hidden' name='topic' value='$web.$topic' />
<input type='hidden' name='newnames' value='$newnames' />
<input type='hidden' name='lockdown' value='$lockdown' />
<input type='hidden' name='endPoint' value='$web.$topic' />
<input type='submit' class='$buttonClass' value='$label' />
</form>
HTML
}

# Handle actions. REST handler, on changeState action.
sub _changeState {
    my ($session) = @_;

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    die unless $web && $topic;

    my $url;
    my $controlledTopic = _initTOPIC( $web, $topic );

    unless ($controlledTopic) {
        $url = TWiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => "oopssaveerr",
            param1   => "Could not initialise workflow for "
              . ( $web   || '' ) . '.'
                . ( $topic || '' )
               );
        TWiki::Func::redirectCgiQuery( undef, $url );
        return undef;
    }

    my $action = $query->param('WORKFLOWACTION');
    my $state  = $query->param('WORKFLOWSTATE');
    die "BAD STATE $action $state!=", $controlledTopic->getState()
      unless $action
        && $state
          && $state eq $controlledTopic->getState()
            && $controlledTopic->haveNextState($action);

    my $newForm = $controlledTopic->newForm($action);

    # Check that no-one else has a lease on the topic
    my $breaklock = $query->param('breaklock');
    unless (TWiki::Func::isTrue($breaklock)) {
        my ( $url, $loginName, $t ) = TWiki::Func::checkTopicEditLock(
            $web, $topic );
        if ( $t ) {
            my $currUser = TWiki::Func::getCanonicalUserID();
            my $locker = TWiki::Func::getCanonicalUserID($loginName);
            if ($locker ne $currUser) {
                $t = TWiki::Time::formatDelta(
                    $t, $TWiki::Plugins::SESSION->i18n );
                $url = TWiki::Func::getScriptUrl(
                    $web, $topic, 'oops',
                    template => 'oopswfplease',
                    param1   => TWiki::Func::getWikiName($locker),
                    param2   => $t,
                    param3   => $state,
                    param4   => $action,
                   );
                TWiki::Func::redirectCgiQuery( undef, $url );
                return undef;
            }
        }
    }

    try {
        try {
            if ($newForm) {

                # If there is a form with the new state, and it's not
                # the same form as previously, we need to kick into edit
                # mode to support form field changes. In this case the
                # transition is delayed until after the edit is saved
                # (the transition is executed by the beforeSaveHandler)
                $url =
                  TWiki::Func::getScriptUrl(
                      $web, $topic, 'edit',
                      breaklock             => $breaklock,
                      t                     => time(),
                      formtemplate          => $newForm,
                      # pass info about pending state change
                      template              => 'workflowedit',
                      WORKFLOWPENDINGACTION => $action,
                      WORKFLOWCURRENTSTATE  => $state,
                      WORKFLOWPENDINGSTATE  =>
                        $controlledTopic->haveNextState($action),
                      WORKFLOWWORKFLOW      =>
                        $controlledTopic->{workflow}->{name},
                     );
            }
            else {
                $controlledTopic->changeState($action);
                # Flag that this is a state change to the beforeSaveHandler
                local $isStateChange = 1;
                $controlledTopic->save();
                $url = TWiki::Func::getScriptUrl( $web, $topic, 'view' );
            }

            TWiki::Func::redirectCgiQuery( undef, $url );
        } catch Error::Simple with {
            my $error = shift;
            throw TWiki::OopsException(
                'oopssaveerr',
                web    => $web,
                topic  => $topic,
                params => [ $error || '?' ]
               );
        };
    } catch TWiki::OopsException with {
        my $e = shift;
        if ( $e->can('generate') ) {
            $e->generate($session);
        }
        else {

            # Deprecated, TWiki compatibility only
            $e->redirect($session);
        }

    };
    return undef;
}

# Mop up other WORKFLOW tags without individual handlers
sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

    my $controlledTopic = _initTOPIC( $web, $topic );

    if ( $controlledTopic ) {

        # show all tags defined by the preferences
        my $url = TWiki::Func::getScriptUrl( $web, $topic, 'view' );
        $controlledTopic->expandWorkflowPreferences( $url, $_[0] );

        return unless ( $controlledTopic->debugging() );
    }

    # Clean up unexpanded variables
    $_[0] =~ s/%WORKFLOW[A-Z_]*%//g;
}

sub _restFork {
    my ($session) = @_; 
    # Update the history in the template topic and the new topic
    my $query = TWiki::Func::getCgiQuery();
    my $forkTopic = $query->param('topic');
    my @newnames = split(/,/, $query->param('newnames'));
    my $lockdown = $query->param('lockdown');

    (my $forkWeb, $forkTopic) =
      TWiki::Func::normalizeWebTopicName( undef, $forkTopic );

    if ( TWiki::Func::topicExists( $forkWeb, $forkTopic ) ) {
        # Validated
        $forkWeb =
          TWiki::Sandbox::untaintUnchecked( $forkWeb );
        $forkTopic =
          TWiki::Sandbox::untaintUnchecked( $forkTopic );
    }

    my ($ttmeta, $tttext) = TWiki::Func::readTopic(
        $forkWeb, $forkTopic);

    my $now = TWiki::Func::formatTime( time(), undef, 'servertime' );
    my $who = TWiki::Func::getWikiUserName();

    # create the new topics
    foreach my $newname ( @newnames ) {
        $newname =
          TWiki::Sandbox::untaintUnchecked( $newname );
        my ($w, $t) =
          TWiki::Func::normalizeWebTopicName( $forkWeb, $newname );
        if (TWiki::Func::topicExists($w, $t)) {
            return "<span class='twikiAlert'>WORKFLOWFORK: '$w.$t' already exists</span>";
        }
        my $text = $tttext;
        my $meta = new TWiki::Meta($session, $w, $t);
        # Clone the template
        foreach my $k ( keys %$ttmeta ) {
            # Note that we don't carry over the history from the forked topic
            next if ( $k =~ /^_/ || $k eq 'WORKFLOWHISTORY' );
            my @data;
            foreach my $item ( @{ $ttmeta->{$k} } ) {
                my %datum = %$item;
                push( @data, \%datum );
            }
            $meta->putAll( $k, @data );
        }
        my $history = {
            value => "<br>Forked from [[$forkWeb.$forkTopic]] by $who at $now",
        };
        $meta->put( "WORKFLOWHISTORY", $history );
        TWiki::Func::saveTopic($w, $t, $meta, $text,
                                 { forcenewrevision => 1 });
    }

    my $history = $ttmeta->get('WORKFLOWHISTORY') || {};
    $history->{value} .= "<br>Forked to " .
      join(', ', map { "[[$forkWeb.$_]]" } @newnames). " by $who at $now";
    $ttmeta->put( "WORKFLOWHISTORY", $history );

    if ($lockdown) {
        $ttmeta->putKeyed("PREFERENCE",
                          { name => 'ALLOWTOPICCHANGE', value => 'nobody' });
    }

    TWiki::Func::saveTopic( $forkWeb, $forkTopic, $ttmeta, $tttext,
                             { forcenewrevision => 1 });
}

# Used to trap an edit and check that it is permitted by the workflow
sub beforeEditHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    # Check the state change parameters to see if this edit is
    # part of a state change (state changes may be permitted even
    # for users who can't edit, so we have to suppress the edit
    # check in this case)
    my $changingState = 1;
    my $query = TWiki::Func::getCgiQuery();
    foreach my $p ( qw(WORKFLOWPENDINGACTION WORKFLOWCURRENTSTATE
                     WORKFLOWPENDINGSTATE WORKFLOWWORKFLOW) ) {
        if (!defined $query->param($p)) {
            # All params must be present to change state
            $changingState = 0;
            last;
        }
    }

    return if $changingState; # permissions check not required

    my $controlledTopic = _initTOPIC( $web, $topic );

    return unless $controlledTopic; # not controlled, so check not required

    unless ( $controlledTopic->canEdit() ) {
        throw TWiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Edit topic',
'You are not permitted to edit this topic. You have been denied access by Workflow Plugin'
            ]
        );
    }
}

# Check that the user is allowed to attach to the topic, if it is controlled
sub beforeAttachmentSaveHandler {
    my ( $attrHashRef, $topic, $web ) = @_;
    my $controlledTopic = _initTOPIC( $web, $topic );
    return unless $controlledTopic;

    unless ( $controlledTopic->canEdit() ) {
        throw TWiki::OopsException(
            'accessdenied',
            status => 403,
            def    => 'topic_access',
            web    => $_[2],
            topic  => $_[1],
            params => [
                'Edit topic',
'You are not permitted to attach to this topic. You have been denied access by Workflow Plugin'
            ]
        );
    }
}

# The beforeSaveHandler inspects the request parameters to see if the
# right params are present to trigger a state change. The legality of
# the state change is *not* checked - it's assumed that the change is
# coming as the result of an edit invoked by a state transition.
sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    # $isStateChange is true if state has just been changed in this session.
    # In this case we don't need the access check.
    return if ($isStateChange);

    # Otherwise we need to check if the packet of state change information
    # is present.
    my $query = TWiki::Func::getCgiQuery();
    my $changingState = 1;
    my %stateChangeInfo;
    foreach my $p ( qw(WORKFLOWPENDINGACTION WORKFLOWCURRENTSTATE
                     WORKFLOWPENDINGSTATE WORKFLOWWORKFLOW) ) {
        $stateChangeInfo{$p} = $query->param($p);
        if (defined $stateChangeInfo{$p}) {
            $query->delete($p);
        } else {
            # All params must be present to change state
            $changingState = 0;
            last;
        }
    }

    my $controlledTopic;

    if ($changingState) {
        # See if we are expecting to apply a new state from query
        # params
        my ($wfw, $wft) = TWiki::Func::normalizeWebTopicName(
            undef, $stateChangeInfo{WORKFLOWWORKFLOW} );

        # Can't use initTOPIC, because the data comes from the save
        my $workflow = new TWiki::Plugins::WorkflowPlugin::Workflow(
            $wfw, $wft );
        $controlledTopic =
          new TWiki::Plugins::WorkflowPlugin::ControlledTopic(
              $workflow, $web, $topic, $meta, $text );

    } else {
        # Otherwise we are *not* changing state so we can use initTOPIC
        $controlledTopic = _initTOPIC( $web, $topic );
    }

    return unless $controlledTopic;

    if ($changingState) {
        # The beforeSaveHandler has no way to abort the save,
        # so we have to do a state change without a topic save.
        $controlledTopic->changeState($stateChangeInfo{WORKFLOWPENDINGACTION});
    } elsif ( !$controlledTopic->canEdit() ) {
        # Not a state change, make sure the AllowEdit in the state table
        # permits this action
        throw TWiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $_[2],
            topic => $_[1],
            params =>
              [ 'Save topic',
'You are not permitted to save this topic. You have been denied access by Workflow Plugin' ]
             );
    }
}

1;
