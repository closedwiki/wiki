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

# PRIVATE CLASS TWiki::Plugin
#
# Reference information for a single plugin.
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
    ASSERT(ref($session) eq "TWiki") if DEBUG;
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
    ASSERT(ref($this) eq "TWiki::Plugin") if DEBUG;

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
    ASSERT(ref($this) eq "TWiki::Plugin") if DEBUG;

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
                        $TWiki::Plugins::SESSION->{user}->login(),
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

# Get the version number of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getVersion {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Plugin") if DEBUG;

    no strict 'refs';
    return ${"TWiki::Plugins::$this->{name}::VERSION"};
    use strict 'refs';
}

# Get the description string for the given plugin
sub getDescription {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Plugin") if DEBUG;

    return "" if $this->{disabled};

    unless( $this->{description} ) {
        my $pref = uc( $this->{name} ) . "_SHORTDESCRIPTION";
        $this->{description} = $this->prefs()->getPreferencesValue( $pref );
    }

    return "\t\* $this->{web}.$this->{name}: $this->{description}\n";
}

1;
