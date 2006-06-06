#
# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
#
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
# PDF writer module for PublishContrib
#

use strict;

package TWiki::Contrib::PublishContrib::pdf;

use Error qw( :try );
use TWiki::Contrib::PublishContrib::file;
use TWiki::Contrib::PublishContrib::PDFWriter;
 
@TWiki::Contrib::PublishContrib::pdf::ISA = qw( TWiki::Contrib::PublishContrib::file );

my $publishWeb;

sub new {
    my( $class, $path, $web, $genopt ) = @_;
    my $this = bless( $class->SUPER::new( $path, "${web}_$$" ), $class );
    $this->{genopt} = $genopt;
    $publishWeb = $web;
    return $this;
}

sub addString {
    my( $this, $string, $file) = @_;
    $this->SUPER::addString( $string, $file );
    push( @{$this->{files}}, "$this->{path}/$this->{web}/$file" )
      if( $file =~ /\.html$/ );
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );
    push( @{$this->{files}}, "$this->{path}/$this->{web}/$to" )
      if( $to =~ /\.html$/ );
}

sub close {
    my $this = shift;
    TWiki::Contrib::PublishContrib::PDFWriter->writePdf( "$this->{path}/$publishWeb.pdf", \@{$this->{files}} );
}

1;
