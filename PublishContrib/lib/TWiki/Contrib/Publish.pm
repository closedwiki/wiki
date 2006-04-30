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

package TWiki::Contrib::Publish;

use TWiki;
use TWiki::Func;
use Error qw( :try );

use strict;

use vars qw( $VERSION $RELEASE $ob $cb $br $os $cs );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

$ob = '';
$cb = '';
$br = "\n";
$os = '***';
$cs = $os;

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

#  Main rendering loop.
sub publish {
    my $session = shift;

    unless ( defined $TWiki::cfg{PublishContrib}{Dir} ) {
        die "{PublishContrib}{Dir} not defined; run install script";
    }
    unless( -d $TWiki::cfg{PublishContrib}{Dir}) {
        die "{PublishContrib}{Dir} $TWiki::cfg{PublishContrib}{Dir} does not exist";
    }

    my $query = $session->{cgiQuery};
    my $web = $query->param( 'web' ) || $session->{webName};

    $session->{webName} = $web;

    $TWiki::Plugins::SESSION = $session;

    my ($inclusions, $exclusions, $filter, $skin, $genopt, $format);

    # Load defaults from a config topic if one was specified
    my $configtopic = $query->param('configtopic');
    if ( $configtopic ) {
        unless( TWiki::Func::topicExists($web, $configtopic) ) {
            die "Specified configuration topic does not exist in $web!\n";
        }
        my $cfgt = TWiki::Func::readTopicText($web, $configtopic);
        unless( TWiki::Func::checkAccessPermission(
            "VIEW", TWiki::Func::getWikiName(),
            $cfgt, $configtopic, $web)) {
            die "Access to $configtopic denied";
        }
        $cfgt =~ s/\r//g;

        while ( $cfgt =~ s/^\s+\*\s+Set\s+([A-Z]+)\s*=(.*?)$//m ) {
            my $k = $1;
            my $v = $2;
            $v =~ s/^\s*(.*?)\s*$/$1/go;

            if ( $k eq "INCLUSIONS" ) {
                $inclusions = $v;
            } elsif ( $k eq "EXCLUSIONS" ) {
                $exclusions = $v;
            } elsif ( $k eq "TOPICSEARCH" ) {
                $filter = $v;
            } elsif ( $k eq "PUBLISHSKIN" ) {
                $skin = $v;
            } elsif ( $k eq "SKIN" ) {
                $skin = $v;
            } elsif( $k eq "EXTRAS" ) {
                $genopt = $v;
            } elsif( $k eq 'FORMAT' ) {
                $format = $v;
            }
        }
    } else {
        if ( defined($query->param('inclusions')) ) {
            $inclusions = $query->param('inclusions');
        } else {
            $inclusions = '*';
        }
        $exclusions = $query->param('exclusions') || '';
        $filter = $query->param('filter') ||
          $query->param('topicsearch') || '';
        $genopt = $query->param('genopt') || '';
        # 'compress' retained for compatibility
        if( defined $query->param('compress') ) {
            $format = $query->param('compress');
        } else {
            $format = $query->param( 'format' );
        }
        $format ||= 'file';
    }
    # convert wildcard pattern to RE
    $inclusions =~ s/([*?])/.$1/g;
    $inclusions =~ s/,/|/g;
    $exclusions =~ s/([*?])/.$1/g;
    $exclusions =~ s/,/|/g;

    $skin ||= $query->param('skin') || $query->param('publishskin') ||
      TWiki::Func::getPreferencesValue("PUBLISHSKIN") || '';

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

    my $topic = $query->param('publishtopic') || $session->{topicName};
    my($header, $footer) = '';
    unless( TWiki::Func::getContext()->{command_line} ) {
        TWiki::Func::writeHeader($query);
        my $tmpl = TWiki::Func::readTemplate("view");
        $tmpl =~ s/%META{.*?}%//g;
        for my $tag qw( REVTITLE REVARG REVISIONS MAXREV CURRREV ) {
            $tmpl =~ s/%$tag%//g;
        }
        ($header, $footer) = split(/%TEXT%/, $tmpl);
        $header = TWiki::Func::expandCommonVariables( $header, $topic, $web );
        $header = TWiki::Func::renderText( $header, $web );
        $header =~ s/<nop>//go;
        print $header;
        my $url = $query->url().$query->path_info().'?'.$query->query_string();
        $ob = '<b>';
        $cb = '</b>';
        $br = "<br />\n";
        $os = '<span class="twikiAlert">';
        $cs = '</span>';
        print "${ob}URL: ${cb} $url$br";
    }
    print "${ob}{PublishContrib}{Dir}: ${cb}$TWiki::cfg{PublishContrib}{Dir}$br";
    print "${ob}{PublishContrib}{URL}: ${cb}$TWiki::cfg{PublishContrib}{URL}$br";
    print "${ob}Web: $web${cb}$br";
    print "${ob}Config: $configtopic$br" if $configtopic;
    print "${ob}Skin: ${cb}$skin$br";
    print "${ob}Inclusions: ${cb}$inclusions$br";
    print "${ob}Exclusions: ${cb}$exclusions$br";
    print "${ob}Content Filter: ${cb}$filter$br";
    print "${ob}Generator options: ${cb}$genopt$br";

    my $archive;

    my $generator = 'TWiki::Contrib::PublishContrib::'.$format;
    eval 'use '.$generator.
      ';$archive = new '.$generator.
        '("'.$TWiki::cfg{PublishContrib}{Dir}.'","'.$web.'","'.
          $genopt.'")';
    die $@ if $@;

    publishWeb($web, TWiki::Func::getWikiName(), $inclusions,
               $exclusions, $skin, $filter, $archive);

    my $text = 'Published to <a href="'.
      $TWiki::cfg{PublishContrib}{URL}.'/'.$archive->{id}.'">'.
        $archive->{id}.'</a>';

    $archive->close();

    $text = TWiki::Func::expandCommonVariables( $text, $topic, $web );
    $text = TWiki::Func::renderText( $text, $web );
    print $text;
    $footer = TWiki::Func::expandCommonVariables( $footer, $topic, $web );
    $footer = TWiki::Func::renderText( $footer, $web );
    print $footer;
}

#  Publish the contents of one web.
#   * =$web= - which web to publish
#   * =$inclusions= - REs describing which topics to include
#   * =$exclusions= - REs describing which topics to exclude
#   * =$skin= -
#   * =$filter= -
#   * =$archive= - archiver

sub publishWeb {
    my ($web, $wikiName, $inclusions, $exclusions, $skin, $filter, $archive) = @_;

    # Get list of topics from this web.
    my @topics = TWiki::Func::getTopicList($web);

    # Choose template.
    my $tmpl = TWiki::Func::readTemplate("view", $skin);
    die "Couldn't find template\n" if(!$tmpl);

    # Attempt to render each included page.
    my %copied;
    foreach my $topic (@topics) {
        print "${ob}$topic: ${cb}\t";
        if( $topic !~ /^($inclusions)$/ ) {
            print "${os}not included$cs";
        } elsif( $exclusions && $topic =~ /^($exclusions)$/ ) {
            print "${os}excluded$cs";
        } else {
            try {
                publishTopic($web, $topic, $wikiName, $skin, $tmpl,
                             \%copied, $filter, $archive);
                print "published";
            } catch Error::Simple with {
                my $e = shift;
                print "not published: ".$e->{-text};
            };
        }
        print $br;
    }
}

#  Publish one topic from web.
#   * =$web= - which web to publish
#   * =$topic= - which topic to publish
#   * =$skin= - which skin to use
#   * =\%copied= - map of copied resources to new locations
sub publishTopic {
    my ($web, $topic, $wikiName, $skin, $tmpl, $copied, $filter, $archive) = @_;

    # Read topic data.
    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );

    unless( TWiki::Func::checkAccessPermission( "VIEW", $wikiName,
                                                $text, $topic, $web)) {
        print "View access to $topic denied";
        return;
    }

    if ( $filter && $text =~ /$filter/ ) {
        print "$topic excluded by filter";
        return;
    }

    # SMELL: need a new prefs object for each topic
    my $twiki = $TWiki::Plugins::SESSION;
    $twiki->{prefs} = new TWiki::Prefs($twiki);
    $twiki->{prefs}->pushGlobalPreferences();
    $twiki->{prefs}->pushPreferences($TWiki::cfg{UsersWebName}, $wikiName, 'USER '.$wikiName);
    $twiki->{prefs}->pushWebPreferences($web);
    $twiki->{prefs}->pushPreferences($web, $topic, 'TOPIC');
    $twiki->{prefs}->pushPreferenceValues('SESSION', $twiki->{client}->getSessionValues());

    my ($revdate, $revuser, $maxrev);
    ($revdate, $revuser, $maxrev) = $meta->getRevisionInfo();
    $revuser = $revuser->wikiName();

    # Handle standard formatting.
    $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
    $text = TWiki::Func::renderText($text);

    $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
    $tmpl = TWiki::Func::renderText($tmpl, "", $meta);

    $tmpl =~ s/%TEXT%/$text/g;
    # legacy
    $tmpl =~ s/<nopublish>.*?<\/nopublish>//gs;
    # New tags
    my $newTmpl = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $tmpl )) {
        if( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newTmpl = '' unless( $tagSeen );
            $tagSeen = 1;
        } elsif( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        } elsif( $publish ) {
            $newTmpl .= $s;
        }
    }
    $tmpl = $newTmpl;
    $tmpl =~ s/.*?<\/nopublish>//gs;
    $tmpl =~ s/%MAXREV%/$maxrev/g;
    $tmpl =~ s/%CURRREV%/$maxrev/g;
    $tmpl =~ s/%REVTITLE%//g;
    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;

    # Strip unsatisfied WikiWords.
    $tmpl =~ s/<span class="twikiNewLink">(.*?)<\/span>/_handleNewLink($1)/ge;

    # Copy files from pub dir to rsrc dir in static dir.
    my $pub = TWiki::Func::getPubUrlPath();
    my $hs = $ENV{HTTP_HOST} || "localhost";
    $tmpl =~ s!(['"])($TWiki::cfg{DefaultUrlHost}|https?://$hs)?$pub/(.*?)\1!$1._copyResource($web, $3, $copied, $archive).$1!ge;

    my $ilt;

    # Modify topic links relative to server base
    $ilt = $TWiki::Plugins::SESSION->getScriptUrl(0, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1"._topicURL($2,$web).$1!ge;

    # Modify absolute topic links.
    $ilt = $TWiki::Plugins::SESSION->getScriptUrl(1, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1"._topicURL($2,$web).$1!ge;

    my $extras = 0;

    # Handle image tags using absolute URLs not otherwise satisfied
    $tmpl =~ s!(<img\s+.*?\bsrc=)(["'])(.*?)\2(.*?>)!$1.$2._handleURL($3,$archive,\$extras).$2.$4!ge;

    # Remove base tag
    $tmpl =~ s/<base[^>]+\/>//;
    $tmpl =~ s/<nop>//g;

    # Write the resulting HTML.
    $archive->addString( $tmpl, $topic.'.html' );
}

#  Copy a resource (image, style sheet, etc.) from twiki/pub/%WEB% to
#   static HTML's rsrc directory.
#   * =$web= - name of web
#   * =$rsrcName= - name of resource (relative to pub/%WEB%)
#   * =\%copied= - map of copied resources to new locations
sub _copyResource {
    my ($web, $rsrcName, $copied, $archive) = @_;

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
            $archive->addDirectory( "rsrc" );
            $archive->addDirectory( "rsrc/$path" );
            $archive->addFile( "$TWikiPubDir/$rsrcName" , "rsrc/$path/$file" );
        }
        # Record copy so we don't duplicate it later.
        my $destURL = "rsrc/$path/$file";
        $destURL =~ s!//!/!g;
        $copied->{$rsrcName} = $destURL;
	
	# check css for additional resources, ie, url()
	if ($rsrcName =~ /\.css$/) {
	  my @moreResources = ();
	  open(F, "$TWikiPubDir/$rsrcName") ||
        die "Cannot read $TWikiPubDir/$rsrcName: $!";
	  while (my $line = <F>) {
	    if ($line =~ /url\(["']?(.*?)["']?\)/) {
	      push @moreResources, $1;
	    }
	  }
	  close(F);
	  foreach my $resource (@moreResources) {
	    # recurse
	    _copyResource($web, "$path/$resource", $copied, $archive);
	  }
	}
    }
    return $copied->{$rsrcName};
}

sub _topicURL {
    my( $path, $web ) = @_;
    my $extra = '';

    if( $path && $path =~ /(\?.*)$/ ) {
        $extra = $1;
    }

    $path ||= $TWiki::cfg{HomeTopicName};
    $path .= $TWiki::cfg{HomeTopicName} if $path =~ /\/$/;

    # Normalise
    $web = join('/', split( /[\/\.]+/, $web ));
    $path = join('/', split( /[\/\.]+/, $path ));

    # make a path relative to the web
    $path = File::Spec->abs2rel( $path, $web );
    $path .= '.html';

    return $path.$extra;
}

sub _handleURL {
    my( $src, $archive, $extras ) = @_;

    return $src unless $src =~ /^[a-z]+:/;

    require LWP;
    if ( $@ ) {
        print "${ob}LWP not installed - cannot fetch $src${cb}$br";
        return $src;
    }
    my $userAgent = LWP::UserAgent->new();
    $userAgent->agent( 'TWikiPublishContrib' );

    my $response = $userAgent->get( $src );
    unless( $response->is_success ) {
        print "${ob}failed to GET $src${cb}$br";
        return $src;
    }

    # Note: no extension; rely on file format.
    # Images are pretty good that way.
    my $file = '___extra'.$$extras++;
    $archive->addDirectory( "rsrc" );
    $archive->addString( $response->content(), "rsrc/$file" );

    return 'rsrc/'.$file;
}

# Returns a pattern that will match the HTML used by TWiki to represent an
# unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
# SMELL: another case for a WysiwygPlugin-style rendering engine
sub _handleNewLink {
    my $link = shift;
    $link =~ s!<a .*?>!!gi;
    $link =~ s!\?</a>!!gi;
    return $link;
}

1;
