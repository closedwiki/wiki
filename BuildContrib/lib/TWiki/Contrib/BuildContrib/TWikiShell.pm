#! perl -w
use strict;
 no strict 'refs';


package TWiki::Contrib::BuildContrib::TWikiShell;
use base qw(Term::Shell);    # or manually edit @MyShell::ISA.

sub run_hello {
 my ( $o, $cmd, @args ) = @_;
 print "$o $cmd ".join(" ", @args);
}

sub run_ {

}

sub run_q {
  my $self = shift;
  $self->run_exit();

}

sub new {
  my $self = shift;
  my $new = $self->SUPER::new(@_);
#use TWiki::Contrib::BuildContrib::TWikiCLI::Extension::Dev;

# $self->find_handlers();
  return $new;
}

sub run_import {
  my $self = shift;
  my ( $class, @args ) = @_;
  print "$self $class ".join(" ", @args);
#  my $class = shift @args;
   
 eval " require $class;";
 $self->find_handlers($class); ;
 if ($@) {
   return 0;
 }
 {
  return 1;
 }   
   
#  die "missing param" unless $class;
  $self->find_handlers($class);

}

sub run_dump {
 my $self = shift;
 use Data::Dump;
   
 print Data::Dump::dump($self);
}

# overrides Term::Shell

sub find_handlers {
    my $o = shift;
    my $pkg = shift || $o->{API}{class};

    # Find the handlers in the given namespace:
    my %handlers;
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


sub add_handlers {
    my $o = shift;
    my $pkg = shift;
    
    for my $hnd (@_) {

	next unless $hnd =~ /^(cli|run|help|smry|comp|catch|alias)_/o;
	my $t = $1;
	my $a = substr($hnd, length($t) + 1);
	# Add on the prefix and suffix if the command is defined
	print "$t $a\n";
	if (length $a) {
	    substr($a, 0, 0) = $o->cmd_prefix;
	    $a .= $o->cmd_suffix;
	}
	if ($o ne $pkg) {
	 $hnd = $pkg."::".$hnd;
	}
	
	$o->{handlers}{$a}{$t} = $hnd;
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

sub handler {
    my $o = shift;
    my ($command, $type, $args, $preserve_args) = @_;
    my $coderef = $o->SUPER::handler(@_);
    print join(" ",@$args)." ($command, $type, $args)\n";
    return $coderef;
}

package MyTest;

sub run_mytest {
   print "Tested!\n";
}

package MyTest2;

sub run_mytest {
   print "Conflict?\n";
}

1;

