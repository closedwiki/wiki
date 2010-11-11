# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

# =========================
package TWiki::Plugins::RandomQuotePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $doOldInclude $renderingWeb
    );

$VERSION = '$Rev$';
$RELEASE = '2010-11-10';

$pluginName = 'RandomQuotePlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $doOldInclude = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_OLDINCLUDE" ) || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/( *)%RANDOMQUOTE{(.*?)}%/&_handleRandomQuoteTag( $1, $2 )/geo;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

# =========================
sub _handleRandomQuoteTag
{
    my ( $thePre, $theArgs ) = @_;
    my $text = "";
    my $topicText = "";
    my ($pre, $author, $saying, $category);
    
    TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( thePre = $thePre )" ) if $debug;
    TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( theArgs = $theArgs )" ) if $debug;
    
    my $theWeb = &TWiki::Func::extractNameValuePair( $theArgs, "web" ) || TWiki::Func::getMainWebname( );
    TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( web = $theWeb )" ) if $debug;
    my $quotesFile = &TWiki::Func::extractNameValuePair( $theArgs, "quotes_file" ) || "RandomQuotes";
    TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( quotesFile = $quotesFile )" ) if $debug;
    my $format = &TWiki::Func::extractNameValuePair( $theArgs, "format" );
    TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( $format )" ) if $debug;
    $format =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
    $format =~ s/([^\n])$/$1\n/os;        # append new line if needed
    
    if ( !TWiki::Func::topicExists ( $theWeb, $quotesFile ) ) {
	$text = "*Topic $theWeb.$quotesFile does not exist!*\n";
    } else {
	# $text .= "_Topic $theWeb.$quotesFile found._\n\n" if $debug;
	$topicText = TWiki::Func::readTopicText( $theWeb, $quotesFile );
	# remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
	$topicText =~ s/.*?%STARTINCLUDE%//s;
	$topicText =~ s/%STOPINCLUDE%.*//s;

	# TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( $topicText )" ) if $debug;
	my @quotes = split(/\n/,$topicText);
	srand(time ^ 22/7);
	my $quote = int (rand(@quotes)) + 1;
	# TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( quote = $quote )" ) if $debug;
	TWiki::Func::writeDebug( "- ${pluginName}::_handleRandomQuoteTag( $quotes[$quote] " ) if $debug;
	($pre, $author, $saying, $category) = split (/\|/, $quotes[$quote]);
	if ($format) {
	    my $line = "";
	    $line = $format;
	    $line =~ s/\$author/$author/gos;
	    $line =~ s/\$saying/$saying/gos;
	    $line =~ s/\$category/$category/gos;
	    TWiki::Func::writeDebug( "- ${pluginName}::_handleMovableTypeTag( $line )" ) if $debug;
	    $text .= $line;
	} else {
	    $text .= "\"$saying\"  -- $author";
	}
    }

    return $text;
}

1;
