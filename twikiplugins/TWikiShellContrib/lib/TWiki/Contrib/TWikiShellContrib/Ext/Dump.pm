package TWiki::Contrib::TWikiShellContrib::Ext::Dump;

use Data::Dumper;

sub run_config {
    my $shell=shift;
    my $config=shift;
    print Data::Dumper->Dump([$config],[qw(config)]);
}

sub smry_config { return "Dumps the config"; }
sub help_config { return smry_config()."\n"; }

sub run_handlers {
    my $shell=shift;
    print Dumper($shell->{handlers});
}

sub smry_handlers { return "Dumps the registered handlers"; }
sub help_handlers{ return smry_handlers()."\n"; }

sub smry { return "Dumps various debug informations"; }
sub help { return "Dumps various debug informations:\n dump config  ".help_config()." dump handlers  ".help_handlers()};
sub run { print help(); }    
1;
    
