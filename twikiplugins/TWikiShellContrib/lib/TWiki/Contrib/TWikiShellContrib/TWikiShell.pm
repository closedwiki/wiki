package TWiki::Contrib::TWikiShellContrib::TWikiShell;

use TWiki::Contrib::TWikiShellContrib::Standard;
use TWiki::Contrib::TWikiShellContrib::Common;
use TWiki::Contrib::TWikiShellContrib::Zip;
use Data::Dumper;

#use diagnostics;
use Cwd;
use strict;
 no strict 'refs';

use base qw(Term::Shell);
use vars qw {$config $prefix};

my @standardModules =qw (TWiki::Contrib::TWikiShellContrib::Standard

                  TWiki::Contrib::TWikiShellContrib::Ext::Reload    
);


$prefix= "TWiki::Contrib::TWikiShellContrib::Ext";
my $standardModule= "";

sub run_ { } #Do nothing on empty lines

sub alias_exit {  return qw{q quit}; }

sub new {
    my $self=shift;
    $config = shift;
    my $new = $self->SUPER::new(@_);

    $new->init_handlers($config);
    checkUnzipMechanism($config);
    $self->find_handlers("TWiki::Contrib::TWikiShellContrib::Zip");
    
    return $new;
}

sub init_handlers {
    my $self=shift;
	my $config=shift;

    foreach my $standardModule (@standardModules) {
        $self->find_handlers($standardModule);
    }
    
	my @registered=keys %{$config->{register}};
	foreach my $registeredExt (@registered) {
		$self->cmd("import $registeredExt") if ($config->{register}{"$registeredExt"});
	}
    
}

my $prompt="twiki";
sub prompt {
	my $self=shift;
	$prompt=shift;
}

#sub prompt_str() { return "\ntwiki> "}; 
sub prompt_str() { 
    if ($config->mode) {
        return "\n".$prompt."/".$config->mode." > "; 
    } else {
        return "\n$prompt > "; 
    }
}

####################### HANDLERS ##############################################
    
# Add support for multi-level commands
# Called to find the handler to call for a given command
sub handler {
    my $o = shift;
    my ($command, $type, $args, $preserve_args) = @_;

    # First try finding the standard handler, then fallback to the
    # catch_$type method. The columns represent "action", "type", and "push",
    # which control whether the name of the command should be pushed onto the
    # args.
    my @tries = (
	[$config->mode." ".$command, $type, 0],
	[$command, $type, 0],
	[$o->cmd_prefix . $type . $o->cmd_suffix, 'catch', 1],
    );

    my $concat="";
    foreach my $arg (@$args) {
        $concat.=" ".$arg;
        unshift @tries, [$command.$concat ,$type,0];
        unshift @tries, [$config->mode." ".$command.$concat ,$type,0];
    }

    # The user can control whether or not to search for "unique" matches,
    # which means calling $o->possible_actions(). We always look for exact
    # matches.
    my @matches = qw(exact_action);
    push @matches, qw(possible_actions) if $o->{API}{match_uniq};

    for my $try (@tries) {
    	my ($cmd, $type, $add_cmd_name) = @$try;
    	for my $match (@matches) {
    	    my @handlers = $o->$match($cmd, $type);
    	    next unless @handlers;
    	    unshift @$args, $command  if $add_cmd_name and not $preserve_args;
    	    my $handler=$o->unalias($handlers[0], $type);
    	    
    	    if (defined(&$handler)) {
                return $handler;
            } else {
                return $standardModule."::undefined_".$type;
            }
    	}
    }
    return undef;
}

#-----------------------------------------------------------------------------

sub run_handtest {
    my $self=shift;
    my %cmdHandlers = %{$self->{handlers}};
    
    foreach my $command (keys %cmdHandlers) {
        my %actions=%{$cmdHandlers{$command}};
        foreach my $action (keys %actions) {            
            my $handler=$actions{$action};
            print extractPackageFromSub($handler);
            print "\n-------------------------------------------------------------\n";    
        }
    }
}
sub remove_handlers {
    my $self = shift;
    my $pkg = shift || $self->{API}{class};
    
    my %cmdHandlers = %{$self->{handlers}};
    my @toRemove=();
    foreach my $command (keys %cmdHandlers) {
        my %actions=%{$cmdHandlers{$command}};
        foreach my $action (keys %actions) {            
            my $handler=$actions{$action};
            my $package=extractPackageFromSub($handler);
            if ($pkg eq $package) {
                unshift @toRemove,$command;
            }            
        }
    }
    
    foreach my $toRemove (@toRemove) {
        $self->{handlers}{$toRemove}=undef;
    }
}

#-----------------------------------------------------------------------------
sub find_handlers {
    my $o = shift;
    my $pkg = shift || $o->{API}{class};
    my $showHandlers = shift;
	my $count=0;
    # Find the handlers in the given namespace:
    {
	    no strict 'refs';
	    my @r = keys %{ $pkg . "::" };  
	    $count=$o->add_handlers($pkg, $showHandlers , @r);
   }

    # Find handlers in its base classes.
    {
	    no strict 'refs';
	    my @isa = @{ $pkg . "::ISA" };
	    for my $pkg (@isa) {
	        $count+=$o->find_handlers($pkg,$showHandlers);
	    }
    }
	return $count;
}

#-----------------------------------------------------------------------------

sub _getBaseCommandPrefix {
    my $pkg=shift;
    my $commandPrefix="";
	if ($pkg =~ /$prefix\:\:(.*)/) {
        $commandPrefix = join(" ",map { lc } split("::",$1)); #My first perlish one-liner :)
    }
    chomp $commandPrefix;
    return $commandPrefix;
}
sub add_handlers {
    my $o = shift;
    my $pkg = shift;
	my $showHandlers= shift;
	
	my $count=0;

    for my $hnd (@_) {
        my $commandPrefix=_getBaseCommandPrefix($pkg);
        
        if ( $hnd eq "run" || $hnd eq "help" || $hnd eq "smry") {
            if ($commandPrefix) {
                $o->{handlers}{$commandPrefix}{$hnd} = $pkg."::".$hnd;
				$count++;
				$config->printVeryVerbose("$commandPrefix $hnd added.\n") if $showHandlers;
            }
            next;
        }
    	next unless $hnd =~ /^(cli|run|help|smry|comp|catch|alias)_?(.*)/o;
    	my $t = $1;
    	    
    	my $a = $2 || "";
    	$a = $commandPrefix." ".$a if $commandPrefix;
    	
    	# Add on the prefix and suffix if the command is defined
    	if (length $a) {
    	    substr($a, 0, 0) = $o->cmd_prefix;
    	    $a .= $o->cmd_suffix;
    	}
    	if ($o ne $pkg) {
    	 $hnd = $pkg."::".$hnd;
    	}
    	$o->{handlers}{$a}{$t} = $hnd;				
		$count++;
		$config->printVeryVerbose("$a $t added.\n") if $showHandlers;

    	$o->{packages}{$pkg}=$pkg;
    	
    	if ($o->has_aliases($a)) {
    	    my @a = $o->get_aliases($a);
    	    for my $alias (@a) {
        		substr($alias, 0, 0) = $o->cmd_prefix;
        		$alias .= $o->cmd_suffix;
        		$o->{handlers}{$alias}{$t} = $hnd;
				$count++;
				$config->printVeryVerbose("$alias $t added.\n") if $showHandlers;
    	    }
    	}
    }
	return $count;
}

#-----------------------------------------------------------------------------


##############################
# Import an external module
##############################

# TODO: import Some::Command using "import some command "
sub run_import {
    my $self = shift;
    my ( $config, $cmd) = @_;
	
	my $class=$cmd;

    unless ($cmd =~ /TWiki::/) {
      $class=$prefix."::".ucfirst $cmd;
    }
    $config->printNotQuiet("Importing $class\n");
    {
        no warnings;
        local $SIG{__WARN__}=sub { $@.=$_[0];};
		eval "use $class;";
        if ($@) {
            if ($@ =~ /Can\'t locate/) {
            print "No extension for $cmd found\n";
            } else {
                $self->{packages}{$class}=$class;
                print $@."\nPlease, use the reload command after fixing the above error\n";
                return 0;
            }
        }else {
			my $commandCount=keys %{$self->{handlers}};
            my $handlersCount = $self->find_handlers($class,1); ;
			$commandCount = (keys %{$self->{handlers}})-$commandCount;
            $config->printVeryVerbose("$commandCount commands ($handlersCount handlers) imported\n");
            my $importHook=$class."::onImport";
            if (defined &$importHook) {
                &$importHook($self,$config);
            }
            return 1;
        }
    }
}

sub run_register {
    my $self = shift;
    my ( $config, $cmd) = @_;
	$self->run_import($config, $cmd);
	$config->{register}{$cmd}=1;
	$config->save();
	$config->printNotQuiet("$cmd registered\n");    
}

sub smry_register {
    return "Register an extension to be loaded at shell startup";
}

sub run_unregister {
    my $self = shift;
    my ( $config, $cmd) = @_;
    if (defined $config->{register}{$cmd}) {
	    $config->{register}{$cmd}=0 ;
	    $config->save();
	    $config->printNotQuiet("$cmd unregistered\n");    
    } else {
        $config->printNotQuiet("$cmd is not registered\n");    
    }
}

sub smry_unregister {
    return "Unregister an extension";
}

############################## HOOKS ############################## 

sub postloop {
    print "Done.\n";
}

sub precmd {
    my $self = shift;
    my ($handler, $cmd, $args) = @_;
    
    if (uc $$cmd eq 'HELP' || uc $$cmd eq 'EXIT') {
        return;
    }

    # All this mumbo-jumbo is to guarantee 
    # that the right args are passed down to the command
    # Because the way Term::Shell works, when handling 
    # multi-level commands (like "dump config"), the value 
    # of $cmd will be "dump" and the value of @$args 
    # will be ("config"), even if there is a handler 
    # for the "dump config" command.
    if ($$handler =~ /$prefix/) {
        my $tmp=$$handler;
        $tmp =~ s/$prefix//;
        if ($tmp =~ /(.*)\:\:[^\:]+/) {
            $tmp=lc $1;
            $tmp=~ s/\:\:/ /g; 
            my $arg="";
            do {
                $arg=shift @$args;
            } while($arg && $tmp=~ /$arg/);
            
            unshift @$args,$arg if ($arg && !($$handler =~ /_/));
        }
    }

    #I can't remember why this code is here... :S    
    if ($$handler =~/(.*)_.*\s+/) {
        $$handler =~ s/$$cmd//;
        $$handler =~ s/\s+//;
        
        my ( $class, @remainingArgs ) = $self->findTargetClassForString($$cmd,@$args);
        @$args=@remainingArgs;
        print "Class: $class\n";
        print "prefix: $prefix\n";
        print "handler: $handler\n";
        
        $$handler=$prefix."::".$class."::".$$handler;
        #print "Handler: ". $$handler . "\n";
    }
    
    unshift @$args,$config;
}

############################### PRINT STUFF ################################ 

sub printVeryVerbose{
    printVerbose(@_);
}
    
sub printNotQuiet {
    printTerse(@_);
}

sub printVerbose { #verbose == 1 && verbose !=0
    my ($self,$text)=@_;    
    print $text if ($config->{verbosity}>1);
}

sub printTerse {
    my ($self,$text)=@_;    
    print $text if ($config->{verbosity}>0);
}

sub printDebug {
    my ($self,$text)=@_;    
    print $text unless ($config->{debug} ==0);
}

############################### CATCHERS  ################################ 

sub catch_run() {
    my ($self,$command,@params)=@_;
    $self->dispatch($command,@params);
    #print "I don't know $command with params ".join(",",@params)."\n";
}

#-----------------------------------------------------------------------------

sub dispatch {
 my ($self,@args) = @_;

 my ( $class, @remainingArgs ) = $self->findTargetClassForString(@args);

 unless ($class) {
    print "Couldn't resolve your request\n";
    return;
 }
 
 $self->run_import($config,$class,@remainingArgs);
 $self->cmd(join(" ",@remainingArgs));

}

#-----------------------------------------------------------------------------

sub findTargetClassForString {
 my ($self,$config,@cli_args) = @_;

 # e.g. extension dev foo bar
 # we match extension dev, because Extension::Dev exists but
 # neither Extension::Dev::Foo::Bar nor Extension::Dev::Foo nor
 # exists

 # ucfirst shift @args; # eg. extension => Extension
 my $argsSeparator = $#cli_args;
 my $classToTry;
 my @remainingParameters;
 my $remainingParameters;
 while ($argsSeparator>=0) {
            
      $classToTry = join( "::", map { ucfirst } @cli_args[ 0 .. $argsSeparator ] );
      $argsSeparator--;
      @remainingParameters = @cli_args[ $argsSeparator + 1 .. $#cli_args ];
      $remainingParameters =join( " ", @remainingParameters );
    
      #print "Trying $prefix" . "::" . $classToTry . " '$remainingParameters'\n";
      if ( classExists($classToTry) ) {
       last;
      }
      $classToTry = undef;
 } ;
 
 return ( $classToTry, @remainingParameters );
}

#-----------------------------------------------------------------------------
sub classExists {
 my ($class) = @_;
 my $fqClass = $prefix . "::" . $class;
 eval " require $fqClass ";
 if ($@) {
  return 0;
 } else {
  return 1;
 }
}


1;

