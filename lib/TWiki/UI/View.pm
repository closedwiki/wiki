# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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
=begin twiki

---+ TWiki::UI::View

UI delegate for view function

=cut

package TWiki::UI::View;

use strict;
use TWiki;
use TWiki::User;
use TWiki::UI;

=pod

---++ view( $web, $topic, $scruptUrl, $query )
Generate a complete HTML page that represents the viewed topics.
The view is controlled by CGI parameters as follows:
| =rev= | topic revision to view |
| =raw= | no format body text if set |
| =skin= | name of skin to use |
| =contenttype= | |

=cut
sub view {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topicName = $session->{topicName};

    my $viewRaw = $query->param( "raw" ) || "";
    my $contentType = $query->param( "contenttype" );

    my $maxrev = 1;
    my $extra = "";
    my $revdate = "";
    my $revuser = "";

    TWiki::UI::checkWebExists( $session, $webName, $topicName );

    my $skin = $session->getSkin();

    # Set page generation mode to RSS if using an RSS skin
    if( $skin =~ /^rss/ ) {
        $session->{renderer}->setRenderMode( 'rss' );
    }

    my $rev = $session->{store}->cleanUpRevID( $query->param( "rev" ));

    my $topicExists =
      $session->{store}->topicExists( $webName, $topicName );
    # text and meta of the _latest_ rev of the topic
    my( $currText, $currMeta );
    # text and meta of the chosen rev of the topic
    my( $meta, $text );
    if( $topicExists ) {
        ( $currMeta, $currText ) = $session->{store}->readTopic
          ( undef, $webName, $topicName, undef );
        ( $revdate, $revuser, $maxrev ) =
          $currMeta->getRevisionInfo( $webName, $topicName );

        $revdate = TWiki::formatTime( $revdate );

        if ( !$rev || $rev > $maxrev ) {
            $rev = $maxrev;
        } elsif ( $rev < 0 ) {
            $rev = 1;
        }

        if( $rev < $maxrev ) {
            # Note: the most recent topic read in even if earlier rev
            # requested. The most recent rev is required for access
            # control checking.
            ( $meta, $text ) = $session->{store}->readTopic
              ( $session->{user}, $webName, $topicName, $rev );

            ( $revdate, $revuser ) = $meta->getRevisionInfo();
            $revdate = TWiki::formatTime( $revdate );
            $extra .= "r$rev";
        } else {
            # viewing the most recent rev
            ( $text, $meta ) = ( $currText, $currMeta );
        }
    } else { # Topic does not exist yet
        $rev = 1;
        if( TWiki::isValidTopicName( $topicName )) {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, "WebTopicViewTemplate" );
        } else {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, "WebTopicNonWikiTemplate" );
        }
        ( $text, $meta ) = ( $currText, $currMeta );
        $extra .= " (not exist)";
    }

    if( $viewRaw ) {
        $extra .= " raw=$viewRaw";
        if( $viewRaw =~ /debug/i ) {
            $text = $session->{store}->getDebugText( $meta, $text );
        }
        # a skin name starting with the word 'text' is intended to be
        # used like this:
        # http://.../view/Codev/MyTopic?skin=text&contenttype=text/plain&raw=on
        # which shows the topic as plain text; useful for those who want
        # to download plain text for the topic.
        # SMELL: this is not documented anywhere that I can find, and the
        # poor slob who creates "texture_skin" is going to get a hell of
        # a shock! This should be done with "raw=text", not with a skin.
        if( $skin !~ /^text/ ) {
            my $vtext = "<form><textarea readonly=\"readonly\" " .
              "wrap=\"virtual\" rows=\"\%EDITBOXHEIGHT%\" " .
                "cols=\"\%EDITBOXWIDTH%\">";
            $vtext = $session->handleCommonTags( $vtext, $topicName );
            $text = TWiki::entityEncode( $text );
            $text =~ s/\t/   /go;
            $text = "$vtext$text</textarea></form>";
        }
    } else {
        $text = $session->handleCommonTags( $text, $topicName );
        $text = $session->{renderer}->getRenderedVersion( $text );
    }

    if( $TWiki::cfg{Log}{view} ) {
        # write log entry
        $session->writeLog( "view", "$webName.$topicName", $extra );
    }

    # get view template, standard view or a view with a different skin
    my $tmpl = $session->{templates}->readTemplate( "view", $skin );
    if( ! $tmpl ) {
        my $mess = "<html><body>\n"
          . "<h1>TWiki Installation Error</h1>\n"
            . "Template file view.tmpl not found or template directory \n"
              . "$TWiki::cfg{TemplateDir} not found.<p />\n"
                . "Check the configuration setting for TemplateDir\n"
                  . "</body></html>\n";
        $session->writeCompletePage( $mess );
        return;
    }

    my( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote ) =
      $session->readOnlyMirrorWeb( $webName );

    if( $mirrorSiteName ) {
        # disable edit and attach
        # FIXME: won't work with non-default skins, see %EDITURL%
        $tmpl =~ s/%EDITTOPIC%/$mirrorLink | <strike>Edit<\/strike>/go;
        $tmpl =~ s/<a [^>]*?>Attach<\/a>/<strike>Attach<\/strike>/goi;
        if( $topicExists ) {
            # remove the NOINDEX meta tag
            $tmpl =~ s/<meta name="robots"[^>]*>//goi;
        } else {
            $text = "";
        }
        $tmpl =~ s/%REVTITLE%//go;
    } elsif( $rev < $maxrev ) {
        # disable edit of previous revisions - FIXME consider change
        # to use two templates
        # SMELL: won't work with non-default skins, see %EDITURL%
        $tmpl =~ s/%EDITTOPIC%/<strike>Edit<\/strike>/go;
        $tmpl =~ s/<a [^>]*?>Attach<\/a>/<strike>Attach<\/strike>/goi;
        $tmpl =~ s|<a [^>]*?>Rename/move<\/a>|<strike>Rename/move<\/strike>|goi;
        $tmpl =~ s/%REVTITLE%/\(r$rev\)/go;
        $tmpl =~ s/%REVARG%/&rev=$rev/go;
    } else {
        # Remove the NOINDEX meta tag (for robots) from both Edit and 
        # Create pages
        $tmpl =~ s/<meta name="robots"[^>]*>//goi;
        my $editAction = $topicExists ? 'Edit' : 'Create';
        # Special case for 'view' to handle %EDITTOPIC% and Edit vs.
        # Create.
        # New %EDITURL% variable is implemented by handleCommonTags,
        # suffixes '?t=NNNN' to ensure that every Edit link is unique,
        # fixing
        # Codev.RefreshEditPage bug relating to caching of Edit page.
        $tmpl =~ s!%EDITTOPIC%!<a href=\"%EDITURL%\"><b>$editAction</b></a>!go;

        # FIXME: Implement ColasNahaboo's suggested %EDITLINK% along
        # same lines, within handleCommonTags
        $tmpl =~ s/%REVTITLE%//go;
        $tmpl =~ s/%REVARG%//go;
    }

    # SMELL: HUH? - TODO: why would you not show the revisions around
    # the version that you are displaying? and this logic is yucky@!
    my $i = $maxrev;
    my $j = $maxrev;
    my $revisions = "";
    my $breakRev = 0;
    if( ( $TWiki::cfg{NumberOfRevisions} > 0 ) &&
        ( $TWiki::cfg{NumberOfRevisions} < $maxrev ) ) {
        $breakRev = $maxrev - $TWiki::cfg{NumberOfRevisions} + 1;
    }
    while( $i > 0 ) {
        if( $i == $rev) {
            $revisions = "$revisions | r$i";
        } else {
            $revisions = "$revisions | <a href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=$i\">r$i</a>";
        }
        if( $i != 1 ) {
            if( $i == $breakRev ) {
                $i = 1;
            } else {
                $j = $i - 1;
                $revisions = "$revisions | <a href=\"%SCRIPTURLPATH%/rdiff%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=$i&amp;rev2=$j\">&gt;</a>";
            }
        }
        $i = $i - 1;
    }
    $tmpl =~ s/%REVISIONS%/$revisions/go;

    $tmpl =~ s/%REVINFO%/%REVINFO%$mirrorNote/go;

    $tmpl = $session->handleCommonTags( $tmpl, $topicName, $webName );

    if( $viewRaw ) {
        $tmpl =~ s/%META{[^}]*}%//go;
    } else {
        $tmpl = $session->{renderer}->renderMetaTags( $webName, $topicName, $tmpl, $meta, ( $rev == $maxrev ) );
    }

    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, "", $meta );

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%MAXREV%/$maxrev/go;
    $tmpl =~ s/%CURRREV%/$rev/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    # Write header based on "contenttype" parameter, used to produce
    # MIME types like text/plain or text/xml, e.g. for RSS feeds.
    if( $contentType ) {
        if( $skin =~ /^rss/ ) {
            $tmpl =~ s/<img [^>]*>//g;  # remove image tags
            $tmpl =~ s/<a [^>]*>//g;    # remove anchor tags
            $tmpl =~ s/<\/a>//g;        # remove anchor tags
        }
    } elsif( $skin =~ /^rss/ ) {
        $tmpl =~ s/<img [^>]*>//g;  # remove image tags
        $tmpl =~ s/<a [^>]*>//g;    # remove anchor tags
        $tmpl =~ s/<\/a>//g;        # remove anchor tags
        $contentType = 'text/xml';
    } else {
        $contentType = 'text/html'
    }
    $session->writeCompletePage( $tmpl );
}

=pod

---++ viewfile( $web, $topic, $query )
Command handler for viewfile. View a file in the browser.
Some parameters are passed in CGI query:
| =filename= | |
| =rev= | |

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
                                  -Content_Disposition => "inline;filename=$fileName");
            print "$fileContent";
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
    $session->redirect( "$host$TWiki::cfg{PubUrlPath}/$webName/$topic/$fileName" );
}

sub _suffixToMimeType {
    my( $session, $theFilename ) = @_;

    my $mimeType = 'text/plain';
    if( $theFilename =~ /\.(.+)$/ ) {
        my $suffix = $1;
        my @types = grep{ s/^\s*([^\s]+).*?\s$suffix\s.*$/$1/i }
          map{ "$_ " }
            split( /[\n\r]/, $session->{store}->readFile( $TWiki::cfg{MimeTypesFileName} ) );
        $mimeType = $types[0] if( @types );
    }
    return $mimeType;
}

1;
