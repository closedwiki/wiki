# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
#
# Read/write meta data that describes a topic
# Data is held as TWiki variables at the start and end of each topic

package TWiki::Meta;

use strict;

sub new
{
   my $self = {};
   bless $self;   
   return $self;
}

# ===========================
# Replace data for this type.  If type is keyed then only the entry where
# key matches relavent field is replaced
# Order that args sets are put in is maintained
sub put
{
   my( $self, $type, %args ) = @_;
   
   my $data = $self->{$type};
   my $key = _key( $type );
   
   if( $data ) {
       if( $key ) {
           my $found = "";
           my @data = @$data;
           for( my $i=0; $i<scalar @$data; $i++ ) {
               if( $data[$i]->{$key} eq $args{$key} ) {
                   $data->[$i] = \%args;
                   $found = 1;
                   last;
               }
           }
           if( ! $found ) {
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
   my( $type ) = @_;
   
   my $key = "";
   
   if( $type eq "FIELD" || $type eq "FILEATTACHMENT" ) {
       $key = "name";
   }
}

# ===========================
# Find one meta data item
# Key needed for some types (see _key)
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

# ===========================
# Get all meta data for a specific type
# Returns array, zero length if no items
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

# ===========================
# If no keyValue, remove all types, otherwise for types
# with key, just remove specified item. Remove all types
# if $type is empty.
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

# ===========================
# Copy all entries of a type from another meta data set to self,
# overwriting the own set
sub copyFrom
{
    my( $self, $otherMeta, $type ) = @_;

    my $data = $otherMeta->{$type};
    $self->{$type} = $data if( $data );
}

# ===========================
# Number of entries of a given type
sub count
{
    my( $self, $type ) = @_;
    
    my $count = 0;
    
    my $data = $self->{$type};
    if( $data ) {
       $count = scalar @$data;
    }
    
    return $count;
}

sub _writeKeyValue
{
    my( $key, $value ) = @_;
    
    $value = cleanValue( $value );
    
    my $text = "$key=\"$value\"";
    
    return $text;
}

sub _writeTypes
{
    my( $self, @types ) = @_;
    
    my $text = "";

    if( $types[0] eq "not" ) {
        # write all types that are not in the list
        my %seen;
        @seen{ @types } = ();
        @types = ();  # empty "not in list"
        foreach my $key ( keys %$self ) {
            push( @types, $key ) unless exists $seen{ $key };
        }
    }
    
    foreach my $type ( @types ) {
        my $data = $self->{$type};
        foreach my $item ( @$data ) {
            my $sep = "";
            $text .= "%META:$type\{";
            my $name = $item->{"name"};
            if( $name ) {
                # If there's a name field, put first to make regexp based searching easier
                $text .= _writeKeyValue( "name", $item->{"name"} );
                $sep = " ";
            }
            foreach my $key ( sort keys %$item ) {
                if( $key ne "name" ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = " ";
                }
            }
            $text .= "\}%\n";
         }
    }

    return $text;
}

sub cleanValue
{
    my( $value ) = @_;
   
    $value =~ s/\r\r\n/%_N_%/go;
    $value =~ s/\r\n/%_N_%/go;
    $value =~ s/\n\r/%_N_%/go;
    $value =~ s/\r\n/%_N_%/go; # Deal with doubles or \n\r
    $value =~ s/\r/\n/go;
    $value =~ s/\n/%_N_%/go;
    $value =~ s/"/%_Q_%/go;
    
    return $value;
}

sub restoreValue
{
    my( $value ) = @_;
    
    $value =~ s/%_N_%/\n/go;
    $value =~ s/%_Q_%/"/go;
    
    return $value;
}



# ======================
sub _keyValue2Hash
{
    my( $args ) = @_;
    
    my %res = ();
    
    # Format of data is name="value" name1="value1" [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        my $key = $1;
        my $value = $2;
        $value = restoreValue( $value );
        $res{$key} = $value;
    }
    
    return %res;
}

# ===========================
# Returns text with meta stripped out
sub read
{
    my( $self, $text ) = @_;
    
    my $newText = "";

    foreach ( split( /\n/, $text ) ) {
        if( /^%META:([^{]+){([^}]*)}%/ ) {
            my $type = $1;
            my $args = $2;
            my %list = _keyValue2Hash( $args );
            $self->put( $type, %list );
        } else {
            $newText .= "$_\n";
        }
    }
    
    return $newText;
}

# ===========================
# Meta data for start of topic
sub writeStart
{
    my( $self ) = @_;
    
    return $self->_writeTypes( qw/TOPICINFO TOPICPARENT/ );
}

# ===========================
# Meta data for end of topic
sub writeEnd
{
    my( $self ) = @_;
    
    my $text = $self->_writeTypes( qw/FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    # append remaining meta data
    $text .= $self->_writeTypes( qw/not TOPICINFO TOPICPARENT FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    return $text;
}

# ===========================
# Prepend/append meta data to topic
sub write
{
    my( $self, $text ) = @_;
    
    my $start = $self->writeStart();
    my $end = $self->writeEnd();
    $text = $start . "$text";
    $text =~ s/([^\n\r])$/$1\n/;     # new line is required at end
    $text .= $end;
    
    return $text;
}



1;
