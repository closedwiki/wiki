# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
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

---+ package TemplateToolkitPlugin

This plugin allows to use
[[http://www.template-toolkit.org][Template Toolkit]]
syntax in your TWiki topic.

=cut

package TWiki::Plugins::TemplateToolkitPlugin;

use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $NO_PREFS_IN_TOPIC );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Allow Template Toolkit expansion of topics';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
my $pluginName = 'TemplateToolkitPlugin';

# The template object.  It is made persistent to allow it to be
# created from e.g. a mod_perl startup routine, like that:
#     use Template;
#     use TWiki::Plugins::TemplateToolkitPlugin;
#     $TWiki::Plugins::TemplateToolkitPlugin::tt = Template->new(...);
# For non-persistent interpreters the tt object is instanciated in
# initPlugin
our $tt;

# Defaults can be overridden by configuration settings
#    1 TT preferences - only used once on object creation
my %tt_defaults  =  (START_TAG => '(?:(?<=\[{2})|(?<=\]\[)|(?<![\[\]]))\[%',
                    );
my $process_tt_default   =  0;

# Variables which need to be recorded between different callbacks
# *Must* be initialized per-request for mod_perl compliance
my $process_tt;



=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

The initialisation performs the following steps:
   1 compiles =Template.pm= (unless this has been done in advance), 
     failing gracefully in case of error
   1 initializes the TT object - again allowing for a persistent instance
      1 Picks options from =%TWiki::cfg=
   1 saves configuration options as package vars

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Check for availability of the Template module, indicate plugin
    # initialisation failure if missing
    eval {require Template;};
    if ($@) {
        TWiki::Func::writeWarning("Failed to use the Template Toolkit module");
        return 0;
    }

    # The TT object may have been created before in a persistent interpreter,
    # so check for existence before doing it for this particular request
    if (! $tt) {
        # Initialize TT options from the defaults hash, and override
        # with values from the configuration if present
        my $tt_options  =  $TWiki::cfg{Plugins}{TemplateToolkitPlugin}{TTOptions};
        my %tt_options  =  (defined $tt_options  and  ref $tt_options  eq  'HASH')
                        ?  (%tt_defaults,%$tt_options)
                        :  (%tt_defaults);

        # Create the TT object, indicate plugin init failure if it doesn't work
        $tt = Template->new(\%tt_options);
        if (! $tt) {
            TWiki::Func::writeWarning("Failed to create the TT object");
            return 0;
        }

        # Initialize per-block plugin processing options
        my $use_tt  =  $TWiki::cfg{Plugins}{TemplateToolkitPlugin}{UseTT};
        $process_tt_default  =  $use_tt if defined $use_tt;
    }

    $debug = $TWiki::cfg{Plugins}{TemplateToolkitPlugin}{Debug} || 0;

    # per-request option must be explicitly set to default (mod_perl)
    $process_tt  =  $process_tt_default;

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'TEMPLATETOOLKIT', \&_TT );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    # TWiki::Func::registerRESTHandler('example', \&restExample);


    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% variable
# You would have one of these for each variable you want to process.
sub _TT {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: The empty string - this variable is just an invisible trigger
    #         to control TT processing

    $process_tt  =  _isTrue($params->{_DEFAULT})  if  (defined $params->{_DEFAULT});
    return '';
}

=pod

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Handler called immediately before TWiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to 
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a 
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are 
inserted into the text inside &lt;!--!marker!--&gt; characters so the 
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters 
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a 
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

The current handler simply feeds the text without verbatim blocks to TT
and returns the result (using $_[0] as in/out parameter).

=cut

sub preRenderingHandler {
    my ($text,$pMap) = @_;

    my $out;
    if ($process_tt) {
        $tt->process(\$_[0],{},\$out)  or warn $tt->error();
        $_[0]  =  $out;
    }
}


# ----------------------------------------------------------------------
# Non-serviceable parts inside
sub _isTrue {
    my $value = shift;
    return $value =~ /^on|yes|1$/i ? 1 : 0;
}

1;
