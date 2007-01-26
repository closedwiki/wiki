#!/usr/bin/perl
# Test program for NativeTWikiSearch
# If it is correctly installed, this program will accept parameters like grep
# e.g.
# perl test.pl -i -l NativeTWikiSearch test.pl Makefile.PL NativeTWikiSearch.xs
#
use NativeTWikiSearch;
my $result = NativeTWikiSearch::cgrep(\@ARGV);
print "RESULT\n".join("\n", @$result)."\n";
