# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
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

---+ package TWiki::Meta

Meta-data handling.

A meta-data object is a hash of different types of meta-data (keyed on
the type, such as 'FIELD' and 'TOPICINFO').

Each entry in the hash is an array, where each entry in the array
contains another hash of the key=value pairs, corresponding to a
single meta-datum.

If there may be multiple entries of the same top-level type (i.e. for FIELD
and FILEATTACHMENT) then the array hash multiple entries. Otherwise
the array has only one entry.

The module knows nothing about how meta-data is stored. That is entirely the
responsibility of the Store module.

Meta-data objects are created by the Store engine when topics are read. They
are populated using the =put= method.

=cut

package TWiki::Meta;

use strict;
use Error qw(:try);
use Assert;
use TWiki::Merge;

use vars qw( $formatVersion );

$formatVersion = "1.0";

=pod

---++ ClassMethod new($session, $web, $topic)

Construct a new, empty Meta collection.

=cut

sub new {
    my ( $class, $session, $web, $topic ) = @_;
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    my $this = bless( {}, $class );

    # Note: internal fields must be prepended with _. All other
    # fields will be assumed to be meta-data.
    $this->{_session} = $session;

    ASSERT($web) if DEBUG;
    ASSERT($topic) if DEBUG;

    $this->{_web} = $web;
    $this->{_topic} = $topic;

    return $this;
}

=pod

---++ ObjectMethod put($type, \%args)

Put a hash of key=value pairs into the given type set in this meta.

See the main comment for this package to understand how meta-data is
represented.

=cut

sub put {
    my( $this, $type, $args ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my $data = $this->{$type};
    my $key = _key( $type );

    if( $data ) {
        if( $key ) {
            my $found = '';
            my $keyName = $args->{$key};
            my @data = @$data;
            unless( $keyName ) {
                $this->{_session}->writeWarning( "Meta: Required $key parameter is missing for META:$type" );
                return;
            }
            for( my $i = 0; $i < scalar( @$data ); $i++ ) {
                if( $data[$i]->{$key} eq $keyName ) {
                    $data->[$i] = $args;
                    $found = 1;
                    last;
                }
            }
            unless( $found ) {
                push @$data, $args;
            }
        } else {
            $data->[0] = $args;
        }
    } else {
        my @data = ( $args );
        $this->{$type} = \@data;
    }
}

# ===========================
# Give the key field for a type, '' if no key

sub _key {
    my $type = shift;

    return 'name' if( $type eq 'FIELD' || $type eq 'FILEATTACHMENT' );

    return undef;
}

# ===========================
=pod

---++ ObjectMethod get( $type, $key ) -> \%hash

Find the value of a meta-datum in the map. If the type is FIELD or
FILEATTACHMENT, the $key parameter is required to say _which_
entry you want. Otherwise it can be undef.

The result is a reference to the hash for the item.

=cut

sub get {
    my( $this, $type, $keyValue ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my $data = $this->{$type};
    my $key = _key( $type );

    if( $data ) {
        if( $key ) {
            foreach my $item ( @$data ) {
                if( $item->{$key} eq $keyValue ) {
                    return $item;
                }
            }
        } else {
            return $data->[0];
        }
    }

    return undef;
}

=pod

---++ ObjectMethod find (  $type  ) -> @values

Get all meta data for a specific type
Returns the array stored for the type. This will be zero length
if there are no entries.

=cut

sub find {
    my( $this, $type ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my $itemsr = $this->{$type};
    my @items = ();

    if( $itemsr ) {
        @items = @$itemsr;
    }

    return @items;
}

=pod

---++ ObjectMethod remove ( $type, $key )

With no type, will remove all the contents of the object.

With a $type but no $key, will remove _all_ items of that type (so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove {
    my( $this, $type, $keyValue ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my %args = ();
    my $key = '';
    $key = _key( $type ) if( $type );

    if( $keyValue && $key ) {
       my $data = $this->{$type};
       my @newData = ();
       foreach my $item ( @$data ) {
           if( $item->{$key} ne $keyValue ) {
               push @newData, $item;
           }
       }
       $this->{$type} = \@newData;
    } elsif( $type ) {
       delete $this->{$type};
    } else {
       $this = {};
       bless $this;
    }
}

=pod

---++ ObjectMethod copyFrom ( $otherMeta, $type  )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

If $type is undef, will copy ALL TYPES.

SMELL: That spec absolutely _STINKS_ !!
SMELL: this is a shallow copy

=cut

sub copyFrom {
    my( $this, $otherMeta, $type ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;
    ASSERT(ref($otherMeta) eq 'TWiki::Meta') if DEBUG;

    if( $type ) {
        my $data = $otherMeta->{$type};
        $this->{$type} = $data if $data;
    } else {
        foreach my $k ( keys %$otherMeta ) {
            unless( $k =~ /^_/ ) {
                $this->copyFrom( $otherMeta, $k );
            }
        }
    }
}

=pod

---++ ObjectMethod count (  $type  ) -> $integer

Return the number of entries of the given type that are in this meta set

=cut

sub count {
    my( $this, $type ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;
    my $data = $this->{$type};

    return scalar @$data if( defined( $data ));

    return 0;
}

=pod

---++ ObjectMethod addTOPICINFO (  $web, $topic, $rev, $time, $user )
   * =$web= - the web
   * =$topic= - the topic
   * =$rev= - the revision number (defaults to 1)
   * =$time= - the time stamp, defaults to time()
   * =$user= - the user object, defaults to the current session user

Add TOPICINFO type data to the object, as specified by the parameters.

=cut

sub addTOPICINFO {
    my( $this, $web, $topic, $rev, $time, $user ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    $time ||= time();
    $user ||= $this->{_session}->{user};

    $rev = 1 unless $rev;

    $this->put( 'TOPICINFO',
                {
                 # compatibility; older versions of the code use
                 # RCS rev numbers save with them so old code can
                 # read these topics
                 version => '1.'.$rev,
                 date    => $time,
                 author  => $user->wikiName(),
                 format  => $formatVersion
                } );
}

=pod

---++ ObjectMethod getRevisionInfo ( ) -> ( $date, $author, $rev, $comment )

Try and get revision info from the meta information, or, if it is not
present, kick down to the Store module for the same information.

Returns ( $revDate, $author, $rev, $comment )

$rev is an integer revision number.

=cut

sub getRevisionInfo {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my $topicinfo = $this->get( 'TOPICINFO' );

    my( $date, $author, $rev, $comment );
    if( $topicinfo ) {
        $date = $topicinfo->{date} ;
        $author = $this->{_session}->{users}->findUser($topicinfo->{author});
        $rev = $topicinfo->{version};
        $rev =~ s/^\$Rev(: \d+)?\$$/0/;
        $rev =~ s/^\d+\.//;
        $comment = '';
    } else {
        # Get data from Store
        my $store = $this->{_session}->{store};
        ( $date, $author, $rev, $comment ) =
          $store->getRevisionInfo( $this->{_web}, $this->{_topic}, 0 );
    }

    return( $date, $author, $rev, $comment );
}

=pod

---++ ObjectMethod updateSets( \$text )

If there are any settings 'Set SETTING = value' in =$text= for a setting
that is set in form metadata in =$meta=, these are changed so that the
value in the =$text= setting is the same as the one set in the =$meta= form.

=cut

sub updateSets {
    my( $this, $rtext ) = @_;
    ASSERT(ref($this) eq 'TWiki::Meta') if DEBUG;

    my $form = $this->get( 'FORM' );
    if( $form ) {
        my @fields = $this->find( 'FIELD' );
        foreach my $field ( @fields ) {
            my $key = $field->{name};
            my $value = $field->{value};
            my $attributes = $field->{attributes};
            if( $attributes && $attributes =~ /[S]/o ) {
                $value =~ s/\n/\\\n/o;
                # SMELL: Worry about verbatim?  Multi-lines?
                $$rtext =~ s/($TWiki::regex{setRegex}$key\s*=).*?$/$1 $value/gm;
            }
        }
    }
}

=pod

---++ ObjectMethod merge( $otherMeta )

Merge the data in the other meta block.
   * File attachments that only appear in one set are preserved.
   * Form fields that only appear in one set are preserved.
   * Form field values that are different in each set are text-merged
   * We don't merge for field attributes or title
   * Topic info is not touched

=cut

sub merge {
    my ( $this, $other ) = @_;

    my $data = $other->{FIELD};
    if( $data ) {
        foreach my $otherD ( @$data ) {
            my $thisD = $this->get( 'FIELD', $otherD->{name} );
            if ( $thisD && $thisD->{value} ne $otherD->{value} ) {
                my $merged = TWiki::Merge::insDelMerge( $otherD->{value},
                                                        $thisD->{value},
                                                        qr/(\s+)/ );
                # SMELL: we don't merge attributes or title
                $thisD->{value} = $merged;
            } elsif ( !$thisD ) {
                $this->put('FIELD', $otherD );
            }
        }
    }

    $data = $other->{FILEATTACHMENT};
    if( $data ) {
        foreach my $otherD ( @$data ) {
            my $thisD = $this->get( 'FILEATTACHMENT', $otherD->{name} );
            if ( !$thisD ) {
                $this->put('FILEATTACHMENT', $otherD );
            }
        }
    }
}

1;
