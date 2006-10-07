#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
#
# Abstract base class of all configuration components. A configuration
# component may be a collection item (a ConfigSection) or an individual Value.

package TWiki::Configure::Item;

use strict;

sub new {
    my $class = shift;

    my $this = bless({}, $class);
    $this->{parent} = undef;
    $this->{desc} = '';

    return $this;
}

sub addToDesc {
    my ($this, $desc) = @_;

    $this->{desc} .= "$desc\n";
}

sub haveSettingFor {
    die "Implementation required";
}

# Accept an attribute setting for this item (e.g. a key name).
sub set {
    my ($this, %params) = @_;
    foreach my $k (keys %params) {
        $this->{$k} = $params{$k};
    }
}

sub inc {
    my ($this, $key) = @_;

    $this->{$key}++;
    $this->{parent}->inc($key) if $this->{parent};
}

sub getSectionObject {
    return undef;
}

sub getValueObject {
    return undef;
}

1;
