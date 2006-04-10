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
# File writer module for PublishContrib
#
use strict;

package TWiki::Contrib::PublishContrib::file;

use Error qw( :try );

sub new {
    my( $class, $path, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;
    $this->{id} = $web;
    $this->{root} = "$this->{path}/$web/WebHome.html";

    eval "use File::Copy;use File::Path;";
    die $@ if $@;

    File::Path::mkpath("$this->{path}/$web");

    return $this;
}

sub addDirectory {
    my( $this, $name ) = @_;
    my $d = "$this->{web}/$name";
    File::Path::mkpath("$this->{path}/$d");
}

sub addString {
    my( $this, $string, $file) = @_;
    my $f = "$this->{web}/$file";
    open(F, ">$this->{path}/$f") || die "Cannot write $f: $!";
    print F $string;
    close(F);
}

sub addFile {
    my( $this, $from, $to ) = @_;
    File::Copy::copy( $from, "$this->{path}/$this->{web}/$to" );
}

sub close {
}

1;

