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
use TWiki::UI::OopsException;

sub preview {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

    my $skin = $session->getSkin();
    my $changeform = $query->param( 'submitChangeForm' ) || "";
    my $dontNotify = $query->param( "dontnotify" ) || "";
    my $saveCmd = $query->param( "cmd" ) || "";
    my $theParent = $query->param( 'topicparent' ) || "";
    my $formTemplate = $query->param( "formtemplate" );
    my $textparam = $query->param( "text" );

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $tmpl = "";
    my $text = "";
    my $ptext = "";
    my $meta = "";
    my $formFields = "";

    TWiki::UI::checkMirror( $session, $webName, $topic );

    # Is user looking to change the form used?  Sits oddly in preview, but 
    # to avoid Javascript and pick up text on edit page it has to be in preview.
    if( $changeform ) {
        $session->{form}->changeForm( $webName, $topic );
        return;
    }

    # get view template, standard view or a view with a different skin
    $tmpl = $session->{templates}->readTemplate( "preview", $skin );
    $tmpl =~ s/%DONTNOTIFY%/$dontNotify/go;
    my $forceNewRevision = $query->param( "forcenewrevision" ) && 'checked="checked"' || '';
    $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/$forceNewRevision/go;
    if( $saveCmd ) {
        unless( $user->isAdmin()) {
            throw TWiki::UI::OopsException( $webName, $topic, "accessgroup",
                                        "$TWiki::cfg{UsersWebName}.$TWiki::cfg{SuperAdminGroup}" );
        }
        $tmpl =~ s/\(preview\)/\(preview cmd=$saveCmd\)/go;
    }
    $tmpl =~ s/%CMD%/$saveCmd/go;

    if( $saveCmd ne "repRev" ) {
        my $dummy = "";
        ( $meta, $dummy ) =
          $session->{store}->readTopic( $user, $webName, $topic, undef );

        # parent setting
        if( $theParent eq "none" ) {
            $meta->remove( "TOPICPARENT" );
        } elsif( $theParent ) {
            $meta->put( "TOPICPARENT", { "name" => $theParent } );
        }
        $tmpl =~ s/%TOPICPARENT%/$theParent/go;

        if( $formTemplate ) {
            $meta->remove( "FORM" );
            $meta->put( "FORM", { name => $formTemplate } )
              if( $formTemplate ne "none" );
            $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
        } else {
            $tmpl =~ s/%FORMTEMPLATE%//go;
        }

        # get the edited text and combine text, form and attachments for preview
        $session->{form}->fieldVars2Meta( $webName, $query, $meta );
        $text = $textparam;
        unless ( defined $text ) {
            # empty topic not allowed
            throw TWiki::UI::OopsException( $webName, $topic, "empty" );
        }
        #AS added hook for plugins that want to do heavy stuff
        $session->{plugins}->afterEditHandler( $text, $topic, $webName );
        $ptext = $text;

        if( $meta->count( "FORM" ) ) {
            $formFields = &TWiki::Form::getFieldParams( $meta );
        }
    } else {
        # undocumented "repRev" mode
        $text = $textparam; # text to save
        $ptext = $text;
        $meta = $session->{store}->extractMetaData( $webName, $topic, \$ptext );
        # SMELL: what the heck is this supposed to do?????
        $text =~ s/%_(.)_%/%__$1__%/go;
    }

    # SMELL: this is horrible, it only handles verbatim. It should be
    # done by getRenderedVersion with an override for the wikiword
    # handling.
    my $verbatim = {};
    $ptext = $session->{renderer}->takeOutBlocks( $ptext, "verbatim",
                                                  $verbatim );
    $meta->updateSets( \$ptext );
    $ptext = $session->handleCommonTags( $ptext, $webName, $topic );
    $ptext = $session->{renderer}->getRenderedVersion( $ptext, $webName, $topic );

    # do not allow click on link before save: (mods by TedPavlic)
    my $oopsUrl = '%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
    $oopsUrl = $session->handleCommonTags( $oopsUrl, $webName, $topic );
    $ptext =~ s/(?<=<a\s)([^>]*)(href=(?:".*?"|[^"].*?(?=[\s>])))/$1href="$oopsUrl?template=oopspreview" $TWiki::cfg{NoFollow}/goi;
    $ptext =~ s/<form(?:|\s.*?)>/<form action="$oopsUrl">\n<input type="hidden" name="template" value="oopspreview">/goi;
    $ptext =~ s/(?<=<)([^\s]+?[^>]*)(onclick=(?:"location.href='.*?'"|location.href='[^']*?'(?=[\s>])))/$1onclick="location.href='$oopsUrl\?template=oopspreview'"/goi;

    $session->{renderer}->putBackBlocks( $ptext, $verbatim,
                                         "verbatim", "pre",
                                         \&TWiki::Render::verbatimCallBack );

    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, 0, 0 );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );
    $tmpl =~ s/%TEXT%/$ptext/go;

    $text = TWiki::encodeSpecialChars( $text );

    $tmpl =~ s/%HIDDENTEXT%/$text/go;
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $session->writeCompletePage( $tmpl );
}

1;
