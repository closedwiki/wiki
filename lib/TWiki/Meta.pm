# Module of TWiki Collaboration Platform, http://TWiki.org/
#
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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally change TWiki.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize TWiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#
# Jun 2001 - written by John Talintyre, jet@cheerful.com

=begin twiki

---+ TWiki::Meta Module

Meta-data handling.

A meta-data object is a hash of different types of meta-data (keyed on
the type, such as "FIELD" and "TOPICINFO").

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

=pod

---++ sub new ()

Construct a new, empty Meta collection.

=cut

sub new {
    my ( $class, $web, $topic ) = @_;
    my $self = {};
    throw Error::Simple("ASSERT: no web") unless $web;
    throw Error::Simple("ASSERT: no topic") unless $topic;
    $self->{_web} = $web;
    $self->{_topic} = $topic;
    bless( $self, $class );
    return $self;
}

=pod

# ===========================
# Replace data for this type.  If type is keyed then only the entry where
# key matches relevant field is replaced
# Order that args sets are put in is maintained
=pod

---++ sub put (  $self, $type, %args  )

Put a hash of key=value pairs into the given type set in this meta.

See the main comment for this package to understand how meta-data is
represented.

=cut

sub put
{
   my( $self, $type, %args ) = @_;

   my $data = $self->{$type};
   my $key = _key( $type );

   if( $data ) {
       if( $key ) {
           my $found = "";
           my $keyName = $args{$key};
           my @data = @$data;
           unless( $keyName ) {
               TWiki::writeWarning( "Meta: Required $key parameter is missing for META:$type" );
               return;
           }
           for( my $i = 0; $i < scalar( @$data ); $i++ ) {
               if( $data[$i]->{$key} eq $keyName ) {
                   $data->[$i] = \%args;
                   $found = 1;
                   last;
               }
           }
           unless( $found ) {
               push @$data, \%args;
           }
       } else {
           $data->[0] = \%args; 
       }

   } else {
       my @data = ( \%args );
       $self->{$type} = \@data;
   }
}

# ===========================
# Give the key field for a type, "" if no key

sub _key
{
   my $type = shift;

   return "name" if( $type eq "FIELD" || $type eq "FILEATTACHMENT" );

   return undef;
}

# ===========================
=pod

---++ sub findOne (  $self, $type, $key  )

Find the value of a meta-datum in the map. If the type is FIELD or
FILEATTACHMENT, the $key parameter is required to say _which_
entry you want. Otherwise it can be undef.

SMELL: This method would be better named "lookup" or "get".

=cut

sub findOne
{
   my( $self, $type, $keyValue ) = @_;
   
   my %args = ();

   my $data = $self->{$type};
   my $key = _key( $type );

   if( $data ) {
       if( $key ) {
           foreach my $item ( @$data ) {
               if( $item->{$key} eq $keyValue ) {
                   %args = %$item;
                   last;
               }
           }
       } else {
           my $item = $data->[0];
           %args = %$item;
       }
   }

   return %args;
}

=pod

---++ sub find (  $self, $type  )

Get all meta data for a specific type
Returns the array stored for the type. This will be zero length
if there are no entries.

=cut

sub find
{
    my( $self, $type ) = @_;
    
    my $itemsr = $self->{$type};
    my @items = ();
    
    if( $itemsr ) {
        @items = @$itemsr;
    }
    
    return @items;
}

=pod

---++ sub remove ( $self, $type, $key )

With no type, will remove all the contents of the object.

With a $type but no $key, will remove _all_ items of that type (so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove
{
    my( $self, $type, $keyValue ) = @_;
    
    my %args = ();
    my $key = "";
    $key = _key( $type ) if( $type );
    
    if( $keyValue && $key ) {
       my $data = $self->{$type};
       my @newData = ();
       foreach my $item ( @$data ) {
           if( $item->{$key} ne $keyValue ) {
               push @newData, $item;
           }
       }
       $self->{$type} = \@newData;
    } elsif( $type ) {
       delete $self->{$type};
    } else {
       $self = {};
       bless $self;   
    }
}

=pod

---++ sub copyFrom (  $self, $otherMeta, $type  )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

SMELL: That spec absolutely _STINKS_ !!

=cut

sub copyFrom
{
    my( $self, $otherMeta, $type ) = @_;

    my $data = $otherMeta->{$type};
    $self->{$type} = $data if( $data );
}

=pod

---++ sub count (  $self, $type  )

Return the number of entries of the given type that are in this meta set

=cut

sub count
{
    my( $self, $type ) = @_;
    my $data = $self->{$type};

    return scalar @$data if( defined( $data ));

    return 0;
}

=pod

---++ sub restoreValue (  $value  )

Converts %_N_% to a newline and %_Q_% to a " in the string. This is
part of Meta because it is an operation that is frequently associated
with meta-data values.

SMELL: That isn't a good enough reason!

=cut

sub restoreValue
{
    my( $value ) = @_;

    $value =~ s/%_N_%/\n/go;
    $value =~ s/%_Q_%/"/go;

    return $value;
}

=pod

---++ sub addTopicInfo (  $web, $topic, $rev, $meta, $forceDate, $forceUser  )

Add TOPICINFO type data to the object, as specified by the parameters.

=cut

sub addTopicInfo {
    my( $self, $web, $topic, $rev, $forceDate, $forceUser ) = @_;

    my $time = $forceDate || time();
    my $user = $forceUser || $TWiki::userName;

    die "ASSERT $rev" unless( $rev =~ /^\d+$/ ); # temporary

    my @args =
      (
       # compatibility; older versions of the code use RCS rev numbers
       # save with them so old code can read these topics
       version => "1.$rev",
       date    => $time,
       author  => $user,
       format  => $TWiki::formatVersion
      );
    $self->put( "TOPICINFO", @args );
}

=pod

---++ sub getRevisionInfo ( )

Try and get revision info from the meta information, or, if it is not
present, kick down to the Store module for the same information.

Returns ( $revDate, $author, $rev, $comment )

$rev is an integer revision number.

=cut

sub getRevisionInfo {
    my $self = shift;

    my %topicinfo = $self->findOne( "TOPICINFO" );

    my( $date, $author, $rev, $comment );
    if( %topicinfo ) {
       $date = $topicinfo{"date"} ;
       $author = $topicinfo{"author"};
       $rev = $topicinfo{"version"};
       $rev =~ s/^\d+\.//;
       $comment = "";
    } else {
       # Get data from Store
       ( $date, $author, $rev, $comment ) =
         TWiki::Store::getRevisionInfo( $self->{_web}, $self->{_topic}, 0 );
    }

    return( $date, $author, $rev, $comment );
}

1;
