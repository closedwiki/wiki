package TWiki::Contrib::CommandSet::TWiki;

use TWiki::Contrib::CommandSet::TWiki::Conf;


sub help {
   my $shell=shift;
   my $config=shift;
    return "TWiki Related Commands\n";
}

sub smry {
    return " Display this help";
}


sub onImport {
    my ($shell) = @_;
    configure(@_);
}

1;
