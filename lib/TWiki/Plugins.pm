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

# Reference information for a single plugin
package TWiki::Plugin;

use strict;
use TWiki;
use TWiki::Sandbox;
use Assert;

use vars qw( @registrableHandlers );

@registrableHandlers =
  (                                # VERSION:
   'earlyInitPlugin',              # 1.020
   'initPlugin',                   # 1.000
   'initializeUserHandler',        # 1.010
   'registrationHandler',          # 1.010
   'beforeCommonTagsHandler',      # 1.024
   'commonTagsHandler',            # 1.000
   'afterCommonTagsHandler',       # 1.024
   'startRenderingHandler',        # 1.000
   'outsidePREHandler',            # 1.000
   'insidePREHandler',             # 1.000
   'endRenderingHandler',          # 1.000
   'beforeEditHandler',            # 1.010
   'afterEditHandler',             # 1.010
   'beforeSaveHandler',            # 1.010
   'afterSaveHandler',             # 1.020
   'beforeAttachmentSaveHandler',  # 1.022
   'afterAttachmentSaveHandler',   # 1.022
   'writeHeaderHandler',           # 1.010
   'redirectCgiQueryHandler',      # 1.010
   'getSessionValueHandler',       # 1.010
   'setSessionValueHandler',       # 1.010
   'renderFormFieldForEditHandler',# ?
   'renderWikiWordHandler',        # 1.023
  );

sub new {
    my ( $class, $session, $name ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;
    my $this = bless( {}, $class );

    $name = TWiki::Sandbox::untaintUnchecked( $name );
    $this->{name} = $name;
    $this->{disabled} = 0;

    unless ( $name =~ m/^[A-Za-z0-9_]+Plugin$/ ) {
        push( @{$this->{errors}}, "$name - invalid name for plugin" );
        $this->{disabled} = 1;
    }

    $this->{session} = $session;

    return $this;
}

sub store { my $this = shift; return $this->{session}->{store}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }

# Load and verify a plugin, invoking any early registration
# handlers. Return the user resulting from the user handler call.
sub load {
    my ( $this ) = @_;
    assert(ref($this) eq "TWiki::Plugin") if DEBUG;

    return if $this->{disabled};

    # look for the plugin installation web (needed for attached files)
    # in the order:
    #   1 fully specified web.plugin
    #   2 TWiki.plugin
    #   3 Plugins.plugin
    #   4 thisweb.plugin

    my $web;
    if ( $this->store()->topicExists( $TWiki::twikiWebname, $this->{name} ) ) {
        # found plugin in TWiki web
        $web = $TWiki::twikiWebname;
    } elsif ( $this->store()->topicExists( "Plugins", $this->{name} ) ) {
        # found plugin in Plugins web (compatibility, deprecated)
        $web = "Plugins";
    } elsif ( $this->store()->topicExists( $this->{session}->{webName},
                                           $this->{name} ) ) {
        # found plugin in current web
        $web = $this->{session}->{webName};
    } else {
        # not found
        push( @{$this->{errors}}, "Plugins: couldn't register $this->{name}, no plugin topic" );
        $this->{web} = "(Not Found)";
        $this->{disabled} = 1;
        return undef;
    }

    $this->{web} = $web;

    my $p = 'TWiki::Plugins::'.$this->{name};
    #use Benchmark qw(:all :hireswallclock);
    #my $begin = new Benchmark;
    eval "use $p;";
    if ($@) {
        push( @{$this->{errors}}, "Plugin \"$p\" could not be loaded.  Errors were:\n----\n$@----" );
        $this->{disabled} = 1;
        return undef;
    }

    my $user;
    my $sub = $p . '::earlyInitPlugin';
    if( defined( &$sub ) ) {
        # Set the session for this call stack
        local $TWiki::Plugins::SESSION = $this->{session};
        # Note that the earlyInitPlugin method is _never called_. Not sure why
        # it exists at all!
        $sub = $p. '::initializeUserHandler';
        no strict 'refs';
        $user = &$sub( $this->{session}->{remoteUser},
                       $this->{session}->{url},
                       $this->{session}->{pathInfo} );
        use strict 'refs';
    }
    #print STDERR "Compile $p: ".timestr(timediff(new Benchmark, $begin))."\n";

    return $user;
}

# invoke plugin initialisation and register handlers.
sub registerHandlers {
    my ( $this, $plugins ) = @_;
    assert(ref($this) eq "TWiki::Plugin") if DEBUG;

    return if $this->{disabled};

    my $p = "TWiki::Plugins::" . $this->{name};
    my $sub = $p . "::initPlugin";
    if( ! defined( &$sub ) ) {
        push( @{$this->{errors}}, "$sub is not defined");
        $this->{disabled} = 1;
        return;
    }

    $this->prefs()->getPrefsFromTopic( $this->{web}, $this->{name},
                                       uc( $this->{name} ) . "_");

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    no strict 'refs';
    my $status = &$sub( $TWiki::Plugins::SESSION->{topicName},
                        $TWiki::Plugins::SESSION->{webName},
                        $TWiki::Plugins::SESSION->{userName},
                        $this->{web} );
    use strict 'refs';

    unless( $status ) {
        push( @{$this->{errors}}, "$p\::initPlugin did not return true ($status)" );
        $this->{disabled} = 1;
        return;
    }

    foreach my $h ( @registrableHandlers ) {
        my $sub = $p.'::'.$h;
        push( @{$plugins->{registeredHandlers}{$h}}, $sub )
          if( defined( &$sub ));
    }
}

sub getVersion {
    my $this = shift;
    assert(ref($this) eq "TWiki::Plugin") if DEBUG;

    no strict 'refs';
    return ${"TWiki::Plugins::$this->{name}::VERSION"};
    use strict 'refs';
}

sub getDescription {
    my $this = shift;
    assert(ref($this) eq "TWiki::Plugin") if DEBUG;

    return "" if $this->{disabled};

    unless( $this->{description} ) {
        my $pref = uc( $this->{name} ) . "_SHORTDESCRIPTION";
        $this->{description} = $this->prefs()->getPreferencesValue( $pref );
    }

    return "\t\* $this->{web}.$this->{name}: $this->{description}\n";
}

=pod

---+ TWiki::Plugins Module

This module defines the singleton object that handles Plugins
loading, initialization and execution

=cut

package TWiki::Plugins;

use strict;
use Assert;

use vars qw ( $VERSION $SESSION $inited );

$VERSION = '1.026';
$inited = 0;

my %onlyOnceHandlers =
  ( initializeUserHandler          => 1,
    registrationHandler            => 1,
    writeHeaderHandler             => 1,
    redirectCgiQueryHandler        => 1,
    getSessionValueHandler         => 1,
    setSessionValueHandler         => 1,
    renderFormFieldForEditHandler  => 1,
    renderWikiWordHandler          => 1,
  );

=pod

---++ sub new( $session )
Construct new singleton plugins engine object. The object is a contained for
a list of plugins and a set of handlers registered by each plugin. The plugins
and the handlers are carefully ordered.

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( {}, $class );

    assert(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

    unless( $inited ) {
        TWiki::registerTagHandler( "PLUGINDESCRIPTIONS",
                                   \&_handlePLUGINDESCRIPTIONS );
        TWiki::registerTagHandler( "ACTIVATEDPLUGINS",
                                   \&_handleACTIVATEDPLUGINS );
        TWiki::registerTagHandler( "FAILEDPLUGINS",
                                   \&_handleFAILEDPLUGINS );
        $inited = 1;
    }

    return $this;
}

sub prefs { my $this = shift; return $this->{session}->{prefs}; }

=pod

---+ load()
Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If disabled is set, no plugin handlers will be called.

=cut

sub load {
    my ( $this, $disabled ) = @_;
    assert(ref($this) eq "TWiki::Plugins") if DEBUG;

    my %disabledPlugins;

    # SMELL: this module should not rely on the environment. This
    # should be handled somewhere else. TWiki.pm?
    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        return "";
    }

    my $p;
    my %lookup;

    my $query = $this->{session}->{cgiQuery};

    my $debugEnablePlugins;
    my $session = $this->{session};

    if ( $query ) {
        $debugEnablePlugins = $query->param( 'debugenableplugins' );
    }

    if ( defined( $debugEnablePlugins )) {
        # enable only specific plugins, for test and benchmarking
        foreach $p ( grep { /^[A-Za-z0-9_]+Plugin$/ }
                     split( /[,\s]+/, $debugEnablePlugins )) {
            $p =~ s/\.([^.]+)$/$1/;
            unless( $lookup{$p} ) {
                push( @{$this->{plugins}}, $lookup{$p} =
                      new TWiki::Plugin( $session, $p ) );
            }
        }
    } else {
        # user-requested plugins
        my $installed = $this->prefs()->getPreferencesValue( "INSTALLEDPLUGINS" ) || "";
        foreach $p ( grep { /^[A-Za-z0-9_]+Plugin$/ }
                     split( /[,\s]+/ , $installed )) {
            $p =~ s/\.([^.]+)$/$1/;
            unless( $lookup{$p} ) {
                push( @{$this->{plugins}}, $lookup{$p} =
                      new TWiki::Plugin( $session, $p ) );
            }
        }

        # implicitly requested plugins
        foreach $p ( grep { /^[A-Za-z0-9_]+Plugin$/ }
                     split( /[,\s]+/ ,_discoverPluginPerlModules()) ) {
            unless( $lookup{$p} ) {
                push( @{$this->{plugins}}, $lookup{$p} =
                      new TWiki::Plugin( $session, $p ) );
            }
        }

        my $disabled = $this->prefs()->getPreferencesValue( "DISABLEDPLUGINS" ) || "";
        foreach $p ( grep { /^[A-Za-z0-9_]+Plugin$/ }
                     split( /[,\s]+/ , $disabled )) {
            if ( $p =~ /^.+Plugin$/ ) {
                $p =~ s/\.([^.]+)$/$1/;
                push( @{$this->{errors}}, "Disabled in DISABLEDPLUGINS" );
                $lookup{$p}->{disabled} = 1 if $lookup{$p};
            }
        }
    }

    my $user;
    foreach my $p ( @{$this->{plugins}} ) {
        if ( $disabled ) {
            # all plugins are disabled
            push( @{$this->{errors}}, "all plugins are disabled" );
            $p->{disabled} = 1;
        } else {
            $user = $p->load();
        }
    }

    return $user;
}

sub _discoverPluginPerlModules {
    my $libDir = TWiki::getTWikiLibDir();
    my @modules = ();
    if( opendir( DIR, "$libDir/TWiki/Plugins" ) ) {
        @modules = map{ s/\.pm$//i; $_ }
                   sort
                   grep /^[A-Za-z0-9_]+Plugin\.pm$/, readdir DIR;
        closedir( DIR );
    }
    return join(",", @modules);
}

=pod

---++ sub enable()

Initialisation that is done after the user is known.

=cut

sub enable {
    my $this = shift;
    assert(ref($this) eq "TWiki::Plugins") if DEBUG;

    foreach my $plugin ( @{$this->{plugins}} ) {
        $plugin->registerHandlers( $this );
        # Report initialisation errors
        if ( $plugin->{errors} ) {
            $this->{session}->writeWarning( join( "\n", @{$plugin->{errors}} ));
        }
    }
}

=pod

---++ sub getPluginVersion()

Returns the $TWiki::Plugins::VERSION number if no parameter is specified,
else returns the version number of a named Plugin. If the Plugin cannot
be found or is not active, 0 is returned.

=cut

sub getPluginVersion {
    my ( $this, $thePlugin ) = @_;
    assert(ref($this) eq "TWiki::Plugins") if DEBUG;

    return $VERSION unless $thePlugin;

    foreach my $plugin ( @{$this->{plugins}} ) {
        if( $plugin->{name} eq $thePlugin ) {
            last if ( $plugin->{disabled} );
            return $plugin->getVersion();
        }
    }
    return 0;
}

# apply named handler
sub _applyHandlers {
    # must be shifted to clear parameter vector
    my $this = shift;
    assert(ref($this) eq "TWiki::Plugins") if DEBUG;
    my $handlerName = shift;

    my $status;
    foreach my $handler ( @{$this->{registeredHandlers}{$handlerName}} ) {
        # Set the value of $SESSION for this call stack
        local $SESSION = $this->{session};
        # apply handler on the remaining list of args
        no strict 'refs';
        $status = &$handler;
        use strict 'refs';
        if( $status && $onlyOnceHandlers{$handlerName} ) {
            return $status;
        }
    }
    return undef;
}

# %FAILEDPLUGINS reports reasons why plugins failed to load
# note this is invoked with the session as the first parameter
sub _handleFAILEDPLUGINS {
    my $this = shift->{plugins};
    my $text;

    $text .= "---++ Plugins defined\n";

    foreach my $plugin ( @{$this->{plugins}} ) {
        $text .= "\t* <nop>$plugin->{name}";
        if ( $plugin->{disabled} && $plugin->{errors}) {
            $text .= " DISABLED\n---+++ Errors\n<verbatim>\n" .
              join( "\n", @{$plugin->{errors}} ) . "\n</verbatim>";
        }
        $text .= "\n";
    }

    $text.="\n\n";

    foreach my $handler (@TWiki::Plugin::registrableHandlers) {
        $text .= "| $handler |";
        if ( defined( $this->{registeredHandlers}{$handler} ) ) {
            $text .= join "<br />", @{$this->{registeredHandlers}{$handler}};
        }
        $text .= " |\n";
    }

    return $text;
}

# note this is invoked with the session as the first parameter
sub _handlePLUGINDESCRIPTIONS {
    my $this = shift->{plugins};
    my $text = "";
    foreach my $plugin ( @{$this->{plugins}} ) {
        $text .= $plugin->getDescription();
    }

    return $text;
}

# note this is invoked with the session as the first parameter
sub _handleACTIVATEDPLUGINS {
    my $this = shift->{plugins};
    my $text = "";
    foreach my $plugin ( @{$this->{plugins}} ) {
        unless( $plugin->{disabled} ) {
            $text .= "$plugin->{web}.$plugin->{name}, ";
        }
    }
    $text =~ s/\,\s*$//o;
    return $text;
}

=pod

---++ sub registrationHandler ()

Called by the register script

=cut

sub registrationHandler {
    my $this = shift;
    assert(ref($this) eq "TWiki::Plugins") if DEBUG;
    #my( $web, $wikiName, $loginName ) = @_;
    $this->_applyHandlers( 'registrationHandler', @_ );
}

=pod

---++ sub beforeCommonTagsHandler ()

Called by sub handleCommonTags at the beginning (for cache Plugins only)

=cut

sub beforeCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'beforeCommonTagsHandler', @_ );
}

=pod

---++ sub commonTagsHandler ()

Called by sub handleCommonTags, after %INCLUDE:"..."%

=cut

sub commonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'commonTagsHandler', @_ );
}

=pod

---++ sub afterCommonTagsHandler ()

Called by sub handleCommonTags at the end (for cache Plugins only)

=cut

sub afterCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'afterCommonTagsHandler', @_ );
}

=pod

---++ sub startRenderingHandler ()

Called by getRenderedVersion just before the line loop

=cut

sub startRenderingHandler {
    my $this = shift;
    #my ( $text, $web ) = @_;
    $this->_applyHandlers( 'startRenderingHandler', @_ );
}

=pod

---++ sub outsidePREHandler ()

Called by sub getRenderedVersion, in loop outside of <PRE> tag

=cut

sub outsidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_applyHandlers( 'outsidePREHandler', @_ );
}

=pod

---++ sub insidePREHandler ()

Called by sub getRenderedVersion, in loop inside of <PRE> tag

=cut

sub insidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_applyHandlers( 'insidePREHandler', @_ );
}

=pod

---++ sub endRenderingHandler ()

Called by getRenderedVersion just after the line loop

=cut

sub endRenderingHandler {
    my $this = shift;
    #my ( $text ) = @_;
    $this->_applyHandlers( 'endRenderingHandler', @_ );
}

=pod

---++ sub beforeEditHandler ()

Called by edit

=cut

sub beforeEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    $this->_applyHandlers( 'beforeEditHandler', @_ );
}

=pod

---++ sub afterEditHandler ()

Called by edit

=cut

sub afterEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    $this->_applyHandlers( 'afterEditHandler', @_ );
}

=pod

---++ sub beforeSaveHandler ()

Called just before the save action

=cut

sub beforeSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'beforeSaveHandler', @_ );
}

=pod

---++ sub afterSaveHandler ()

Called just after the save action

=cut

sub afterSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'afterSaveHandler', @_ );
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

sub beforeAttachmentSaveHandler {
    my $this = shift;
    #my ( $theAttrHash, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'beforeAttachmentSaveHandler', @_ );
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

sub afterAttachmentSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'afterAttachmentSaveHandler', @_ );
}


=pod

---++ sub writeHeaderHandler ()

Called by TWiki::writePageHeader

=cut

sub writeHeaderHandler {
    my $this = shift;
    return $this->_applyHandlers( 'writeHeaderHandler', @_ );
}

=pod

---++ sub redirectCgiQueryHandler ()

Called by TWiki::redirect

=cut

sub redirectCgiQueryHandler {
    my $this = shift;
    return $this->_applyHandlers( 'redirectCgiQueryHandler', @_ );
}

=pod

---++ sub getSessionValueHandler ()

Called by TWiki::getSessionValue

=cut

sub getSessionValueHandler {
    my $this = shift;
    return $this->_applyHandlers( 'getSessionValueHandler', @_ );
}

=pod

---++ sub setSessionValueHandler ()

Called by TWiki::setSessionValue

=cut

sub setSessionValueHandler {
    my $this = shift;
    return $this->_applyHandlers( 'setSessionValueHandler', @_ );
}

=pod

---++ sub renderFormFieldForEditHandler ( $name, $type, $size, $value, $attributes, $possibleValues )

| Description:       | This handler is called before built-in types are considered. It generates the HTML text rendering this form field, or false, if the rendering should be done by the built-in type handlers. |
| Parameter: =$name= | name of form field |
| Parameter: =$type= | type of form field |
| Parameter: =$size= | size of form field |
| Parameter: =$value= | value held in the form field |
| Parameter: =$attributes= | attributes of form field  |
| Parameter: =$possibleValues= | the values defined as options for form field, if any |
| Return: =$text=  | HTML text that renders this field. If false, form rendering continues by considering the built-in types. |

Note that a common application would be to generate formatting of the
field involving generation of javascript. Such usually also requires
the insertion of some common javascript into the page header. Unfortunately,
there is currently no mechanism to pass that script to where the header of
the page is visible. Consequentially, the common javascript may have to
be emitted as part of the field formatting and might be duplicated many
times throughout the page.

=cut

sub renderFormFieldForEditHandler {
    my $this = shift;
    return $this->_applyHandlers( 'renderFormFieldForEditHandler', @_ );
}

=pod

---++ sub renderWikiWordHandler ()

Change how a WikiWord is rendered

Originated from the TWiki:Plugins.SpacedWikiWordPlugin hack

=cut

sub renderWikiWordHandler {
    my $this = shift;
    return $this->_applyHandlers( 'renderWikiWordHandler', @_ );
}

1;
