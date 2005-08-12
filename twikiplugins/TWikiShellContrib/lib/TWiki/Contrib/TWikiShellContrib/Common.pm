package TWiki::Contrib::TWikiShellContrib::Common;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(extractPackageFromSub askUser);

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
1;