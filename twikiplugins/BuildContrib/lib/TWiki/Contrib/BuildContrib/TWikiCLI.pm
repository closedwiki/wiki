package TWiki::Contrib::BuildContrib::TWikiCLI;
my $prefix = "TWiki::Contrib::BuildContrib::TWikiCLI";

use Getopt::Long; # see http://www.aplawrence.com/Unix/perlgetopts.html

sub dispatch {
 my $verboseFlag = 0;
 GetOptions( "verbose!" => \$verboseFlag );

 my @args =  qw(extension install DistributionContrib);# "@ARGV;

 my $class = ucfirst lc shift @args; # eg. extension => Extension 
 my $fqClass = $prefix."::".$class;

 eval { require $fqClass; } ;

 if ($@ ){
     print "no can do - $@";
 }
 
 my $dispatchSub = $@
  ? \&noSuchMethod  # don't have it
  : sub { dispatch2(@_) };

 if (defined &$dispatchSub) {
     print "calling $dispatchSub\n";
  return &$dispatchSub(@args);
 } else {
  return helpText();
 }

# print "Unprocessed by Getopt::Long\n" if $ARGV[0];
# foreach (@ARGV) {
#  print "$_\n";
# }
}

sub noSuchMethod {
    my ($err) = @_;
    return "no such method - $err\n";

}

sub helpText {
   return "Help text goes here\n";

}

sub dispatch2 {
    return "ok";
}
1;
