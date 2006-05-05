# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Disposable;

Base class for objects that are session-specific, and must be freed
at the end of each TWiki session.

Perl garbage collection is pretty stupid; if any objects form
cyclic subgraphs, they will not be disposed automatically. This
is not normally a problem, as the memory is freed when the perl
instance exists. However accelerators such as mod_perl hang on to
the perl instance, and after many runs the memory leakage can
become significant. So when a TWiki session ends, we have to try
and make sure the memory is clean. This base class
provides some basic support for this process.

=cut

package TWiki::Disposable;

=pod

---++ ObjectMethod cleanUp()
Complete processing after the client's HTTP request has been responded
to. The baseclass implementation of this recursively calls cleanUp on
all referenced objects.

The main purpose of this method is to break apart subgraphs containing
cycles. It does so by undeffing all the fields in the object hash.

The default behaviour is to recursively call any object references in
fields in the object. Note that if an object contains a non-object hash,
or a reference to an array, then their contents will *not* be visited by
default. It is up to the specific subclass to clean these. Also note that
just inheriting from TWiki::Disposable isn't enough; the object must also
be reachable from the TWiki session object, or it won't be collected
automatically.

=cut

sub cleanUp {
    my $this = shift;

    # Block recursion
    return if $this->{_slaughtered};
    $this->{_slaughtered} = 1;

    foreach my $subobject (keys %$this) {
        my $so = $this->{$subobject};
        my $class = ref $so;
        if( $class && $class->isa( 'TWiki::Disposable' )) {
            $so->cleanUp();
        }
    }
    # Clear the fields of $this, except for the flag field
    %$this = ( _slaughtered => 1 );
}

1;
