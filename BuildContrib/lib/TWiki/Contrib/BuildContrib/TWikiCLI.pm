package TWiki::Contrib::BuildContrib::TWikiCLI;
my $prefix = "TWiki::Contrib::BuildContrib::TWikiCLI";

use Getopt::Long; # see http://www.aplawrence.com/Unix/perlgetopts.html

sub dispatch {
 my $verboseFlag = 0;
 GetOptions( "verbose!" => \$verboseFlag );

 my @args =  qw(extension install DistributionContrib);# "@ARGV;

 my $class = ucfirst lc shift @args; # eg. extension => Extension 
 my $fqClass = $prefix."::".$class;

 eval { require $fqClass; import $fqClass; };
 
 my $dispatchSub = $@
  ? &noSuchMethod  # don't have it
  : sub { dispatch(@_) };


 if (defined &$dispatchSub) {
  return &$dispatchSub(@args);
 } else {
  return helpText();
 }

 print "Unprocessed by Getopt::Long\n" if $ARGV[0];
 foreach (@ARGV) {
  print "$_\n";
 }
}

sub noSuchMethod {


}
1;
