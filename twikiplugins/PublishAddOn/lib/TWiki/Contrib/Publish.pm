#
#  publish
#  Publish site (generate static HTML)
#
#  Based loosely on GenHTMLPlugin
#  Copyright (C) 2001 Motorola
#
#  Revisions Copyright (C) 2002, Eric Scouten
#  Cairo updates Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2001 Sven Dowideit, svenud@ozemail.com.au
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

package TWiki::Contrib::Publish;

use vars qw($query $thePathInfo $theRemoteUser $theUrl $debug $ZipPubUrl $publishDir $publishUrlPath $blah $TWikiPubDir $PubUrlPath $VERSION );

$VERSION = 1.200;

$blah = "."; # x 16384;

#  Main rendering loop.
sub main {

    # Read command-line arguments and make 

    # Fill in default environment variables if invoked from command-line.

    $ENV{HTTP_USER_AGENT} = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" if (!exists $ENV{HTTP_USER_AGENT});
    $ENV{REMOTE_ADDR} = "127.0.0.1" if (!exists $ENV{REMOTE_ADDR});
    $ENV{REMOTE_PORT} = "2509" if (!exists $ENV{REMOTE_PORT});
    $ENV{REMOTE_USER} = "TWikiGuest" if (!exists $ENV{REMOTE_USER});
    $ENV{REQUEST_METHOD} = "GET" if (!exists $ENV{REQUEST_METHOD});
    $ENV{QUERY_STRING} = "" if (!exists $ENV{QUERY_STRING});

    # Tweak environment variables depending on command-line arguments.

    foreach my $arg (@ARGV) {
        if ($arg =~ /^\-/) {
            if ($arg eq "-y") {
                if ($ENV{QUERY_STRING}) {
                    $ENV{QUERY_STRING} .= "&goAhead=yes";
                } else {
                    $ENV{QUERY_STRING} = "goAhead=yes";
                }
            } elsif ( $arg eq "-d" ) {
                $debug = 1;
            } else {
                die "Unknown command-line option $arg\n";
            }
        } else {
            $ENV{PATH_INFO} = "/$arg" if (!exists $ENV{PATH_INFO});
        }
    }

    die "Don't know what web to publish\n" if (!exists $ENV{PATH_INFO});

    # Now do normal CGI init.

    $query = new CGI;
    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theTopic = $query->param('topic');
    my $theUrl = $query->url;
    my $goAhead = $query->param('goAhead');

    my $configtopic = $query->param('configtopic');

    if ( defined($query->param('debug')) ) {
        $debug = $query->param('debug');
    }

    print "Content-type: text/plain\n\n" if ($debug);
    $| = 0 if ($debug);

    my ($topic, $web, $scriptUrlPath, $userName, $dataDir)
      = TWiki::initialize($thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query);

    print "INIT : $topic, $web, $scriptUrlPath, $userName, $dataDir\n" if ($debug);

    # Load defaults from a config topic if one was specified
    my ($config_meta, $config_text);
    my ($inclusions, $exclusions, $topicsearch, $skin);
    my $notify="off";

    if ( $configtopic && ! &TWiki::Store::topicExists($web, $configtopic) ) {
        die "Specified configuration topic does not exist!\n";
    } elsif ( $configtopic ) {
        my ($meta, $text) = &TWiki::Store::readTopic($web, $configtopic);
        $text =~ s|\cM|\n|sgmio;
        #print "got configtopic text = '$text'\n";

        while ( $text =~ m|^\s+\*\s+Set\s+([A-Z]+)\s*=(.*?)$|smgio ) {
            my $k = $1;
            my $v = $2;
            $v =~ s/^\s*(.*?)\s*$/$1/go;

            if ( $k eq "INCLUSIONS" ) { $inclusions = $v; }
            elsif ( $k eq "EXCLUSIONS" ) { $exclusions = $v; }
            elsif ( $k eq "NOTIFY" ) { $notify = $v; }
            elsif ( $k eq "TOPICSEARCH" ) { $topicsearch = $v; }
            elsif ( $k eq "SKIN" ) { $skin = $v; }
        }
    }
    if ( defined($query->param('notify')) ) {
        $notify = $query->param('notify');
    }
    if ( defined($query->param('inclusions')) ) {
        $inclusions = $query->param('inclusions');
    }
    if ( defined($query->param('exclusions')) ) {
        $exclusions = $query->param('exclusions');
    }
    if ( defined($query->param('topicsearch')) ) {
        $topicsearch = $query->param('topicsearch');
    }
    if ( defined($query->param('skin')) ) {
        $skin = $query->param('skin');
    }

    # Choose skin if nothing provided
    if ( ! $skin ) {
        $skin = TWiki::Func::getPreferencesValue("SKIN");
    }

    my $wikiUserName = TWiki::Func::userToWikiName($userName);

    # Print environment variables for debugging.

    if ($debug) {
        foreach my $key (sort keys %ENV) {
            print "$key => $ENV{$key}\n";
        }
    }

    # Make sure TWiki.cfg has proper variables.

    $publishDir = TWiki::Func::getPreferencesValue("PUBLISH_DIR");
    $publishUrlPath = TWiki::Func::getPreferencesValue("PUBLISH_URL_PATH");

    $TWikiPubDir = TWiki::Func::getPubDir();
    $PubUrlPath = TWiki::Func::getPubUrlPath();

    if (!$publishDir || !$publishUrlPath) {
        TWiki::Func::redirectCgiQuery($query, TWiki::Func::getOopsUrl($web, $topic, "oopspublisherr"));
        return;
    }

    # Make sure appropriate directories exist. Create them if they don't.
    if (!-d $publishDir && ! -e $publishDir) {
        print "mkpath $publishDir\n" if ($debug);
        mkpath($publishDir, 0, 0777);
    } elsif ( !-d $publishDir && -e $publishDir ) {
        print "FAIL: $publishDir exists but isn't a directory\n" if ($debug);
        &TWiki::redirect($query, &TWiki::getOopsUrl($web, $topic,
                                                    "oopspublisherr"));
        return;
    }

    if (!-d "$publishDir") {
        print "FAIL: $publishDir didn't get created\n" if ($debug);
        TWiki::redirect($query, &TWiki::getOopsUrl($web, $topic,
                                                   "oopspublisherr"));
        return;
    }

    my $tmp = TWiki::formatGmTime(time());
    $tmp =~s/^(\d+)\s+(\w+)\s+(\d+).*/$1_$2_$3/g;
    my $zipfilename=$theRemoteUser . "_" . $web . "_" . $tmp .".zip";

    # Has user selected topic(s) yet?

    if (!$goAhead) {
        &chooseTopicScreen($web, $topic);
    } else {
        print "START PUBLISHING...\n" if ($debug);
        my $succeeded = publishWeb($web, $topic, $inclusions,
                                   $exclusions, $skin, $topicsearch,
                                   "$publishDir/$zipfilename");
        my $successURL = &TWiki::getOopsUrl($web, $topic,
                                            "oopspublished",
                                            "$publishUrlPath/$zipfilename");

        # Send e-mail notification.

        my @notifylist = TWiki::getEmailNotifyList($web);
        if ($notify ne "off" && @notifylist && ($#notifylist >= 0)) {

            my $text = "From: " . TWiki::Prefs::getPreferencesValue("WIKIWEBMASTER") . "\n";
            $text .= "To: " . (join ', ', @notifylist) . "\n";
            $text .= "Subject: \%WIKITOOLNAME\%.\%WEB\% - Automated notification of publication\n\n";

            $text .= "This is an automated email notification of \%WIKITOOLNAME\%.\n\n";

            $text .= "The web \%WEB\% has been published in ZIP file $TWiki::urlHost$publishUrlPath/$zipfilename\n\n\n";
      
            $text .= "Review recent changes in:\n";
            $text .= "  $TWiki::urlHost$scriptUrlPath/view%SCRIPTSUFFIX%/%WEB%/WebChanges\n\n";

            $text .= "Subscribe / Unsubscribe in:\n";
            $text .= "  $TWiki::urlHost$scriptUrlPath/view%SCRIPTSUFFIX%/%WEB%/%NOTIFYTOPIC%\n\n";

            $text = TWiki::Func::expandCommonVariables( $text, $topic, $web );

            my $error = TWiki::Net::sendEmail( $text );
        }

        # Succeeded.


        TWiki::redirect($query, $successURL) if ($succeeded);
    }
}

#   Display screen so user can decide which pages to publish.
#
#   @param $web the web to publish
#   @param $topic topic that was selected
sub chooseTopicScreen {
    my ($web, $topic) = @_;

    # Write HTTP headers.
    TWiki::writeHeader($query);

    # Render publish confirm screen.

    my $tmpl = TWiki::Store::readTemplate("publish");
    $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
    $tmpl = TWiki::Func::renderText($tmpl, $web);
    $tmpl =~ s/%RESEARCH/%SEARCH/go; # Pre search result from being rendered
    $tmpl = TWiki::expandCommonVariables($tmpl, $topic, $web);

    print $tmpl;
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
    my ($web, $topic, $inclusions, $exclusions, $skin, $topicsearch, $destZip) = @_;

    # Get list of topics from this web.
    my @topics = TWiki::Func::getTopicList($web);

    # Parse list of includes/excludes.

    $inclusions = ".*" unless (defined ($inclusions));
    my @include = split( /[\r\n]+/, $inclusions );

    $exclusions = "Web.*" unless (defined ($exclusions));
    my @exclude = split( /[\r\n]+/, $exclusions );

    my $zip = Archive::Zip->new();

    # Attempt to render each included page.
    my %copied;
    foreach my $topic (@topics) {
         next unless grep { /^$topic/ } @include;
         next if grep { /^$topic/ } @exclude;
         publishTopic($web, $topic, $skin, \%copied,
                      $topicsearch, $zip);
     }

    print "ZIP CREATED : $destZip\n" if ($debug);
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
    my ($web, $topic, $skin, $copied, $topicsearch, $zip) = @_;
    print "\npublishTopic($web, $topic, $skin, ...) $blah\n" if ($debug);

    # Used to set the topic when traversing the web.
    # THIS IS NASTY - but I can't find any other reliable way
    # to force TWiki to change topic.
    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theUrl = $query->url;
    my ($itopic, $iweb, $iscriptUrlPath, $iuserName, $idataDir) =
      TWiki::initialize($thePathInfo, $theRemoteUser, $topic, $theUrl, $query);
    die "Bad re-init (web = $iweb, should be $web)\n" if ($iweb ne $web);
    die "Bad re-init (topic = $itopic, should be $topic)\n" if ($itopic ne $topic);

    # Choose template.
    print "  Read template$blah\n" if ($debug);
    my $tmpl = TWiki::Func::readTemplate("view", $skin);
    die "Couldn't find template\n" if(!$tmpl);
    # FIXME should have an oops template...

    # Read topic data.
    print "  Read topic$blah\n" if ($debug);
    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );
    if ( $topicsearch ) {
        if ( $text !~ /$topicsearch/ ) {
            print "  Topic doesn't match search criteria ($topicsearch), skipping.\n" if ($debug);
            return;
        }
    }
    my ($revdate, $revuser, $maxrev) = TWiki::Store::getRevisionInfoFromMeta($web, $topic, $meta, "isoFormat");
    $revuser = TWiki::userToWikiName($revuser);
    # TO DO: Check page permissions.
    print "  Check page permissions$blah\n" if ($debug);
    # Swap in revision info.
    # [scouten 12/08/02]: Omit revision number and author.
    my $shortRevDate = TWiki::Func::renderText("$revdate GMT", $web);
    $shortRevDate =~ s( \- \d\d:\d\d GMT)()o;
    $tmpl =~ s/%REVINFO%/$shortRevDate/go;
    # Handle standard formatting.
    print "  Handle standard formatting (text)$blah\n" if ($debug);
    $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
    $text = TWiki::Func::renderText($text);
    print "  Handle standard formatting (topic)$blah\n" if ($debug);
    $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
    $tmpl = TWiki::handleMetaTags($web, $topic, $tmpl, $meta, 1);
    print "  Handle standard formatting (meta)$blah\n" if ($debug);
    #print "--- \$tmpl:\n$tmpl\n\n";
    #print "--- \$meta:\n";
    #foreach my $key (sort keys %$meta) {
    #print "  $key > $meta->{$key}\n";
    #}
    #print "\n\n----\n\n$blah";
    $tmpl = TWiki::Func::renderText($tmpl, "", $meta); ## better to use meta rendering?
    print "  Merge content$blah\n" if ($debug);
    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%MAXREV%/1.$maxrev/go;
    $tmpl =~ s/%CURRREV%/1.$maxrev/go;
    $tmpl =~ s/%REVTITLE%//go;
    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;   # remove <nop> tags (PTh 06 Nov 2000)
    # Strip unsatisfied WikiWords.
    my $ult = getUnsatisfiedLinkTemplate($web);
    $tmpl =~ s/$ult/$1/g;
    # Copy files from pub dir to rsrc dir in static dir.
    print "  Copy files if [$PubUrlPath] $blah\n" if ($debug);
    $tmpl =~ s((?<==\")(?:http://localhost)?$PubUrlPath\/([^\"]+)(?=\"))(&copyResource($web, $1, $copied, $zip))geo;
    $tmpl =~ s((?<==\")$PubUrlPath\/([^\"]+)(?=\"))(&copyResource($web, $1, $copied, $zip))geo;
    # Modify internal links.
    print "  Update internal links $blah\n" if ($debug);
    my $ilt = getInternalLinkTemplate($web, $topic);
    $tmpl =~ s/$ilt/<a href="$1.html$2"$3>$4<\/a>/g;
    # Scrap anything inside <nopublish> elements.
    print "  Scrap <nopublish> $blah\n" if ($debug);
    $tmpl =~ s(<nopublish>.*?<\/nopublish>)()gos;
    # Remove base tag  - DZA
    $tmpl =~ s/<base[^>]+\/>//;
    # Fix some links - DZA
    $tmpl =~ s!<a href=\"(?:http://localhost)?/bin/view/$web/!<a href=\"!go;
    $tmpl =~ s!<a href=\"(?:http://localhost)?/bin/view/([/A-Za-z0-9_]+)((\#[^\"]+)?)\"!<a href=\"../$1.html$2\"!go;
    # Insert .html in internal links.
    print "  Insert .html in internal links $blah\n" if ($debug);
    # Handle SlideShow plugin urls
    $tmpl =~ s/href=(.*)\?slideshow=on\&amp;skin=\w+/href=$1/g;
    $tmpl =~ s/href=\"([A-Za-z0-9_]+)((\#[^\"]+)?)\"/href=\"$1.html$2\"/go;
    # Write the resulting HTML.
    print "  Write HTML $blah\n" if ($debug);
    $zip->addString( "$tmpl", "$topic.html" );
    print "  Done $blah\n" if ($debug);
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
    if (exists $copied->{$rsrcName}) {
        print "    Skip resource $rsrcName -- already copied$blah\n" if ($debug);
    } else {
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
        print "    Copy resource $TWikiPubDir/$rsrcName\n               in rsrc/$path/$file \n" if ($debug);
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

#  Returns a pattern that will match the HTML used by TWiki to represent an
#  unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
sub getUnsatisfiedLinkTemplate {
    my ($web) = @_;
    my $t = "!£%^&*(){}";# must _not_ exist!
    my $linkFmt = TWiki::internalLink("", $web, $t, "TheLink", undef, 1);
    $linkFmt =~ s/\//\\\//go;
    my $pre = $linkFmt;
    $pre =~ s/TheLink.*//o;
    my $post = $linkFmt;
    $post =~ s/.*TheLink//o;
    $post =~ s/\"[^\"]*\"/\"[^\"]*\"/o;
    $post =~ s/\?/\\?/o;
    return $pre . "(.*?)" . $post;
}


#  Returns a pattern that will match the HTML used by TWiki to represent an
#  internal link. THIS IS NASTY, but I don't know how else to do it.
sub getInternalLinkTemplate {
    my ($web, $topic) = @_;
    my $linkFmt = &TWiki::internalLink("", $web, $topic, "TheLink", undef, 1);
    $linkFmt =~ s/$web\/$topic/$web\/([^"#]*)([^"]*)/g;
    $linkFmt =~ s/\//\\\//go;
    $linkFmt =~ s/>TheLink/([^>]*?)>(.*?)/go;
    return $linkFmt;
}

1;
