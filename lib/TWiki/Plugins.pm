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

=pod

---+ package TWiki::Plugins

This module defines the singleton object that handles Plugins
loading, initialization and execution.

=cut

=pod

Note that as of version 1.026 of this module, TWiki internal
methods are _no longer available_ to plugins. Any calls to
TWiki internal methods must be replaced by calls via the
$SESSION object in this package, or via the Func package.
For example, the call:

my $pref = TWiki::getPreferencesValue("URGH");

should be replaced with

my $pref = TWiki::Func::getPreferencesValue("URGH");

and the call

my $t = TWiki::writeWarning($message);

should be replaced with

my $pref = $TWiki::Plugins::SESSION->writeWarning($message);

Methods in other modules such as Store must be accessed through
the relevant TWiki sub-object, for example

TWiki::Store::updateReferringPages(...)

should be replaced with

$TWiki::Plugins::SESSION->{store}->updateReferringPages(...)

Note that calling TWiki internal methods is very very bad practice,
and should be avoided wherever practical.

The developers of TWiki reserve the right to change internal
methods without warning, unless those methods are clearly
marked as PUBLIC. PUBLIC methods are part of the core specification
of a module and can be trusted.

=cut

package TWiki::Plugins;

use strict;
use Assert;
use TWiki::Plugin;
use TWiki::Func;

use vars qw ( $VERSION $SESSION $inited );

=pod

---++ PUBLIC constant $VERSION
This is the version number of the plugins package. Use it for checking
if you have a recent enough version.

---++ PUBLIC $SESSION
This is a reference to the TWiki session object. It can be used in
plugins to get at the methods of the TWiki kernel.

You are _highly_ recommended to only use the methods in the
[[TWikiFuncDotPm][Func]] interface, unless you have no other choice,
as kernel methods may change between TWiki releases.

=cut

$VERSION = '1.026';

$inited = 0;

my %onlyOnceHandlers =
  (
   initializeUserHandler          => 1,
   registrationHandler            => 1,
   writeHeaderHandler             => 1,
   redirectCgiQueryHandler        => 1,
   getSessionValueHandler         => 1,
   setSessionValueHandler         => 1,
   renderFormFieldForEditHandler  => 1,
   renderWikiWordHandler          => 1,
  );

=pod

---++ ClassMethod new( $session )

Construct new singleton plugins engine object. The object is a contained for
a list of plugins and a set of handlers registered by each plugin. The plugins
and the handlers are carefully ordered.

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( {}, $class );

    ASSERT(ref($session) eq "TWiki") if DEBUG;
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

---++ ObjectMethod load($disabled) -> $loginName

Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If disabled is set, no plugin handlers will be called.

=cut

sub load {
    my ( $this, $disabled ) = @_;
    ASSERT(ref($this) eq "TWiki::Plugins") if DEBUG;

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

---++ ObjectMethod enable()

Initialisation that is done after the user is known.

=cut

sub enable {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Plugins") if DEBUG;

    foreach my $plugin ( @{$this->{plugins}} ) {
        $plugin->registerHandlers( $this );
        # Report initialisation errors
        if ( $plugin->{errors} ) {
            $this->{session}->writeWarning( join( "\n", @{$plugin->{errors}} ));
        }
    }
}

=pod

---++ ObjectMethod getPluginVersion() -> $number

Returns the $TWiki::Plugins::VERSION number if no parameter is specified,
else returns the version number of a named Plugin. If the Plugin cannot
be found or is not active, 0 is returned.

=cut

sub getPluginVersion {
    my ( $this, $thePlugin ) = @_;
    ASSERT(ref($this) eq "TWiki::Plugins") if DEBUG;

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
    ASSERT(ref($this) eq "TWiki::Plugins") if DEBUG;
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

---++ ObjectMethod registrationHandler ()

Called by the register script

=cut

sub registrationHandler {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Plugins") if DEBUG;
    #my( $web, $wikiName, $loginName ) = @_;
    $this->_applyHandlers( 'registrationHandler', @_ );
}

=pod

---++ ObjectMethod beforeCommonTagsHandler ()

Called by sub handleCommonTags at the beginning (for cache Plugins only)

=cut

sub beforeCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'beforeCommonTagsHandler', @_ );
}

=pod

---++ ObjectMethod commonTagsHandler ()

Called by sub handleCommonTags, after %INCLUDE:"..."%

=cut

sub commonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'commonTagsHandler', @_ );
}

=pod

---++ ObjectMethod afterCommonTagsHandler ()

Called by sub handleCommonTags at the end (for cache Plugins only)

=cut

sub afterCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    $this->_applyHandlers( 'afterCommonTagsHandler', @_ );
}

=pod

---++ ObjectMethod startRenderingHandler ()

Called by getRenderedVersion just before the line loop

=cut

sub startRenderingHandler {
    my $this = shift;
    #my ( $text, $web ) = @_;
    $this->_applyHandlers( 'startRenderingHandler', @_ );
}

=pod

---++ ObjectMethod outsidePREHandler ()

Called by sub getRenderedVersion, in loop outside of &lt;PRE&gt; tag

=cut

sub outsidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_applyHandlers( 'outsidePREHandler', @_ );
}

=pod

---++ ObjectMethod insidePREHandler ()

Called by sub getRenderedVersion, in loop inside of &lt;PRE&gt; tag

=cut

sub insidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    $this->_applyHandlers( 'insidePREHandler', @_ );
}

=pod

---++ ObjectMethod endRenderingHandler ()

Called by getRenderedVersion just after the line loop

=cut

sub endRenderingHandler {
    my $this = shift;
    #my ( $text ) = @_;
    $this->_applyHandlers( 'endRenderingHandler', @_ );
}

=pod

---++ ObjectMethod beforeEditHandler ()

Called by edit

=cut

sub beforeEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    $this->_applyHandlers( 'beforeEditHandler', @_ );
}

=pod

---++ ObjectMethod afterEditHandler ()

Called by edit

=cut

sub afterEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    $this->_applyHandlers( 'afterEditHandler', @_ );
}

=pod

---++ ObjectMethod beforeSaveHandler ()

Called just before the save action

=cut

sub beforeSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'beforeSaveHandler', @_ );
}

=pod

---++ ObjectMethod afterSaveHandler ()

Called just after the save action

=cut

sub afterSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    $this->_applyHandlers( 'afterSaveHandler', @_ );
}

=pod

---++ ObjectMethod beforeAttachmentSaveHandler ( $attrHashRef, $topic, $web ) 

This code provides Plugins with the opportunity to alter an uploaded attachment between the upload and save-to-store processes. It is invoked as per other Plugins.
   * =$attrHashRef= - Hash reference of attachment attributes (keys are indicated below)
   * =$topic= -     | Topic name
   * =$web= -       | Web name

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

---++ ObjectMethod afterAttachmentSaveHandler( $attachmentAttrHash, $topic, $web, $error )

This code provides plugins with the opportunity to alter an uploaded attachment between the upload and save-to-store processes. It is invoked as per other plugins.

   * =$attrHashRef= - Hash reference of attachment attributes (keys are indicated below)
   * =$topic= -     | Topic name
   * =$web= -       | Web name
   * =$error= -     | Error string of save action, empty if OK

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

---++ ObjectMethod writeHeaderHandler () -> $headers

Called by TWiki::writePageHeader

=cut

sub writeHeaderHandler {
    my $this = shift;
    return $this->_applyHandlers( 'writeHeaderHandler', @_ );
}

=pod

---++ ObjectMethod redirectCgiQueryHandler () -> $result

Called by TWiki::redirect

=cut

sub redirectCgiQueryHandler {
    my $this = shift;
    return $this->_applyHandlers( 'redirectCgiQueryHandler', @_ );
}

=pod

---++ ObjectMethod getSessionValueHandler () -> $sessionValue

Called by TWiki::getSessionValue

=cut

sub getSessionValueHandler {
    my $this = shift;
    return $this->_applyHandlers( 'getSessionValueHandler', @_ );
}

=pod

---++ ObjectMethod setSessionValueHandler () -> $result

Called by TWiki::setSessionValue

=cut

sub setSessionValueHandler {
    my $this = shift;
    return $this->_applyHandlers( 'setSessionValueHandler', @_ );
}

=pod

---++ ObjectMethod renderFormFieldForEditHandler ( $name, $type, $size, $value, $attributes, $possibleValues ) -> $html

This handler is called before built-in types are considered. It generates the HTML text rendering this form field, or false, if the rendering should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if any
Return HTML text that renders this field. If false, form rendering continues by considering the built-in types.

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

---++ ObjectMethod renderWikiWordHandler () -> $result

Change how a WikiWord is rendered

Originated from the TWiki:Plugins.SpacedWikiWordPlugin hack

=cut

sub renderWikiWordHandler {
    my $this = shift;
    return $this->_applyHandlers( 'renderWikiWordHandler', @_ );
}

1;
