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

=begin twiki

---+ TWiki:: Module

This module handles Plugins loading, initialization and execution

=cut

package TWiki::Plugins;

use strict;
use TWiki;
use TWiki::Sandbox;

use vars qw ( $VERSION $SESSION );

$VERSION = '1.026';

my @registrableHandlers =
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

sub users { my $this = shift; return $this->{session}->{users}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }

=pod

---++ sub new( $session )
Construct new singleton plugins engine object

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( {}, $class );

    $this->{session} = $session;

    return $this;
}

=pod

---+ earlyInit()
Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If disabled is set, no plugin handlers will be called.

=cut

sub earlyInit {
    my ( $this, $disabled ) = @_;

    my %disabledPlugins;

    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        return "";
    }

    # Get INSTALLEDPLUGINS and DISABLEDPLUGINS variables
    my $plugin = $this->prefs()->getPreferencesValue( "INSTALLEDPLUGINS" ) || "";
    $plugin =~ s/[\n\t\s\r]+/ /go;
    my @setInstPlugins = grep { /^.+Plugin$/ } split( /,?\s+/ , $plugin );
    $plugin = $this->prefs()->getPreferencesValue( "DISABLEDPLUGINS" ) || "";
	foreach my $p (split( /,?\s+/ , $plugin)) {
        if ( $p =~ /^.+Plugin$/ ) {
            $p =~ s/^.*\.(.*)$/$1/;
            $this->{disabledPlugins}{$p} = 1 if ( $p );
        }
	}

    my @discoveredPlugins = _discoverPluginPerlModules();
    my $p = "";
    foreach $plugin ( @setInstPlugins ) {
        $p = $plugin;
        $p =~ s/^.*\.(.*)$/$1/o; # cut web
        if( $p && !$this->{disabledPlugins}{$p} ) {
            push( @{$this->{instPlugins}}, $plugin );
        }
    }
    # append discovered plugin modules to installed plugin list
    push( @{$this->{instPlugins}}, @discoveredPlugins );

    # enable only specific plugins, for test and benchmarking
    my $query = $this->{session}->{cgiQuery};
    if ( $query ) {
        my $debugEnablePlugins = $query->param( 'debugenableplugins' );
        @{$this->{instPlugins}} = split( /[\, ]+/, $debugEnablePlugins )
          if( $debugEnablePlugins );
    }

    my $user;
    return $user if( $disabled );

    my %reg = ();
    foreach my $plugin ( @{$this->{instPlugins}} ) {
        my $p = $plugin;
        $p =~ s/^.*\.(.*)$/$1/o; # cut web
        unless( $this->{disabledPlugins}{$p} || $reg{$p} ) {
            $user = $this->_earlyRegister( $p );
            $reg{$p} = 1;
        }
    }

    return $user;
}

=pod

---++ sub lateInit($disabled)

Initialisation that is done is done after the user is known.
If $disabled is set no handlers will be called.

=cut

sub lateInit {
    my ( $this, $disabled ) = @_;

    return if $disabled;

    my $p = "";
    my $plugin = "";
    foreach $plugin ( @{$this->{instPlugins}} ) {
        $p = $plugin;
        $p =~ s/^.*\.(.*)$/$1/o; # cut web
        unless( $this->{disabledPlugins}{$p} ) {
            $this->_lateRegister( $p );
        }
    }
}

# Load and verify a plugin, invoking any early registration
# handlers
sub _earlyRegister {
    my ( $this, $plugin ) = @_;

    # look for the plugin installation web (needed for attached files)
    # in the order:
    #   1 fully specified web.plugin
    #   2 TWiki.plugin
    #   3 Plugins.plugin
    #   4 thisweb.plugin

    if( $this->{installWeb}{$plugin} ) {
        # Plugin is already registered
        return undef;
    }

    if ( $plugin =~ m/^[A-Za-z0-9_]+Plugin$/ ) {
        $plugin = TWiki::Sandbox::untaintUnchecked($plugin);
    } else {
        $this->_initialisationError("$plugin - invalid name for plugin");
        return undef;
    }

    my $web;
    if ( $this->store()->topicExists( $TWiki::twikiWebname, $plugin ) ) {
        # found plugin in TWiki web
        $web = $TWiki::twikiWebname;
    } elsif ( $this->store()->topicExists( "Plugins", $plugin ) ) {
        # found plugin in Plugins web (compatibility, deprecated)
        $web = "Plugins";
    } elsif ( $this->store()->topicExists( $this->{session}->{webName},
                                           $plugin ) ) {
        # found plugin in current web
        $web = $this->{session}->{webName};
    } else {
        # not found
        $this->_initialisationError( "Plugins: couldn't register $plugin, no plugin topic" );
        $this->{installWeb}{$plugin} = "(Not Found)";
        return;
    }

    $this->{installWeb}{$plugin} = $web;

    my $p = 'TWiki::Plugins::'.$plugin;
    #use Benchmark qw(:all :hireswallclock);
    #my $begin = new Benchmark;
    eval "use $p;";
    if ($@) {
        $this->_initialisationError("Plugin \"$plugin\" could not be loaded.  Errors were:\n----\n$@----");
        return undef;
    }

    my $user;
    my $sub = $p . '::earlyInitPlugin';
    if( defined( &$sub ) ) {
        local $SESSION = $this->{session};
        # Note that the earlyInitPlugin method is _never called_. Not sure why
        # it exists at all!
        $sub = $p. '::initializeUserHandler';
        no strict 'refs';
        $user = &$sub( $this->{session}->{remoteUser},
                       $this->{session}->{url},
                       $this->{session}->{pathInfo} );
        use strict 'refs';
    }
    #print STDERR "Compile $plugin: ".timestr(timediff(new Benchmark, $begin))."\n";

    return $user;
}

# invoke plugin initialisation handlers, and register all
# handlers.
sub _lateRegister {
    my ( $this, $plugin ) = @_;

    my $p = "TWiki::Plugins::" . $plugin;
    my $sub = $p . "::initPlugin";
    if( ! defined( &$sub ) ) {
        $this->_initialisationError("$sub is not defined");
        return undef;
    }

    $this->prefs()->getPrefsFromTopic( $this->{installWeb}{$plugin}, $plugin,
                                       uc( $plugin ) . "_");

    local $SESSION = $this->{session};

    no strict 'refs';
    my $status = &$sub( $this->{session}->{topicName},
                        $this->{session}->{webName},
                        $this->{session}->{userName},
                        $this->{installWeb}{$plugin} );
    use strict 'refs';

    if( $status ) {
        foreach my $h ( @registrableHandlers ) {
            $sub = $p.'::'.$h;
            push( @{$this->{registeredHandlers}{$h}}, $sub )
              if( defined( &$sub ));
        }
        push( @{$this->{activePlugins}}, $plugin );
    } else {
        $this->_initialisationError("$p\::initPlugin did not return true ($status)");
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

    return $VERSION unless $thePlugin;

    foreach my $plugin ( @{$this->{activePlugins}} ) {
        if( $plugin eq $thePlugin ) {
            no strict 'refs';
            return ${"TWiki::Plugins::${plugin}::VERSION"};
            use strict 'refs';
        }
    }
    return 0;
}

sub _discoverPluginPerlModules {
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

sub _initialisationError {
   my( $this, $error ) = @_;
   $this->{initialisationErrors} .= $error."\n";
   $this->{session}->writeWarning( $error );
}

sub _applyHandlers {
    my( $this, $handlerName ) = @_;

    return undef if( $TWiki::disableAllPlugins );

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
sub _handleFAILEDPLUGINS {
    my $this = shift;
    my $text;

    $text .= "---++ Plugins defined\n";

    foreach my $plugin (@{$this->{instPlugins}}) {
        $text .= "\t* $plugin\n";
    }

    $text.="\n\n";

    foreach my $handler (@registrableHandlers) {
        $text .= "| $handler |";
        $text .= "| $handler | ";
        if ( defined( $this->{registeredHandlers}{$handler} ) ) {
            $text .= join "<br />", @{$this->{registeredHandlers}{$handler}};
        }
        $text .= " |\n";
    }

    my $err = $this->{initialisationErrors};
    $err = "None" unless $err;
    $text .= "<br />\n---++ Errors\n<verbatim>\n$err\n</verbatim>\n";

    return $text;
}

sub _handlePLUGINDESCRIPTIONS {
    my $this = shift;
    my $text = "";
    my $line = "";
    my $pref = "";
    foreach my $plugin ( @{$this->{activePlugins}} ) {
        $pref = uc( $plugin ) . "_SHORTDESCRIPTION";
        $line = $this->prefs()->getPreferencesValue( $pref );
        if( $line ) {
            $text .= "\t\* $this->{installWeb}{$plugin}.$plugin: $line\n"
        }
    }

    return $text;
}

sub _handleACTIVATEDPLUGINS {
    my $this = shift;
    my $text = "";
    foreach my $plugin ( @{$this->{activePlugins}} ) {
	  $text .= "$this->{installWeb}{$plugin}.$plugin, ";
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
    #my( $web, $wikiName, $loginName ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'registrationHandler', @_ );
}

=pod

---++ sub beforeCommonTagsHandler ()

Called by sub handleCommonTags at the beginning (for cache Plugins only)

=cut

sub beforeCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'beforeCommonTagsHandler', @_ );
}

=pod

---++ sub commonTagsHandler ()

Called by sub handleCommonTags, after %INCLUDE:"..."%

=cut

sub commonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'commonTagsHandler', @_ );
    $_[0] =~ s/%PLUGINDESCRIPTIONS%/$this->_handlePLUGINDESCRIPTIONS()/geo;
    $_[0] =~ s/%ACTIVATEDPLUGINS%/$this->_handleACTIVATEDPLUGINS()/geo;
    $_[0] =~ s/%FAILEDPLUGINS%/$this->_handleFAILEDPLUGINS()/geo;
}

=pod

---++ sub afterCommonTagsHandler ()

Called by sub handleCommonTags at the end (for cache Plugins only)

=cut

sub afterCommonTagsHandler {
    my $this = shift;
    #my( $text, $topic, $theWeb ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'afterCommonTagsHandler', @_ );
}

=pod

---++ sub startRenderingHandler ()

Called by getRenderedVersion just before the line loop

=cut

sub startRenderingHandler {
    my $this = shift;
    #my ( $text, $web ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'startRenderingHandler', @_ );
}

=pod

---++ sub outsidePREHandler ()

Called by sub getRenderedVersion, in loop outside of <PRE> tag

=cut

sub outsidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'outsidePREHandler', @_ );
}

=pod

---++ sub insidePREHandler ()

Called by sub getRenderedVersion, in loop inside of <PRE> tag

=cut

sub insidePREHandler {
    my $this = shift;
    #my( $text ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'insidePREHandler', @_ );
}

=pod

---++ sub endRenderingHandler ()

Called by getRenderedVersion just after the line loop

=cut

sub endRenderingHandler {
    my $this = shift;
    #my ( $text ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'endRenderingHandler', @_ );
}

=pod

---++ sub beforeEditHandler ()

Called by edit

=cut

sub beforeEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'beforeEditHandler', @_ );
}

=pod

---++ sub afterEditHandler ()

Called by edit

=cut

sub afterEditHandler {
    my $this = shift;
    #my( $text, $topic, $web ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'afterEditHandler', @_ );
}

=pod

---++ sub beforeSaveHandler ()

Called just before the save action

=cut

sub beforeSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'beforeSaveHandler', @_ );
}

=pod

---++ sub afterSaveHandler ()

Called just after the save action

=cut

sub afterSaveHandler {
    my $this = shift;
    #my ( $theText, $theTopic, $theWeb ) = @_;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
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
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
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
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    $this->_applyHandlers( 'afterAttachmentSaveHandler', @_ );
}


=pod

---++ sub writeHeaderHandler ()

Called by $TWiki::writeHeader

=cut

sub writeHeaderHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    return $this->_applyHandlers( 'writeHeaderHandler', @_ );
}

=pod

---++ sub redirectCgiQueryHandler ()

Called by TWiki::redirect

=cut

sub redirectCgiQueryHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    return $this->_applyHandlers( 'redirectCgiQueryHandler', @_ );
}

=pod

---++ sub getSessionValueHandler ()

Called by TWiki::getSessionValue

=cut

sub getSessionValueHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    return $this->_applyHandlers( 'getSessionValueHandler', @_ );
}

=pod

---++ sub setSessionValueHandler ()

Called by TWiki::setSessionValue

=cut

sub setSessionValueHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
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

sub renderFormFieldForEditHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    return $this->_applyHandlers( 'renderFormFieldForEditHandler', @_ );
}

=pod

---++ sub renderWikiWordHandler ()

Called by TWiki::internalLink to change how a WikiWord is rendered

Originated from the TWiki:Plugins.SpacedWikiWordPlugin hack

=cut

sub renderWikiWordHandler {
    my $this = shift;
    die "ASSERT $this from ".join(",",caller)."\n" unless $this =~ /^TWiki::Plugins=HASH/;
    return $this->_applyHandlers( 'renderWikiWordHandler', @_ );
}


1;
