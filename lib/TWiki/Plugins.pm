# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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
# 2004-01-13 RafaelAlvarez Added a new Plugin callback handler (afterSaveHandler)
=begin twiki

---+ TWiki:: Module

This module handles Plugins loading, initialization and execution

=cut

package TWiki::Plugins;

use strict;
no strict 'refs';

use vars qw(
			%activePluginWebs @activePlugins @instPlugins %disabledPlugins
			@registrableHandlers %registeredHandlers %onlyOnceHandlers
			$VERSION $initialisationErrors
    );

$VERSION = '1.026';

$initialisationErrors = "";

@registrableHandlers = (                 #                                      VERSION:
        'earlyInitPlugin',               # ( )                                   1.020
        'initPlugin',                    # ( $topic, $web, $user, $installWeb )  1.000
        'initializeUserHandler',         # ( $loginName, $url, $pathInfo )       1.010
        'registrationHandler',           # ( $web, $wikiName, $loginName )       1.010
        'beforeCommonTagsHandler',       # ( $text, $topic, $web )               1.024
        'commonTagsHandler',             # ( $text, $topic, $web )               1.000
        'afterCommonTagsHandler',        # ( $text, $topic, $web )               1.024
        'startRenderingHandler',         # ( $text, $web )                       1.000
        'outsidePREHandler',             # ( $text )                             1.000
        'insidePREHandler',              # ( $text )                             1.000
        'endRenderingHandler',           # ( $text )                             1.000
        'beforeEditHandler',             # ( $text, $topic, $web )               1.010
        'afterEditHandler',              # ( $text, $topic, $web )               1.010
        'beforeSaveHandler',             # ( $text, $topic, $web )               1.010
        'afterSaveHandler',              # ( $text, $topic, $web, $errors )      1.020
        'beforeAttachmentSaveHandler',   # ( $attrHash, $topic, $web )           1.022
        'afterAttachmentSaveHandler',    # ( $attrHash, $topic, $web, $error )   1.022
        'writeHeaderHandler',            # ( $query )                            1.010
        'redirectCgiQueryHandler',       # ( $query, $url )                      1.010
        'getSessionValueHandler',        # ( $key )                              1.010
        'setSessionValueHandler',        # ( $key, $value )                      1.010
        'renderFormFieldForEditHandler', # ( $name, $type, $size, $value, $attributes, $output )
        'renderWikiWordHandler',         # ( text )                              1.023
    );
    
%onlyOnceHandlers = ( 'initializeUserHandler'   => 1,
                      'registrationHandler'     => 1,
                      'writeHeaderHandler'      => 1,
                      'redirectCgiQueryHandler' => 1,
                      'getSessionValueHandler'  => 1,
                      'setSessionValueHandler'  => 1,
                      'renderFormFieldForEditHandler'  => 1,
                      'renderWikiWordHandler'  => 1
                    );

%registeredHandlers = ();


# =========================
=pod

---++ sub getPluginVersion()

Returns the $TWiki::Plugins::VERSION number if no parameter is specified,
else returns the version number of a named Plugin. If the Plugin cannot
be found or is not active, 0 is returned.

=cut

sub getPluginVersion
{
    my ( $thePlugin ) = @_;

    my $version = 0;
    if( $thePlugin ) {
        foreach my $plugin ( @activePlugins ) {
            if( $plugin eq $thePlugin ) {
                $version = ${"TWiki::Plugins::${plugin}::VERSION"};
            }
        }
    } else {
        $version = $VERSION;
    }
    return $version;
}

# Locate and register all plugins.
sub _discoverPluginPerlModules
{
    my $libDir = TWiki::getTWikiLibDir();
    my @plugins = ();
    my @modules = ();
    if( opendir( DIR, "$libDir/TWiki/Plugins" ) ) {
        @modules = map{ s/\.pm$//i; $_ }
                   sort
                   grep /.+Plugin\.pm$/i, readdir DIR;
        push( @plugins, @modules );
        closedir( DIR );
    }
    return @plugins;
}

# Register a plugin handler
sub _registerHandler
{
    my ( $handlerName, $theHandler ) = @_;
    push @{$registeredHandlers{$handlerName}}, ( $theHandler );
}

# Internal routine called every time a plugin fails to load
sub _initialisationError {
   my( $error ) = @_;
   $initialisationErrors .= $error."\n";
   TWiki::writeWarning( $error );
}

# FIXME: make all this sub more robust
# parameters: ( $plugin, $topic, $web, $user )
# If $user is empty this is preInitPlugin call - used to establish the user
sub _registerPlugin
{
    my ( $plugin, $topic, $web, $user, $theLoginName, $theUrl, $thePathInfo ) = @_;

    # look for the plugin installation web (needed for attached files)
    # in the order:
    #   1 fully specified web.plugin
    #   2 TWiki.plugin
    #   3 Plugins.plugin
    #   4 thisweb.plugin

    # Ignore an empty plugin name (should not happen, fix the calling function!).
	if ( ! $plugin ) {
      _initialisationError( "Plugins: undefined or empty plugin name" );
	  return;
    }

    my $installWeb = '';
    # first check for fully specified plugin
    if ( $plugin =~ m/^(.+)\.([^\.]+Plugin)$/ ) {
        $installWeb = $1;
        $plugin = $2;
    } 

    if( $activePluginWebs{$plugin} ) {
        # Plugin is already registered
        return;
    }

    if( ! $installWeb ) {
        if ( TWiki::Store::topicExists( $TWiki::twikiWebname, $plugin ) ) {
            # found plugin in TWiki web
            $installWeb = $TWiki::twikiWebname;
        } elsif ( TWiki::Store::topicExists( "Plugins", $plugin ) ) {
            # found plugin in Plugins web
            $installWeb = "Plugins";
        } elsif ( TWiki::Store::topicExists( $web, $plugin ) ) {
            # found plugin in current web
            $installWeb = $web;
        } else {
            # not found
            _initialisationError( "Plugins: couldn't register $plugin, no plugin topic" );
            return;
        }
    }

    # untaint & clean up the dirty laundry ....
    if ( $plugin =~ m/^([A-Za-z0-9_]+Plugin)$/ ) {
        $plugin = $1; 
    } else {
        _initialisationError("$plugin - invalid topic name for plugin");
        return;
    }

    my $p   = 'TWiki::Plugins::'.$plugin;

    eval "use $p;";

    if ($@) {
	_initialisationError("Plugin \"$p\" could not be loaded by Perl.  Errors were:\n----\n$@----");
	return;
    }
    
    my $h   = "";
    my $sub = "";
    my $prefix = "";
    if( ! $user ) {
        $sub = $p . '::earlyInitPlugin';
        if( ! defined( &$sub ) ) {
            return;
        }
        $sub = $p. '::initializeUserHandler';
        $user = &$sub( $theLoginName );
        return $user;

    }
    $sub = $p.'::initPlugin';
    # we register a plugin ONLY if it defines initPlugin AND it returns true 
    if( ! defined( &$sub ) ) {
        _initialisationError("Plugin $p iniPlugin did not return true");
        return;
    }
    # read plugin preferences before calling initPlugin
    $prefix = uc( $plugin ) . "_";
    TWiki::Prefs::getPrefsFromTopic( $installWeb, $plugin, $prefix );

    if( &$sub( $topic, $web, $user, $installWeb ) ) {
        foreach $h ( @registrableHandlers ) {
            $sub = $p.'::'.$h;
            _registerHandler( $h, $sub ) if defined( &$sub );
        }
        $activePluginWebs{$plugin} = $installWeb;
        push( @activePlugins, $plugin );;
    }
}

sub _applyHandlers
{
    my $handlerName = shift;
    my $theHandler;
    if( $TWiki::disableAllPlugins ) {
        return;
    }
    my $status;
    
    foreach $theHandler ( @{$registeredHandlers{$handlerName}} ) {
        # apply handler on the remaining list of args
        $status = &$theHandler;
        if( $onlyOnceHandlers{$handlerName} ) {
            if( $status ) {
                return $status;
            }
        }
    }
    
    return undef;
}

=pod

---++ sub initialize1 (  $theTopicName, $theWebName, $theLoginName, $theUrl, $thePathInfo  )

 Initialisation that is done is done before the user is known
 Can return a user e.g. if a plugin like SessionPlugin sets the user
 using initializeUserHandler.

=cut

sub initialize1
{
    my( $theTopicName, $theWebName, $theLoginName, $theUrl, $thePathInfo ) = @_;

    # initialize variables, needed when TWiki::initialize called more then once
    %registeredHandlers = ();
    undef @activePlugins;
    undef %activePluginWebs;
    undef @instPlugins;
	undef %disabledPlugins;

    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        return "";
    }

    # Get INSTALLEDPLUGINS and DISABLEDPLUGINS variables
    my $plugin = TWiki::Prefs::getPreferencesValue( "INSTALLEDPLUGINS" ) || "";
    $plugin =~ s/[\n\t\s\r]+/ /go;
    my @setInstPlugins = grep { /^.+Plugin$/ } split( /,?\s+/ , $plugin );
    $plugin = TWiki::Prefs::getPreferencesValue( "DISABLEDPLUGINS" ) || "";
	foreach my $p (split( /,?\s+/ , $plugin)) {
	  if ( $p =~ /^.+Plugin$/ ) {
		$p =~ s/^.*\.(.*)$/$1/;
		$disabledPlugins{$p} = 1 if ( $p );
	  }
	}

    my @discoveredPlugins = _discoverPluginPerlModules();
    my $p = "";
    foreach $plugin ( @setInstPlugins ) {
	  $p = $plugin;
	  $p =~ s/^.*\.(.*)$/$1/o; # cut web
	  if( $p && !$disabledPlugins{$p} ) {
		push( @instPlugins, $plugin );
	  }
    }
    # append discovered plugin modules to installed plugin list
    push( @instPlugins, @discoveredPlugins );

    # enable only specific plugins, for test and benchmarking
    my $query = TWiki::getCgiQuery();
    if ( $query ) {
        my $debugEnablePlugins = $query->param( 'debugenableplugins' );
        @instPlugins = split( /[\, ]+/, $debugEnablePlugins )
          if( $debugEnablePlugins );
    }

    # for efficiency we register all possible handlers at once
    my $user = "";
    my $posUser = "";
    foreach $plugin ( @instPlugins ) {
	  $p = $plugin;
	  $p =~ s/^.*\.(.*)$/$1/o; # cut web
	  unless( $disabledPlugins{$p} ) {
		$posUser = _registerPlugin( $plugin, $theTopicName, $theWebName, "", $theLoginName, $theUrl, $thePathInfo );
		if( $posUser ) {
		  $user = $posUser;
		}
	  }
    }
    unless( $user ) {
        $user = TWiki::User::initializeRemoteUser( $theLoginName );
    }
    return $user;
}


=pod

---++ sub initialize2 (  $theTopicName, $theWebName, $theUser  )
Initialisation that is done is done after the user is known

=cut

sub initialize2
{
    my( $theTopicName, $theWebName, $theUser ) = @_;

    # for efficiency we register all possible handlers at once
    my $p = "";
    my $plugin = "";
    foreach $plugin ( @instPlugins ) {
        $p = $plugin;
        $p =~ s/^.*\.(.*)$/$1/o; # cut web
        unless( $disabledPlugins{$p} ) {
            _registerPlugin( $plugin, @_, $theWebName, $theUser );
        }
    }
}

# %FAILEDPLUGINS reports reasons why plugins failed to load
sub _handleFAILEDPLUGINS
{
   my $text;

   $text .= "---++ Plugins defined\n";

   foreach my $plugin (@instPlugins) {
      $text .= "\t* $plugin\n";
   }

   $text.="\n\n";

   foreach my $handler (@registrableHandlers) {
      $text .= "| $handler |";
      $text .= "| $handler | ";
      if ( defined( $registeredHandlers{$handler} ) ) {
          $text .= join "<br />", @{$registeredHandlers{$handler}};
      }
      $text .= " |\n";
   }

   my $err = $initialisationErrors;
   $err = "None" unless $err;
   $text .= "<br />\n---++ Errors\n<verbatim>\n$err\n</verbatim>\n";

   return $text;
}

sub _handlePLUGINDESCRIPTIONS
{
    my $text = "";
    my $line = "";
    my $pref = "";
    foreach my $plugin ( @activePlugins ) {
        $pref = uc( $plugin ) . "_SHORTDESCRIPTION";
        $line = TWiki::Prefs::getPreferencesValue( $pref );
        if( $line ) {
            $text .= "\t\* $activePluginWebs{$plugin}.$plugin: $line\n"
        }
    }

    return $text;
}

sub _handleACTIVATEDPLUGINS
{
    my $text = "";
    foreach my $plugin ( @activePlugins ) {
	  $text .= "$activePluginWebs{$plugin}.$plugin, ";
    }
    $text =~ s/\,\s*$//o;
    return $text;
}

=pod

---++ sub registrationHandler ()

Called by the register script

=cut

sub registrationHandler
{
#    my( $web, $wikiName, $loginName ) = @_;
    _applyHandlers( 'registrationHandler', @_ );
}

=pod

---++ sub beforeCommonTagsHandler ()

Called by sub handleCommonTags at the beginning (for cache Plugins only)

=cut

sub beforeCommonTagsHandler
{
#    my( $text, $topic, $theWeb ) = @_;
    _applyHandlers( 'beforeCommonTagsHandler', @_ );
}

=pod

---++ sub commonTagsHandler ()

Called by sub handleCommonTags, after %INCLUDE:"..."%

=cut

sub commonTagsHandler
{
#    my( $text, $topic, $theWeb ) = @_;
    _applyHandlers( 'commonTagsHandler', @_ );
    $_[0] =~ s/%PLUGINDESCRIPTIONS%/&_handlePLUGINDESCRIPTIONS()/geo;
    $_[0] =~ s/%ACTIVATEDPLUGINS%/&_handleACTIVATEDPLUGINS()/geo;
    $_[0] =~ s/%FAILEDPLUGINS%/&_handleFAILEDPLUGINS()/geo;
}

# =========================
=pod

---++ sub afterCommonTagsHandler ()

Called by sub handleCommonTags at the end (for cache Plugins only)

=cut

sub afterCommonTagsHandler
{
#    my( $text, $topic, $theWeb ) = @_;
    _applyHandlers( 'afterCommonTagsHandler', @_ );
}

# =========================
=pod

---++ sub startRenderingHandler ()

Called by getRenderedVersion just before the line loop

=cut

sub startRenderingHandler
{
#    my ( $text, $web ) = @_;
    _applyHandlers( 'startRenderingHandler', @_ );
}

# =========================
=pod

---++ sub outsidePREHandler ()

Called by sub getRenderedVersion, in loop outside of <PRE> tag

=cut

sub outsidePREHandler
{
#    my( $text ) = @_;
    _applyHandlers( 'outsidePREHandler', @_ );
}

# =========================
=pod

---++ sub insidePREHandler ()

Called by sub getRenderedVersion, in loop inside of <PRE> tag

=cut

sub insidePREHandler
{
#    my( $text ) = @_;
    _applyHandlers( 'insidePREHandler', @_ );
}

# =========================
=pod

---++ sub endRenderingHandler ()

Called by getRenderedVersion just after the line loop

=cut

sub endRenderingHandler
{
#    my ( $text ) = @_;
    _applyHandlers( 'endRenderingHandler', @_ );
}

# =========================
=pod

---++ sub beforeEditHandler ()

Called by edit

=cut

sub beforeEditHandler
{
#    my( $text, $topic, $web ) = @_;
    _applyHandlers( 'beforeEditHandler', @_ );
}

# =========================
=pod

---++ sub afterEditHandler ()

Called by edit

=cut

sub afterEditHandler
{
#    my( $text, $topic, $web ) = @_;
    _applyHandlers( 'afterEditHandler', @_ );
}

# =========================
=pod

---++ sub beforeSaveHandler ()

Called by TWiki::Store::saveTopic before the save action

=cut

sub beforeSaveHandler
{
#    my ( $theText, $theTopic, $theWeb ) = @_;
    _applyHandlers( 'beforeSaveHandler', @_ );
}

=pod

---++ sub afterSaveHandler ()

Called by TWiki::Store::saveTopic after the save action

=cut

sub afterSaveHandler
{
#    my ( $theText, $theTopic, $theWeb ) = @_;
    _applyHandlers( 'afterSaveHandler', @_ );
}

=pod

---++ sub beforeAttachmentSaveHandler ( $attrHashRef, $topic, $web ) 

| Description: | This code provides Plugins with the opportunity to alter an uploaded attachment between the upload and save-to-store processes. It is invoked as per other Plugins. |
| Parameter: =$attrHashRef= | Hash reference of attachment attributes (keys are indicated below) |
| Parameter: =$topic=       | Topic name |
| Parameter: =$web=         | Web name |
| Return:                   | There is no defined return value for this call |

Keys in $attrHashRef:
| *Key*       | *Value* |
| attachment  | Name of the attachment |
| tmpFilename | Name of the local file that stores the upload |
| comment     | Comment to be associated with the upload |
| user        | Login name of the person submitting the attachment, e.g. "jsmith" |

Note: All keys should be used read-only, except for comment which can be modified.

Example usage:

<pre>
   my( $attrHashRef, $topic, $web ) = @_;
   $$attrHashRef{"comment"} .= " (NOTE: Extracted from blah.tar.gz)";
</pre>

=cut

sub beforeAttachmentSaveHandler
{
    # Called by TWiki::Store::saveAttachment before the save action
#    my ( $theAttrHash, $theTopic, $theWeb ) = @_;
    _applyHandlers( 'beforeAttachmentSaveHandler', @_ );
}

=pod

---++ sub afterAttachmentSaveHandler( $attachmentAttrHash, $topic, $web, $error ) 

| Description: | This code provides plugins with the opportunity to alter an uploaded attachment between the upload and save-to-store processes. It is invoked as per other plugins. |

| Parameter: =$attrHashRef= | Hash reference of attachment attributes (keys are indicated below) |
| Parameter: =$topic=       | Topic name |
| Parameter: =$web=         | Web name |
| Parameter: =$error=       | Error string of save action, empty if OK |
| Return:                   | There is no defined return value for this call |

Keys in $attrHashRef:
| *Key*       | *Value* |
| attachment  | Name of the attachment |
| tmpFilename | Name of the local file that stores the upload |
| comment     | Comment to be associated with the upload |
| user        | Login name of the person submitting the attachment, e.g. "jsmith" |

Note: All keys should be used read-only.

=cut

sub afterAttachmentSaveHandler
{
# Called by TWiki::Store::saveAttachment after the save action
#    my ( $theText, $theTopic, $theWeb ) = @_;
    _applyHandlers( 'afterAttachmentSaveHandler', @_ );
}


# =========================
=pod

---++ sub writeHeaderHandler ()

Called by TWiki::writeHeader

=cut

sub writeHeaderHandler
{
    return _applyHandlers( 'writeHeaderHandler', @_ );
}

# =========================
=pod

---++ sub redirectCgiQueryHandler ()

Called by TWiki::redirect

=cut

sub redirectCgiQueryHandler
{
    return _applyHandlers( 'redirectCgiQueryHandler', @_ );
}

# =========================
=pod

---++ sub getSessionValueHandler ()

Called by TWiki::getSessionValue

=cut

sub getSessionValueHandler
{
    return _applyHandlers( 'getSessionValueHandler', @_ );
}

# =========================
=pod

---++ sub setSessionValueHandler ()

Called by TWiki::setSessionValue

=cut

sub setSessionValueHandler
{
    return _applyHandlers( 'setSessionValueHandler', @_ );
}

# ========================
=pod

---++ sub renderFormFieldForEditHandler ( $name, $type, $size, $value, $attributes, $possibleValues )

| Description:       | This handler is called by Form.renderForEdit, before built-in types are considered. It generates the HTML text rendering this form field, or false, if the rendering should be done by the built-in type handlers. |
| Parameter: =$name= | name of form field |
| Parameter: =$type= | type of form field |
| Parameter: =$size= | size of form field |
| Parameter: =$value= | value held in the form field |
| Parameter: =$attributes= | attributes of form field  |
| Parameter: =$possibleValues= | the values defined as options for form field, if any |
| Return: =$text=  | HTML text that renders this field. If false, form rendering continues by considering the built-in types. |

Typical usage is in the style of Form.renderForEdit:

<pre>
   if ( is_type1($type) ) {
      $ret = compute_formating_for_type1();
   } elsif ( is_type2($type) ) {
      $ret = compute_formating_for_type2();
   } ...
   clean_up_if_necessary($ret);
   return $ret;
</pre>

Note that a common application would be to generate formatting of the 
field involving generation of javascript. Such usually also requires 
the insertion of some common javascript into the page header. Unfortunately, 
there is currently no mechanism to pass that script to where the header of 
the page is visible. Consequentially, the common javascript will have to
be emitted as part of the field formatting and might be duplicated many
times throughout the page.

=cut

sub renderFormFieldForEditHandler
{
    return _applyHandlers( 'renderFormFieldForEditHandler', @_ );
}

=pod

---++ sub renderWikiWordHandler ()

Called by TWiki::internalLink to change how a WikiWord is rendered

Originated from the TWiki:Plugins.SpacedWikiWordPlugin hack

=cut

sub renderWikiWordHandler
{
    return _applyHandlers( 'renderWikiWordHandler', @_ );
}


1;
