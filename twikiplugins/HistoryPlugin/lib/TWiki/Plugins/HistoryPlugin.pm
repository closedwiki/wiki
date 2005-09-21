# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
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
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::HistoryPlugin;    # change the package name and $pluginName!!!

use TWiki::Func;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.121';
$pluginName = 'HistoryPlugin';  # Name of this Plugin

my ($rev1, $rev2, $nrev, $maxrev);

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub DISABLE_earlyInitPlugin
{
### Remove DISABLE_ for a plugin that requires early initialization, that is expects to have
### initializeUserHandler called before initPlugin, giving the plugin a chance to set the user
### See SessionPlugin for an example of this.
    return 1;
}


# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the beginning of TWiki::handleCommonTags (for cache Plugins use only)
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $rev1 = $rev2 = $nrev = $maxrev = undef;

    # do custom extension rule, like for example:
    $_[0] =~ s/%HISTORY%/&handleHistory()/ge;
    $_[0] =~ s/%HISTORY{(.*?)}%/&handleHistory($1)/ge;

    $_[0] =~ s/%HISTORY_REV1%/$rev1/g if defined($rev1);
    $_[0] =~ s/%HISTORY_REV2%/$rev2/g if defined($rev2);
    $_[0] =~ s/%HISTORY_NREV%/$nrev/g if defined($nrev);
    $_[0] =~ s/%HISTORY_MAXREV%/$maxrev/g if defined($maxrev);

#    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] ) returns:\n$_[0]" ) if $debug;


}

# =========================
sub DISABLE_afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # Called at the end of TWiki::handleCommonTags (for cache Plugins use only)
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}

# =========================
sub DISABLE_beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================

sub handleHistory {

    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::handleHistory: Args=>$_[0]<\n") if $debug;

    my %params = TWiki::Func::extractParameters($_[0]);

    my $web = $params{web} || $web;
    my $topic = $params{topic} || $topic;
    my $format = $params{format} ||
		 $params{_DEFAULT} || 
		 'r1.$rev - $date - $wikiusername%BR%';
    my $header = $params{header} ;
    $header = "\$next{'...'}%BR%" unless defined($header);
    my $footer = $params{footer} ;
    $footer = "\$previous{'...'}" unless defined($footer);

    unless ( TWiki::Func::topicExists( $web, $topic) ) {
	return "Topic $web.$topic does not exist";
    }

    # Get revisions

    $maxrev = (TWiki::Func::getRevisionInfo($web, $topic) )[2];
    $rev1 = $params{rev1};
    $rev1 =~ s/1\.// if $rev1;
    $rev2 = $params{rev2};
    $rev2 =~ s/1\.// if $rev2;
    $nrev = $params{nrev} ||
	    TWiki::Func::getPluginPreferencesValue( "NREV" ) ||
	    10;

    $rev2 ||= $rev1 ? $rev1 + $nrev - 1 : $maxrev;
    $rev1 ||= $rev2 - $nrev + 1;

    ($rev1, $rev2) = ($rev2, $rev1) if $rev1 > $rev2;
    $rev1 = $maxrev if $rev1 > $maxrev;
    $rev1 = 1 if $rev1 < 1;
    $rev2 = $maxrev if $rev2 > $maxrev;
    $rev2 = 1 if $rev2 < 1;

    # Start the output
    my $out = handleHeadFoot($header, $rev1, $rev2, $nrev, $maxrev);

    # Print revision info

    my @revs = ($rev1..$rev2);

    my $reverse = $params{reverse} || 1;
    $reverse = 0 if $reverse =~ /off|no/i;
    @revs = reverse(@revs) if $reverse;

    foreach my $rev (@revs) {

	my ($date, $user, $revout, $comment) = 
	    TWiki::Func::getRevisionInfo($web, $topic, $rev);

        my $revinfo = $format;
	$revinfo =~ s/\$web/$web/g;
	$revinfo =~ s/\$topic/$topic/g;
	$revinfo =~ s/\$rev/$revout/g;
	$revinfo =~ s/\$date/TWiki::Func::formatTime($date)/ge;
	$revinfo =~ s/\$username/$user/g;
	$revinfo =~ s/\$wikiname/TWiki::Func::userToWikiName($user,1)/ge;
	$revinfo =~ s/\$wikiusername/TWiki::Func::userToWikiName($user,0)/ge;

	$revinfo =~ s|^((   )+)|"\t" x length($1/3)|e;

	$out .= $revinfo."\n";

        $rev--;
    }
    $out .= handleHeadFoot($footer, $rev1, $rev2, $nrev, $maxrev);

    return $out;
}

sub handleHeadFoot {

    my ($text, $rev1, $rev2, $nrev, $maxrev) = @_;

    if ($rev2 >= $maxrev) {
	$text =~ s/\$next({.*?})//g;
    } else {
	while ($text =~ /\$next({(.*?)})/ ) {
	    my $args = $2 || '';

	    my $newrev1 = $rev2 < $maxrev ? $rev2 + 1 : $rev2;
	    my $newrev2 = $newrev1 + $nrev - 1;
	    $newrev2 = $maxrev if $newrev2 > $maxrev;

	    $args =~ s/'/"/g;
	    $args =~ s/\$rev1/$newrev1/g;
	    $args =~ s/\$rev2/$newrev2/g;
	    $args =~ s/\$nrev/$nrev/g;

	    my %params = TWiki::Func::extractParameters($args);
	    my $newtext = $params{text} ||
			  $params{_DEFAULT} || '';
	    my $url = $params{url} || '';
	    my $replace = $url ? "[[$url][$newtext]]" : $newtext;
	    $text =~ s/\$next({.*?})/$replace/;
	}
    }

    if ($rev1 <= 1) {
	$text =~ s/\$previous({.*?})//g;
    } else {
	while ($text =~ /\$previous({(.*?)})/ ) {
	    my $args = $2 || '';

	    my $newrev2 = $rev1 > 1 ? $rev1 - 1 : 1;
	    my $newrev1 = $newrev2 - $nrev + 1;
	    $newrev1 = 1 if $newrev1 < 1;

	    $args =~ s/'/"/g;
	    $args =~ s/\$rev1/$newrev1/g;
	    $args =~ s/\$rev2/$newrev2/g;
	    $args =~ s/\$nrev/$nrev/g;

	    my %params = TWiki::Func::extractParameters($args);
	    my $newtext = $params{text} ||
			  $params{_DEFAULT} || '';
	    my $url = $params{url} || '';
	    my $replace = $url ? "[[$url][$newtext]]" : $newtext;
	    $text =~ s/\$previous({.*?})/$replace/;
	}
    }

    return $text;
}







1;
