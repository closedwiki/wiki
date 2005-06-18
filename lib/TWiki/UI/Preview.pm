# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
package TWiki::UI::Preview;

use strict;
use TWiki;
use TWiki::UI;
use TWiki::Form;
use Error qw( :try );
use TWiki::OopsException;

sub preview {
    my $session = shift;

    $session->enterContext( 'preview' );

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

    my $skin = $session->getSkin();
    my $changeform = $query->param( 'submitChangeForm' ) || '';
    my $dontNotify = $query->param( 'dontnotify' ) || '';
    my $saveCmd = $query->param( 'cmd' ) || '';
    my $theParent = $query->param( 'topicparent' ) || '';
    my $formTemplate = $query->param( 'formtemplate' );
    my $textparam = $query->param( 'text' );

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'preview' );

    my $tmpl = '';
    my $text = '';
    my $ptext = '';
    my $meta = '';
    my $formFields = '';

    TWiki::UI::checkMirror( $session, $webName, $topic );

    # Is user looking to change the form used?  Sits oddly in preview, but 
    # to avoid Javascript and pick up text on edit page it has to be in preview.
    if( $changeform ) {
        $session->writeCompletePage
          ( TWiki::UI::generateChangeFormPage( $session, $webName, $topic ) );
        return;
    }

    # get view template, standard view or a view with a different skin
    $tmpl = $session->{templates}->readTemplate( 'preview', $skin );
    if( $dontNotify ) {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%/checked="checked"/go;
    } else {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%//go;
    }
    my $forceNewRevision = $query->param( 'forcenewrevision' ) || '';
    if( $forceNewRevision ) {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/go;
    } else {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%//go;
    }
    if( $saveCmd ) {
        unless( $user->isAdmin()) {
            throw TWiki::OopsException( 'accessdenied', def => 'only_group',
                                        web => $webName,
                                        topic => $topic,
                                        params => "$TWiki::cfg{UsersWebName}.$TWiki::cfg{SuperAdminGroup}" );
        }
        $tmpl =~ s/\(preview\)/\(preview cmd=$saveCmd\)/go;
    }
    $tmpl =~ s/%CMD%/$saveCmd/go;

    if( $saveCmd ne 'repRev' ) {
        my $dummy = '';
        ( $meta, $dummy ) =
          $session->{store}->readTopic( $user, $webName, $topic, undef );

        # parent setting
        if( $theParent eq 'none' ) {
            $meta->remove( 'TOPICPARENT' );
        } elsif( $theParent ) {
            $meta->put( 'TOPICPARENT', { 'name' => $theParent } );
        }
        $tmpl =~ s/%TOPICPARENT%/$theParent/go;

        if( $formTemplate ) {
            $meta->remove( 'FORM' );
            $meta->put( 'FORM', { name => $formTemplate } )
              if( $formTemplate ne 'none' );
            $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
        } else {
            $tmpl =~ s/%FORMTEMPLATE%//go;
        }

        # get the edited text and combine text, form and attachments
        my $form = $meta->get( 'FORM' );
        my $formDef;
        if( $form ) {
            my $fn = $form->{name};
            $formDef = new TWiki::Form( $session, $webName, $fn );
        }

        if( $formDef ) {
            $formDef->getFieldValuesFromQuery( $query, $meta, 0, 1 );
        }

        $text = $textparam;
        $session->{plugins}->afterEditHandler( $text, $topic, $webName );
        $ptext = $text;

        if( $formDef ) {
            $formFields = $formDef->renderHidden( $meta, 0 );
        }
    } else {
        # undocumented 'repRev' mode
        $text = $textparam; # text to save
        $ptext = $text;
        $session->{store}->extractMetaData( $meta, \$ptext );
    }

    # SMELL: this is horrible, it only handles verbatim. It should be
    # done by getRenderedVersion with an override for the wikiword
    # handling.
    my $verbatim = {};
    $ptext = $session->{renderer}->takeOutBlocks( $ptext, 'verbatim',
                                                  $verbatim );
    $ptext = $session->handleCommonTags( $ptext, $webName, $topic );
    $ptext = $session->{renderer}->getRenderedVersion( $ptext, $webName, $topic );

    # Disable links and forms
    my $oopsUrl = '%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
    $oopsUrl = $session->handleCommonTags( $oopsUrl, $webName, $topic );
    $ptext =~ s/(<a\s[^>]*\bhref=[^>]*>)/_killLink($1, $oopsUrl)/geis;
    my $formKiller = CGI::start_form( -action=>$oopsUrl )
      . CGI::hidden(-name=>'template' -value=>'oopspreview');
    $ptext =~ s/<form(?:|\s.*?)>/$formKiller/gois;
    $ptext =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1._killEvent($1, $oopsUrl)/geis;

    $session->{renderer}->putBackBlocks( $ptext, $verbatim,
                                         'verbatim', 'pre',
                                         \&TWiki::Render::verbatimCallBack );

    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, 0, 0 );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );
    $tmpl =~ s/%TEXT%/$ptext/go;

    $text = TWiki::entityEncode( $text );
    $tmpl =~ s/%HIDDENTEXT%/$text/go;
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;

    $session->writeCompletePage( $tmpl );
}

# change the href in a link to the oops url
sub _killLink {
    my( $a, $oopsUrl ) = @_;

    $a =~ s/\bhref=".*?"/href="$oopsUrl?template=oopspreview"/;
    $a =~ s/>$/ rel="nofollow">/;

    return $a;
}

# Subtly edit javascript in an event trigger
sub _killEvent {
    my( $event, $oopsUrl ) = @_;

    $event =~ s/^(.)//;
    my $quote = $1;
    $event =~ s/$quote$//;
    my $etouq = ( $quote eq '"' ? "'" : '"' ); # opposite quote
    $event =~ s/\blocation\.href=$etouq.*?$etouq/location.href=$etouq$oopsUrl?template=oopspreview$etouq/g;

    return $quote.$event.$quote;
}

1;
