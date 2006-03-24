# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2006 Peter Thoeny, peter@thoeny.org
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

=pod
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
| =skin= | comma-separated list of skin(s) to use |
| =contenttype= | Allows you to specify an alternate content type |

=cut

sub view {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topicName = $session->{topicName};

    my $raw = $query->param( 'raw' ) || '';
    my $contentType = $query->param( 'contenttype' );

    my $showRev = 1;
    my $logEntry = '';
    my $revdate = '';
    my $revuser = '';
    my $store = $session->{store};
    # is this view indexable by search engines? Default yes.
    my $indexableView = 1;

    $session->enterContext( 'view' );

    TWiki::UI::checkWebExists( $session, $webName, $topicName, 'view' );

    my $skin = $session->getSkin();

    my $rev = $store->cleanUpRevID( $query->param( 'rev' ));

    my $topicExists =
      $store->topicExists( $webName, $topicName );

    # text and meta of the _latest_ rev of the topic
    my( $currText, $currMeta );
    # text and meta of the chosen rev of the topic
    my( $meta, $text );
    if( $topicExists ) {
        ( $currMeta, $currText ) = $store->readTopic
          ( $session->{user}, $webName, $topicName, undef );
        TWiki::UI::checkAccess( $session, $webName, $topicName,
                                'view', $session->{user}, $currText );
        ( $revdate, $revuser, $showRev ) = $currMeta->getRevisionInfo();
        $revdate = TWiki::Time::formatTime( $revdate );

        throw Error::Simple( $rev.' is not a valid revision' )
          unless $rev =~ /^([\d\.]+)$/;

        if ( !$rev || $rev > $showRev ) {
            $rev = $showRev;
        } elsif ( $rev < 0 ) {
            $rev = 1;
        }
        if( $rev < $showRev ) {
            ( $meta, $text ) = $store->readTopic
              ( $session->{user}, $webName, $topicName, $rev );

            ( $revdate, $revuser ) = $meta->getRevisionInfo();
            $revdate = TWiki::Time::formatTime( $revdate );
            $logEntry .= 'r'.$rev;
        } else {
            # viewing the most recent rev
            ( $text, $meta ) = ( $currText, $currMeta );
        }
    } else { # Topic does not exist yet
        $indexableView = 0;
        $session->enterContext( 'new_topic' );
        $rev = 1;
        if( TWiki::isValidTopicName( $topicName )) {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, 'WebTopicViewTemplate' );
        } else {
            ( $currMeta, $currText ) =
              TWiki::UI::readTemplateTopic( $session, 'WebTopicNonWikiTemplate' );
        }
        ( $text, $meta ) = ( $currText, $currMeta );
        $logEntry .= ' (not exist)';
    }

    if( $raw ) {
        $indexableView = 0;
        $logEntry .= ' raw='.$raw;
        if( $raw eq 'debug' || $raw eq 'all' ) {
            $text = $store->getDebugText( $meta, $text );
        }
    }

    if( $TWiki::cfg{Log}{view} ) {
        $session->writeLog( 'view', $webName.'.'.$topicName, $logEntry );
    }

    my( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote ) =
      $session->readOnlyMirrorWeb( $webName );

    # Note; must enter all contexts before the template is read, as
    # TMPL:P is expanded on the fly in the template reader. :-(
    my( $revTitle, $revArg ) = ( '', '' );
    if( $mirrorSiteName ) {
        $session->enterContext( 'inactive' );
        unless( $topicExists ) {
            $text = '';
        }
    } elsif( $rev < $showRev ) {
        $session->enterContext( 'inactive' );
        # disable edit of previous revisions
        $revTitle = '(r'.$rev.')';
        $revArg = '&rev='.$rev;
    }

    my $template = $query->param( 'template' ) ||
      $session->{prefs}->getPreferencesValue( 'VIEW_TEMPLATE' ) ||
        'view';

    my $tmpl = $session->{templates}->readTemplate( $template, $skin );
    if( !$tmpl && $template ne 'view' ) {
        $tmpl = $session->{templates}->readTemplate( 'view', $skin );
    }

    if( !$tmpl ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'no_such_template',
                                    web => $webName,
                                    topic => $topicName,
                                    params => [ $template, 'VIEW_TEMPLATE' ] );
    }

    $tmpl =~ s/%REVINFO%/%REVINFO%$mirrorNote/go;
    $tmpl =~ s/%REVTITLE%/$revTitle/g;
    $tmpl =~ s/%REVARG%/$revArg/g;

    if( $indexableView &&
          $TWiki::cfg{AntiSpam}{RobotsAreWelcome} &&
            !$query->param() ) {
        # it's an indexable view type, there are no parameters
        # on the url, and robots are welcome. Remove the NOINDEX meta tag
        $tmpl =~ s/<meta name="robots"[^>]*>//goi;
    }

    # Show revisions around the one being displayed
    # we start at $showRev then possibly jump near $rev if too distant
    my $revsToShow = $TWiki::cfg{NumberOfRevisions} + 1;
    $revsToShow = $showRev if $showRev < $revsToShow;
    my $doingRev = $showRev;
    my $revs = '';
    while( $revsToShow > 0 ) {
        $revsToShow--;
        if( $doingRev == $rev) {
            $revs .= 'r'.$rev;
        } else {
            $revs .= CGI::a({
                             href=>$session->getScriptUrl( 0,
                                                           'view',
                                                           $webName,
                                                           $topicName,
                                                           rev => $doingRev ),
                             rel => 'nofollow'
                            },
                            "r$doingRev" );
        }
        if ( $doingRev - $rev >= $TWiki::cfg{NumberOfRevisions} ) {
            # we started too far away, need to jump closer to $rev
            use integer;
            $doingRev = $rev + $revsToShow / 2;
            $doingRev = $revsToShow if $revsToShow > $doingRev;
            $revs .= ' |';
            next;
        }
        if( $revsToShow ) {
            $revs .= '&nbsp;' . CGI::a
              ( { href=>$session->getScriptUrl(
                  0, 'rdiff', $webName, $topicName,
                  rev1 => $doingRev,
                  rev2 => $doingRev-1 ),
                  rel => 'nofollow' },
                '&lt;' ) . '&nbsp;';
        }
        $doingRev--;
    }

    my $ri = $session->{renderer}->renderRevisionInfo( $webName,
                                                       $topicName,
                                                       $meta );
    $tmpl =~ s/%REVINFO%/$ri/go;
    $tmpl =~ s/%REVISIONS%/$revs/go;

    # extract header and footer from the template, if there is a
    # %TEXT% tag marking the split point
    my( $start, $end );
    if( $tmpl =~ m/^(.*)%TEXT%(.*)$/so ) {
        $start = $1;
        $end = $2;
    } else {
        $start = $tmpl;
        $end = '';
	$text = '';
    }

    # If minimalist is set, images and anchors will be stripped from text
    my $minimalist = 0;
    if( $contentType ) {
        $minimalist = ( $skin =~ /\brss/o );
    } elsif( $skin =~ /\brss/o ) {
        $contentType = 'text/xml';
        $minimalist = 1;
    } elsif( $raw eq 'text' || $raw eq 'all' ) {
        $contentType = 'text/plain';
    } else {
        $contentType = 'text/html'
    }
    $session->{SESSION_TAGS}{MAXREV} = $showRev;
    $session->{SESSION_TAGS}{CURRREV} = $rev;

    # Set page generation mode to RSS if using an RSS skin
    $session->enterContext( 'rss' ) if $skin =~ /\brss/o;

    # Set the meta-object that contains the rendering info
    # SMELL: hack to get around not having a proper topic object model
    $session->enterContext( 'can_render_meta', $meta );

    my $page;
    # Legacy: If the _only_ skin is 'text' it is used like this:
    # http://.../view/Codev/MyTopic?skin=text&contenttype=text/plain&raw=on
    # which shows the topic as plain text; useful for those who want
    # to download plain text for the topic. So when the skin is 'text'
    # we do _not_ want to create a textarea.
    # raw=on&skin=text is deprecated; use raw=text instead.
    if( $raw eq 'text' || $raw eq 'all' || ( $raw && $skin eq 'text' )) {
        # use raw text
        $page = $text;
    } else {
        my @args = ( $session, $webName, $topicName, $meta, $minimalist );

        $session->enterContext( 'header_text' );
        $page = _prepare($start, @args);
        $session->leaveContext( 'header_text' );

        if( $raw ) {
            my $p = $session->{prefs};
            $page .=
              CGI::textarea( -readonly => 'readonly',
                             -wrap => 'virtual',
                             -rows => $p->getPreferencesValue('EDITBOXHEIGHT'),
                             -cols => $p->getPreferencesValue('EDITBOXWIDTH'),
                             -style => $p->getPreferencesValue('EDITBOXSTYLE'),
                             -default => $text
                           );
        } else {
            $session->enterContext( 'body_text' );
            $page .= _prepare($text, @args);
            $session->leaveContext( 'body_text' );
        }

        $session->enterContext( 'footer_text' );
        $page .= _prepare($end, @args);
        $session->leaveContext( 'footer_text' );
    }
    # Output has to be done in one go, because if we generate the header and
    # then redirect because of some later constraint, some browsers fall over
    $session->writeCompletePage( $page, 'view', $contentType )
}

sub _prepare {
    my( $text, $session, $webName, $topicName, $meta, $minimalist) = @_;

    $text = $session->handleCommonTags( $text, $webName, $topicName );
    $text = $session->{renderer}->getRenderedVersion( $text, $webName, $topicName );
    $text =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    if( $minimalist ) {
        $text =~ s/<img [^>]*>//gio;  # remove image tags
        $text =~ s/<a [^>]*>//gio;    # remove anchor tags
        $text =~ s/<\/a>//gio;        # remove anchor tags
    }

    return $text;
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

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'viewfile' );
    TWiki::UI::checkTopicExists( $session, $webName, $topic, 'viewfile' );
    unless( $fileName && $session->{store}->attachmentExists(
        $webName, $topic, $fileName )) {
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'no_such_attachment',
                                    web => $webName,
                                    topic => $topic,
                                    params => [ 'viewfile', $fileName||'?' ] );
    }
    my $fileContent = $session->{store}->readAttachment(
        $session->{user}, $webName, $topic, $fileName, $rev );

    print $query->header(
        -type => _suffixToMimeType( $session, $fileName ),
        -Content_length => length( $fileContent ),
        -Content_Disposition => 'inline;filename='.$fileName);
    print $fileContent;
}

sub _suffixToMimeType {
    my( $session, $theFilename ) = @_;

    my $mimeType = 'text/plain';
    if( $theFilename =~ /\.([^.]+)$/ ) {
        my $suffix = $1;
        my @types = grep{ s/^\s*([^\s]+).*?\s$suffix\s.*$/$1/i }
          map{ $_.' ' }
            split( /[\n\r]/,
                   TWiki::readFile( $TWiki::cfg{MimeTypesFileName} ) );
        $mimeType = $types[0] if( @types );
    }
    return $mimeType;
}

1;
