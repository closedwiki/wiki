# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ module TWiki::Config

---++ Purpose

This module consists of just a single subroutine =readConfig=.  It allows to
safely modify configuration variables _for one single run_ without affecting
normal TWiki operation.

---++ Implementation Note

This module is written against the Perl convention which suggests to name a
package after the module it is in.  The reason is legacy: TWiki's main
configuration file =TWiki.cfg= defines configuration data without a namespace,
whereas definitions in =LocalSite.cfg= explicitly use TWiki's package.

=cut

package TWiki;

# Site configuration constants
use vars qw( %cfg );

=pod

---++ StaticMethod readConfig()

In normal TWiki operations as a web server this routine is called by the
=BEGIN= block of =TWiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key 
=$cfg{ConfigurationFinished}= as an indicator.

=cut

sub readConfig {
    return if $cfg{ConfigurationFinished};

    # Get LocalSite first, to pick up definitions of things like
    # {RCS}{BinDir} and {LibDir} that are used in TWiki.cfg
    # do, not require, because we do it twice
    do 'LocalSite.cfg';
    # Now get all the defaults
    require 'TWiki.cfg';
    die "Cannot read TWiki.cfg: $@" if $@;
    die "Bad configuration: $@" if $@;

    # If we got this far without definitions for key variables, then
    # we need to default them. otherwise we get peppered with
    # 'uninitialised variable' alerts later.

    foreach my $var qw( DataDir DefaultUrlHost PubUrlPath
                        PubDir TemplateDir ScriptUrlPath LocalesDir ) {
        # We can't do this, because it prevents TWiki being run without
        # a LocalSite.cfg, which we don't want
        # die "$var must be defined in LocalSite.cfg"
        #  unless( defined $TWiki::cfg{$var} );
        $TWiki::cfg{$var} ||= 'NOT SET';
    }

    # read localsite again to ensure local definitions override TWiki.cfg
    do 'LocalSite.cfg';
    die "Bad configuration: $@" if $@;

    $cfg{ConfigurationFinished} = 1;
}

1;
