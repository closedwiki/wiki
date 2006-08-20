sub check {
    # Get Cygwin perl's package version number
    my $pkg = `perl -v; 
    if ($?) { 
        return TWiki::Configure::Checker::WARN(<<HERE);
Cannot identify perl package version - cygcheck or grep not installed
HERE
    } else {
        $pkg = (split ' ', $pkg)[1];    # Package version
        return $pkg;
    }
}

1;
