package TWiki::Contrib::TWikiShellContrib::Standard;

use FileHandle;
##############################
# set verbosity
##############################
sub run_verbose {
    my ($shell,$config,$level) = @_;

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
    my ($shell,$config) = @_;

    $config->{verbosity}=0;
    print "verbosity : $config->{verbosity}\n";
    
}

sub smry_quiet { return "Set the verbosity level to 0";}
sub help_quiet { return smry_quiet()."\n";}

sub run_use {
    my ($shell,$config,$mode) = @_;
    $config->mode($mode);
    print "Mode set to: ".$config->mode."\n";
}

sub smry_use {
	return "experimetal feature - don't use!";
}

sub print_debug_level {
    my $debug = shift;
    print "Debug ";
    if ($debug) {
        print "On";
    } else {
        print "Off";
    }
    print "\n";
}

sub run_debug {
    my ($shell,$config,$mode)=@_;
    
    if ($mode) {
        if (uc $mode eq "ON") {
            $config->{debug}=1;
        } else {
            $config->{debug}=0;
        }
    }  
    print_debug_level($config->{debug});
    
}
sub smry_debug {
    return "set debugging On and Off. Usage: debug [on/off]";
}

sub help_debug {
    return smry_debug."\n";
}
#sub undefined_run {
#    print "Undefined action\n";
#}
#    
#sub undefined_smry {
#    return "undocumented - no help available";
#}
#
#sub undefined_help {
#    return "No help available\n";
#}

#####################################################################
# TODO: Reload should remove those handlers that are removed from the module to be reloaded.
# TODO: Reload should call the onImport hook

package TWiki::Contrib::TWikiShellContrib::Ext::Reload;
use FileHandle;

sub _reloadClass { 
    my ($shell,$config,$class) = @_;
    
    if (!exists $shell->{packages}{$class}) {
        $config->printNotQuiet("Class $class not loaded. Please, use import instead\n");                        
    } else {
        my $file=$class;
        $file=~ s!\:\:!\/!g;
        $config->printNotQuiet("Reloading $class .......");
        _reload($config,$file.".pm"); 
        {
            no warnings;
            $shell->remove_handlers($class);
            $shell->find_handlers($class);
         }   
    }
}

  
sub _reload {
    my ($config,$class) = @_;
    
    my $fh = FileHandle->new($INC{$class});
    if (!$fh) {
        print "$class not found\n";
        return;
    }
	local($/);
	{
	    no warnings;
	    eval <$fh>;
	    warn $@ if $@;
	    $config->printNotQuiet("Done.\n");
    }
    
}
sub run_shell {
    my ($shell,$config) = @_;
    $config->printNotQuiet("Reloading Shell .......");
    _reload($config,'TWiki/Contrib/TWikiShellContrib/TWikiShell.pm');
}

sub smry_shell { return "Reloads the shell (don't clear the handler list)";}  
sub help_shell { return smry_shell()."\n"; }

sub smry { return "Reloads the specified command set";}  
sub help { return smry()."\n"; }


sub run {
    my ($shell,$config,@args) = @_;
    if (!@args) {
        return;
    }
    my $cmd=join(" ",@args);
    
    my $handler=$shell->{handlers}{"$cmd"}{run};
    
    if ($handler && $handler=~/(.*)\:\:[^\:]+/) {
        _reloadClass($shell,$config,"$1");
    } else {
        my ( $class, @remainingArgs ) = $shell->findTargetClassForString($config,@args);  
        if ($class) {  
            $class=$TWiki::Contrib::TWikiShellContrib::TWikiShell::prefix."::".$class;
            _reloadClass($shell,$config,$class);
        } else {
            $config->printNotQuiet("Cannot find the associated module to command $cmd\n");
        }
    }
}   

    
1;
    
