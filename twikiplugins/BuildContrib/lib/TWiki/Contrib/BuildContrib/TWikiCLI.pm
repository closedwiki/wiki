#! perl -w
use strict;
use diagnostics;
use Cwd;

print cwd()."\n";
#BEGIN {
#chdir "../../lib";
#}

package TWiki::Contrib::BuildContrib::TWikiCLI;
my $prefix = "TWiki::Contrib::BuildContrib::TWikiCLI";

use Getopt::Long; # see http://www.aplawrence.com/Unix/perlgetopts.html
#use TWiki::Contrib::BuildContrib::TWikiCLI::Extension;

sub dispatch {
 my $verboseFlag = 0;
 GetOptions( "verbose!" => \$verboseFlag );

 my @args =  @ARGV;

 my ($class, $args) = findTargetClassForString(@args);
 
 unless ($class) {
     return helpText();
     exit;
 }
 my $fqClass = $prefix."::".$class;

 dispatch2($fqClass, "_init");
 dispatch2($fqClass, @args);
 
 }

# print "Unprocessed by Getopt::Long\n" if $ARGV[0];
# foreach (@ARGV) {
#  print "$_\n";
# }

sub findTargetClassForString {
 my @cli_args = @_;
 # e.g. extension dev foo bar
 # we match extension dev, because Extension::Dev exists but
 # neither Extension::Dev::Foo::Bar nor Extension::Dev::Foo nor 
 # exists
  
# ucfirst shift @args; # eg. extension => Extension 
 my $argsSeparator = $#cli_args;
 my $classToTry;
 my $remainingParameters;
 
 while ($argsSeparator--) {
  $classToTry = join("::", map {ucfirst} @cli_args[0..$argsSeparator]);
  $remainingParameters = join(" ", @cli_args[$argsSeparator+1..$#cli_args]);
  
  print "Trying $classToTry '$remainingParameters'\n";
  if (classExists($classToTry)) {
   last;
  }
  $classToTry = undef;
  last if ($argsSeparator < 1);
 }
 return ($classToTry, $remainingParameters);
}

sub classExists {
  my ($class) = @_;
  my $fqClass = $prefix."::".$class;
  print "\tTesting $fqClass\n";
  eval { require $fqClass; };
  if ($@) {
   print $@;
   return 0;
  } {
   return 1;
  }
}

sub noSuchMethod {
    my ($err) = @_;
    return "no such method - $err\n";

}

sub helpText {
   return "Help text goes here\n";

}

sub dispatch2 {
    my ($class,$do,@args) = @_;

    my $dispatchSubName = $class."::".'cli_'.$do;
    print "dispatching to $dispatchSubName\n";
    my $ans;
    if (defined &$dispatchSubName) {
	no strict 'refs';
	eval {
	    $ans = &$dispatchSubName(@args);
	};
	if ($@){
	    return $@;
	} else {
	    return $ans;
	}
    } else {
	print "No such $dispatchSubName\n";
	return helpText();
    }
}
1;
