# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

=begin twiki

---+ package TWiki::UI::View

UI delegate for view function

=cut

package TWiki::UI::View;

use strict;
use integer;

use TWiki;
use TWiki::User;
use TWiki::UI;
use TWiki::Time;

=pod

---++ StaticMethod view( $session, $web, $topic, $scruptUrl, $query )
=view= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Generate a complete HTML page that represents the viewed topics.
The view is controlled by CGI parameters as follows:

| =rev= | topic revision to view |
| =raw= | no format body text if set |
| =skin= | name of skin to use |
| =contenttype= | Allows you to specify an alternate content type |

=cut
sub view {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topicName = $session->{topicName};

    my $viewRaw = $query->param( 'raw' ) || '';
    my $contentType = $query->param( 'contenttype' );

    my $showRev = 1;
    my $extra = '';
    my $revdate = '';
    my $revuser = '';

    TWiki::UI::checkWebExists( $session, $webName, $topicName );

    my $skin = $session->getSkin();

    # Set page generation mode to RSS if using an RSS skin
    if( $skin =~ /^rss/ ) {
        $session->{renderer}->setRenderMode( 'rss' );
    }

    my $rev = $session->{store}->cleanUpRevID( $query->param( 'rev' ));

    my $topicExists =
      $session->{store}->topicExists( $webName, $topicName );
    # text and meta of the _latest_ rev of the topic
    my( $currText, $currMeta );
    # text and meta of the chosen rev of the topic
    my( $meta, $text );
    if( $topicExists ) {
        ( $currMeta, $currText ) = $session->{store}->readTopic
          ( $session->{user}, $webName, $topicName, undef );
        ( $revdate, $revuser, $showRev ) =
          $currMeta->getRevisionInfo( $webName, $topicName );

        $revdate = TWiki::Time::formatTime( $revdate );

        if ( !$rev || $rev > $showRev ) {
            $rev = $showRev;
        } elsif ( $rev < 0 ) {
            $rev = 1;
        }

        if( $rev < $showRev ) {
            # Note: the most recent topic read in even if earlier rev
            # requested.
            ( $meta, $text ) = $session->{store}->readTopic
              ( $session->{user}, $webName, $topicName, $rev );

            ( $revdate, $revuser ) = $meta->getRevisionInfo();
            $revdate = TWiki::Time::formatTime( $revdate );
            $extra .= 'r'.$rev;
        } else {
            # viewing the most recent rev
            ( $text, $meta ) = ( $currText, $currMeta );
        }
    } else { # Topic does not exist yet
        $rev = 1;
        if( TWiki::isValidTopicName( $topicName )) {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, 'WebTopicViewTemplate' );
        } else {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, 'WebTopicNonWikiTemplate' );
        }
        ( $text, $meta ) = ( $currText, $currMeta );
        $extra .= ' (not exist)';
    }

    if( $viewRaw ) {
        $extra .= ' raw='.$viewRaw;
        if( $viewRaw =~ /debug/i ) {
            $text = $session->{store}->getDebugText( $meta, $text );
        }
        # a skin name starting with the word 'text' is intended to be
        # used like this:
        # http://.../view/Codev/MyTopic?skin=text&contenttype=text/plain&raw=on
        # which shows the topic as plain text; useful for those who want
        # to download plain text for the topic.
        # SMELL: this is not documented anywhere that I can find, and the
        # poor slob who creates 'texture_skin' is going to get a hell of
        # a shock! This should be done with "raw=text", not with a skin.
        if( $skin !~ /^text\b/ ) {
            my $p = $session->{prefs};
            $text =
              CGI::textarea
                  ( -readonly => 'readonly',
                    -wrap => 'virtual',
                    -rows => $p->getPreferencesValue('EDITBOXHEIGHT'),
                    -cols => $p->getPreferencesValue('EDITBOXWIDTH'),
                    -style => $p->getPreferencesValue('EDITBOXSTYLE'),
                    -default => "\n".$text
                  );
        }
    } else {
        $text = $session->handleCommonTags( $text, $webName, $topicName );
        $text = $session->{renderer}->getRenderedVersion( $text,
                                                          $webName,
                                                          $topicName );
    }

    if( $TWiki::cfg{Log}{view} ) {
        # write log entry
        $session->writeLog( 'view', $webName.'.'.$topicName, $extra );
    }

    # get view template, standard view or a view with a different skin
    my $tmpl = $session->{templates}->readTemplate( 'view', $skin );
    if( ! $tmpl ) {
        my $mess = CGI::start_html().
          CGI::h1('TWiki Installation Error').
          'Template file view.tmpl not found or template directory'.
            $TWiki::cfg{TemplateDir}.' not found.'.CGI::p().
              'Check the configuration setting for TemplateDir'.
                CGI::end_html();
        $session->writeCompletePage( $mess );
        return;
    }

    my( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote ) =
      $session->readOnlyMirrorWeb( $webName );

    # is this view indexable by search engines?
    my $indexableView = 1;

    if( $mirrorSiteName ) {
        # disable edit and attach
        # FIXME: won't work with non-default skins, see %EDITURL%
        $tmpl =~ s/%EDITTOPIC%/$mirrorLink.' | '.CGI::strike('Edit')/ge;
        $tmpl =~ s/<a\s[^>]*href="[^"]*\/(attach|rename)\b[^>]*>(.*?)<\/a>/CGI::strike($2)/gei;
        if( $topicExists ) {
            # allow view to be indexed
            $indexableView = 1;
        } else {
            $text = '';
        }
        $tmpl =~ s/%REVTITLE%//go;
    } elsif( $rev < $showRev ) {
        # disable edit of previous revisions - FIXME consider change
        # to use two templates
        # SMELL: won't work with non-default skins, see %EDITURL%
        $tmpl =~ s/%EDITTOPIC%/CGI::strike('Edit')/ge;
        $tmpl =~ s/<a\s[^>]*href="[^"]*\/(attach|rename)\b[^>]*>(.*?)<\/a>/CGI::strike($2)/gei;
        $tmpl =~ s/%REVTITLE%/(r$rev)/go;
        $tmpl =~ s/%REVARG%/&rev=$rev/go;
    } else {
        $indexableView = 1;
        my $editAction = $topicExists ? 'Edit' : 'Create';
        my $ea = CGI::a( { href => $session->{SESSION_TAGS}{EDITURL},
                           rel => 'nofollow' },
                         CGI::b($editAction));
        $tmpl =~ s/%EDITTOPIC%/$ea/go;
        $tmpl =~ s/%REVTITLE%//go;
        $tmpl =~ s/%REVARG%//go;
    }

    if( $indexableView && ! keys %{$query->Vars()} ) {
        # it's an indexable view type and there are no parameters
        # on the url. Remove the NOINDEX meta tag
        $tmpl =~ s/<meta name="robots"[^>]*>//goi;
    }

    # Show revisions around the one being displayed
    # we start at $showRev then possibly jump near $rev if too distant
    my $revsToShow = $TWiki::cfg{NumberOfRevisions} + 1;
    $revsToShow = $showRev if $showRev < $revsToShow;
    my $doingRev = $showRev;
    my $revs;
    while( $revsToShow > 0 ) {
        $revsToShow--;
        if( $doingRev == $rev) {
            $revs .= ' r'.$rev;
        } else {
            $revs .= CGI::a({
                             href=>$session->getScriptUrl( $webName,
                                                           $topicName,
                                                           'view',
                                                           rev => $doingRev ),
                             rel => 'nofollow'
                            },
                            " r$doingRev" );
        }
        if ($doingRev-$rev >= $TWiki::cfg{NumberOfRevisions}) {
            # we started too far away, need to jump closer to $rev
            use integer;
            $doingRev = $rev + $revsToShow / 2;
            $doingRev = $revsToShow if $revsToShow > $doingRev;
            $revs .= ' |';
            next;
        }
        if( $revsToShow ) {
            $revs .= CGI::a
              ( { href=>$session->getScriptUrl
                  ( $webName, $topicName, 'rdiff',
                    rev1 => $doingRev,
                    rev2 => $doingRev-1 ),
                  rel => 'nofollow' },
                '&gt;' );
        }
        $doingRev--;
    }
    $tmpl =~ s/%REVISIONS%/$revs/go;
    $tmpl =~ s/%REVINFO%/%REVINFO%$mirrorNote/go;
    $tmpl =~ m/^(.*)%TEXT%(.*$)/s;

    my $start = $1;
    my $end = $2;
    my $strip = 0;
    if( $contentType ) {
        $strip = ( $skin =~ /^rss/ );
    } elsif( $skin =~ /^rss/ ) {
        $contentType = 'text/xml';
        $strip = 1;
    } else {
        $contentType = 'text/html'
    }
    $session->{SESSION_TAGS}{MAXREV} = $showRev;
    $session->{SESSION_TAGS}{CURRREV} = $rev;

    $session->writePageHeader( undef, undef, $contentType, 0 );

    # output in three chunks in case the text takes a long time to render.
    # the client can keep busy fetching the stylesheet, if it's smart.
    my $isTop = ( $rev == $showRev );
    _bungOut($start, $session, $webName, $topicName, $meta, $isTop, $viewRaw, $strip, 0);

    _bungOut( $text, $session, $webName, $topicName,$meta, $isTop, $viewRaw, $strip, 1);

    _bungOut($end, $session, $webName, $topicName, $meta, $isTop, $viewRaw, $strip, 0);
}

sub _bungOut {
    my ($text, $session, $webName, $topicName, $meta, $isTop, $viewRaw, $strip, $isText) = @_;
    my $renderer = $session->{renderer};

    unless( $viewRaw && $isText ) {
        $text = $renderer->renderMetaTags
          ( $webName, $topicName, $text, $meta, $isTop, $viewRaw );

        $text = $session->handleCommonTags( $text, $webName, $topicName );
        $text = $renderer->getRenderedVersion( $text, $webName, $topicName );
        $text =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        # Write header based on 'contenttype' parameter, used to produce
        # MIME types like text/plain or text/xml, e.g. for RSS feeds.
        if( $strip ) {
            $text =~ s/<img [^>]*>//gi;  # remove image tags
            $text =~ s/<a [^>]*>//gi;    # remove anchor tags
            $text =~ s/<\/a>//gi;        # remove anchor tags
        }
    }
    print $text;
}

=pod

---++ StaticMethod viewfile( $session, $web, $topic, $query )
=viewfile= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Command handler for viewfile. View a file in the browser.
Some parameters are passed in CGI query:
| =filename= | Attachment to view |
| =rev= | Revision to view |

=cut

sub viewfile {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $fileName = $query->param( 'filename' );

    my $rev = $session->{store}->cleanUpRevID( $query->param( 'rev' ) );

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $topRev = $session->{store}->getRevisionNumber( $webName, $topic, $fileName );

    if( $rev && $rev ne $topRev ) {
        my $fileContent =
          $session->{store}->readAttachment( $session->{user}, $webName, $topic,
                                             $fileName, $rev );
        if( $fileContent ) {
            my $mimeType = _suffixToMimeType( $session, $fileName );
            print $query->header( -type => $mimeType,
                                  -Content_Disposition => 'inline;filename='.$fileName);
            print $fileContent;
            return;
        } else {
            # If no file content we'll try and show pub content, should there be a warning FIXME
        }
    }

    # this should actually kick off a document conversion 
    # (.doc, .xls... to .html) and show the html file.
    # Convert only if html file does not yet exist
    # for now, show the original document:
;
    my $host = $session->{urlHost};
    $session->redirect( $host.$TWiki::cfg{PubUrlPath}.
                        "/$webName/$topic/$fileName" );
}

sub _suffixToMimeType {
    my( $session, $theFilename ) = @_;

    my $mimeType = 'text/plain';
    if( $theFilename =~ /\.(.+)$/ ) {
        my $suffix = $1;
        my @types = grep{ s/^\s*([^\s]+).*?\s$suffix\s.*$/$1/i }
          map{ $_.' ' }
            split( /[\n\r]/, $session->{store}->readFile( $TWiki::cfg{MimeTypesFileName} ) );
        $mimeType = $types[0] if( @types );
    }
    return $mimeType;
}

1;
