# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
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
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   renderFormFieldForEditHandler( $name, $type, $size, $value, $attributes, $possibleValues)
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, unused handlers are disabled. To
# enable a handler remove the leading DISABLE_ from the function
# name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::DefaultPlugin;

use TWiki::Func;

use strict;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $doOldInclude $renderingWeb
    );

$VERSION = '1.030';
$pluginName = 'DefaultPlugin';  # Name of this Plugin

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $doOldInclude = TWiki::Func::getPluginPreferencesFlag( "OLDINCLUDE" ) || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # for compatibility for earlier TWiki versions:

    ######################
    # Old INCLUDE syntax
    if( $doOldInclude ) {
        # allow two level includes
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::_handleINCLUDE( TWiki::extractParameters( $1 ), $_[1], $_[2], "" )/geo;
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::_handleINCLUDE( TWiki::extractParameters( $1 ), $_[1], $_[2], "" )/geo;
    }

    ######################
    # Full attachment filename
    # Process the filename suffixed to %ATTACHURLPATH%
    # Required for migration purposes
    my $pubUrlPath = TWiki::Func::getPubUrlPath();
    my $attfexpr = TWiki::nativeUrlEncode( "$pubUrlPath/$_[2]/$_[1]" );
    my $fnRE =  TWiki::Func::getRegularExpression( "filenameRegex" );
    $_[0] =~ s!$attfexpr/($fnRE)!"$attfexpr/".&TWiki::nativeUrlEncode($1)!ge;

    ######################
    # TOC handling
    # SMELL: this should be in its own plugin
    $_[0] =~ s/%TOC({([^}]*)})?%/&_handleTOC($2, @_)/ge;
}

sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render deprecated *_text_* as "bold italic" text:
    $_[0] =~ s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<strong><em>$2<\/em><\/strong>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&TWiki::Render::internalLink($2,$3,"$2:$3",$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/&TWiki::Render::internalLink($web,$2,$2,$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&TWiki::Render::internalLink($2,$3,$3,$1,1)/geo;

    # Use <link>....</link> links
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/<link>(.*?)<\/link>/&TWiki::internalLink("",$web,$1,$1,"",1)/geo;
}

# Parameters:
#    * $text          : the text of the current topic
#    * $topic         : the topic we are in
#    * $web           : the web we are in
#    * $tocAttributes : "Topic" [web="Web"] [depth="N"]
# Return value: $tableOfContents
# Andrea Sterbini 22-08-00 / PTh 28 Feb 2001
# Handles %<nop>TOC{...}% syntax.  Creates a table of contents using TWiki bulleted
# list markup, linked to the section headings of a topic. A section heading is
# entered in one of the following forms:
#    * $headingPatternSp : \t++... spaces section heading
#    * $headingPatternDa : ---++... dashes section heading
#    * $headingPatternHt : &lt;h[1-6]> HTML section heading &lt;/h[1-6]>
sub _handleTOC {
    my $args = shift;
    my %params = TWiki::Func::extractParameters( $args );

    ##     $_[0]     $_[1]      $_[2]    $_[3]
    ## my( $theText, $theTopic, $theWeb, $attributes ) = @_;
    my $topicName = $_[1];
    my $webName = $_[2];

    # get the topic name attribute
    my $topicname = $params{_DEFAULT}  || $_[1];

    # get the web name attribute
    my $web = $params{web} || $_[2];
    $web =~ s/\//\./g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $depth = $params{depth} || 6;

    #get the title attribute
    my $title = $params{title} || "";
    $title = "\n<span class=\"twikiTocTitle\">$title</span>" if( $title );

    my $result  = "";
    my $line  = "";
    my $level = "";
    my @list  = ();
my $debug = "";
    if( "$web.$topicname" eq "$_[2].$_[1]" ) {
        # use text from parameter
        @list = split( /\n/, $_[0] );

    } else {
        # read text from file
        if ( ! TWiki::Func::topicExists( $web, $topicname ) ) {
            return _inlineError( "TOC: Cannot find topic \"$web.$topicname\"" );
        }
        my $t = TWiki::Func::readWebTopic( $web, $topicname );
        $t =~ s/.*?%STARTINCLUDE%//s;
        $t =~ s/%STOPINCLUDE%.*//s;
        @list = split( /\n/, TWiki::Func::expandCommonVariables( $t, $topicname, $web ) );
    }

    my $headerDaRE =  TWiki::Func::getRegularExpression( "headerPatternDa" );
    my $headerSpRE =  TWiki::Func::getRegularExpression( "headerPatternSp" );
    my $headerHtRE =  TWiki::Func::getRegularExpression( "headerPatternHt" );
    my $webnameRE =   TWiki::Func::getRegularExpression( "webNameRegex" );
    my $wikiwordRE =  TWiki::Func::getRegularExpression( "wikiWordRegex" );
    my $abbrevRE =    TWiki::Func::getRegularExpression( "abbrevRegex" );
    my $headerNoTOC = TWiki::Func::getRegularExpression( "headerPatternNoTOC" );
    @list = grep { /(<\/?pre>)|($headerDaRE)|($headerSpRE)|($headerHtRE)/o } @list;
    my $insidePre = 0;
    my $i = 0;
    my $tabs = "";
    my $anchor = "";
    my $highest = 99;
    # SMELL: this handling of <pre> is archaic. Surely this should be
    # done using the outsidePreHandler?
    foreach $line ( @list ) {
        if( $line =~ /^.*<pre>.*$/io ) {
            $insidePre = 1;
            $line = "";
        }
        if( $line =~ /^.*<\/pre>.*$/io ) {
            $insidePre = 0;
            $line = "";
        }
        if (!$insidePre) {
            $level = $line ;
            if ( $line =~  /$headerDaRE/o ) {
                $level =~ s/$headerDaRE/$1/go;
                $level = length $level;
                $line  =~ s/$headerDaRE/$2/go;
            } elsif
               ( $line =~  /$headerSpRE/o ) {
                $level =~ s/$headerSpRE/$1/go;
                $level = length $level;
                $line  =~ s/$headerSpRE/$2/go;
            } elsif
               ( $line =~  /$headerHtRE/io ) {
                $level =~ s/$headerHtRE/$1/gio;
                $line  =~ s/$headerHtRE/$2/gio;
            }
            my $urlPath = "";
            if( "$web.$topicname" ne "$webName.$topicName" ) {
                # not current topic, can't omit URL
                $urlPath = "$TWiki::dispScriptUrlPath$TWiki::dispViewPath$TWiki::scriptSuffix/$webPath/$topicname";
            }
            if( ( $line ) && ( $level <= $depth ) ) {
                $anchor = TWiki::Render::makeAnchorName( $line );
                # cut TOC exclude '---+ heading !! exclude'
                $line  =~ s/\s*$headerNoTOC.+$//go;
                $line  =~ s/[\n\r]//go;
                next unless $line;
                $highest = $level if( $level < $highest );
                $tabs = "";
                for( $i=0 ; $i<$level ; $i++ ) {
                    $tabs = "\t$tabs";
                }
                # Remove *bold*, _italic_ and =fixed= formatting
                $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                $line =~ s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                # Prevent WikiLinks
                $line =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;  # '[[...][...]]'
                $line =~ s/\[\[(.*?)\]\]/$1/ge;        # '[[...]]'
                $line =~ s/([\s\(])($webnameRE)\.($wikiwordRE)/$1<nop>$3/g;  # 'Web.TopicName'
                $line =~ s/([\s\(])($wikiwordRE)/$1<nop>$2/g;  # 'TopicName'
                $line =~ s/([\s\(])($abbrevRE)/$1<nop>$2/g;    # 'TLA'
                # create linked bullet item, using a relative link to anchor
                $line = "$tabs* <a href=\"$urlPath#$anchor\">$line</a>";
                $result .= "\n$line";
            }
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        $result = "<div class=\"twikiToc\">$title$result\n</div>";
        return $result;

    } else {
        return _inlineError("TOC: No TOC in \"$web.$topicname\" $debug");
    }
}

# Format an error for inline inclusion in HTML
sub _inlineError {
    my( $errormessage ) = @_;
    return "<font size=\"-1\" class=\"twikiAlert\" color=\"#FF0000\">$errormessage</font>" ;
}

1;
