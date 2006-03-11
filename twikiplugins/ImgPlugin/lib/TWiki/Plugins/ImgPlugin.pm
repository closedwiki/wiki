# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ package ImgPlugin

This is a pretty winky-dink plugin that allows people to use %IMG{"foo.gif"}% instead
of <img src="%ATTACHURL%/foo.gif" />. It allows specification of the standard attributes 
as well as an optional web=<web> and/or topic=<topic>.

Another small step in the eradication of html in TWiki!

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::ImgPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'ImgPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle tags that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki tag handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
    #my $exampleCfgVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );
    # There is also an equivalent:
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( 'EXAMPLE' );
    # that may _only_ be called from the main plugin package.

    #$exampleCfgVar ||= 'default'; # make sure it has a value

    # register the _IMGfunction to handle %IMG{...}%
    TWiki::Func::registerTagHandler( 'IMG', \&_IMG);

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('example', \&restExample);

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %IMG{...}% tag
# You would have one of these for each tag you want to process.
sub _IMG{
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    # For example, %IMG{'foo.gif' topic="SomeTopic"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'

    my $imgName = $params->{_DEFAULT};
    my $path = TWiki::Func::getPubUrlPath();
    my $imgTopic = $params->{topic} || $theTopic;
    my $imgWeb = $params->{web} || $theWeb;
    my $altTag = $params->{alt} || '';

    my @attrs = ('align', 'border', 'height', 'width', 'id', 'class');

    my $txt = "<img src='$path/$imgWeb/$imgTopic/$imgName' ";
    $txt .= " alt='$altTag'";
    while (my $key = shift @attrs) {
	if (my $val = $params->{$key}) {
	    $txt .= " $key='$val'";
	}
    }
    $txt .= " />";

    return $txt;
}
return 1;
