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

package TWiki::Contrib::PublishContrib::pdf;

use Error qw( :try );
use TWiki::Contrib::PublishContrib::file;

@TWiki::Contrib::PublishContrib::pdf::ISA = qw( TWiki::Contrib::PublishContrib::file );

sub new {
    my( $class, $path, $web, $genopt ) = @_;
    my $this = bless( $class->SUPER::new( $path, "${web}_$$" ), $class );
    $this->{id} = $web.'.pdf';
    $this->{genopt} = $genopt;
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
    my $cmd = $TWiki::cfg{PublishContrib}{PDFCmd};
    die "{PublishContrib}{PDFCmd} not defined" unless $cmd;
    my @extras = split( /\s+/, $this->{genopt} );
    my @args = ( FILE => "$this->{path}/$this->{id}",
                 FILES => \@{$this->{files}},
                 EXTRAS => \@extras);

    $ENV{HTMLDOC_DEBUG} = 1; # see man htmldoc - goes to apache err log
    $ENV{HTMLDOC_NOCGI} = 1; # see man htmldoc
    $TWiki::Plugins::SESSION->{sandbox}->{TRACE} = 1;
    $this->{REAL_SAFE_PIPE_OPEN} =
    $this->{EMULATED_SAFE_PIPE_OPEN} = 0;

    my( $data, $exit ) =
      $TWiki::Plugins::SESSION->{sandbox}->sysCommand( $cmd, @args );

    File::Path::rmtree("$this->{path}/$this->{web}", 0, 1 );

    die "htmldoc failed: $exit $data" if $exit;
}

1;

