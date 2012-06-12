# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2008-2012 TWiki:TWiki.TWikiContributor
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
# =========================
#
# This Plugin publishes topics of a web as static HTML pages.

# =========================
package TWiki::Plugins::PublishWebPlugin;

use strict;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2012-06-12';

our $SHORTDESCRIPTION = 'Maintain a static website collaboratively in a TWiki web';
our $NO_PREFS_IN_TOPIC = 1;
my $pluginName = 'PublishWebPlugin';  # Name of this Plugin
my $initialized = 0;
my $error = '';
my $web;
my $topic;
my $debug;
my $publishWeb;
my $publishSkin;
my $excludeTopic;
my $homeLabel;
my %niceTopicFilter;
my $templatePath;
my $publishPath;
my $attachPath;
my $publishDir;
my $attachDir;
my $publishUrlPath;

# =========================
sub initPlugin
{
    ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'PUBLISHWEB', \&_handlePublishWeb );

    # Get plugin debug flag
    $debug = $TWiki::cfg{Plugins}{PublishWebPlugin}{Debug} || 0;

    writeDebug( "initPlugin( $web.$topic ) is OK" );
    $initialized = 0;
    $error = "";
    return 1;
}

# =========================
sub initialize
{
    return if( $initialized );

    # Get plugin preferences
    $publishWeb   = TWiki::Func::getPreferencesValue( "PUBLISHWEBPLUGIN_PUBLISHWEBNAME" ) || "DemoWebsite";
    $publishWeb   = TWiki::Func::expandCommonVariables( $publishWeb, $topic, $web );
    $publishSkin  = TWiki::Func::getPreferencesValue( "PUBLISHWEBPLUGIN_PUBLISHSKIN" ) || "demo_website";
    $publishSkin  =~ s/[^A-Za-z0-9_\-\.]//go; # filter out dangerous chars
    $excludeTopic = TWiki::Func::getPreferencesValue( "PUBLISHWEBPLUGIN_EXCLUDETOPIC" ) ||
      "WebAtom, WebChanges, WebCreateNewTopic, WebHome, WebIndex, WebLeftBar, WebNotify, " .
      "WebPublish, WebPreferences, WebRss, WebSearchAdvanced, WebSearch, WebStatistics, " .
      "WebTopicList, WebTopMenu, WebTopicCreator, WebTopicEditTemplate";
    $excludeTopic = TWiki::Func::expandCommonVariables( $excludeTopic, $topic, $web );
    $excludeTopic =~ s/,\s*/\|/go;
    $excludeTopic = '(' . $excludeTopic . ')';
    $homeLabel    = TWiki::Func::getPreferencesValue( "PUBLISHWEBPLUGIN_HOMELABEL" ) || "Home";
    my $val       = TWiki::Func::getPreferencesValue( "PUBLISHWEBPLUGIN_NICETOPICFILTER" ) || "";
    %niceTopicFilter = split( /,\s*/, $val );

    my $lcWeb = lc( $web );

    # template path for skin file; empty for twiki/templates; must be absolute path if specified
    $templatePath = $TWiki::cfg{Plugins}{PublishWebPlugin}{TemplatePath} || "";
    $templatePath =~ s/%WEB%/$web/;
    $templatePath =~ s/%LCWEB%/$lcWeb/;
    $templatePath =~ s/%SKIN%/$publishSkin/;

    # output file directory; can be absolute path or relative to twiki/pub
    $publishPath = $TWiki::cfg{Plugins}{PublishWebPlugin}{PublishPath} || "../path/to/html";
    $publishPath =~ s/%WEB%/$web/;
    $publishPath =~ s/%LCWEB%/$lcWeb/;
    $publishPath =~ s/%SKIN%/$publishSkin/;

    # attach dir; must be relative to $publishPath
    $attachPath  = $TWiki::cfg{Plugins}{PublishWebPlugin}{AttachPath} || "_publish";
    $attachPath =~ s/%WEB%/$web/;
    $attachPath =~ s/%LCWEB%/$lcWeb/;
    $attachPath =~ s/%SKIN%/$publishSkin/;

    # URL path corresponding to $publishPath
    $publishUrlPath = $TWiki::cfg{Plugins}{PublishWebPlugin}{PublishUrlPath} || "";
    $publishUrlPath =~ s/%WEB%/$web/;
    $publishUrlPath =~ s/%LCWEB%/$lcWeb/;
    $publishUrlPath =~ s/%SKIN%/$publishSkin/;

    # Initialization
    $publishDir = TWiki::Func::getPubDir( ) . '/' . $publishPath; # assume relative
    $publishDir = $publishPath if( $publishPath =~ /^\// ); # use absolute path if so

    $attachDir  = $publishDir . '/' . $attachPath; # assume relative path
    $attachDir  = $attachPath if( $attachPath =~ /^\// ); # use absolute path if so

    $initialized = 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "commonTagsHandler( $_[2].$_[1] )" );
    $_[0] =~ s/%(START|STOP)PUBLISH%[\n\r]*//go;
}

# =========================
sub afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "afterSaveHandler( $_[2].$_[1] )" );

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    initialize();
    return unless( $_[2] eq $publishWeb );
    publishTopic( $_[2], $_[1], $_[0] );
}

# =========================
sub publishTopic
{
    my( $theWeb, $theTopic, $text, $session ) = @_;

    writeDebug( "publishTopic( $theWeb, $theTopic )" );
    return unless( $theWeb eq $publishWeb );
    return if( $theTopic =~ /$excludeTopic/ );
    my $skin = $publishSkin;

    unless( $text ) {
        $text = TWiki::Func::readTopicText( $theWeb, $theTopic );
    }
    if( $text =~ /META\:FIELD{name=\"PublishSkin\".*?value=\"([^\"]+)\"/ ) {
        $skin = $1;
        $skin =~ s/[^A-Za-z0-9_\-\.]//go; # filter out dangerous chars
    }
    $text =~ s/%META:[A-Z0-9]+\{[^\n\r]+[\n\r]*//gs;
    $text =~ s/.*?%STARTPUBLISH%[\n\r]*//s;
    $text =~ s/%STOPPUBLISH%.*//s;

    # load skin file
    my $tmpl = '';
    if( $templatePath ) {
        # assume /path/to/publishskin.html
        my $skinFile = $templatePath . '/' . $skin . '.html';
        $tmpl = TWiki::Func::readFile( $skinFile );
        unless( $tmpl ) {
            $tmpl = "<html><body><h1>Error: Skin $skinFile not found</h1>";
            $tmpl .= "\n%TEXT%</body></html>";
        }
    } else {
        # assume twiki/templates/view/publishskin.tmpl
        $tmpl = TWiki::Func::readTemplate( "view", $skin );
        unless( $tmpl ) {
            $tmpl = "<html><body><h1>Error: Skin $skin not found</h1>";
            $tmpl .= "\n%TEXT%</body></html>";
        }
    }
    $tmpl =~ s/%META\{.*?\}%[\n\r]*//gs;
    $tmpl =~ s/[\n\r]+$//os;

    # merge template and page text
    $tmpl =~ s/%TEXT%/$text/;

    # temporarily trick TWiki to take current topic as base topic, needed
    # to properly expand %BASETOPIC% if topic is republished in WebPublish
    my( $saveWeb, $saveBaseWeb, $saveTopic, $saveBaseTopic );
    if( $session ) {
        $saveWeb       = $session->{SESSION_TAGS}{WEB};
        $saveBaseWeb   = $session->{SESSION_TAGS}{BASEWEB};
        $saveTopic     = $session->{SESSION_TAGS}{TOPIC};
        $saveBaseTopic = $session->{SESSION_TAGS}{BASETOPIC};
        $session->{SESSION_TAGS}{WEB}       = $theWeb;
        $session->{SESSION_TAGS}{BASEWEB}   = $theWeb;
        $session->{SESSION_TAGS}{TOPIC}     = $theTopic;
        $session->{SESSION_TAGS}{BASETOPIC} = $theTopic;
    }

    $tmpl = TWiki::Func::expandCommonVariables( $tmpl, $theTopic, $theWeb );
    ## FIXME my $wikiWordRegex = TWiki::Func::getRegularExpression( "wikiWordRegex" );
    $tmpl =~ s/(^|[\(\s])([A-Z][A-Za-z0-9]*)\.([A-Z]+[a-z]+[A-Za-z0-9])/$1<nop>$3/go;
    $tmpl =~ s/\[\[(.*?)\]\[(.*?)\]\]/&handleLink($1,$2)/geo;
    $tmpl =~ s/\[\[(.*?)\]\]/&handleLink($1,$1)/geo;
    $tmpl = TWiki::Func::renderText( $tmpl, $theWeb );

    if( $session ) {
        $session->{SESSION_TAGS}{WEB}       = $saveWeb;
        $session->{SESSION_TAGS}{BASEWEB}   = $saveBaseWeb;
        $session->{SESSION_TAGS}{TOPIC}     = $saveTopic;
        $session->{SESSION_TAGS}{BASETOPIC} = $saveBaseTopic;
    }

    # fix links to attachments
    my $pubDir = TWiki::Func::getPubDir();
    my $pubUrl = TWiki::Func::getPubUrlPath();
    $tmpl =~ s/(https?:\/\/[^\/]*)?($pubUrl)\/([^\)'" ]+)/&fixAndCopyAttachments($2, $3, $pubDir )/geo;
    $tmpl =~ s/<\/?(nop|noautolink)\/?>\n?//gois;
    $tmpl =~ s|https?://[^/]*/$attachPath|/$attachPath|gois; # Cut protocol and host

    # remove URL parameters to make TOC and other TWiki internal links work
    $tmpl =~ s/(<a href=[\"\'][A-Za-z0-9_\-\/]*)\?[^\#\"\']*/$1/gos;

    my $name = buildName( $theTopic, 'file' );
    writeDebug( "publishTopic, saving file $name using $skin skin" );
    TWiki::Func::saveFile( $name, $tmpl );

    return $theTopic;
}

# =========================
sub fixAndCopyAttachments
{
    my ( $pubUrl, $path, $pubDir ) = @_;
    my $file = $path;
    $file =~ s/.*\///;
    my $from = "$pubDir/$path";
    my $to   = "$attachDir/$file";
#    writeDebug( "fixAndCopyAttachments, copying attachment from $from to $to" );
    use File::Copy;
    unless( copy( $from, $to ) ) {
        $error = "Error: Can't copy $from $to ($!)";
        TWiki::Func::writeWarning( "- ${pluginName}: $error\n" );
    }
    return "$attachPath/$file";
}

# =========================
sub handleLink
{
    my ( $link, $label ) = @_;
    if( $link =~ /^(http|ftp)\:/ ) {
        return "<a href=\"$link\">$label</a>";
    } elsif( $link eq $label ) {
        return '<a href="'
               . buildName( $link, 'url' ) . '">'
               . buildName( $link, 'label' ) . '</a>';
    } else {
        return '<a href="' . buildName( $link, 'url' ) . "\">$label</a>";
    }
}

# =========================
sub _handlePublishWeb
{
    my( $session, $params ) = @_;

    my $action =    $params->{_DEFAULT};
    my $topicName = $params->{topic} || $topic;
    my $text = '';
    initialize();
    if( $action eq "breadcrumb" ) {
        if( $topicName ne "Index" ) {
            $text .= "[[Index][$homeLabel]]";
            foreach( getParents( $web, $topicName ) ) {
                $text .= " &gt; [[$_]["
                      . buildName( $_, 'label' ) . ']]';
            }
            $text .= ' &gt; ';
        }
    } elsif( $action eq "nicetopic" ) {
        $text =  buildName( $topicName, 'label' );
    } elsif( $action eq "topicname" ) {
        $text =  buildName( $topicName, 'link' );
    } elsif( $action eq "topicurl" ) {
        $text =  buildName( $topicName, 'url' );
    } elsif( $action eq "publishurlpath" ) {
        $text =  buildName( $topicName, 'publishurlpath' );
    } elsif( $action eq "publish" ) {
        $topicName = $params->{topic} || ''; # again, without || $topic
        if( $topicName eq "all" ) {
            my @topics = ();
            foreach( TWiki::Func::getTopicList( $publishWeb ) ) {
                $topic = $_;
                $topicName = $_;
                if( publishTopic( $publishWeb, $topicName, undef, $session ) ) {
                    push( @topics, "[[$publishWeb.$topicName]]" );
                }
            }
            my $done = join( ', ', @topics );
            $text = "PUBLISHWEB: Published topics $done";
        } elsif( $topicName ) {
            if( TWiki::Func::topicExists( $publishWeb, $topicName ) ) {
                $topic = $topicName;
                if( publishTopic( $publishWeb, $topicName, undef, $session ) ) {
                    $text = "PUBLISHWEB: Published topic [[$publishWeb.$topicName]]";
                } else {
                    $text = "PUBLISHWEB error: Topic [[$publishWeb.$topicName]] not published";
                }
            } else {
                $text = "PUBLISHWEB error: Topic <nop>$publishWeb.$topicName does not exist";
            }
        } else {
            $text = 'PUBLISHWEB error: Missing topic="" parameter for "publish" action';
        }
    } elsif( $action ) {
        $text = 'PUBLISHWEB error: Unrecognized action';
    } else {
        $text = '';
    }
    return $text;
}

# =========================
sub getParents
{
    my ( $web, $topic ) = @_;
    my @arr = ( );
    for(;;) {
        my $text = TWiki::Func::readTopicText( $web, $topic, '', 1 );
        last unless( $text =~ s/.*?\%META:TOPICPARENT\{name\=\"([^\"]+).*/$1/s );
        last if( $text =~ /^(Index|WebHome)$/ ); # stop at home topic
        last if( grep { /^$text$/ } @arr );      # prevent recursion
        push( @arr, $text );
        $topic = $text;
    }
    return reverse @arr;
}

# =========================
sub buildName
{
    my ( $topic, $type ) = @_;
    # $type for 'Topic_Name':
    # 'name':   'topic_name.html'
    # 'url':    'topic_name.html'
    # 'file':   '/file/path/to/topic_name.html'
    # 'label':  'Topic Name'
    # 'publishurlpath': {Plugins}{PublishWebPlugin}{PublishUrlPath} configure setting
    my $text = lc( $topic ) . '.html';
    $text =~ s/[^a-z0-9_\-\.]+//go;
    $text =~ /(.*)/;
    $text = $1; # untaint
    if( $type eq 'url' ) {
        # keep text as is (relative URL)
    } elsif( $type eq 'file' ) {
        $text = $publishDir . '/' . $text;
    } elsif( $type eq 'label' ) {
        $text = $topic;
        while( my( $from, $to ) = each( %niceTopicFilter ) ) {
            $text =~ s/\Q$from\E/$to/go;
        }
        $text =~ s/_/ /go;
        $text =~ s/^Index$/$homeLabel/o;
    } elsif( $type eq 'publishurlpath' ) {
        $text = $publishUrlPath;
    }
    return $text;
}

# =========================
sub writeDebug
{
    my( $text ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}: $text" ) if $debug;
}

# =========================
1;
