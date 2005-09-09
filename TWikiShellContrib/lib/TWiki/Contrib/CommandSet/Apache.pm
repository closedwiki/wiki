package TWiki::Contrib::CommandSet::Apache;

use TWiki::Contrib::CommandSet::Apache::Httpd;
use TWiki::Contrib::CommandSet::Apache::Conf;

sub run_delete {
    #my ($shell,$config,$name, $base)=@_;
    deleteInstallFromApacheConfig(@_);
}

sub run_add {
    addInstallToApacheConfig(@_);
}

sub help_delete {
    return 'Not implemented';
}

sub help_add {
    return 'Not implemented';
}


sub smry_delete {
    return 'Not implemented';
}

sub smry_add {
    return 'Not implemented';
}


sub onImport {
    configure(@_);
}

1;
