# PDF writer module for PublishContrib
#
# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
# PDF Writer module for PublishContrib
#

use strict;

package TWiki::Contrib::PublishContrib::PDFWriter;

use Error qw( :try );

sub writePdf {
	my $this = shift;
	my ($pdf, $filesRef, $debug) = @_;
    my $cmd = $TWiki::cfg{PublishContrib}{PDFCmd};
    die "{PublishContrib}{PDFCmd} not defined" unless $cmd;
    my @extras = split( /\s+/, $this->{genopt} );
    my @args = ( FILE => $pdf,
                 FILES => $filesRef,
                 EXTRAS => \@extras);

    $ENV{HTMLDOC_DEBUG} = 1; # see man htmldoc - goes to apache err log
    $ENV{HTMLDOC_NOCGI} = 1; # see man htmldoc
    $TWiki::Plugins::SESSION->{sandbox}->{TRACE} = 1;
    $this->{REAL_SAFE_PIPE_OPEN} =
    $this->{EMULATED_SAFE_PIPE_OPEN} = 0;
	
    print "Running '".$cmd."'\n" if $debug;
    my( $data, $exit ) =
      $TWiki::Plugins::SESSION->{sandbox}->sysCommand( $cmd, @args );

    File::Path::rmtree("$this->{path}/$this->{web}", 0, 1 );

    die "htmldoc failed: $exit $data" if $exit;
}

1;
