#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::BuildContrib::TWikiCLI;
my $prefix = "TWiki::Contrib::BuildContrib::TWikiCLI";

use Getopt::Long; # see http://www.aplawrence.com/Unix/perlgetopts.html
use TWiki::Contrib::BuildContrib::TWikiCLI::Extension;

sub dispatch {
 my $verboseFlag = 0;
 GetOptions( "verbose!" => \$verboseFlag );

 my @args =  @ARGV;

 my $class = ucfirst shift @args; # eg. extension => Extension 

 unless ($class) {
     return helpText();
 }
 my $fqClass = $prefix."::".$class;

 dispatch2($fqClass, @args);
 
 }

# print "Unprocessed by Getopt::Long\n" if $ARGV[0];
# foreach (@ARGV) {
#  print "$_\n";
# }


sub noSuchMethod {
    my ($err) = @_;
    return "no such method - $err\n";

}

sub helpText {
   return "Help text goes here\n";

}

sub dispatch2 {
    my ($class,$do,@args) = @_;

    my $dispatchSubName = $class."::".$do;
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
