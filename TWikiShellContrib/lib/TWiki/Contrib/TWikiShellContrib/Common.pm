package TWiki::Contrib::TWikiShellContrib::Common;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(extractPackageFromSub);

sub extractPackageFromSub {
    my $sub=shift;
    if ($sub=~/(.*)\:\:[^\:]+/) {
        return $1;
    } else {
        return "";
    }
}

1;