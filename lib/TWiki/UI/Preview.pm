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

    my $theParent = $query->param( 'topicparent' ) || '';
    my $formTemplate = $query->param( 'formtemplate' );
    my $textparam = $query->param( 'text' );

    # get view template, standard view or a view with a different skin
    my $skin = $session->getSkin();
    my $tmpl = $session->{templates}->readTemplate( 'preview', $skin );
    if( $query->param( 'dontnotify' ) ) {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%/checked="checked"/go;
    } else {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%//go;
    }
    if( $query->param( 'forcenewrevision' ) ) {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/go;
    } else {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%//go;
    }
    my $saveCmd = $query->param( 'cmd' ) || '';
    $tmpl =~ s/%CMD%/$saveCmd/go;

    my( $meta, $text, $saveOpts, $merged ) =
      TWiki::UI::Save::buildNewTopic($session);

    my $formFields = '';
    my $form = $meta->get('FORM') || '';
    if( $form ) {
        $form = $form->{name};
        my $formDef = new TWiki::Form( $session, $webName, $form );
        $formFields = $formDef->renderHidden( $meta );
    }

    $session->{plugins}->afterEditHandler( $text, $topic, $webName );

    $tmpl =~ s/%FORMTEMPLATE%/$form/g;

    my $parent = $meta->get('TOPICPARENT');
    $parent = $parent->{name} if( $parent );
    $parent ||= '';
    $tmpl =~ s/%TOPICPARENT%/$parent/g;

    # SMELL: this is horrible, it only handles verbatim. It should be
    # done by getRenderedVersion with an override for the wikiword
    # handling.
    my $verbatim = {};
    $text = $session->{renderer}->takeOutBlocks( $text, 'verbatim',
                                                  $verbatim );
    $text = $session->handleCommonTags( $text, $webName, $topic );
    $text = $session->{renderer}->getRenderedVersion( $text, $webName, $topic );

    # Disable links and inputs
    $text =~ s(<a\s[^>]*>(.*?)</a>)
      (<span style="text-decoration:underline;color:blue">$1</span>)gis;
    $text =~ s/<(input|button|textarea) /<$1 disabled="disabled"/gis;
    $text =~ s(</?form(|\s.*?)>)()gis;
    $text =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

    $session->{renderer}->putBackBlocks( $text, $verbatim,
                                         'verbatim', 'pre',
                                         \&TWiki::Render::verbatimCallBack );

    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, 0, 0 );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );

    $tmpl =~ s/%TEXT%/$text/go;

    $text = TWiki::entityEncode( $text );
    $tmpl =~ s/%HIDDENTEXT%/$text/go;
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;

    $session->writeCompletePage( $tmpl );
}

1;
