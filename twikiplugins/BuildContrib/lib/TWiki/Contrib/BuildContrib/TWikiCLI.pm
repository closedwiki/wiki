package TWiki::Contrib::BuildContrib::TWikiCLI;

use Getopt::Long;

my $verboseFlag = 0;
GetOptions("verbose!"=>\$verboseFlag);

print "Unprocessed by Getopt::Long\n" if $ARGV[0];
foreach (@ARGV) {
  print "$_\n";
}

1;
