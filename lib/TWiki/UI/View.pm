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
| =raw= | don't format body text if set |
| =unlock= | remove any topic locks if set |
| =skin= | name of skin to use |
| =contenttype= | |

=cut

sub view {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topicName = $session->{topicName};

    my $viewRaw = $query->param( "raw" ) || "";
    my $unlock  = $query->param( "unlock" ) || "";
    my $contentType = $query->param( "contenttype" );

    my $text = "";
    my $meta = "";
    my $maxrev = 1;
    my $extra = "";
    my $wikiUserName = $session->{users}->userToWikiName( $session->{userName} );
    my $revdate = "";
    my $revuser = "";

    return unless TWiki::UI::webExists( $session, $webName, $topicName );

    my $skin = $session->getSkin();

    # Set page generation mode to RSS if using an RSS skin
    if( $skin =~ /^rss/ ) {
        $session->{renderer}->setRenderMode( 'rss' );
    }

    if( $unlock eq "on" ) {
        # unlock topic, user cancelled out of edit
        $session->{store}->lockTopic( $webName, $topicName, "on" );
    }

    my $rev = $session->{store}->cleanUpRevID( $query->param( "rev" ));
    my $topicExists = $session->{store}->topicExists( $webName, $topicName );
    if( $topicExists ) {
        ( $meta, $text ) = $session->{store}->readTopic( $wikiUserName,
                                                     $webName, $topicName,
                                                     undef, 1 );
        ( $revdate, $revuser, $maxrev ) =
          $meta->getRevisionInfo( $webName, $topicName );

        $revdate = TWiki::formatTime( $revdate );

        if ( !$rev || $rev > $maxrev ) {
            $rev = $maxrev;
        } elsif ( $rev < 0 ) {
            $rev = 1;
        }

        if( $rev < $maxrev ) {
            # Most recent topic read in even if earlier topic requested - makes
            # code simpler and performance impact should be minimal
            ( $meta, $text ) =
              $session->{store}->readTopic( $wikiUserName,
                                        $webName, $topicName, $rev, 0 );

            # SMELL: why doesn't this use $meta?
            ( $revdate, $revuser ) =
              $session->{store}->getRevisionInfo( $webName, $topicName, $rev );
            $revdate = TWiki::formatTime( $revdate );
            $extra .= "r$rev";
        }
    } else { # Topic does not exist yet
        $rev = 1;
        if( TWiki::isValidTopicName( $topicName )) {
            ( $meta, $text ) =
              TWiki::UI::readTemplateTopic( $session, "WebTopicViewTemplate" );
        } else {
            ( $meta, $text ) =
              TWiki::UI::readTemplateTopic( $session, "WebTopicNonWikiTemplate" );
        }
        $extra .= " (not exist)";
    }

    # This has to be done before $text is rendered!!
    my $viewAccessOK =
      $session->{security}->checkAccessPermission( "view", $wikiUserName, $text, $topicName, $webName );
    # SMELL: why wait so long before processing this if the read access failed?

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

    if( $TWiki::doLogTopicView ) {
        # write log entry
        $session->writeLog( "view", "$webName.$topicName", $extra );
    }

    # get view template, standard view or a view with a different skin
    my $tmpl = $session->{templates}->readTemplate( "view", $skin );
    if( ! $tmpl ) {
        my $mess = "<html><body>\n"
          . "<h1>TWiki Installation Error</h1>\n"
            . "Template file view.tmpl not found or template directory \n"
              . "$TWiki::templateDir not found.<p />\n"
                . "Check the \$templateDir variable in TWiki.cfg.\n"
                  . "</body></html>\n";
        $session->writeHeader( $query, length( $mess ));
        print $mess;
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

        # Special case for 'view' to handle %EDITTOPIC% and Edit vs. Create.
        # New %EDITURL% variable is implemented by handleCommonTags, suffixes
        # '?t=NNNN' to ensure that every Edit link is unique, fixing
        # Codev.RefreshEditPage bug relating to caching of Edit page.
        $tmpl =~ s!%EDITTOPIC%!<a href=\"%EDITURL%\"><b>$editAction</b></a>!go;

        # FIXME: Implement ColasNahaboo's suggested %EDITLINK% along the 
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
    if( ( $TWiki::numberOfRevisions > 0 ) &&
        ( $TWiki::numberOfRevisions < $maxrev ) ) {
        $breakRev = $maxrev - $TWiki::numberOfRevisions + 1;
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
    $tmpl = $session->handleCommonTags( $tmpl, $topicName );

    if( $viewRaw ) {
        $tmpl =~ s/%META{[^}]*}%//go;
    } else {
        $tmpl = $session->{renderer}->renderMetaTags( $webName, $topicName, $tmpl, $meta, ( $rev == $maxrev ) );
    }
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, "", $meta ); ## better to use meta rendering?

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%MAXREV%/$maxrev/go;
    $tmpl =~ s/%CURRREV%/$rev/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> tags (PTh 06 Nov 2000)

    # Check if some part of the sequence of Store accesses failed
    if( $session->{store}->accessFailed() ) {
        # Can't read requested topic and/or included (or other accessed topics
        # user could not be authenticated, may be not logged in yet?
        my $viewauthFile = $ENV{'SCRIPT_FILENAME'};
        # SMELL: depends on view script being called view. And what if this
        # script is _already_ viewauth? Could use \b, but still depends on
        # the name.
        $viewauthFile =~ s|/view|/viewauth|o;
        if( ( ! $query->remote_user() ) && (-e $viewauthFile ) ) {
            # try again with authenticated viewauth script
            # instead of non authenticated view script
            my $url = $ENV{"REQUEST_URI"};
            if( $url && $url =~ m|/view| ) {
                # $url i.e. is "twiki/bin/view.cgi/Web/Topic?cms1=val1&cmd2=val2"
                $url =~ s|/view|/viewauth|o;
                $url = "Urlhost()$url";
            } else {
                # If REQUEST_URI is rewritten and does not contain the name "view"
                # try looking at the CGI environment variable SCRIPT_NAME.
                #
                # Assemble the new URL using the host, the changed script name,
                # the path info, and the query string.  All three query variables
                # are in the list of the canonical request meta variables in CGI 1.1.
                my $script      = $ENV{'SCRIPT_NAME'};
                my $pathInfo    = $ENV{'PATH_INFO'};
                my $queryString = $ENV{'QUERY_STRING'};
                $pathInfo    = '/' . $pathInfo    if ($pathInfo);
                $queryString = '?' . $queryString if ($queryString);
                if ($script && $script =~ m|/view| ) {
                    $script =~ s|/view|/viewauth|o;
                    $url = "Urlhost()$script$pathInfo$queryString";
                } else {
                    # If SCRIPT_NAME does not contain the name "view"
                    # the last hope is to try the SCRIPT_FILENAME ...
                    $viewauthFile =~ s|^.*/viewauth|/viewauth|o;  # strip off $Twiki::scriptUrlPath
                    $url = $session->{urlhost}.$session->{scriptUrlPath}."/$viewauthFile$pathInfo$queryString";
                }
            }
            TWiki::UI::redirect( $session, $url );
        }
    }
    if( $topicExists && ! $viewAccessOK ) {
        TWiki::UI::oops( $session, $webName, $topicName, "accessview" );
    }

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

    $session->writeHeaderFull( $query, 'basic', $contentType, length( $tmpl ));
    print $tmpl;
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

    return unless TWiki::UI::webExists( $session, $webName, $topic );

    my $topRev = $session->{store}->getRevisionNumber( $webName, $topic, $fileName );

    if( ( $rev ) && ( $rev ne $topRev ) ) {
        my $fileContent =
          $session->{store}->readAttachmentVersion( $webName, $topic,
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

    my $pubUrlPath = $TWiki::pubUrlPath;
    my $host = $session->{urlHost};
    TWiki::UI::redirect( $session, "$host$pubUrlPath/$webName/$topic/$fileName" );
}

sub _suffixToMimeType {
    my( $session, $theFilename ) = @_;

    my $mimeType = 'text/plain';
    if( $theFilename =~ /\.(.+)$/ ) {
        my $suffix = $1;
        my @types = grep{ s/^\s*([^\s]+).*?\s$suffix\s.*$/$1/i }
          map{ "$_ " }
            split( /[\n\r]/, $session->{store}->readFile( $TWiki::mimeTypesFilename ) );
        $mimeType = $types[0] if( @types );
    }
    return $mimeType;
}

1;
