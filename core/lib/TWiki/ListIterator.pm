# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2013 Peter Thoeny, peter[at]thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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

---+ package TWiki::ListIterator

Iterator over a list

=cut

package TWiki::ListIterator;

use strict;

=pod

---++ new(\@list)

Create a new iterator over the given list. Designed primarily for operations
over fully defined lists of object references. The list is not damaged in
any way.

=cut


sub new {
    my ($class, $list) = @_;
    my $this = bless({
        list => $list,
        index => 0,
        process => undef,
        filter => undef,
        next => undef,
    }, $class);
    return $this;
}

=pod

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

<verbatim>
my $it = new TWiki::ListIterator(\@list);
while ($it->hasNext()) {
   ...
</verbatim>

=cut

sub hasNext {
    my( $this ) = @_;
    return 1 if $this->{next};
    my $n;
    do {
        if( $this->{list} && $this->{index} < scalar(@{$this->{list}}) ) {
            $n = $this->{list}->[$this->{index}++];
        } else {
            return 0;
        }
    } while ($this->{filter} && !&{$this->{filter}}($n));
    $this->{next} = $n;
    return 1;
}

=pod

---++ next() -> $data

Return the next entry in the list.

The iterator object can be customised to pre- and post-process entries from
the list before returning them. This is done by setting two fields in the
iterator object:

   * ={filter}= can be defined to be a sub that filters each entry. The entry
     will be ignored (next() will not return it) if the filter returns false.
   * ={process}= can be defined to be a sub to process each entry before it
     is returned by next. The value returned from next is the value returned
     by the process function.

For example,
<verbatim>
my @list = ( 1, 2, 3 );

my $it = new TWiki::ListIterator(\@list);
$it->{filter} = sub { return $_[0] != 2 };
$it->{process} = sub { return $_[0] + 1 };
while ($it->hasNext()) {
    my $x = $it->next();
    print "$x, ";
}
</verbatim>
will print
<verbatim>
2, 4
</verbatim>

=cut

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->{next};
    $this->{next} = undef;
    $n = &{$this->{process}}($n) if $this->{process};
    return $n;
}

1;
