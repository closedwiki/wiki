#!/usr/bin/perl -w

use strict;
no strict 'refs';
use diagnostics;


my $arg = join(" ",@ARGV) || "";

use Cwd;
my $cwd = cwd();
$cwd =~ s/^C://g; # Code_Smell
my $eclipseDevDir = "/DOCUME~1/MARTIN~1/MYDOCU~1/DEVELO~1";

my $script = $cwd."/twikicli.pl";
$ENV{TWIKI_LIBS} = $eclipseDevDir."/BuildC~1/lib:$eclipseDevDir/DistributionContrib/lib";


require $script;

#die "failed to call twikicli.pl - $!";
