package TWiki::Contrib::TWikiShellContrib::Standard;


##############################
# set verbosity
##############################
sub run_verbose {
    my ($self,$config,$level) = @_;

    if (!$level) {
        print "verbosity : $config->{verbosity}\n";
        return;
    }

    if ($level>=1 && $level<=2) {
        $config->{verbosity}=$level;
        print "verbosity : $config->{verbosity}\n";
    } else {
        print "Unknown verbosity level $level\n";
    }
}

sub smry_verbose { return "Sets the verbosity level (1,2)"; }
sub help_verbose { return "Sets the verbosity level
 Level    Effect
   1      Minimun information about the run is displayed (Default)
   2      All information about the run is displayed
   
If called without arguments, show the current verbosity level.   
\n"; }


sub run_quiet {
    my ($self,$config) = @_;

    $config->{verbosity}=0;
    print "verbosity : $config->{verbosity}\n";
    
}

sub smry_quiet { return "Set the verbosity level to 0";}
sub help_quiet { return smry_quiet()."\n";}

sub undefined_run {
    print "Undefined action\n";
}
    
sub undefined_smry {
    return "undocumented - no help available";
}

sub undefined_help {
    return "No help available\n";
}

    
1;
    
