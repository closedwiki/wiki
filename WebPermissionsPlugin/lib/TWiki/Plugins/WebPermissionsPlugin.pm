# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) Evolved Media Network 2005
# Copyright (C) Spanlink Communications 2006
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.
#
# Author: Crawford Currie http://c-dot.co.uk
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates WebPreferences
# in each affected web.

package TWiki::Plugins::WebPermissionsPlugin;

use strict;

use vars qw( $VERSION $RELEASE $pluginName $antiBeforeSaveRecursion);


use TWiki::Func;
use CGI qw( :all );
use Error;

$pluginName = 'WebPermissionsPlugin';

$VERSION = '$Rev: 160$';

$RELEASE = '1.000';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            'Version mismatch between WebPermissionsPlugin and TWiki::Plugins' );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'WEBPERMISSIONS', \&_WEBPERMISSIONS );
    TWiki::Func::registerTagHandler( 'TOPICPERMISSIONS', \&_TOPICPERMISSIONS );

#    TWiki::Func::registerRESTHandler('setACLs', \&REST_setACLs);
$antiBeforeSaveRecursion = 0;

    if( $TWiki::Plugins::VERSION == 1.1 ) {
        eval 'use TWiki::Contrib::FuncUsersContrib';
        die $@ if $@;
    }

    return 1;
}


# BUGO: because WEBPERMISSIONS is using the same view to change and display,
# updated ACL's do not apply to this view.
# TWiki has already loaded the permissions that it is using, and some
# random plugins have already processed things based on the ACLs prior to
# the users change. THIS IS HORRIGIBILE
# IMO it needs to be either rest or save, though i'm going to lean to rest
# especially as we don't want to continue to presume that ACLs are topic based
# the advantage with save, is that it will re-direct to view on success (and
# resolve permissions issues)
sub _WEBPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;

    #return undef unless TWiki::Func::isAdmin();

    my $query = $session->{cgiQuery};
    my $action = $query->param( 'web_permissions_action' );
    my $editing = $action && $action eq 'Edit';
    my $saving =  $action && $action eq 'Save';

    my @modes = split(/[\s,]+/,$TWiki::cfg{Plugins}{WebPermissionsPlugin}{modes} ||
                           'VIEW,CHANGE' );

    my @webs;
    my $chosenWebs = $params->{webs} || $query->param('webs');
    if( $chosenWebs ) {
        @webs = split(/[,\s]+/, $chosenWebs);
    } else {
        @webs = TWiki::Func::getListOfWebs( 'user' );
    }
    my @knownusers;

    my %table;
    foreach $web ( @webs ) {
        my $acls = TWiki::Func::getACLs( \@modes, $web );

        @knownusers = keys %$acls unless scalar( @knownusers );
        if( $saving ) {
            my $changes = 0;
            foreach my $user ( @knownusers ) {
                foreach my $op ( @modes ) {
                    my $onoff = $query->param($user.':'.$web.':'.$op);
                    if( $onoff && !$acls->{$user}->{$op} ||
                          !$onoff && $acls->{$user}->{$op} ) {
                        $changes++;
                        $acls->{$user}->{$op} = $onoff;
                    }
                }
            }
            # Commit changes to ACLs
            if( $changes ) {
                TWiki::Func::setACLs( \@modes, $acls, $web );
            }
        }
        $table{$web} = $acls;
    }

    # Generate the table
    my $tab = '';

    my %images;
    foreach my $op ( @modes ) {
        if( -f TWiki::Func::getPubDir().'/TWiki/WebPermissionsPlugin/'.$op.'.gif' ) {
              $images{$op} =
                CGI::img( { src => TWiki::Func::getPubUrlPath().
                              '/TWiki/WebPermissionsPlugin/'.$op.'.gif' } );
              $tab .= $images{$op}.' '.$op;
        } else {
            $images{$op} = $op;
        }
    }

    $tab .= CGI::start_table( { border => 1, class => 'twikiTable' } );

    my $repeat_heads = $params->{repeatheads} || 0;
    my $repeater = 0;
    my $row;
    foreach my $user ( sort @knownusers ) {
        unless( $repeater ) {
            $row = CGI::th( '' );
            foreach $web ( @webs ) {
                $row .= CGI::th( $web );
            }
            $tab .= CGI::Tr( $row );
            $repeater = $repeat_heads;
        }
        $repeater--;
        $row = CGI::th( ' '.$user.' ' );
        foreach $web ( sort @webs ) {
            my $cell;
            foreach my $op ( @modes ) {
                if( $editing ) {
                    my %attrs = ( type => 'checkbox', name => $user.':'.$web.':'.$op );
                    $attrs{checked} = 'checked' if $table{$web}->{$user}->{$op};
                    $cell .= CGI::label( ($images{$op} || $op).CGI::input( \%attrs ));
                } elsif( $table{$web}->{$user}->{$op} ) {
                    $cell .= $images{$op} || $op;
                }
            }
            $row .= CGI::td( $cell );
        }
        $tab .= CGI::Tr( $row );
    }
    $tab .= CGI::end_table();

    if( $editing ) {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Save',  -class => 'twikiSubmit');
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Cancel',  -class => 'twikiSubmit' );
    } else {
        $tab .= CGI::submit( -name => 'web_permissions_action', -value => 'Edit',  -class => 'twikiSubmit' );
    }
    my $page = CGI::start_form(
        -method => 'POST',
        -action => TWiki::Func::getScriptUrl( $web, $topic, 'view') );

    if( defined $chosenWebs ) {
      $page .= CGI::hidden( -name => 'webs', -value => $chosenWebs );
    }

    $page .= $tab . CGI::end_form();
    return $page;
}

#TODO: add param topic= and show= specify to list only groups / only users / both
sub _TOPICPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;

    #this is to redirect to the "no access" page if this tag is used in a non-view template.
    TWiki::UI::checkAccess( $session, $web, $topic,
                                'view', $session->{user} );

   my $disableSave = 'Disabled';
   $disableSave = '' if TWiki::Func::checkAccessPermission( 'CHANGE', 
                    TWiki::Func::getWikiUserName(), undef, $topic, $web );

   my $pluginPubUrl = TWiki::Func::getPubUrlPath().'/'.
            TWiki::Func::getTwikiWebname().'/'.$pluginName;

    #add the JavaScript
    my $jscript = TWiki::Func::readTemplate ( 'webpermissionsplugin', 'topicjavascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    TWiki::Func::addToHEAD($pluginName, $jscript);

    my $templateText = TWiki::Func::readTemplate ( 'webpermissionsplugin', 'topichtml' );
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{save}%/g if ($disableSave eq '');
    $templateText =~ s/%SCRIPT%/%SCRIPTURL{view}%/g unless ($disableSave eq '');
    $templateText = TWiki::Func::expandCommonVariables( $templateText, $topic, $web );

    my $topicViewerGroups = '';
    my $topicViewers = '';
    my $topicEditorGroups = '';
    my $topicEditors = '';
    my $unselectedGroups = '';
    my $unselectedUsers = '';

#TODO: i'm worried that getACL's returns a full matrix of all users - surely a sparse matrix would be more scalable
                                
    my $acls = TWiki::Func::getACLs( [ 'VIEW', 'CHANGE' ], $web, $topic);
    foreach my $user ( sort (keys %$acls) ) {
        my $userObj = TWiki::Func::lookupUser( wikiname => $user );
        if ( $acls->{$user}->{CHANGE} ) {
            $topicEditors .= '<OPTION>'.$userObj->wikiName().'</OPTION>' unless ($userObj->isGroup());
            $topicEditorGroups .= '<OPTION>'.$userObj->wikiName().'</OPTION>' if ($userObj->isGroup());
        } elsif ( $acls->{$user}->{VIEW} ) {
            $topicViewers .= '<OPTION>'.$userObj->wikiName().'</OPTION>' unless ($userObj->isGroup());
            $topicViewerGroups .= '<OPTION>'.$userObj->wikiName().'</OPTION>' if ($userObj->isGroup());
        } else {
            $unselectedUsers .= '<OPTION>'.$userObj->wikiName().'</OPTION>' unless ($userObj->isGroup());
            $unselectedGroups .= '<OPTION>'.$userObj->wikiName().'</OPTION>' if ($userObj->isGroup());
        }
    }
    $templateText =~ s/%EDITGROUPS%/$topicEditorGroups/g;
    $templateText =~ s/%EDITUSERS%/$topicEditors/g;
    $templateText =~ s/%VIEWGROUPS%/$topicViewerGroups/g;
    $templateText =~ s/%VIEWUSERS%/$topicViewers/g;
    $templateText =~ s/%UNSELECTEDGROUPS%/$unselectedGroups/g;
    $templateText =~ s/%UNSELECTEDUSERS%/$unselectedUsers/g;
    $templateText =~ s/%PLUGINNAME%/$pluginName/g;
    $templateText =~ s/%DISABLESAVE%/$disableSave/g;

    return $templateText;
}

#TODO: rejig this so it works for the WEBPERMS too
sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    my ( $text, $topic, $web, $meta ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    my $action = $query->param('topic_permissions_action');
    return unless (defined($action));#nothing to do with this plugin
    
     if ($action ne 'Save') {
        #SMELL: canceling out from, or just stoping a save seems to be quite difficult
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );
        throw Error::Simple( 'cancel permissions action' );
    }
    
    return if ($antiBeforeSaveRecursion == 1);
    $antiBeforeSaveRecursion = 1;
   
    #these lists only contain seelcted users (by using javascript to select the changed ones in save onclick)
    my @topicEditors = $query->param('topiceditors');
    my @topicViewers = $query->param('topicviewers');
    my @disallowedUsers = $query->param('disallowedusers');

   if ((@topicEditors || @topicViewers || @disallowedUsers)) {
        #TODO: change this to get modes from params
        my @modes = split(/[\s,]+/,$TWiki::cfg{Plugins}{WebPermissionsPlugin}{modes} ||
                           'VIEW,CHANGE' );
        my $acls = TWiki::Func::getACLs( \@modes, $web, $topic);
        my ($userName, $userObj);
        foreach $userName (@topicEditors) {
            $userObj = TWiki::Func::lookupUser( wikiname => $userName );
            $acls->{$userObj->webDotWikiName()}->{'CHANGE'} = 1;
            $acls->{$userObj->webDotWikiName()}->{'VIEW'} = 1;
        }
        foreach $userName (@topicViewers) {
            $userObj = TWiki::Func::lookupUser( wikiname => $userName );
            $acls->{$userObj->webDotWikiName()}->{'CHANGE'} = 0;
            $acls->{$userObj->webDotWikiName()}->{'VIEW'} = 1;
        }
        foreach $userName (@disallowedUsers) {
            $userObj = TWiki::Func::lookupUser( wikiname => $userName );
            $acls->{$userObj->webDotWikiName()}->{'CHANGE'} = 0;
            $acls->{$userObj->webDotWikiName()}->{'VIEW'} = 0;
        }

        #TODO: what exactly happens on error?
        TWiki::Func::setACLs( \@modes, $acls, $web, $topic );
        
        #read in what setACLs just saved, (don't grok why redirect looses the save)
        ($_[3], $_[0]) = TWiki::Func::readTopic($_[2],$_[1]);

        #SMELL: canceling out from, or just stoping a save seems to be quite difficult
        #return a redirect to view..
        TWiki::Func::redirectCgiQuery( $query, &TWiki::Func::getViewUrl( $web, $topic ) );
        throw Error::Simple( 'permissions action saved' );

   }
}

1;
