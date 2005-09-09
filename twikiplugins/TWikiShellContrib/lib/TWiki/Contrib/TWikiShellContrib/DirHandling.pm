package TWiki::Contrib::TWikiShellContrib::DirHandling;

use Exporter;

@ISA=(Exporter);
@EXPORT=qw(makepath dirEntries cd);


sub makepath {
    my ($to) = @_;
    chop($to) if ($to =~ /\n$/o);
    $to =~ m!(.*?)\/(.*)$!;
    _buildpath($1,$2);
    
}

sub _buildpath {
    my ($parent,$to) =@_;
    return if (!$to); 
    chop($to) if ($to =~ /\n$/o);
    _create($parent) if $parent;
    
    if ($to =~ m!(.*?)\/(.*)$!) {
        _buildpath("$parent/$1",$2);
    }
}    

sub _create {
    my $dir=shift;
    mkdir "$dir" || warn "Warning: Failed to make $dir: $!" unless (-e "$dir" || -d "$dir");;
}

=pod

---++++ cd($dir)
  Change to the given directory

=cut

sub cd {
    my ($file) = @_;
    print "Changing to $file\n";
    chdir($file) || die 'Failed to cd to '.$file;
}


sub dirEntries {
    my $dir=shift;
    opendir DIR,$dir;
    my @entries = readdir DIR;
    close DIR;
    return @entries;
}

1;