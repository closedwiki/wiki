
package TWiki::Contrib::TWikiShellContrib::TWikiShell;

use TWiki::Contrib::TWikiShellContrib::Standard;
use Data::Dumper;

my $prefix = "TWiki::Contrib::TWikiShellContrib::Ext";
my $standardModule= "TWiki::Contrib::TWikiShellContrib::Standard";
#use diagnostics;
use Cwd;
use strict;
 no strict 'refs';

use base qw(Term::Shell);
use vars qw {$config};

sub run_ { } #Do nothing on empty lines

sub alias_exit {  return qw{q quit}; }

sub new {
  my $self=shift;
  $config = shift;
  my $new = $self->SUPER::new(@_);

  $new->find_handlers($standardModule);
  #TODO: Scan directory for installed extentions
  return $new;
}

sub prompt_str() { return "\ntwiki> "}; 

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
	[$command, $type, 0],
	[$o->cmd_prefix . $type . $o->cmd_suffix, 'catch', 1],
    );

    my $concat="";
    foreach my $arg (@$args) {
        $concat.=" ".$arg;
        unshift @tries, [$command.$concat ,$type,0];
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

sub find_handlers {
    my $o = shift;
    my $pkg = shift || $o->{API}{class};
    
    # Find the handlers in the given namespace:
    {
	    no strict 'refs';
	    my @r = keys %{ $pkg . "::" };
	    $o->add_handlers($pkg, @r );
   }

    # Find handlers in its base classes.
    {
	    no strict 'refs';
	    my @isa = @{ $pkg . "::ISA" };
	    for my $pkg (@isa) {
	        $o->find_handlers($pkg);
	    }
    }
}

#-----------------------------------------------------------------------------

sub add_handlers {
    my $o = shift;
    my $pkg = shift;

    for my $hnd (@_) {
    	next unless $hnd =~ /^(cli|run|help|smry|comp|catch|alias)_/o;
    	my $t = $1;
    	    
    	my $a = substr($hnd, length($t) + 1);
    	#print "t= $t   a=$a \n";
    	# Add on the prefix and suffix if the command is defined
    	if (length $a) {
    	    substr($a, 0, 0) = $o->cmd_prefix;
    	    $a .= $o->cmd_suffix;
    	}
#    	print "1) hnd= $hnd\n";
    	if ($o ne $pkg) {
    	 $hnd = $pkg."::".$hnd;
    	}
#    	print "2) hnd= $hnd\n";
    	my $c="";
##### (RAF)    	
    	if ($pkg =~ /$prefix\:\:(.*)/) {
    	    my @childpkgs=split("::",$1);
    	    foreach my $childpkg (@childpkgs) {
    	        #print "Prefixed ".lc $1."\n";
    	        $c.=lc $childpkg." ";
            }
        }


        if ($c) {
            $a=$c.$a;
            chop $c;
            $o->{handlers}{$c}{run} = $pkg."::run";
            $o->{handlers}{$c}{help} = $pkg."::help";
            $o->{handlers}{$c}{smry} = $pkg."::smry";
        }
##### (RAF)        
    	$o->{handlers}{$a}{$t} = $hnd;
#    	print $o->{handlers}{$a}{$t} ."\n";
    	
    	if ($o->has_aliases($a)) {
    	    my @a = $o->get_aliases($a);
    	    for my $alias (@a) {
        		substr($alias, 0, 0) = $o->cmd_prefix;
        		$alias .= $o->cmd_suffix;
        		$o->{handlers}{$alias}{$t} = $hnd;
    	    }
    	}
    }
}

#-----------------------------------------------------------------------------


##############################
# Import an external module
##############################

sub run_import {
    my $self = shift;
    my ( $config, $class, @args ) = @_;
    unless ($class =~ /TWiki::/) {
      $class=$prefix."::".ucfirst $class;
    }
    print "Importing $class\n";

    eval " require $class;";
    if ($@) {
      print "Import failed: $! $? $@\n";
      # should unset %INC{$class} so that it can reload
    }
    $self->find_handlers($class); ;
    if ($@) {
        return 0;
    }else {
        return 1;
    }
   
#  die "missing param" unless $class;
  $self->find_handlers($class);
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

    if ($$handler =~ /$prefix/) {
        shift @$args;
    }
    
    if ($$handler =~/(.*)_.*\s+/) {
        $$handler =~ s/$$cmd//;
        $$handler =~ s/\s+//;
        
        my ( $class, @remainingArgs ) = findTargetClassForString($$cmd,@$args);
        @$args=@remainingArgs;
        print "Class: $class\n";
        print "prefix: $prefix\n";
        print "handler: $handler\n";
        
        $$handler=$prefix."::".$class."::".$$handler;
        #print "Handler: ". $$handler . "\n";
    }
    
    unshift @$args,$config;
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

 my ( $class, @remainingArgs ) = findTargetClassForString(@args);

 unless ($class) {
    print "Couldn't resolve your request\n";
    return;
 }
 
 $self->run_import($class,@remainingArgs);
 $self->cmd(join(" ",@remainingArgs));

}

#-----------------------------------------------------------------------------

sub findTargetClassForString {
 my ($config,@cli_args) = @_;

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

