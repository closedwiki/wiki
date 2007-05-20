# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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

All TWiki topics have *data* (text) and *meta-data* (information about the
topic). Meta-data includes information such as file attachments, form fields,
topic parentage etc. When TWiki loads a topic from the store, it represents
the meta-data in the topic using an object of this class.

A meta-data object is a hash of different types of meta-data (keyed on
the type, such as 'FIELD' and 'TOPICINFO').

Each entry in the hash is an array, where each entry in the array
contains another hash of the key=value pairs, corresponding to a
single meta-datum.

If there may be multiple entries of the same top-level type (i.e. for FIELD
and FILEATTACHMENT) then the array has multiple entries. These types
are referred to as "keyed" types. The array entries are keyed with the
attribute 'name' which must be in each entry in the array.

For unkeyed types, the array has only one entry.

Pictorially,
   * TOPICINFO
      * author => '...'
      * date => '...'
      * ...
   * FILEATTACHMENT
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }
   * FIELD
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }

=cut

package TWiki::Meta;

use strict;
use Error qw(:try);
use Assert;
use TWiki::Merge;

=pod

---++ ClassMethod new($session, $web, $topic)
   * =$session= - a TWiki object (e.g. =$TWiki::Plugins::SESSION)
   * =$web=, =$topic= - the topic that the metadata relates to
Construct a new, empty object to contain meta-data for the given topic.

=cut

sub new {
    my ( $class, $session, $web, $topic ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    # Note: internal fields must be prepended with _. All other
    # fields will be assumed to be meta-data.
    $this->{_session} = $session;

    ASSERT($web) if DEBUG;
    ASSERT($topic) if DEBUG;

    $this->{_web} = $web;
    $this->{_topic} = $topic;

    $this->{FILEATTACHMENT} = [];

    return $this;
}

=pod

---++ ClassMethod web()

Get the web name

=cut

sub web {
    return $_[0]->{_web};
}

=pod

---++ ClassMethod topic()

Get the topic name

=cut

sub topic {
    return $_[0]->{_topic};
}

=pod

---++ ObjectMethod put($type, \%args)

Put a hash of key=value pairs into the given type set in this meta. This
will *not* replace another value with the same name (for that see =putKeyed=)

For example, 
<verbatim>
$meta->put( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

sub put {
    my( $this, $type, $args ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    my $data = $this->{$type};
    if( $data ) {
      # overwrite old single value
      $data->[0] = $args;
    } else {
      push( @{$this->{$type}}, $args );
    }
}

=pod

---++ ObjectMethod putKeyed($type, \%args)

Put a hash of key=value pairs into the given type set in this meta, replacing
any existing value with the same key.

For example,
<verbatim>
$meta->putKeyed( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

# Note: Array is used instead of a hash to preserve sequence

sub putKeyed {
    my( $this, $type, $args ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    my $data = $this->{$type};
    if( $data ) {
        my $keyName = $args->{name};
        ASSERT( $keyName ) if DEBUG;
        my $i = scalar( @$data );
        while( $keyName && $i-- ) {
            if( $data->[$i]->{name} eq $keyName ) {
                $data->[$i] = $args;
                return;
            }
        }
        push @$data, $args;
    } else {
      push( @{$this->{$type}}, $args );
    }
}

=pod

---++ ObjectMethod putAll

Replaces all the items of a given key with a new array.

For example,
<verbatim>
$meta->putAll( 'FIELD',
     { name => 'MinAge', title => 'Min Age', value =>'50' },
     { name => 'MaxAge', title => 'Max Age', value =>'103' },
     { name => 'HairColour', title => 'Hair Colour', value =>'white' }
 );
</verbatim>

=cut

sub putAll {
    my( $this, $type, @array ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    $this->{$type} = \@array;
}

=pod

---++ ObjectMethod get( $type, $key ) -> \%hash

Find the value of a meta-datum in the map. If the type is
keyed (idenitifed by a =name=), the =$key= parameter is required
to say _which_ entry you want. Otherwise you will just get the first value.

If you want all the keys of a given type use the 'find' method.

The result is a reference to the hash for the item.

For example,
<verbatim>
my $ma = $meta->get( 'FIELD', 'MinAge' );
my $topicinfo = $meta->get( 'TOPICINFO' ); # get the TOPICINFO hash
</verbatim>

=cut

sub get {
    my( $this, $type, $keyValue ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    my $data = $this->{$type};
    if( $data ) {
        if( defined $keyValue ) {
            foreach my $item ( @$data ) {
                return $item if( $item->{name} eq $keyValue );
            }
        } else {
            return $data->[0];
        }
    }

    return undef;
}

=pod

---++ ObjectMethod find (  $type  ) -> @values

Get all meta data for a specific type.
Returns the array stored for the type. This will be zero length
if there are no entries.

For example,
<verbatim>
my $attachments = $meta->find( 'FILEATTACHMENT' );
</verbatim>

=cut

sub find {
    my( $this, $type ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    my $itemsr = $this->{$type};
    my @items = ();

    if( $itemsr ) {
        @items = @$itemsr;
    }

    return @items;
}

=pod

---++ ObjectMethod remove($type, $key)

With no type, will remove all the contents of the object.

With a $type but no $key, will remove _all_ items of that type (so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove {
    my( $this, $type, $keyValue ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;

    if( $keyValue ) {
       my $data = $this->{$type};
       my @newData = ();
       foreach my $item ( @$data ) {
           if( $item->{name} ne $keyValue ) {
               push @newData, $item;
           }
       }
       $this->{$type} = \@newData;
    } elsif( $type ) {
       delete $this->{$type};
    } else {
        foreach my $entry ( keys %$this ) {
            unless( $entry =~ /^_/ ) {
                $this->remove( $entry );
            }
        }
    }
}

=pod

---++ ObjectMethod copyFrom( $otherMeta, $type, $nameFilter )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

If $type is undef, will copy ALL TYPES.

If $nameFilter is defined (a perl refular expression), it will copy
only data where ={name}= matches $nameFilter.

=cut

sub copyFrom {
    my( $this, $otherMeta, $type, $filter ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;
    ASSERT($otherMeta->isa( 'TWiki::Meta')) if DEBUG;

    if( $type ) {
        foreach my $item ( @{$otherMeta->{$type}} ) {
            if( !$filter || ( $item->{name} && $item->{name} =~ /$filter/ )) {
                my %data = map { $_ => $item->{$_} } keys %$item;
                push( @{$this->{$type}}, \%data );
            }
        }
    } else {
        foreach my $k ( keys %$otherMeta ) {
            unless( $k =~ /^_/ ) {
                $this->copyFrom( $otherMeta, $k );
            }
        }
    }
}

=pod

---++ ObjectMethod count($type) -> $integer

Return the number of entries of the given type

=cut

sub count {
    my( $this, $type ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;
    my $data = $this->{$type};

    return scalar @$data if( defined( $data ));

    return 0;
}

=pod

---++ ObjectMethod getRevisionInfo($fromrev) -> ( $date, $author, $rev, $comment )

Try and get revision info from the meta information, or, if it is not
present, kick down to the Store module for the same information.

Returns ( $revDate, $author, $rev, $comment )

$rev is an integer revision number.

=cut

sub getRevisionInfo {
    my( $this, $fromrev ) = @_;
    ASSERT($this->isa( 'TWiki::Meta')) if DEBUG;
    my $store = $this->{_session}->{store};

    my $topicinfo = $this->get( 'TOPICINFO' );

    my( $date, $author, $rev, $comment );
    if( $topicinfo ) {
        $date = $topicinfo->{date} ;
        $author = $topicinfo->{author};
        $rev = $topicinfo->{version};
        $rev =~ s/^\$Rev(:\s*\d+)?\s*\$$/0/; # parse out SVN keywords in doc
        $rev =~ s/^\d+\.//;
        $comment = '';
        if ( !$fromrev || $rev eq $fromrev ) {
            return( $date, $author, $rev, $comment );
        }
    }
    # Different rev, or no topic info, delegate to Store
    ( $date, $author, $rev, $comment ) =
      $store->getRevisionInfo( $this->{_web}, $this->{_topic}, $fromrev );
    return( $date, $author, $rev, $comment );
}

=pod

---++ ObjectMethod merge( $otherMeta, $formDef )

   * =$otherMeta= - a block of meta-data to merge with $this
   * =$formDef= reference to a TWiki::Form that gives the types of the fields in $this

Merge the data in the other meta block.
   * File attachments that only appear in one set are preserved.
   * Form fields that only appear in one set are preserved.
   * Form field values that are different in each set are text-merged
   * We don't merge for field attributes or title
   * Topic info is not touched
   * The =mergeable= method on the form def is used to determine if that fields is mergeable. if it isn't, the value currently in meta will _not_ be changed.

=cut

sub merge {
    my ( $this, $other, $formDef ) = @_;

    my $data = $other->{FIELD};
    if( $data ) {
        foreach my $otherD ( @$data ) {
            my $thisD = $this->get( 'FIELD', $otherD->{name} );
            if ( $thisD && $thisD->{value} ne $otherD->{value} ) {
                if( $formDef->isTextMergeable( $thisD->{name} )) {
                    my $merged = TWiki::Merge::merge2(
                        'A', $otherD->{value}, 'B', $thisD->{value},
                        '.*?\s+',
                        $this->{_session},
                        $formDef->getField( $thisD->{name} ) );
                    # SMELL: we don't merge attributes or title
                    $thisD->{value} = $merged;
                }
            } elsif ( !$thisD ) {
                $this->putKeyed('FIELD', $otherD );
            }
        }
    }

    $data = $other->{FILEATTACHMENT};
    if( $data ) {
        foreach my $otherD ( @$data ) {
            my $thisD = $this->get( 'FILEATTACHMENT', $otherD->{name} );
            if ( !$thisD ) {
                $this->putKeyed('FILEATTACHMENT', $otherD );
            }
        }
    }
}

=pod

---++ ObjectMethod stringify( $types ) -> $string

Return a string version of the meta object. Uses \n to separate lines.
If =$types= is specified, return only types
that match it. Types should be a perl regular expression.

=cut

sub stringify {
    my( $this, $types ) = @_;
    my $s = '';
    $types ||= qr/^[A-Z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        foreach my $item ( @{$this->{$type}} ) {
            $s .= "$type: " .
              join(' ', map{ "$_='".($item->{$_}||'')."'" }
                     sort keys %$item ) .
                       "\n";
        }
    }
    return $s;
}

=pod

---++ ObjectMethod forEachSelectedValue( $types, $keys, \&fn, \%options )

Iterate over the values selected by the regular expressions in $types and
$keys.
   * =$types= - regular expression matching the names of fields to be processed. Will default to qr/^[A-Z]+$/ if undef.
   * =$keys= - regular expression matching the names of keys to be processed.  Will default to qr/^[a-z]+$/ if undef.

Iterates over each value, calling =\&fn= on each, and replacing the value
with the result of \&fn.

\%options will be passed on to $fn, with the following additions:
   * =_type= => the type name (e.g. "FILEATTACHMENT")
   * =_key= => the key name (e.g. "user")

=cut

sub forEachSelectedValue {
    my( $this, $types, $keys, $fn, $options ) = @_;

    $types ||= qr/^[A-Z]+$/;
    $keys ||= qr/^[a-z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        $options->{_type} = $type;
        my $data = $this->{$type};
        next unless $data;
        foreach my $datum ( @$data ) {
            foreach my $key ( grep { /$keys/ } keys %$datum ) {
                $options->{_key} = $key;
                $datum->{$key} = &$fn( $datum->{$key}, $options );
            }
        }
    }
}

=pod

---++ ObjectMethod getParent() -> $parent

Gets the TOPICPARENT name.

=cut

sub getParent {
    my( $this ) = @_;

    my $value = '';
    my $parent = $this->get( 'TOPICPARENT' );
    $value = $parent->{name} if( $parent );
    # Return empty string (not undef), if TOPICPARENT meta is broken
    $value = '' if (!defined $value);
    return $value;
}

=pod

---++ ObjectMethod getFormName() -> $formname

Returns the name of the FORM, or '' if none.

=cut

sub getFormName {
    my( $this ) = @_;

    my $aForm = $this->get( 'FORM' );
    if( $aForm ) {
        return $aForm->{name};
    }
    return '';
}

=pod

---++ ObjectMethod renderFormForDisplay() -> $html

Render the form contained in the meta for display. Does not require
the form definition.

=cut

sub renderFormForDisplay {
    my $this = shift;

    my $templates = $this->{_session}->{templates};
    my $form = $this->get( 'FORM' );

    return '' unless( $form );

    $templates->readTemplate('formtables');

    my $name = $form->{name};

    my $text = $templates->expandTemplate('FORM:display:header');

	my $rowTemplate = $templates->expandTemplate('FORM:display:row');
    my @fields = $this->find( 'FIELD' );
    foreach my $field ( @fields ) {
        my $fa = $field->{attributes} || '';
        unless ( $fa =~ /H/ ) {
            my $value = $field->{value};
            $value = '&nbsp;' unless defined($value);
            my $title = $field->{title} || $field->{name};
            my $row = $rowTemplate;
            $row =~ s/%A_TITLE%/$title/g;
            $row =~ s/%A_VALUE%/$value/g;
            $text .= $row;
        }
    }
    $text .= $templates->expandTemplate('FORM:display:footer');
    $text =~ s/%A_TITLE%/$name/g;
    return $text;
}

1;
