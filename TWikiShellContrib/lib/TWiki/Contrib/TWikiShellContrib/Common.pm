package TWiki::Contrib::TWikiShellContrib::Common;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(extractPackageFromSub askUser checkIfDir sys_action);

sub extractPackageFromSub {
    my $sub=shift;
    if ($sub=~/(.*)\:\:[^\:]+/) {
        return $1;
    } else {
        return "";
    }
}

sub askUser {
    my ($value,$default,$prompt,$checkOk,$allwaysAsk)=@_;    
    
    if (!$checkOk) {
        $checkOk = sub {return 0};
    }
    
    if ( !$value ) {    
        $value=$default;

        if ($allwaysAsk || !&$checkOk($value)) {
            do {
                print " $prompt [$default]: ---> "; 
                chomp ($value = <STDIN>);
            } until (&$checkOk($value) || $value eq '');

        }
    }    
    return ($value||$default);
}

sub checkIfDir {
   return (-d shift);
}

=pod 

---++++ sys_action($cmd)
Perform a "system" command.

=cut

sub sys_action {
   my ($cmd) = @_;
   print "Command: $cmd\n";
   system($cmd);
   die 'Failed to '.$cmd.': '.$? if ($?);
}


1;