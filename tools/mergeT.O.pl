#!/usr/bin/perl;
#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 TWiki Contributors.
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
#
# Author: Crawford Currie http://c-dot.co.uk
#
# This script synchronises the content of a local subversion checkout with
# the content of the documentation in the 'TWiki' web of twiki.org. It
# only synchronises topics checked in to TWiki; linked documents are ignored.
#
# Progress messages are printed to STDERR. The output of the script is
# a subversion command suitable for committing all the changes that the
# script has imported from t.o.
#
# To run this script:
# cd ..../bin
# perl ../tools/mergeT.O.pl
use strict;

do '../bin/setlib.cfg';

use Algorithm::Diff;

my $path = '';
my @files;

# Iterate over selected webs
foreach my $web qw(TWiki) {
    unless (opendir(D, "../data/$web")) {
        print STDERR "Failed to open $web: $!";
        next;
    }
    # iterate over topics
    foreach my $topic (readdir(D)) {
        local $/;
        next unless $topic =~ /^\w+\.txt$/;

        my $path = "$web/$topic";
        $path =~ s/.txt$//;

        # load local doc version
        my $file = "../data/$path.txt";

        if (-l $file) {
            next; # a link; ignore it

            # if we were going to update linked topics, here's what we'd
            # have to do:
            # Resolve the link
            $file = readlink($file);
            # Relative links to plugins area are relative to data/TWiki
            # but we are in bin; so hack off the first ../
            $file =~ s/^\.\.\///;
        }

        unless (open(F, "<$file")) {
            print STDERR "Failed to open $file: $!\n";
            next;
        }

        # Hack off META
        my $local = <F>;
        $local =~ s/\r//;
        my @llines = split(/\n/, $local);
        my @top;
        while (scalar(@llines) && $llines[0] =~ /^%META:\w+{.*?}%$/) {
            push(@top, shift(@llines));
        }
        my @bottom;
        while (scalar(@llines) && $llines[-1] =~ /^(%META:\w+{.*?}%|\s*)$/) {
            unshift(@bottom, pop(@llines));
        }

        # Load version of doc on t.o
        my $url = "http://twiki.org/cgi-bin/view/$path?raw=all";
        my $remote = getUrl($url);
        unless ($remote =~ s/^(HTTP[^\n]*200.*?\n).*\r\n\r\n//s) {
            $remote =~ /^(.*)[\r\n]/;
            print STDERR "Failed to get $path: $remote\n";
            next;
        }
        if ($remote !~ /.*%STARTSECTION{"distributiondoc"}%/) {
            print STDERR "*** Will not update $path\n";
            print STDERR "\tTWiki.org doc has no 'distributiondoc' section\n";
            next;
        }

        # Hack off stuff outside the distribution section, and meta
        $remote =~ s/\r//;
        $remote =~ s/.*%STARTSECTION{"distributiondoc"}%\s*//s;
        $remote =~ s/\s*%ENDSECTION{"distributiondoc"}%.*//s;
        $remote =~ s/^((%META:\w+{.*?}%\n)+)//s;
        $remote =~ s/((\n%META:\w+{.*?}%\n*)+)$//s;
        $remote =~ s/\s*$/\n/s;

        # Compare
        if ($remote ne $local) {
            my $changes = "---+ $file\n";
            my @rlines = split(/\n/, $remote);
            my $diff = Algorithm::Diff->new(\@llines, \@rlines);
            my $changed = 0;
            while ($diff->Next()) {
                if ($diff->Same()) {
                    push(@top, $diff->Same(1));
                    next;
                }
                if ($diff->Items(1)) {
                    #$changes .= "< ".join("\n< ", $diff->Items(1))."\n";
                    $changed = 1;
                }
                if ($diff->Items(2)) {
                    #$changes .= "> ".join("\n", $diff->Items(2))."\n";
                    push(@top, $diff->Items(2));
                    $changed = 1;
                }
            }
            if ($changed) {
                print STDERR $changes;
                push(@top, @bottom);
                my $content = join("\n", @top);
                if (open(F, ">$file")) {
                    print F $content,"\n";
                    print STDERR "\t$file has been updated\n";
                    close(F);
                    push(@files, $file);
                } else {
                    print STDERR "Failed to open $file for write: $!\n";
                }
            }
        }
    }
}

if (scalar(@files)) {
    print "svn commit -m 'Item1: Automatic documentation synch from TWiki.org' ".
      join(" ", @files)."\n";
}

sub getUrl {
    my ($url) = @_;

    die "Bad URL $url " unless $url =~ m#^(\w+)://(.*?)(/.*)$#;
    my ($protocol, $host, $path) = ($1, $2, $3);
    my $port = 80;
    if ($host =~ s/:(\d+)$//) {
        $port = $1;
    }
    my $req = "GET $path HTTP/1.0\r\nHost: $host\r\nUser-agent: Merger/1.0 +http://twiki.org/\r\n\r\n";
    if ($TWiki::cfg{PROXY}{HOST} && $TWiki::cfg{PROXY}{PORT}) {
        $req = "GET http://$host:$port$path HTTP/1.0\r\n\r\n";
        $host = $TWiki::cfg{PROXY}{HOST};
        $port = $TWiki::cfg{PROXY}{PORT};
    }

    require Socket;

    my $ipaddr = Socket::inet_aton($host);
    die "inet_aton: host cannot be found" unless $ipaddr;
    my $packedaddr = Socket::sockaddr_in( $port, $ipaddr );
    my $proto = getprotobyname('tcp');
    die "getprotobyname: No proto" unless $proto;
    unless (socket(*SOCK, &Socket::PF_INET, &Socket::SOCK_STREAM, $proto)) {
        die "socket: $!.";
    }
    unless (connect(*SOCK, $packedaddr)) {
        die "connect: $!.\n$req";
    }
    select SOCK;
    local $| = 1;
    local $/ = undef;
    print SOCK $req;
    my $result = <SOCK>;
    close( SOCK );
    select STDOUT;
    return $result;
}
