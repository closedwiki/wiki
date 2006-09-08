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

---+ package TWiki::Configure::Load

---++ Purpose

This module consists of just a single subroutine =readConfig=.  It allows to
safely modify configuration variables _for one single run_ without affecting
normal TWiki operation.

=cut

package TWiki::Configure::Load;

=pod

---++ StaticMethod readConfig()

In normal TWiki operations as a web server this routine is called by the
=BEGIN= block of =TWiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key 
=$cfg{ConfigurationFinished}= as an indicator.

=cut

sub readConfig {
    return if $TWiki::cfg{ConfigurationFinished};

    # Reluctantly we have to do this to prevent uninitialised vars
    do 'TWiki.spec';

    # Note: no error handling!
    do 'LocalSite.cfg';

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

    # Expand references to $TWiki::cfg vars embedded in the values of
    # other $TWiki::cfg vars.
    foreach ( values %TWiki::cfg ) {
        next unless $_;
        s/\$TWiki::cfg{([[A-Za-z0-9{}]+)}/$TWiki::cfg{$1}/g;
    }

    $TWiki::cfg{ConfigurationFinished} = 1;
}

=pod

---++ StaticMethod readDefaults() -> \@errors

This is only called by =configure= to initialise the TWiki config hash with
default values from the .spec files.

Normally all configuration values come from LocalSite.cfg. However when
=configure= runs it has to get default values for config vars that have not
yet been saved to =LocalSite.cfg=.

Returns a reference to a list of the errors it saw.

=cut

sub readDefaults {
    my %read = ( 'TWiki.spec' );
    my @errors;

    eval {
        do 'TWiki.spec';
    };
    push(@errors, $@) if ($@);
    foreach my $dir (@INC) {
        opendir(D, $dir) || next;
        foreach my $file (grep { /\.spec$/ } readdir D) {
            # Only read the first occurrence of each .spec file
            next if $read{$file};
            eval {
                do "$dir/$file";
            };
            push(@errors, $@) if ($@);
            $read{$file} = 1;
        }
    }
    return \@errors;
}

1;
