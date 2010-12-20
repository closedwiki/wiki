# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

=pod

---+ package TWiki::Plugins::SliderControlPlugin

To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin.

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS for error messages.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS. See
%TWIKIWEB%.TWikiPlugins#Handlig_deprecated_functions
for information on regarding deprecated handlers that are defined for
compatibility with older TWiki versions.

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut


package TWiki::Plugins::SliderControlPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $doneHeader );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS. Add your own release number
# such as '1.3' or release date such as '2010-05-08'
$RELEASE = '0.1';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'jquery based slider input';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'SliderControlPlugin';

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
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

    # Set plugin preferences in LocalSite.cfg, like this:
    # $TWiki::cfg{Plugins}{SliderControlPlugin}{ExampleSetting} = 1;
    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See TWiki.TWikiPlugins for help in adding your plugin
    # configuration to the =configure= interface.
    my $setting = $TWiki::cfg{Plugins}{SliderControlPlugin}{ExampleSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{SliderControlPlugin}{Debug} || 0;

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('example', \&restExample);

    $doneHeader  = 0;

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% variable
# You would have one of these for each variable you want to process.
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
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
}

=pod

---++ earlyInitPlugin()

This handler is called before any other handler, and before it has been
determined if the plugin is enabled or not. Use it with great care!

If it returns a non-null error string, the plugin will be disabled.

=cut

sub DISABLE_earlyInitPlugin {
    return undef;
}

=pod

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username. Normally TWiki gets the username
from the login manager. This handler gives you a chance to override the
login manager.

Return the *login* name.

This handler is called very early, immediately after =earlyInitPlugin=.

*Since:* TWiki::Plugins::VERSION = '1.010'

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

Called when a new user registers with this TWiki.

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_registrationHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $web, $wikiName, $loginName ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

For variables with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

Plugins that have to parse the entire topic content should implement
this function. Internal TWiki
variables (and any variables declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %<nop>TAGS% are expanded.

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $TWiki::Plugins::VERSION 1.000

=cut

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $included, $meta ) = @_;
    
    # If you don't want to be called from nested includes...
    #   if( $_[3] ) {
    #   # bail out, handler called from an %INCLUDE{}%
    #         return;
    #   }

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    $_[0] =~ s/%SLIDERCONTROL%/&handleSlider($_[1],$_[2], "")/ge;
    $_[0] =~ s/%SLIDERCONTROL{(.*)}%/&handleSlider($_[1],$_[2], $1)/ge;

}

=pod

---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub restExample {
   #my ($session) = @_;
   return "This is an example of a REST invocation\n\n";
}

=pod

---++ _addHeader()

Add all the javascript and css to the head

=cut

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    my $header .= <<'EOF';
<link rel="stylesheet" href="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jslider.css" type="text/css">
<link rel="stylesheet" href="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jslider.blue.css" type="text/css"><!--[if IE 6]>
<link rel="stylesheet" href="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jslider.ie6.css" type="text/css" media="screen">
<link rel="stylesheet" href="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jslider.blue.ie6.css" type="text/css" media="screen"><![
endif]-->
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jquery.core-1.3.2.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jquery.dependClass.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jquery.slider-min.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/SliderControlPlugin/jslider.init.js"></script>
EOF

    TWiki::Func::addToHEAD( 'SLIDERCONTROLPLUGIN_JS', $header );
}

=pod

---++ _addHeader()

Add all the javascript and css to the head

=cut

sub handleSlider
{
    my ($callingtopic, $callingweb, $args) = @_;

    my %params = TWiki::Func::extractParameters( $args );

# initvals . [number(s)] initial values for form
# from . [number] left limit
# to . [number] right limit
# step . [number] step of pointer
# round . [number] how many numbers after comma
# heterogeneity . [array] (percentage of place)/(value of place)
# dimension . [string] show this after number
# limits . [boolean] show or not limits
# scale . [array] labels under slider, .|. . show just line
# skin . [string] if you define new skin, just write here his name, in sources defined blue skin for example
# calculate . [function(value)] function to calculate final numbers, for example time.
# onstatechange . [function(value)] function fires while slider change state.
# callback . [function(value)] function fires on .mouseup. event.

        unless ($params{"name"}) {
                if (TWiki::Func::getPluginPreferencesValue("NAME")) {
                        $params{"name"} = TWiki::Func::getPluginPreferencesValue("NAME");
                } else {
                        $params{"name"} = 'defaultSliderName';
                }
        }
        unless ($params{"from"}) {
                if (TWiki::Func::getPluginPreferencesValue("FROM")) {
                        $params{"from"} = TWiki::Func::getPluginPreferencesValue("FROM");
                } else {
                        $params{"from"} = '1';
                }
        }
        unless ($params{"to"}) {
                if (TWiki::Func::getPluginPreferencesValue("TO")) {
                        $params{"to"} = TWiki::Func::getPluginPreferencesValue("TO");
                } else {
                        $params{"to"} = '10';
                }
        }
        unless ($params{"initvals"}) {
                if (TWiki::Func::getPluginPreferencesValue("INITVALS")) {
                        $params{"initvals"} = TWiki::Func::getPluginPreferencesValue("INITVALS");
                } else {
                        $params{"initvals"} = '7';
                }
        }
        unless ($params{"step"}) {
                if (TWiki::Func::getPluginPreferencesValue("STEP")) {
                        $params{"step"} = TWiki::Func::getPluginPreferencesValue("STEP");
                } else {
                        $params{"step"} = '1';
                }
        }
        unless ($params{"width"}) {
                if (TWiki::Func::getPluginPreferencesValue("WIDTH")) {
                        $params{"width"} = TWiki::Func::getPluginPreferencesValue("WIDTH");
                } else {
                        $params{"width"} = '400px';
                }
        }
        unless ($params{"round"}) {
                if (TWiki::Func::getPluginPreferencesValue("ROUND")) {
                        $params{"round"} = TWiki::Func::getPluginPreferencesValue("ROUND");
                }
        }
#        unless ($params{"orientation"}) {
#                if (TWiki::Func::getPluginPreferencesValue("ORIENTATION")) {
#                        $params{"orientation"} = TWiki::Func::getPluginPreferencesValue("ORIENTATION");
#                }
#        }
        unless ($params{"heterogeneity"}) {
                if (TWiki::Func::getPluginPreferencesValue("HETEROGENEITY")) {
                        $params{"heterogeneity"} = TWiki::Func::getPluginPreferencesValue("HETEROGENEITY");
                }
        }
        unless ($params{"dimension"}) {
                if (TWiki::Func::getPluginPreferencesValue("DIMENSION")) {
                        $params{"dimension"} = TWiki::Func::getPluginPreferencesValue("DIMENSION");
                }
        }
        unless ($params{"limits"}) {
                if (TWiki::Func::getPluginPreferencesValue("LIMITS")) {
                        $params{"limits"} = TWiki::Func::getPluginPreferencesValue("LIMITS");
                }
        }
        unless ($params{"scale"}) {
                if (TWiki::Func::getPluginPreferencesValue("SCALE")) {
                        $params{"scale"} = TWiki::Func::getPluginPreferencesValue("SCALE");
                }
        }
        unless ($params{"skin"}) {
                if (TWiki::Func::getPluginPreferencesValue("SKIN")) {
                        $params{"skin"} = TWiki::Func::getPluginPreferencesValue("SKIN");
                }
        }
        unless ($params{"calculate"}) {
                if (TWiki::Func::getPluginPreferencesValue("CALCULATE")) {
                        $params{"calculate"} = TWiki::Func::getPluginPreferencesValue("CALCULATE");
                }
        }
        unless ($params{"onstatechange"}) {
                if (TWiki::Func::getPluginPreferencesValue("ONSTATECHANGE")) {
                        $params{"onstatechange"} = TWiki::Func::getPluginPreferencesValue("ONSTATECHANGE");
                }
        }
        unless ($params{"callback"}) {
                if (TWiki::Func::getPluginPreferencesValue("CALLBACK")) {
                        $params{"callback"} = TWiki::Func::getPluginPreferencesValue("CALLBACK");
                }
        }


    _addHeader();

    my $ldebug = $debug;
    #&TWiki::Func::writeDebug( "- ${pluginName}::handleSlider(\n someVar: $someVar\n )" ) if $ldebug;
    my $ret = "";

    # Add slider
    $ret .= "<div class=\"layout-slider\"";
    if ($params{"width"}) {
            $ret .= " style=\"width: " . $params{"width"} . "\"";
    }
    $ret .= ">";
    $ret .= "\n<input id=\"" . $params{"name"} . "ID\" type=\"slider\" name=\"" . $params{"name"} . "\" value=\"" . $params{"initvals"} . "\" />";
    $ret .= "\n</div>";
    $ret .= "\n<script type=\"text/javascript\" charset=\"utf-8\">";
    $ret .= "\njQuery(\"#" . $params{"name"} . "ID\").slider({";
    if ($params{"heterogeneity"}) {
            $ret .= "\nheterogeneity: " . $params{"heterogeneity"} . ",";
    }
    if ($params{"dimension"}) {
            $ret .= "\ndimension: '" . $params{"dimension"} . "',";
    }
    if ($params{"round"}) {
            $ret .= "\nround: " . $params{"round"} . ",";
    }
    if ($params{"limits"}) {
            $ret .= "\nlimits: " . $params{"limits"} . ",";
    }
    if ($params{"scale"}) {
            $ret .= "\nscale: " . $params{"scale"} . ",";
    }
#    if ($params{"orientation"}) {
#            $ret .= "\norientation: " . $params{"orientation"} . ",";
#    }
#    if ($params{"skin"}) {
#           $ret .= "\nskin: " . $params{"skin"} . ",";
#    }
    if ($params{"calculate"}) {
            $ret .= "\ncalculate: " . $params{"calculate"} . ",";
    }
    if ($params{"onstatechange"}) {
            $ret .= "\nonstatechange: " . $params{"onstatechange"} . ",";
    }
    if ($params{"callback"}) {
            $ret .= "\ncallback: " . $params{"callback"} . ",";
    }
    $ret .= "\nfrom: " . $params{"from"} . ",";
    $ret .= "\nto: " . $params{"to"} . ",";
    $ret .= "\nstep: " . $params{"step"} . "})\;";
    $ret .= "\n</script>";

    #&TWiki::Func::writeDebug( "- ${pluginName}::handleSlider() returns:\n$ret" ) if $ldebug;
    return $ret;
}



1;
