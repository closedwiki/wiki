#!/usr/bin/perl -wT
BEGIN{($_=$0)=~s!(.*)[\\/][^\\/]+$!!;chdir $1} 

#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999-2000 Peter Thoeny, peter@thoeny.com
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

# A thought on design.  Information is passed to the preview script via various form variables.
# Much of the meta data could have been passed by an extra hidden field, instead individual items such
# as parent information is passed by individual form variables, hopefully giving a clear "API".

use CGI::Carp qw(fatalsToBrowser);
use CGI;
use lib ( '.' );
use lib ( '../lib' );
use TWiki;

use strict;

use vars qw( $query );

$query = new CGI;

&main();

sub main
{
    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theTopic = $query->param( 'topic' ) || "";
    my $theUrl = $query->url;

    my( $topic, $webName, $dummy, $userName ) = 
	&TWiki::initialize( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query );
    $dummy = "";  # to suppress warning

    my $saveCmd = $query->param( 'cmd' ) || "";
    my $breakLock = $query->param( 'breaklock' ) || "";
    my $onlyWikiName = $query->param( 'onlywikiname' ) || "";
    my $tmpl = "";
    my $text = "";
    my $meta = "";
    my $extra = "";
    my $wikiUserName = &TWiki::userToWikiName( $userName );


    &TWiki::writeDebug( "=remoteUserName==== $theRemoteUser" );
    &TWiki::writeDebug( "=userName==== $userName" );
    &TWiki::writeDebug( "=wikiuserName==== $wikiUserName" );
    
    #if the person editing is not known, make them register
    if( $wikiUserName eq &TWiki::userToWikiName( $TWiki::defaultUserName ) ){
	#redirect to the TWiki registration page
        TWiki::redirect( $query, &TWiki::getViewUrl( $TWiki::twikiWebname, "TwikiRegistration") );
        return;
    }


    ##&TWiki::writeDebug( "===== $wikiUserName" );

    if( ! &TWiki::Store::webExists( $webName ) ) {
        my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsnoweb" );
        TWiki::redirect( $query, $url );
        return;
    }

    my( $mirrorSiteName, $mirrorViewURL ) = &TWiki::readOnlyMirrorWeb( $webName );
    if( $mirrorSiteName ) {
        my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsmirror", $mirrorSiteName, $mirrorViewURL );
        print $query->redirect( $url );
        return;
    }

    # prevent non-Wiki names?
    if( ( $onlyWikiName ) && ( ! &TWiki::isWikiName( $topic ) ) &&
        ( ! &TWiki::Store::topicExists( $webName, $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        TWiki::redirect( $query, &TWiki::getViewUrl( $webName, $topic ) );
        return;
    }

    # read topic and check access permission
    if( &TWiki::Store::topicExists( $webName, $topic ) ) {
        ( $meta, $text ) = &TWiki::Store::readTopic( $webName, $topic );
    }
    if( ! &TWiki::Access::checkAccessPermission( "change", $wikiUserName, $text, $topic, $webName ) ) {
        # user has not permission to change the topic
        my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsaccesschange" );
        TWiki::redirect( $query, $url );
        return;
    }
    if( ( $saveCmd ) &&
        ( ! &TWiki::Access::userIsInGroup( $wikiUserName, $TWiki::superAdminGroup ) ) ) {
        # user has no permission to execute undocumented cmd=... parameter
        my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsaccessgroup", "$TWiki::mainWebname.$TWiki::superAdminGroup" );
        TWiki::redirect( $query, $url );
        return;
    }

    my( $lockUser, $lockTime ) = &TWiki::Store::topicIsLockedBy( $webName, $topic );
    if( ( ! $breakLock ) && ( $lockUser ) ) {
        # warn user that other person is editing this topic
        $lockUser = &TWiki::userToWikiName( $lockUser );
        use integer;
        $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
        my $editLock = $TWiki::editLockTime / 60;
        # PTh 20 Jun 2000: changed to getOopsUrl
        my $url = &TWiki::getOopsUrl( $webName, $topic, "oopslocked",
            $lockUser, $editLock, $lockTime );
        TWiki::redirect( $query, $url );
        return;
    }
    &TWiki::Store::lockTopic( $topic );

    my $formTemplate = $query->param( "formtemplate" ) || "";

    # get edit template, standard or a different skin
    my $skin = $query->param( "skin" ) || &TWiki::Prefs::getPreferencesValue( "SKIN" );
    $tmpl = &TWiki::Store::readTemplate( "edit", $skin );
    if( ! &TWiki::Store::topicExists( $webName, $topic ) ) {
        my $templateTopic = $query->param( "templatetopic" ) || "";
        if( $templateTopic ) {
            ( $meta, $text ) = &TWiki::Store::readTopic( $webName, $templateTopic );
        }
        if( ! $text ) {
            ( $meta, $text ) = &TWiki::Store::readTemplateTopic( "WebTopicEditTemplate" );
        }
        $extra = "(not exist)";

        # If present, instantiate form
        if( ! $formTemplate ) {
            my %args = $meta->findOne( "FORM" );
            $formTemplate = $args{"name"};
        }

        my $foo = &TWiki::getLocaldate();
        $text =~ s/%DATE%/$foo/go;
        $text =~ s/%WIKIUSERNAME%/$wikiUserName/go;
    }
    
    # parent setting
    my $theParent = $query->param( 'topicparent' ) || "";
    if( $theParent ) {
        if( $theParent =~ /^([^.]+)\.([^.]+)$/ ) {
            my $parentWeb = $1;
            if( $1 eq $webName ) {
               $theParent = $2;
            }
        }
        $meta->put( "TOPICPARENT", ( "name" => $theParent ) );
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;
    
    # Processing of formtemplate - comes directly from query parameter formtemplate , 
    # or indirectly from webtopictemplate parameter.
    my $oldargsr;
    if( $formTemplate ) {
       my @args = ( name => $formTemplate );
       $meta->remove( "FORM" );
       if( $formTemplate ne "none" ) {
          $meta->put( "FORM", @args );
       } else {
          $meta->remove( "FORM" );
       }
       $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
       my $ptext = $query->param( 'text' );
       if( defined $ptext ) {
           $text = $ptext;
           $text = &TWiki::decodeSpecialChars( $text );
       }
    }
    
    if( $saveCmd eq "repRev" ) {
       $text = TWiki::Store::readTopicRaw( $webName, $topic );
    }

    $text =~ s/&/&amp\;/go;
    $text =~ s/</&lt\;/go;
    $text =~ s/>/&gt\;/go;
    $text =~ s/\t/   /go;

    if( $TWiki::doLogTopicEdit ) {
        # write log entry
        &TWiki::Store::writeLog( "edit", "$webName.$topic", $extra );
    }

    if( $saveCmd ) {
        $tmpl =~ s/\(edit\)/\(edit cmd=$saveCmd\)/go;
    }
    $tmpl =~ s/%CMD%/$saveCmd/go;
    $tmpl = &TWiki::handleCommonTags( $tmpl, $topic );
    if( $saveCmd ne "repRev" ) {
        $tmpl = &TWiki::handleMetaTags( $webName, $topic, $tmpl, $meta );
    } else {
        $tmpl =~ s/%META{[^}]*}%//go;
    }
    $tmpl = &TWiki::getRenderedVersion( $tmpl );

    # Dont want to render form fields, so this after getRenderedVersion
    my %formMeta = $meta->findOne( "FORM" );
    my $form = "";
    $form = $formMeta{"name"} if( %formMeta );
    if( $form && $saveCmd ne "repRev" ) {
       my @fieldDefs = &TWiki::Form::getFormDef( $webName, $form );
       
       if( ! @fieldDefs ) {
            my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsnoformdef" );
            TWiki::redirect( $query, $url );
            return;
       }
       my $formText = &TWiki::Form::renderForEdit( $webName, $form, $meta, $query, @fieldDefs );
       $tmpl =~ s/%FORMFIELDS%/$formText/go;
    } elsif( $saveCmd ne "repRev" && TWiki::Prefs::getPreferencesValue( "WEBFORMS", $webName )) {
       $tmpl =~ s/%FORMFIELDS%/&TWiki::Form::chooseFormButton( "Add form" )/goe;
    } else {
       $tmpl =~ s/%FORMFIELDS%//go;
    }
    
    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used

    $tmpl =~ s/%TEXT%/$text/go;

    TWiki::writeHeader( $query );

    print $tmpl;
}
