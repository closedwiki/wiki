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
# Archive::Zip writer module for PublishContrib
#
use strict;

package TWiki::Contrib::PublishContrib::zip;

use TWiki::Func;

sub new {
    my( $class, $path, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;

    eval "use Archive::Zip qw( :ERROR_CODES :CONSTANTS )";
    die $@ if $@;
    $this->{zip} = Archive::Zip->new();
    $this->{id} = $this->{web}.'.zip';

    return $this;
}

sub addDirectory {
    my( $this, $dir ) = @_;
    $this->{zip}->addDirectory( $dir );
}

sub addString {
    my( $this, $string, $file ) = @_;
    $this->{zip}->addString( $string, $file );
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->{zip}->addFile( $from, $to );
}

sub close {
    my $this = shift;
    $this->{zip}->writeToFileNamed( "$this->{path}/$this->{id}" );
}

1;
