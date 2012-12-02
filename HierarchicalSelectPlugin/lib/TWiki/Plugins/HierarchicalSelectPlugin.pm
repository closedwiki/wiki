# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Twiki Inc
# Copyright (C) 2010-2012 TWiki Contributors
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
# Drop-Down Menu Plugin for TWiki
# Written by Ian Kluft for TWiki Inc.

=pod

---+ package HierarchicalSelectPlugin

This is the drop-down menu TWiki plugin. 

=cut

package TWiki::Plugins::HierarchicalSelectPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
our ( $VERSION, $RELEASE, $SHORTDESCRIPTION, $debug, $pluginName,
	$NO_PREFS_IN_TOPIC, %menu_trees );

$VERSION = '$Rev: 15942 (02 Sep 2009) $';
$RELEASE = '2012-12-01';

$SHORTDESCRIPTION = 'Drop-Down Menu Plugin for JavaScript multi-level drop-down menus';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'HierarchicalSelectPlugin';

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

    # Set plugin preferences in LocalSite.cfg, like this:
    # $TWiki::cfg{Plugins}{HierarchicalSelectPlugin}{ExampleSetting} = 1;
    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See TWiki.TWikiPlugins for help in adding your plugin
    # configuration to the =configure= interface.
    $debug = $TWiki::cfg{Plugins}{HierarchicalSelectPlugin}{Debug} || 0;

    # register the _HIERARCHICALSELECT function to handle %HIERARCHICALSELECT{...}%
    # This will be called whenever %HIERARCHICALSELECT% or %HIERARCHICALSELECT{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'HIERARCHICALSELECT', \&_HIERARCHICALSELECT );

    # Plugin correctly initialized
    return 1;
}

# unHTMLify a string
sub _unhtmlify
{
	my $str = shift;
	$str =~ s/<[^>]*>//g;
	return $str;
}

# get menu content from file or cache
sub _get_menu_tree
{
	my $params = shift;
	my $theTopic = shift;
	my $theWeb = shift;

	# get parameters
	my $menu_web = ( exists $params->{web}) ? $params->{web} : $theWeb;
	my $menu_topic = $params->{topic}; # already error-checked in parent
	my $menu_key = ( exists $params->{key}) ? $params->{key} : $menu_topic;
	$menu_key =~ s/[^\w]//g;
	my $menu_names = ( exists $params->{names}) ? $params->{names} : $menu_topic;
	my $parse_keywords = ( exists $params->{parse_keywords})
		? $params->{parse_keywords} : 0;

	# check if tree has already been generated and saved for this menu
	if ( exists $menu_trees{$menu_key}) {
		return $menu_trees{$menu_key};
	}

	# get menu content
	my $menu_content = TWiki::Func::readTopicText( $menu_web, $menu_topic );
	if ( !$menu_content ) {
		my $err = "HierarchicalSelectPlugin: Failed to read menu topic "
				.$menu_web.".".$menu_topic;
		TWiki::Func::writeWarning( $err );
		return { error => $err };
	}

	#
	# process menu content
	#

	# if there are STARTINCLUDE/STOPINCLUDE tags, only use what's within them
	if ( $menu_content =~ /^.*%STARTINCLUDE%(.*)%STOPINCLUDE%.*$/s ) {
		$menu_content = $1;
	}

	# parse menu level names
	my @level_names = ( defined $menu_names ) ? ( split /,\s*/, $menu_names ) : ();

	# initialize tree root
	my ( %tree, $ins_point, $prev, $serial );
	$serial = 0;
	$tree{parent} = undef;
	$tree{root} = 1;
	$tree{depth} = 0;
	$tree{indent} = 0;
	$tree{serial} = $serial++;
	$ins_point = $prev = \%tree;
	$tree{levelname} = ( exists $level_names[0]) ? $level_names[0] : "level0";
	$tree{levelnames} = \@level_names;
	$tree{maxdepth} = 0;

	# process each line of the menu definition
	foreach my $line ( split /[\r\n]+/, $menu_content ) {
		# needs to match a TWiki bullet menu entry
		$line =~ s/\s*$//s; # remove trailing whitespace
		$line =~ /^( +)\*\s*(.*)/ or next;

		# collect data from menu entry
		my $indent_str = $1;
		my $indent = length( $indent_str );
		my $text = $2;

		# if more than one word, first is form keyword
		my $keyword;
		$text =~ s/\s*$//; # remove trailing whitespace
		if ( $parse_keywords and $text =~ /^([^\s]+)\s+(.+)/ ) {
			$keyword = $1;
			$text = $2;
		} else {
			$keyword = $text;
		}
		
		# create new tree node
		my $node = {};
		$node->{keyword} = $keyword;
		$node->{text} = $text;
		$node->{indent} = $indent;
		$node->{serial} = $serial++;

		# adding node to tree depends on greater, less or equal depth
		my $do_descent = 0;
		if ( $indent > $prev->{indent}) {
			# the indent level has increased
			# previous node will become new insertion point
			$ins_point = $prev;
		} elsif ( $indent < $prev->{indent} ) {
			# the indent level has reduced
			# move insertion point back up the tree to the correct depth
			while (( defined $ins_point ) and ( exists $ins_point->{parent})
				and $ins_point->{indent} >= $indent )
			{
				if ( $ins_point == $ins_point->{parent}) {
					Twiki::Func::writeWarning( "avoided infinite loop: "
						."node-parent points to self\n" );
					last;
				}
				$ins_point = $ins_point->{parent};
			}
		}

		# process special data to be stored with current insertion point node
		if ( $text =~ /^\*([^*]*)\*\s+(.*)/ ) {
			my $dtype = $1;
			my $arg = $2;
			if ( !exists $ins_point->{data}) {
				$ins_point->{data} = {};
			}
			if ( !exists $ins_point->{data}{$dtype}) {
				$ins_point->{data}{$dtype} = [];
			}
			push @{$ins_point->{data}{$dtype}}, $arg;
			undef $node; # clean up
			next;
		}

		# add new node at insertion point
		$node->{depth} = $ins_point->{depth} + 1;
		if ( $node->{depth} > $tree{maxdepth}) {
			$tree{maxdepth} = $node->{depth};
		}
		$node->{levelname} = ( exists $level_names[$node->{depth}])
			? $level_names[$node->{depth}]
			: "level".$node->{depth};
		$node->{parent} = $ins_point;
		if ( !exists $ins_point->{nodes}) {
			$ins_point->{nodes} = [];
		}
		push @{$ins_point->{nodes}}, $node;
		$prev = $node;
	}

	# save for later just in case
	$menu_trees{$menu_key} = \%tree;

	# return tree structure
	return \%tree;
}

# recursive function to generate menu HTML
sub _generate_menu
{
	my $tree = shift;
	my $menu_key = shift;
	my $menu_level = shift;
	my ( $node, $result );

	# skip if the node has no subnodes (not a menu)
	if ( !exists $tree->{nodes}) {
		return "";
	}

	# generate HTML for this tree's top level
	$result = "";
	my $txt_key = lc(_unhtmlify( $menu_key ));
	my $id = ( $tree->{serial}) ? $txt_key.'-'.sprintf("%05d", $tree->{serial})
		: $txt_key."_top";

	# generate menu text if we're doing all levels or at the selected level
	if (( !defined $menu_level ) or ( $menu_level == $tree->{depth})) {
		$result .= '<!-- TWiki '.$txt_key.' '
			.( exists $tree->{keyword} ? $tree->{keyword} : 'root')
			.' ('.sprintf("%05d", $tree->{serial}).') -->'
			.'<div class="twiki_hierarchicalselect menu_'
			.$txt_key.' level'.$tree->{depth}
			.'" id="'.$id.'">'."\n";
		if ( exists $tree->{data}{prefix}) {
			$result .= join( "", @{$tree->{data}{prefix}})."\n";
		}
		$result .= '<select name="'
			.( exists $tree->{keyword} ? $tree->{keyword} : 'root')
			.'" levelname="'.$txt_key."_".$tree->{levelname}.'">\n';
		if ( exists $tree->{data}{default}) {
			$result .= '<option value="none">'
				.join( "", @{$tree->{data}{default}}).'</option>'."\n";
		}
		foreach $node ( @{$tree->{nodes}}) {
			$result .= '<option ';
			if ( exists $node->{nodes}) {
			$result .= 'submenu="'
				.$txt_key.'-'.sprintf("%05d", $node->{serial}).'" ';
			}
			$result .= 'value="'.$node->{keyword}
				.'">'.$node->{text}.'</option>'."\n";
		}
		$result .= "</select>\n";
		if ( exists $tree->{data}{suffix}) {
			$result .= join( "", @{$tree->{data}{suffix}})."\n";
		}
		$result .= "</div>\n";
	}

	# generate HTML recursively for subtrees
	foreach $node ( @{$tree->{nodes}}) {
		$result .= _generate_menu( $node, $txt_key, $menu_level );
	}

	return $result;
}

# The function used to handle the %HIERARCHICALSELECT{...}% variable
# You would have one of these for each variable you want to process.
sub _HIERARCHICALSELECT {
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

    # examples:
	#   %HIERARCHICALSELECT{web="Menus" topic="Example"}%
	#   %HIERARCHICALSELECT{web="Menus" topic="Example" level="1"}%

	# get parameters
	my $menu_web = ( exists $params->{web}) ? $params->{web} : $theWeb;
	my $menu_topic = ( exists $params->{topic}) ? $params->{topic} : undef;
	if ( !defined $menu_topic ) {
		TWiki::Func::writeWarning(
			"HierarchicalSelectPlugin: missing parameter topic in "
				.$menu_web.".".$menu_topic );
		return "HierarchicalSelectPlugin: missing parameter topic in "
				.$menu_web.".".$menu_topic;
	}
	my $menu_key = ( exists $params->{key}) ? $params->{key} : $menu_topic;
	$menu_key =~ s/[^\w]//g;
	my $txt_key = lc(_unhtmlify( $menu_key ));
	my $menu_level = ( exists $params->{level}) ? $params->{level} : undef;

	# add JavaScript code to TWiki header only on pages that use it
    my $js_uri = $TWiki::cfg{Plugins}{HierarchicalSelectPlugin}{JavaScriptURI};
	if ( !defined $js_uri ) {
		$js_uri = TWiki::Func::getPubUrlPath()
			."/".TWiki::Func::getTwikiWebname()
			."/HierarchicalSelectPlugin/twiki-hierarchicalselect.js";
	}
	TWiki::Func::addToHEAD( "HierarchicalSelectPlugin-JS",
		"<script type=\"text/javascript\" src=\"$js_uri\"></script>\n" );

	# get menu treee structure
	my $tree = _get_menu_tree( $params, $theTopic, $theWeb );
	if ( exists $tree->{error}) {
        TWiki::Func::writeWarning($tree->{error});
		return $tree->{error};
	}

	# generate menus
	my $result = _generate_menu( $tree, $menu_key, $menu_level );

	# make hidden input fields for each level's value
	if ( !exists $tree->{inputsdone}) {
		my $level;
		for ( $level = 0; $level < $tree->{maxdepth}; $level++ ) {
			my $levelname;
			if ( exists $tree->{levelnames}[$level]) {
				$levelname = $tree->{levelnames}[$level];
			} else {
				$levelname = "level$level";
			}
			$result .= '<input type="hidden" name="'.$levelname
				.'" id="'.$txt_key."_".$levelname.'" value="">'."\n";
		}
			$tree->{inputsdone} = 1;
	}

	return $result;
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

sub DISABLE_commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

=pod

---++ beforeCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called before TWiki does any expansion of it's own
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

__NOTE:__ This handler is not separately called on included topics.

=cut

sub DISABLE_beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
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
    ### my ( $text, $topic, $web, $meta ) = @_;

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

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterEditHandler($text, $topic, $web, $meta )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data for the topic.
This handler is called by the preview script just before presenting the text.
It is called once when the =preview= script is run.

__NOTE:__ this handler is _not_ called unless the text is previewed.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $TWiki::Plugins::VERSION 1.010

=cut

sub DISABLE_afterEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
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

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
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

*Since:* TWiki::Plugins::VERSION 1.025

=cut

sub DISABLE_afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterRenameHandler( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic (empty string if web rename)
   * =$oldAttachment= - name of old attachment (empty string if web or topic rename)
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic (empty string if web rename)
   * =$newAttachment= - name of new attachment (empty string if web or topic rename)

This handler is called just after the rename/move/delete action of a web, topic or attachment.

*Since:* TWiki::Plugins::VERSION = '1.11'

=cut

sub DISABLE_afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterRenameHandler( " .
                             "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" ) if $debug;
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
   * =user= - the user id
   * =tmpFilename= - name of a temporary file containing the attachment data

*Since:* TWiki::Plugins::VERSION = 1.025

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
   * =user= - the user id

*Since:* TWiki::Plugins::VERSION = 1.025

=cut

sub DISABLE_afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=begin twiki

---++ beforeMergeHandler( $text, $currRev, $currText, $origRev, $origText, $web, $topic )
   * =$text= - the new text of the topic
   * =$currRev= - the number of the most recent rev of the topic in the store
   * =$currText= - the text of that rev
   * =$origRev= - the number of the rev that the edit started on (or undef
     if that revision was overwritten by a replace-revision save)
   * =$origText= - the text of that revision (or undef)
   * =$web= - the name of the web for the topic being saved
   * =$topic= - the name of the topic
This handler is called immediately before a merge of a topic that was edited
simultaneously by two users. It is called once on the topic text from
the =save= script. See =mergeHandler= for handling individual changes in the
topic text (and in forms).

=cut

sub DISABLE_beforeMergeHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $currRev, $currText, $origRev, $origText, $web, $topic ) = @_;
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

*Since:* TWiki::Plugins::VERSION = 1.1

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

*Since:* TWiki::Plugins::VERSION 1.1

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

*Since:* TWiki::Plugins::VERSION 1.010

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
   * =$type= - type of form field (checkbox, radio etc)
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if
     any. May be a scalar (one legal value) or a ref to an array
     (several legal values)

Return HTML text that renders this field. If false, form rendering
continues by considering the built-in types.

*Since:* TWiki::Plugins::VERSION 1.1

Note that since TWiki-4.2, you can also extend the range of available
types by providing a subclass of =TWiki::Form::FieldDefinition= to implement
the new type (see =TWiki::Plugins.JSCalendarContrib= and
=TWiki::Plugins.RatingContrib= for examples). This is the preferred way to
extend the form field types, but does not work for TWiki < 4.2.

=cut

sub DISABLE_renderFormFieldForEditHandler {
}

=pod

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the topic being rendered (only since TWiki 4.2)

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub DISABLE_renderWikiWordHandler {
    my( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
    return $linkText;
}

=pod

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard TWiki scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub DISABLE_completePageHandler {
    #my($html, $httpHeaders) = @_;
    # modify $_[0] or $_[1] if you must change the HTML or headers
}

1;
