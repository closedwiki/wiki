package TWiki::Contrib::TWikiShellContrib::DirHandling;

use Exporter;

@ISA=(Exporter);
@EXPORT=qw(makepath);


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
    _create($parent);
    
    if ($to =~ m!(.*?)\/(.*)$!) {
        _buildpath("$parent/$1",$2);
    }
}    

sub _create {
    my $dir=shift;
    mkdir "$dir" || warn "Warning: Failed to make $to: $!" unless (-e "$dir" || -d "$dir");;
}



1;