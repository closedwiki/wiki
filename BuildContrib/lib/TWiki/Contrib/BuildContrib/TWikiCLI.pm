package TWiki::Contrib::BuildContrib::TWikiCLI;

use Getopt::Long;

sub dispatch {
 my $verboseFlag = 0;
 GetOptions( "verbose!" => \$verboseFlag );

 my $subcommand = $ARGV[0];

 if (defined &$subcommand) {
  return &$subcommand;
 } else {
  return helpText();
 }

 print "Unprocessed by Getopt::Long\n" if $ARGV[0];
 foreach (@ARGV) {
  print "$_\n";
 }
}

sub extension {
 print "love ya sweety\n";

}

1;
