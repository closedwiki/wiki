# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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
    my $userName = $session->{userName};

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
    my $wikiUserName = $session->{wikiUserName};

    TWiki::UI::checkMirror( $session, $webName, $topic );

    # reset lock time, this is to prevent contention in case of a long edit session
    $session->{store}->lockTopic( $webName, $topic );

    # Is user looking to change the form used?  Sits oddly in preview, but 
    # to avoid Javascript and pick up text on edit page it has to be in preview.
    if( $changeform ) {
        $session->{form}->changeForm( $webName, $topic );
        return;
    }

    # get view template, standard view or a view with a different skin
    $tmpl = $session->{templates}->readTemplate( "preview", $skin );
    $tmpl =~ s/%DONTNOTIFY%/$dontNotify/go;
    if( $saveCmd ) {
        TWiki::UI::checkAdmin( $session, $webName, $topic, $wikiUserName );
        $tmpl =~ s/\(preview\)/\(preview cmd=$saveCmd\)/go;
    }
    $tmpl =~ s/%CMD%/$saveCmd/go;

    if( $saveCmd ne "repRev" ) {
        my $dummy = "";
        ( $meta, $dummy ) =
          $session->{store}->readTopic( $wikiUserName, $webName, $topic, undef, 0 );

        # parent setting
        if( $theParent eq "none" ) {
            $meta->remove( "TOPICPARENT" );
        } elsif( $theParent ) {
            $meta->put( "TOPICPARENT", ( "name" => $theParent ) );
        }
        $tmpl =~ s/%TOPICPARENT%/$theParent/go;

        if( $formTemplate ) {
            $meta->remove( "FORM" );
            $meta->put( "FORM", ( name => $formTemplate ) ) if( $formTemplate ne "none" );
            $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
        } else {
            $tmpl =~ s/%FORMTEMPLATE%//go;
        }

        # get the edited text and combine text, form and attachments for preview
        $session->{form}->fieldVars2Meta( $webName, $query, $meta );
        $text = $textparam;
        if( ! $text ) {
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

    my @verbatim = ();
    $ptext = $session->{renderer}->takeOutBlocks( $ptext, "verbatim", \@verbatim );
    $ptext =~ s/ {3}/\t/go;
    $meta->updateSets( \$ptext );
    $ptext = $session->handleCommonTags( $ptext, $topic );
    $ptext = $session->{renderer}->getRenderedVersion( $ptext );

    # do not allow click on link before save: (mods by TedPavlic)
    my $oopsUrl = '%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
    $oopsUrl = $session->handleCommonTags( $oopsUrl, $topic );
    $ptext =~ s@(?<=<a\s)([^>]*)(href=(?:".*?"|[^"].*?(?=[\s>])))@$1href="$oopsUrl?template=oopspreview"@goi;
    $ptext =~ s@<form(?:|\s.*?)>@<form action="$oopsUrl">\n<input type="hidden" name="template" value="oopspreview">@goi;
    $ptext =~ s@(?<=<)([^\s]+?[^>]*)(onclick=(?:"location.href='.*?'"|location.href='[^']*?'(?=[\s>])))@$1onclick="location.href='$oopsUrl\?template=oopspreview'"@goi;

    $ptext = $session->{renderer}->putBackBlocks( $ptext, \@verbatim,
                                                  "verbatim", "pre",
                                                  \&TWiki::Render::verbatimCallBack );

    $tmpl = $session->handleCommonTags( $tmpl, $topic );
    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, 0 );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl );
    $tmpl =~ s/%TEXT%/$ptext/go;

    $text = TWiki::encodeSpecialChars( $text );

    $tmpl =~ s/%HIDDENTEXT%/$text/go;
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $session->writeCompletePage( $tmpl );
}

1;
