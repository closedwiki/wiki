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

=pod

---+ package EmptyPlugin

This is an empty TWiki plugin. It is a fully defined plugin, but is
disabled by default in a TWiki installation. Use it as a template
for your own plugins; see TWiki.TWikiPlugins for details.

Each plugin is a package that may contain these handlers:
| *Handler*                   | *$TWiki::Plugins::VERSION* |
| earlyInitPlugin             | 1.020 |
| initPlugin                  | 1.000 |
| initializeUserHandler       | 1.010 |
| registrationHandler         | 1.010 |
| beforeCommonTagsHandler     | 1.024 |
| commonTagsHandler           | 1.000 |
| afterCommonTagsHandler      | 1.024 |
| preRenderingHandler         | 1.026 |
| postRenderingHandler        | 1.026 |
| beforeEditHandler           | 1.010 |
| afterEditHandler            | 1.010 |
| beforeSaveHandler           | 1.010 |
| afterSaveHandler            | 1.020 |
| beforeAttachmentSaveHandler | 1.023 |
| afterAttachmentSaveHandler  | 1.023 |
| writeHeaderHandler          | 1.010 |
| redirectCgiQueryHandler     | 1.010 |
| getSessionValueHandler      | 1.010 |
| setSessionValueHandler      | 1.010 |

=initPlugin= is REQUIRED, all other are OPTIONAL.

__NOTE:__ To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. You should comment out or delete the whole of
handlers you don't use before you release your plugin.

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
Check the warning log file (defined by $cfg{WarningFileName}) for
errors.

=cut

package TWiki::Plugins::EmptyPlugin;    # change the package name and $pluginName!!!

use vars qw( $VERSION $pluginName $debug $exampleCfgVar );

$VERSION = '1.200';
$pluginName = 'EmptyPlugin';  # Name of this Plugin

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

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
    $exampleCfgVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );
    # There is also an equivalent:
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" );
    # that may _only_ be called from the main plugin package.

    $exampleCfgVar ||= "default"; # make sure it has a value

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    TWiki::Func::registerTagHandler( "EXAMPLETAG", \&_EXAMPLETAG );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% tag
# You would have one of these for each tag you want to process.
sub _EXAMPLETAG {
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

    # For example, %EXAMPLETAG{"hamburger" sideorder="onions"}%
    # $params->{_DEFAULT} will be "hamburger"
    # $params->{sideorder} will be "onions"
}

=cut

---++ earlyInitPlugin()

May be used by a plugin that requires early initialization, that
is expects to have initializeUserHandler called before initPlugin,
giving the plugin a chance to set the user.

The function is never called by the core code; it simply has to be
defined in order for intialiseUserHandler to be called.

See SessionPlugin for an example of usage.

=cut

sub DISABLE_earlyInitPlugin {
    die "Should never be called";
    return 1;
}

=pod

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username, for example based on cookies.

Return the user name, or =guest= if not logged in.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_initializeUserHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $loginName, $url, $pathInfo ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ registrationHandler($web, $wikiName, $loginName )
   * =$web= - the name of the web in the current CGI query
   * =$wikiName= - users wiki name
   * =$loginName= - users login name
Allows a plugin to set something up (for example a cookie) at
time of user registration.

Called by the register script.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_registrationHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $web, $wikiName, $loginName ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ commonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the code that expands %TAGS% syntax in
the topic body and in form fields.

Plugins that want to implement their own %TAGS% with non-trivial
additional syntax should implement this function. Internal TWiki
tags (and any tags declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %TAGS% are expanded.

For tags with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

Note that when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other HTML such as &lt;pre> blocks is
still present).

=cut

sub DISABLE_commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

=pod

---++ beforeCommonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called before TWiki does any expansion of it's own
internal tags. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

=cut

sub DISABLE_beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterCommonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is after TWiki has completed expansion of %TAGS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

=cut

sub DISABLE_afterCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ preRenderingHandler( $text, \%map ) -> $boolean
   * =\$text= - a reference to the text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Handler called immediately before TWiki syntax structures (such as lists) are
processed, but 

Placeholders are text strings constructed using the tag name and a sequence number e.g. "pre1", "verbatim6", "head1" etc. Placeholders are inserted into the text inside &lt;!--!marker!--&gt; characters so the text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters passed to the tag (usually empty) e.g. for
<verbatim>
<pre class="slobadob">
XYZ
</pre>
the map will contain:
<pre>
$removed->{"pre1"}{text}:   XYZ
$removed->{"pre1"}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>
Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_preRenderingHandler {
    my( $pText, $pMap ) = @_;
}

=pod

---++ postRenderingHandler( $text )
   * =\$text= - a reference to the entire rendered HTML page (not including HTTP headers). May be modified in place.

=cut

sub DISABLE_postRenderingHandler {
    my $pText = shift;
}

=pod

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. Use it to process the text before editing.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterEditHandler($text, $topic, $web )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the preview script just before presenting the text.

__NOTE:__ this handler is _not_ called unless the text is previewed.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_afterEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeSaveHandler($text, $topic, $web )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called just before the save action. The text is populated
with 'meta-data tags' before this method is called. If you modify any of
these tags, or their contents, you may break meta-data. You have been warned!

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
This handler is called just after the save action.

New hook in TWiki::Plugins::VERSION = '1.020'

=cut

sub DISABLE_afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called just before the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's Web.<nop>WikiName

New hook in TWiki::Plugins::VERSION = '1.023'

=cut

sub DISABLE_beforeAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterAttachmentSaveHandler(\%attrHash, $topic, $web, $error )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string generated during the save process
This handler is called just after the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's Web.<nop>WikiName

New hook in TWiki::Plugins::VERSION = '1.023'

=cut

sub DISABLE_afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ writeHeaderHandler($query )
   * =$query= - the CGI query

This handler is called just prior to writing the HTTP header.

Return a string containing _additional_ HTTP headers, delimited by CR/LF
and with no blank lines. Plugin generated headers may be modified by core
code before they are output, to fix bugs or manage caching. Plugins should
_not_ attempt to write headers to standard output.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_writeHeaderHandler {
    # do not uncomment, use $_[0] instead
    ### my ( $query ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;
}

=pod

---++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace TWiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_redirectCgiQueryHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $query, $url ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;
}

=pod

---++ getSessionValueHandler($key )
   * =$key= - the name of the key

This handler is called to recover the value of a session key i.e. a key
defined by setSessionValueHandler. This is primarily intended for use
with sesison management plugins..

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_getSessionValueHandler {
    # do not uncomment, use $_[0] instead
    ### my ( $key ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;
}

=pod

---++ setSessionValueHandler($key, $value )
   * =$key= - the name of the key
   * =$value= - the value of the key

This handler is called to set the value of a session key. This is
primarily intended for use with sesison management plugins.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

New hook in TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_setSessionValueHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $key, $value ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;
}

1;
