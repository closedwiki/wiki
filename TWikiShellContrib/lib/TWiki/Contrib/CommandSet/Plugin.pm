package TWiki::Contrib::CommandSet::Plugin;

sub smry { return "Plugin Management"; }
sub help { return ""};
sub run { print help(); }    

sub onImport {
    my ($shell) = @_;
    $shell->importCommand($shell->{config},"Plugin::Develop");
    $shell->importCommand($shell->{config},"Plugin::PutBack");
    $shell->importCommand($shell->{config},"Plugin::Create");

}

1;
    
