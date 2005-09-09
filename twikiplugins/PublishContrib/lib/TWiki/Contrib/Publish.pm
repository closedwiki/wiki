package TWiki::Contrib::Publish;

#
#  Publish site (generate static HTML)
#
#  Based on GenHTMLPlugin
#  Copyright (C) 2001 Motorola
#
#  Revisions Copyright (C) 2002, Eric Scouten
#  Cairo updates Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2001 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2001 Motorola Ltd.
# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
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
#

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use File::Copy;
use File::Path;
use lib ('.');
use lib ('../lib');
use TWiki;
use TWiki::Func;

use strict;

use vars qw( $ZipPubUrl $VERSION $session );

$VERSION = 1.302;

#  Main rendering loop.
sub main {

    # Read command-line arguments and make 

    # Fill in default environment variables if invoked from command-line.

    $ENV{HTTP_USER_AGENT} = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" unless(exists $ENV{HTTP_USER_AGENT});
    $ENV{HTTP_HOST} = "localhost" unless(exists $ENV{HTTP_HOST});
    $ENV{REMOTE_ADDR} = "127.0.0.1" unless(exists $ENV{REMOTE_ADDR});
    $ENV{REMOTE_PORT} = "2509" unless(exists $ENV{REMOTE_PORT});
    $ENV{REMOTE_USER} = "TWikiGuest" unless(exists $ENV{REMOTE_USER});
    $ENV{REQUEST_METHOD} = "GET" unless(exists $ENV{REQUEST_METHOD});
    $ENV{QUERY_STRING} = "" unless(exists $ENV{QUERY_STRING});

    # Tweak environment variables depending on command-line arguments.

    foreach my $arg (@ARGV) {
        if ($arg =~ /^\-/) {
            if ($arg eq "-y") {
                if ($ENV{QUERY_STRING}) {
                    $ENV{QUERY_STRING} .= "&goAhead=yes";
                } else {
                    $ENV{QUERY_STRING} = "goAhead=yes";
                }
            } else {
                die "Unknown command-line option $arg\n";
            }
        } else {
            $ENV{PATH_INFO} = "/$arg" unless(exists $ENV{PATH_INFO});
        }
    }

    # Now do normal CGI init.

    my $query = new CGI;

    $| = 0;

    my $pi = $query->path_info();
    if( $query->param('web')) {
        $pi = '/'.$query->param('web');
    }

    my ($topic, $web, $wikiName);

    if( defined &TWiki::new ) {
        $session = new TWiki($pi, $query->remote_user(), '',
                            $query->url(), $query);
        $TWiki::Plugins::SESSION = $session;
        $topic = $session->{topicName};
        $web = $session->{webName};
        $wikiName = $session->{user}->wikiName();
    } else {
        my( $userName, $scriptUrlPath, $dataDir );
        ($topic, $web, $scriptUrlPath, $userName, $dataDir) =
          TWiki::initialize($pi, $query->remote_user(), '', # COMPATIBILITY
                            $query->url(), $query);
        $wikiName = TWiki::Func::userToWikiName($userName);
    }

    unless ( defined $TWiki::cfg{PublishContrib}{Dir} &&
             defined $TWiki::cfg{PublishContrib}{Dir}) {
        die "Configuration is missing; run install script";
    }

    my ($inclusions, $exclusions, $topicsearch, $skin);
    my $notify="off";

    # Load defaults from a config topic if one was specified
    my $configtopic = $query->param('configtopic');
    if ( $configtopic ) {
        unless( TWiki::Func::topicExists($web, $configtopic) ) {
            die "Specified configuration topic does not exist in $web!\n";
        }
        my $text = TWiki::Func::readTopicText($web, $configtopic);
        unless( TWiki::Func::checkAccessPermission( "VIEW", $wikiName,
                                                    $text, $configtopic,
                                                    $web)) {
            die "Access to $configtopic denied";
        }
        $text =~ s/\r//g;

        while ( $text =~ s/^\s+\*\s+Set\s+([A-Z]+)\s*=(.*?)$//m ) {
            my $k = $1;
            my $v = $2;
            $v =~ s/^\s*(.*?)\s*$/$1/go;

            if ( $k eq "INCLUSIONS" ) {
                $inclusions = $v;
            } elsif ( $k eq "EXCLUSIONS" ) {
                $exclusions = $v;
            } elsif ( $k eq "TOPICSEARCH" ) {
                $topicsearch = $v;
            } elsif ( $k eq "PUBLISHSKIN" ) {
                $skin = $v;
            } elsif ( $k eq "SKIN" ) {
                $skin = $v;
            }
        }
    } else {
        if ( defined($query->param('notify')) ) {
            $notify = $query->param('notify');
        }
        if ( defined($query->param('inclusions')) ) {
            $inclusions = $query->param('inclusions');
        } else {
            $inclusions = '*';
        }
        $exclusions = $query->param('exclusions') || '';
        $topicsearch = $query->param('topicsearch') || '';
    }
    # convert wildcard pattern to RE
    $inclusions =~ s/([*?])/.$1/g;
    $inclusions =~ s/,/|/g;
    $exclusions =~ s/([*?])/.$1/g;
    $exclusions =~ s/,/|/g;

    $skin ||= $query->param('publishskin') ||
      TWiki::Func::getPreferencesValue("PUBLISHSKIN");

    my $ok = 1;
    if ( ! -d $TWiki::cfg{PublishContrib}{Dir} &&
         ! -e $TWiki::cfg{PublishContrib}{Dir}) {
        mkdir($TWiki::cfg{PublishContrib}{Dir}, 0777);
        $ok = !($!);
    }
    die "Can't publish because no useable publish directory was found. Please notify your TWiki administrator" unless -d $TWiki::cfg{PublishContrib}{Dir};
    die "Can't publish because publish URL was not set. Please notify your TWiki administrator" unless $TWiki::cfg{PublishContrib}{URL};

    my $tmp = TWiki::Func::formatTime(time());
    $tmp =~s/^(\d+)\s+(\w+)\s+(\d+).*/$1_$2_$3/g;
    my $zipfilename = $wikiName . "_" . $web . "_" . $tmp .".zip";

    # Has user selected topic(s) yet?

    my $goAhead = $query->param('goAhead');
    if (!$goAhead) {
        # redirect to the "publish" topic
        my $url = TWiki::Func::getScriptUrl('TWiki', 'PublishContrib', "view");
        $url .= '?publishweb='.$web.'&publishtopic='.$topic;
        TWiki::Func::redirectCgiQuery($query, $url);
    } else {
        TWiki::Func::writeHeader($query);
        my $tmpl = TWiki::Func::readTemplate("view", "print.pattern");
        $tmpl =~ s/%META{.*?}%//g;
        my($header, $footer) = split(/%TEXT%/, $tmpl);
        $header = TWiki::Func::expandCommonVariables( $header, $topic, $web );
        $header = TWiki::Func::renderText( $header, $web );
        print $header;
        print "<b>TWiki::cfg{PublishContrib}{Dir}: </b>$TWiki::cfg{PublishContrib}{Dir}<br />\n";
        print "<b>TWiki::cfg{PublishContrib}{URL}_PATH: </b>$TWiki::cfg{PublishContrib}{URL}<br />\n";
        print "<b>Config: $configtopic<br />\n" if $configtopic;
        print "<b>Skin: </b>$skin<br />\n";
        print "<b>Inclusions: </b>$inclusions<br />\n";
        print "<b>Exclusions: </b>$exclusions<br />\n";
        print "<b>Content Filter: </b>$topicsearch<p />\n";
        my $succeeded = publishWeb($web, $topic, $wikiName, $inclusions,
                                   $exclusions, $skin, $topicsearch,
                                   "$TWiki::cfg{PublishContrib}{Dir}/$zipfilename");

        my $text = "Published at $TWiki::cfg{PublishContrib}{URL}/$zipfilename";
        $text = TWiki::Func::expandCommonVariables( $text, $topic, $web );
        $text = TWiki::Func::renderText( $text, $web );
        print $text;
        $footer = TWiki::Func::expandCommonVariables( $footer, $topic, $web );
        $footer = TWiki::Func::renderText( $footer, $web );
        print $footer;
    }
}

#  Publish the contents of one web.
#
#  @param $web which web to publish
#  @param $topic topic that was selected
#  @param $inclusions REs describing which topics to include
#  @param $exclusions REs describing which topics to exclude
#
#  @return 1 if succeeded; 0 if failed (will have redirected to error page)

sub publishWeb {
    my ($web, $topic, $wikiName, $inclusions, $exclusions, $skin, $topicsearch, $destZip) = @_;

    # Get list of topics from this web.
    my @topics = TWiki::Func::getTopicList($web);

    # Choose template.
    my $tmpl = TWiki::Func::readTemplate("view", $skin);
    die "Couldn't find template\n" if(!$tmpl);

    my $zip = Archive::Zip->new();

    # Attempt to render each included page.
    my %copied;
    foreach my $topic (@topics) {
        print "<b>$topic: </b>\n";
        if( $topic !~ /^($inclusions)$/ ) {
            print "<span class='twikiAlert'>not included</span>";
        } elsif( $exclusions && $topic =~ /^($exclusions)$/ ) {
            print "<span class='twikiAlert'>excluded</span>";
        } else {
            publishTopic($web, $topic, $wikiName, $skin, $tmpl,
                         \%copied,
                         $topicsearch, $zip);
            print "published";
        }
        print "<br />\n";
    }

    $zip->writeToFileNamed( $destZip );

    return 1;
}

#  Publish one topic from web.
#
#  @param $web which web to publish
#  @param $topic which topic to publish
#  @param $skin which skin to use
#  @param \%copied map of copied resources to new locations
sub publishTopic {
    my ($web, $topic, $wikiName, $skin, $tmpl, $copied, $topicsearch, $zip) = @_;

    # Read topic data.
    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );

    if ( $topicsearch ) {
        if ( $text !~ /$topicsearch/ ) {
            return;
        }
    }
    unless( TWiki::Func::checkAccessPermission( "VIEW", $wikiName,
                                                $text, $topic, $web)) {
        print "View access to $topic denied; not ";
        return;
    }

    my ($revdate, $revuser, $maxrev);
    if( $session ) {
        ($revdate, $revuser, $maxrev) = $meta->getRevisionInfo();
        $revuser = $revuser->wikiName();
    } else {
        TWiki::Store::getRevisionInfoFromMeta( # COMPATIBILITY
            $web, $topic, $meta, 'isoFormat' );
        $revuser = TWiki::userToWikiName($revuser); # COMPATIBILITY
    }

    # Handle standard formatting.
    $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
    $text = TWiki::Func::renderText($text);

    $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
    if( $session ) {
        $tmpl = $session->{renderer}->renderMetaTags($web, $topic, $tmpl, $meta, 1);
    } else {
        $tmpl = TWiki::handleMetaTags($web, $topic, $tmpl, $meta, 1); # COMPATIBILITY
    }
    $tmpl = TWiki::Func::renderText($tmpl, "", $meta); ## better to use meta rendering?

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/<nopublish>.*?<\/nopublish>//gos;
    $tmpl =~ s/%MAXREV%/1.$maxrev/go;
    $tmpl =~ s/%CURRREV%/1.$maxrev/go;
    $tmpl =~ s/%REVTITLE%//go;
    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;   # remove <nop> tags (PTh 06 Nov 2000)
    # Strip unsatisfied WikiWords.
    my $ult = getUnsatisfiedLinkTemplate($web);
    $tmpl =~ s/$ult/$1/g;
    # Copy files from pub dir to rsrc dir in static dir.
    my $pub = "(?:http://$ENV{HTTP_HOST})?".TWiki::Func::getPubUrlPath();
    $tmpl =~ s!$pub/([^"']+)!&copyResource($web, $1, $copied, $zip)!ge;
    # Modify internal links.
    my $ilt;
    $ilt = TWiki::Func::getViewUrl('NOISE', 'NOISE');
    $ilt =~ s!/NOISE.*!!;
    # link to this web
    $tmpl =~ s!(href=["'])$ilt/$web/(\w+)!$1$2.html!go;
    # link to another web
    $tmpl =~ s!(href=["'])$ilt/(\w+/\w+)!$1../$2.html!go;
    # Remove base tag  - DZA
    $tmpl =~ s/<base[^>]+\/>//;
    # Handle SlideShow plugin urls
    $tmpl =~ s/\bhref=(.*?)\?slideshow=on\&amp;skin=\w+/href=$1/g;
    $tmpl =~ s/\bhref="([A-Za-z0-9_]+)((\#[^"]+)?)"/href="$1.html$2"/go;
    # Write the resulting HTML.
    $zip->addString( $tmpl, "$topic.html" );
}

#  Copy a resource (image, style sheet, etc.) from twiki/pub/%WEB% to
#   static HTML's rsrc directory.
#
#   @param $web name of web
#   @param $rsrcName name of resource (relative to pub/%WEB%)
#   @param \%copied map of copied resources to new locations
sub copyResource {
    my ($web, $rsrcName, $copied, $zip) = @_;
    # See if we've already copied this resource.
    unless (exists $copied->{$rsrcName}) {
        # Nope, it's new. Gotta copy it to new location.
        # Split resource name into path (relative to pub/%WEB%) and leaf name.
        my $file = $rsrcName;
        $file =~ s(^(.*)\/)()o;
        my $path = "";
        if ($rsrcName =~ "/") {
            $path = $rsrcName;
            $path =~ s(\/[^\/]*$)()o;
        }
        # Copy resource to rsrc directory.
        my $TWikiPubDir = TWiki::Func::getPubDir();
        if ( -f "$TWikiPubDir/$rsrcName" ) {
            $zip->addDirectory( "rsrc/$path" );
            $zip->addFile( "$TWikiPubDir/$rsrcName" , "rsrc/$path/$file" );
        }
        # Record copy so we don't duplicate it later.
        my $destURL = "rsrc/$path/$file";
        $destURL =~ s(//)(/)go;
        $copied->{$rsrcName} = "$destURL";
    }
    return $copied->{$rsrcName};
}

# Returns a pattern that will match the HTML used by TWiki to represent an
# unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
# SMELL: another case for a WysiwygPlugin-style rendering engine
sub getUnsatisfiedLinkTemplate {
    my ($web) = @_;
    my $t = "!£%^&*(){}";# must _not_ exist!
    my $linkFmt;
    if( $session ) {
        $linkFmt = $session->{renderer}->_renderNonExistingWikiWord($web, $t, "TheLink");
    } else {
        $linkFmt = TWiki::Render::internalLink("", $web, $t, "TheLink", undef, 1); # COMPATIBILITY
    }
    $linkFmt =~ s/\//\\\//go;
    my $pre = $linkFmt;
    $pre =~ s/TheLink.*//o;
    my $post = $linkFmt;
    $post =~ s/.*TheLink//o;
    $post =~ s/\"[^\"]*\"/\"[^\"]*\"/o;
    $post =~ s/\?/\\?/o;
    return $pre . "(.*?)" . $post;
}

1;
