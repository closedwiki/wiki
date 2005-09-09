package TWiki::Contrib::CommandSet::Plugin;

use Data::Dumper;

sub smry { return "Plugin Management"; }
sub help { return ""};
sub run { print help(); }    

sub onImport {
    my ($shell) = @_;
    $shell->importCommand($shell->{config},"Plugin::Develop");
    $shell->importCommand($shell->{config},"Plugin::PutBack");

}

1;
    
