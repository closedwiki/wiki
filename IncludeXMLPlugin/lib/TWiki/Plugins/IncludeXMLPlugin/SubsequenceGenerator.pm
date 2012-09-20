use strict;
package TWiki::Plugins::IncludeXMLPlugin::SubsequenceGenerator;

=begin twiki

---+ TWiki::Plugins::IncludeXMLPlugin::SubsequenceGenerator

Takes 'offset', 'limit', and 'reverse' as input and generates a subsequence of a sequence
whose entire length is possibly unknown until all the items have been added.

=cut

=begin twiki

---++ StaticMethod new($offset, $limit, $reverse)

Creates a new object.

If $limit is undef, it means unlimited (toward the end).
$offset and/or $limit can be negative, where they will be counted from the end.
$reverse is evaluated as boolean.

=cut

sub new {
    my ($class, $offset, $limit, $reverse) = @_;

    if (!defined $offset) {
        $offset = 0;
    }

    if ($offset < 0 and defined $limit) {
        if ($limit > 0 and -$offset < $limit) {
            $limit = -$offset;
        } elsif ($limit < 0 and -$offset < -$limit) {
            $limit = $offset;
        }
    }

    if ($reverse) {
        if ($offset >= 0) {
            if (!defined $limit) {
                ($offset, $limit) = (0, ($offset == 0 ? undef : -$offset));
            } elsif ($limit >= 0) {
                $offset = -($offset + $limit);
            } else {
                ($offset, $limit) = (-$limit, ($offset == 0 ? undef : -$offset));
            }
        } else {
            if (!defined $limit) {
                ($offset, $limit) = (0, ($offset == 0 ? undef : -$offset));
            } elsif ($limit >= 0) {
                $offset = -($offset + $limit);
            } else {
                ($offset, $limit) = (-$limit, $limit - $offset);
            }
        }
    }

    return bless {
        offset => $offset, limit => $limit, reverse => $reverse,
        end => 0, subseq => {}
    }, $class;
}

=begin twiki

---++ ObjectMethod more()

Can we push more items within the specified limit?

=cut

sub more {
    my ($self) = @_;
    my $limit  = $self->{limit};

    if (!defined $limit) {
        return 1;
    } elsif ($limit == 0) {
        return 0;
    } elsif ($limit < 0) {
        return 1;
    }

    my $offset = $self->{offset};
    my $end    = $self->{end};

    return ($offset < 0) || ($end < $offset + $limit);
}

=begin twiki

---++ ObjectMethod push($item)

Appends an item at the end if the current size is within the limit.
If the item is a reference to 'CODE' (subroutine), it will be lazily evaluated.

=cut

sub push {
    my ($self, $item) = @_;
    return $self->set($self->{end}, $item);
}

=begin twiki

---++ ObjectMethod set($nth, $item)

Sets the item at the specified position if the current size is within the limit.
If the item is a reference to 'CODE' (subroutine), it will be lazily evaluated.

=cut

sub set {
    my ($self, $nth, $item) = @_;
    my $offset = $self->{offset};
    my $limit  = $self->{limit};
    my $subseq = $self->{subseq};

    my $prev_end = $self->{end};
    $self->{end} = $nth + 1 if $self->{end} <= $nth;
    my $end = $self->{end};

    my $should_add = 0;

    if ($offset >= 0) {
        if ($offset <= $nth and
                (!defined $limit or $limit < 0 or $nth < $offset + $limit)) {
            $should_add = 1;
        }
    } else {
        if ($end + $offset <= $nth) {
            $should_add = 1;
        }
    }

    if ($should_add) {
        $subseq->{$nth} = ref $item eq 'CODE' ? $item->($subseq->{$nth}) : $item;
    }

    return $should_add;
}

=begin twiki

---++ ObjectMethod result()

Retrieves a reference to the result array. It may or may not be the exact
reference to the internal array, so the elements should not be modified
directly when retrieved.

=cut

sub result {
    my ($self) = @_;

    my $offset  = $self->{offset};
    my $limit   = $self->{limit};
    my $reverse = $self->{reverse};
    my $subseq  = $self->{subseq};
    my $end     = $self->{end};

    my $from = ($offset >= 0 ? $offset : $end + $offset);

    my $to = (!defined $limit ? $end :
        ($limit >= 0 ? ($from + $limit) : ($end + $limit))) - 1;

    if ($from > $to or $to < 0 or $end <= $from) {
        return [];
    }

    ($from, $to) = map {$_ < 0 ? 0 : ($_ >= $end ? $end - 1 : $_)} ($from, $to);

    my @idx = ($from..$to);
    @idx = reverse @idx if $reverse;

    return [map {
        $subseq->{$_}
    } @idx];
}

1;
