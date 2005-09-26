#!/usr/bin/perl

print <<END;
This script must be run from the tools directory. It will scan the MANIFEST
and compare the contents with what is checked in under subversion. Any#
differences are reported.

The test, tools and twikiplugins directories are *not* scanned.
END
my %man;

map{ s/ .*//; $man{$_} = 1; } grep { !/^!include/  } split(/\n/, `cat MANIFEST` );

my @lost;

foreach my $dir( grep { -d "../$_" }
                   split(/\n/, `svn ls ..`) ) {
    next if $dir =~ /^(test|tools|twikiplugins)/;
    print "Examining $dir\n";
    push( @lost,
          grep { !$man{$_} && !/\/TestCases\// && ! -d "../$_" }
            map{ "$dir$_" }
              split(/\n/, `cd .. && svn ls -R $dir`));
}
print "The following files were found in subversion, but are not in MANIFEST\n";
print join("\n", @lost ),"\n";
