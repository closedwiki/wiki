# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Sven Dowideit, SvenDowideit@wikiring.com
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

---+ package HtmlFormsPlugin



=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::HtmlFormsPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'HtmlFormsPlugin';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'HtmlFormsPlugin';

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
    # $TWiki::cfg{Plugins}{HtmlFormsPlugin}{ExampleSetting} = 1;
    # Then recover it like this. Always provide a default in case the
    # setting is not defined in LocalSite.cfg
    my $setting = $TWiki::cfg{Plugins}{HtmlFormsPlugin}{ExampleSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{HtmlFormsPlugin}{Debug} || 0;

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'SELECT', \&_SELECT );
    TWiki::Func::registerTagHandler( 'CHECKBOX', \&_CHECKBOX );
    TWiki::Func::registerTagHandler( 'RADIO', \&_RADIO );

    TWiki::Func::registerTagHandler( 'TEXTVALUE', \&_TEXTVALUE );
    TWiki::Func::registerTagHandler( 'TEXTAREA', \&_TEXTAREA );
    
    TWiki::Func::registerTagHandler( 'BUTTON', \&_BUTTON );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    # TWiki::Func::registerRESTHandler('example', \&restExample);

    # Plugin correctly initialized
    return 1;
}

sub _SELECT {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $currentvalue = $params->{currentvalue} || '';
    my @current = split(/,\s*/, $currentvalue);
    
    my $optionlist = $params->{options} || '';
    my @options = split(/,\s*/, $optionlist);
    for my $opt (@current) {
        push @options, $opt unless (grep(/$opt/, @options));
    }
    
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->scrolling_list(
#        $session->{cgiQuery}->checkbox_group(
                -name=>$variable,
				-values=>\@options,          #['eenie','meenie','minie','moe'],
				-default=>\@current,         #['eenie','moe'],
				-size=>5,
				-multiple=>'true',
#				-linebreak=>'true',
#               -labels=>\%labels,
#               -attributes=>\%attributes
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}
sub _CHECKBOX {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $currentvalue = $params->{currentvalue} || '';
    my @current = split(/,\s*/, $currentvalue);
    
    my $optionlist = $params->{options} || '';
    my @options = split(/,\s*/, $optionlist);
    for my $opt (@current) {
        push @options, $opt unless (grep(/$opt/, @options));
    }
   
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->checkbox_group(
                -name=>$variable,
				-values=>\@options,          #['eenie','meenie','minie','moe'],
				-default=>\@current,         #['eenie','moe'],
				-linebreak=>'true',
#               -labels=>\%labels,
#               -attributes=>\%attributes
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}
sub _RADIO {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $currentvalue = $params->{currentvalue} || '';
    my @current = split(/,\s*/, $currentvalue);
    
    my $optionlist = $params->{options} || '';
    my @options = split(/,\s*/, $optionlist);
    for my $opt (@current) {
        push @options, $opt unless (grep(/$opt/, @options));
    }
    
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->radio_group(
                -name=>$variable,
				-values=>\@options,          #['eenie','meenie','minie','moe'],
				-default=>\@current,         #['eenie','moe'],
				-linebreak=>'true',
#               -labels=>\%labels,
#               -attributes=>\%attributes
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}
sub _TEXTVALUE {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $value = $params->{value} || '';
   
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->textfield(
                -name=>$variable,
				-value=>$value,
                -size=>50,
    		    -maxlength=>80				
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}
sub _TEXTAREA {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $value = $params->{value} || '';
    
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->textarea(
                -name=>$variable,
				-value=>$value,
                -rows=>10,
    		    -columns=>80				
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}
sub _BUTTON {
    my($session, $params, $theTopic, $theWeb) = @_;
    
    my $value = $params->{value} || '';
    
    my $destinationaddress = $params->{destinationaddress};

    my $web = $theWeb;
    my $topic = $theTopic;
    my $variable = $destinationaddress;
    if ($destinationaddress =~ /^(.*)\.([^.]*)$/) {
        $topic = $1;
        $variable = $2;
    }
    ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);
    
    my $method='POST';
    my $action="%SCRIPTURL{save}%/$web/$topic";
    
    my $element =     
        $session->{cgiQuery}->hidden(
                -name=>$variable,
				-default=>$value,
            );
    return getForm($session, $element, $method, $action, $variable, "$theWeb.$theTopic");
}

################################################################################
sub getForm {
    my ($session, $element, $method, $action, $variable, $redirectTo) = @_;

    my $form =     
#        "\n   * action  =$action= \n   * destinationaddress = =$destinationaddress= \n " .
        $session->{cgiQuery}->start_form(
                -method=>$method,
                -action=>$action,
#                -enctype=>$encoding
		    ) . 
        $element .
#TODO: add disabled if the user does not have permission
        $session->{cgiQuery}->submit(
                -name=>'button_name',
                -value=>"set value"
            ) .
        $session->{cgiQuery}->hidden(
                -name=>'htmlformvalue',
                -default=>"set"
            ) .
        $session->{cgiQuery}->hidden(
                -name=>'variable',
                -default=>"$variable"
            ) .
        $session->{cgiQuery}->hidden(
                -name=>'redirectto',
                -default=>$redirectTo
            ) .
        $session->{cgiQuery}->endform;
        
    return $form;
}


=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my ( $text, $topic, $web ) = @_;
    
   my $query = TWiki::Func::getCgiQuery();
   my $session = $TWiki::Plugins::SESSION;

   return unless defined($query->param('htmlformvalue'));
   
    my $name = $query->param('variable');
    my $params = $query->Vars;
    my @values = split("\0",$params->{$name});   #$query->param($name) || '';
    
    my $set = join(', ', @values);

   $_[3]->putKeyed( 'PREFERENCE',
                                 {
                                     name => $name,
                                     type => 'Set',
                                     title => 'PREFERENCE_'.$name,
                                     value => $set
                                    }
                                );
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.020'

=cut

sub afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

   my $query = TWiki::Func::getCgiQuery();
   my $session = $TWiki::Plugins::SESSION;

   return unless defined($query->param('htmlformvalue'));
    
    #on success, go back to where we came from, not what we saved..
    my ($redirectWeb, $redirectTopic) = TWiki::Func::normalizeWebTopicName('', $query->param('redirectto'));
    my $redirecturl = $session->getScriptUrl( 1, 'view', $redirectWeb, $redirectTopic );
    $session->redirect( $redirecturl );
}

=pod

---++ earlyInitPlugin()

May be used by a plugin that requires early initialization. This handler
is called before any other handler.

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
Allows a plugin to set the username, for example based on cookies.

Return the user name, or =guest= if not logged in.

This handler is called very early, immediately after =earlyInitPlugin=.

__Since:__ TWiki::Plugins::VERSION = '1.010'

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

__Since:__ TWiki::Plugins::VERSION = '1.010'

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
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Plugins that want to implement their own %TAGS% with non-trivial
additional syntax should implement this function. Internal TWiki
variables (and any variables declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %TAGS% are expanded.

For variables with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other HTML such as &lt;pre> blocks is
still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

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
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

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

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub DISABLE_afterCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
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

=cut

sub DISABLE_preRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

__NOTE__: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
}

=pod

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

__NOTE__: meta-data may be embedded in the text passed to this handler 
(using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.010'

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
It is called once when the =preview= script is run.

__NOTE:__ this handler is _not_ called unless the text is previewed.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_afterEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's TWiki user object
   * =tmpFilename= - name of a temporary file containing the attachment data

__Since:__ TWiki::Plugins::VERSION = '1.023'

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
   * =user= - the user's TWiki user object

__Since:__ TWiki::Plugins::VERSION = '1.023'

=cut

sub DISABLE_afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ mergeHandler( $diff, $old, $new, \%info ) -> $text
Try to resolve a difference encountered during merge. The =differences= 
array is an array of hash references, where each hash contains the 
following fields:
   * =$diff= => one of the characters '+', '-', 'c' or ' '.
      * '+' - =new= contains text inserted in the new version
      * '-' - =old= contains text deleted from the old version
      * 'c' - =old= contains text from the old version, and =new= text
        from the version being saved
      * ' ' - =new= contains text common to both versions, or the change
        only involved whitespace
   * =$old= => text from version currently saved
   * =$new= => text from version being saved
   * =\%info= is a reference to the form field description { name, title,
     type, size, value, tooltip, attributes, referenced }. It must _not_
     be wrtten to. This parameter will be undef when merging the body
     text of the topic.

Plugins should try to resolve differences and return the merged text. 
For example, a radio button field where we have 
={ diff=>'c', old=>'Leafy', new=>'Barky' }= might be resolved as 
='Treelike'=. If the plugin cannot resolve a difference it should return 
undef.

The merge handler will be called several times during a save; once for 
each difference that needs resolution.

If any merges are left unresolved after all plugins have been given a 
chance to intercede, the following algorithm is used to decide how to 
merge the data:
   1 =new= is taken for all =radio=, =checkbox= and =select= fields to 
     resolve 'c' conflicts
   1 '+' and '-' text is always included in the the body text and text
     fields
   1 =&lt;del>conflict&lt;/del> &lt;ins>markers&lt;/ins>= are used to 
     mark 'c' merges in text fields

The merge handler is called whenever a topic is saved, and a merge is 
required to resolve concurrent edits on a topic.

=cut

sub DISABLE_mergeHandler {
}

=pod

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =TWiki::Func::addToHEAD= method.

__Since:__ TWiki::Plugins::VERSION 1.026

=cut

sub DISABLE_modifyHeaderHandler {
    my ( $headers, $query ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::modifyHeaderHandler()" ) if $debug;
}

=pod

---++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace TWiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_redirectCgiQueryHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $query, $url ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;
}

=pod

---++ renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html

This handler is called before built-in types are considered. It generates 
the HTML text rendering this form field, or false, if the rendering 
should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if
     any. May be a scalar (one legal value) or a ref to an array
     (several legal values)

Return HTML text that renders this field. If false, form rendering 
continues by considering the built-in types.

=cut

sub DISABLE_renderFormFieldForEditHandler {
}

=pod

---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

=cut

sub restExample {
   #my ($session) = @_;
   return "This is an example of a REST invocation\n\n";
}

1;
