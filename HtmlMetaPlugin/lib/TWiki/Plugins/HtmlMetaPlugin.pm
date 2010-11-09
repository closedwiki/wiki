# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 TWiki:Main.DougClaar
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package HtmlMetaPlugin

This plugin allows the definition of html meta tags, in order to help
certain search engines find TWiki pages.

=cut

package TWiki::Plugins::HtmlMetaPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $HtmlMetaCfgVisibility);

$VERSION = '$Rev: 9598$';
$RELEASE = '2010-11-09';

# Name of this Plugin, only used in this module
$pluginName = 'HtmlMetaPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::_initPlugin( $_[0]; $_[1]; $_[2]; $_[3] )" ) if $debug;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, variables defined by:
    #   * Set VISIBILITY = ... Whether or not to display in body.
    $HtmlMetaCfgVisibility = TWiki::Func::getPreferencesValue( "\U$pluginName\E_VISIBILITY" );
    # There is also an equivalent:
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( 'EXAMPLE' );
    # that may _only_ be called from the main plugin package.

    $HtmlMetaCfgVisibility ||= 0; # make sure it has a value

    # register the _HTMLMETATAG function to handle %HTMLMETA{...}%
    TWiki::Func::registerTagHandler( 'HTMLMETA', \&_HTMLMETATAG );

    # Plugin correctly initialized
    return 1;
}

sub _HTMLMETATAG_error {
    my ($params,@message)=@_;

    my $message="%<nop>HTMLMETA{" . $params->{_RAW} . "}%";
    $message.=" - ERROR (<nop>${pluginName}::_HTMLMETATAG): ";
    $message.=join("",@message);
    $message.="%BR%";
    return $message;
}

# The function used to handle the %HTMLMETATAG{...}% variable
# There are 3 possible parameters:
#	name: html meta tag name
#	content: html meta tag content
#	visibility: Whether or not to display in topic

sub _HTMLMETATAG {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %HTMLMETA{'keywords' contents="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{contents} will be 'onions'

    TWiki::Func::writeDebug( "- ${pluginName}::_HTMLMETATAG( $_[0]; " .
    	join(", ",keys(%{$_[1]})) . "; $_[2]; $_[3] )" ) if $debug;

    TWiki::Func::writeDebug( "- ${pluginName}::_HTMLMETATAG(params=" .
    	join(",",map("$_=$params->{$_}",keys %$params)));

    # The content parameter is required
    return _HTMLMETATAG_error($params,'meta content not defined.') if ! defined $params->{content};

    # If we have the form where the first parameter doesn't have a name,
    # and we don't have a name section, then make that parameter the name.
    $params->{name}=$params->{_DEFAULT} if (
    	! defined $params->{name} && defined $params->{_DEFAULT});

    # The name parameter (which can be passed via _DEFAULT), is required
    return _HTMLMETATAG_error($params,'meta name not defined.') if ! defined $params->{name};

    return _HTMLMETATAG_error($params,'visibility must be a number.') if (
    	defined $params->{visibility} && $params->{visibility}!~/^\s*[+-]?\d+\s*$/);

    # meta name rules from:
    #   http://www.htmlhelp.com/reference/html40/head/meta.html
    #   http://www.htmlhelp.com/reference/html40/values.html#name
    return _HTMLMETATAG_error($params,"meta name has invalid characters.") if
    	($params->{name}!~/^[A-Za-z][A-Za-z0-9\-_:.]*$/);

    # meta content rules from:
    #   http://www.htmlhelp.com/reference/html40/head/meta.html
    #     CONTENT may contain text and entities, but may not contain HTML tags
    #   http://www.htmlhelp.com/reference/html40/entities/
    #     entities are case-sensitive and take the form &name;
    #   http://www.htmlhelp.com/reference/html40/values.html#cdata
    #     Text and entities => CDATA:
    #     Line feeds are ignored, while each carriage return and tab is
    #     replaced with a space. 

    # convert cr and tab to blank
    $params->{content}=~s/\r\t/ /g;

    # There can't be HTML tags, and we don't want to let people be tricky,
    # so we'll change < and > to &lt; and &gt;
    $params->{content}=~s/</\&lt;/g;
    $params->{content}=~s/>/\&gt;/g;

    # look for numeric character entities
    return _HTMLMETATAG_error($params,"meta content cannot contain non-character entities.") if $params->{content}=~/&#(([Xx][0-9A-Fa-f]+)|([0-9]+));/;

    # look for non-characters
    return _HTMLMETATAG_error($params,"meta content cannot contain non-characters.") if $params->{content}=~/\p{IsC}/;
    
    TWiki::Func::writeDebug( "- ${pluginName}::_HTMLMETATAG(name=" .
    	$params->{name} . " content=" . $params->{content});

    # Add to the head section. Use the name as the index. This means that
    # the last one wins!
    TWiki::Func::addToHEAD("HTMLMETA" . $params->{name}, "\n" . 
    	'<meta name="' . $params->{name} .
	'" content="' . $params->{content} . '" />' . "\n");

    my $visible=$HtmlMetaCfgVisibility;
    $visible+=$params->{visibility} if defined $params->{visibility};
    return("%<nop>HTMLMETA{" . $params->{_RAW} . "}% %BR%") if $visible > 0;
    return "";
}

1;

__END__

Test cases

This one is good, but invisible by default:%BR%
%HTMLMETA{name="keywords" content="TWiki"}%

This one is, too:%BR%
%HTMLMETA{name="description" content="It's all about TWiki"}%

This one has no content:%BR%
%HTMLMETA{name="nocontent"}%

I've been through the desert on an HTMLMETA with no name:%BR%
%HTMLMETA{content="no name"}%

This one is ok, uses default for name, but invisible by default:%BR%
%HTMLMETA{"default" content="default name"}%

This one has a bad name:%BR%
%HTMLMETA{name="1Evil1" content="Doesn't start with a letter"}%

A good name is to be desired, this one doesn't have one:%BR%
%HTMLMETA{name="<html here>" content="Has html in it"}%

This one has html in the content, should be escaped, but invisible by default:%BR%
%HTMLMETA{name="ok1" content="<evil html>"}%

This one has a non-character entity:%BR%
%HTMLMETA{name="bad3" content="&#09;"}%

This one has a hex non-character entity:%BR%
%HTMLMETA{name="bad4" content="&#x0A;"}%

This one has an extended character, which is ok, but invisible by default:%BR%
%HTMLMETA{name="ok2" content="señora"}%

This one has a (character) entity, which is ok, but invisible by default:%BR%
%HTMLMETA{name="ok3" content="&copy;2006"}%

This one has a ^G, which is not ok:%BR%
%HTMLMETA{name="bad5" content=""}%

This one has bad visibility, so you can't see it in the header:%BR%
%HTMLMETA{name="bad6" content="bad visibility" visibility="yes"}%

This one has positive visibility, so you should see it:%BR%
%HTMLMETA{name="ok4" content="positive visibility" visibility="1"}%

If I was invisible...This one has negative visibility, so you shouldn't see it:%BR%
%HTMLMETA{name="ok5" content="negative visibility" visibility="-1"}%

This one is good, but invisible by default. It is also has a duplicate name:%BR%
%HTMLMETA{name="keywords" content="TWiki wabbit"}%
