#! perl -w
use strict;
no strict 'refs';

#use TWiki::Contrib::BuildContrib::TWikiCLI::Extension::Dev;
package TWiki::Contrib::BuildContrib::TWikiShell;
use base qw(Term::Shell);    # or manually edit @MyShell::ISA.

sub run_hello {
 my ( $o, $cmd, @args ) = @_;
 print "HELLO, WORLD";
}

#sub run_ {
#
#}

sub run_q {
 my $self = shift;
 $self->run_exit();

}

sub new {
 my $self = shift;
 my $new  = $self->SUPER::new(@_);

 $self->{subcommand} = "/";

 # $self->find_handlers();
 return $new;
}

=pod

use TWiki::Contrib::BuildContrib::TWikiCLI::Extension::Dev will create a set of delegate TWikiShell 
objects each with one method for each class needed to get lower down in the hierarchy.

The last object created is a real TWikiShell for the $class. The others are simply proxies for the
hierarchy. The intent is that you should be able to do:

use TWiki::Contrib::BuildContrib::TWikiCLI::Extension::Dev

then:
  twiki contrib buildcontrib twikicli extension dev
  
=cut

sub run_use {
 my $self = shift;
 my ( $class, @args ) = @_;
 print "$self $class " . join( " ", @args );
 my $err = $self->requireClass($class);

 print
   "Need to add a sequence of handlers for each directory of package $class\n";

 my @hierarchy = split /::/, $class;

 my $lastObject = $self;
 foreach my $step (@hierarchy) {
  print "Doing $step\n";
  $step = lc $step;
  my $delegate;

  unless ( $delegate = $lastObject->handler( $step, "run" ) ) {
#   print $lastObject->print() . " has no handler for $step\n";
   $delegate = TWiki::Contrib::BuildContrib::TWikiShell->new();
   $delegate->{subcommand} = $step;
#   print "==> " . $delegate->print;
    print "Created delegate for $step\n";
  } else {
#   print "Delegate : $delegate\n";
  }
  
  $delegate->{subcommand} = $step;
  $lastObject->add_coderef_handler( $step, $delegate );

  print "$step is handled by $delegate\n";

  $lastObject = $delegate;
 }

 if ($err) {
  return 0;
 } else {
  return 1;
 }
}

sub requireClass {
 my $self  = shift;
 my $class = shift;
 eval "require $class;";
 print "Require returned '$@'\n";
 return $@;
}

sub run_import {
 my $self = shift;
 my ( $class, @args ) = @_;
 print "$self $class " . join( " ", @args );

 my $err = $self->requireClass($class);

 #  if ($err) {
 #   print $err
 #   return;
 #  }
 $self->find_handlers($class);
 if ($err) {
  return 0;
 } else {
  return 1;
 }

}

sub run_dump {
 my $self = shift;
 use Data::Dump;

 print Data::Dump::dump($self) . "\n";
}

sub run_inc {
 my $self = shift;
 use Data::Dump;

 print Data::Dump::dump( \%INC ) . "\n";
}

# overrides Term::Shell

sub find_handlers {
 my $o        = shift;
 my $pkg      = shift || $o->{API}{class};
 my $override = shift || 'yes';

 # Find the handlers in the given namespace:
 # print "Handlers for $pkg (override = $override)\n";
 my %handlers;
 {
  no strict 'refs';
  my @r = keys %{ $pkg . "::" };
  $o->add_handlers( $pkg, $override, @r );
 }

 # print "Now doing BASE CLASSES\n";
 # Find handlers in its base classes.
 {
  no strict 'refs';
  my @isa = @{ $pkg . "::ISA" };
  for my $pkg (@isa) {
   $o->find_handlers( $pkg, 'no' );
  }
 }
}

sub add_coderef_handler {
 my $o       = shift;
 my $cmd     = shift;
 my $coderef = shift;

# print "\tFor o=$o, adding cmd=$cmd coderef=$coderef\n";
 $o->{handlers}{$cmd}{run} = $coderef;
}

# WARNING: Method signature changed from Term::Shell.
sub add_handlers {
 my $o            = shift;
 my $pkg          = shift;
 my $overrideFlag = shift;

 # print "o=$o pkg=$pkg override=$overrideFlag ".join(",",@_);
 for my $hnd (@_) {
  unless ( $hnd =~ /^(cli|run|help|smry|comp|catch|alias)_/o ) {

   #   print "Skipping $hnd\n";
   next;
  }

  #  print "Adding $hnd\n";
  my $t = $1;
  my $a = substr( $hnd, length($t) + 1 );

  # Add on the prefix and suffix if the command is defined
  #  print "$t $a\n";
  if ( length $a ) {
   substr( $a, 0, 0 ) = $o->cmd_prefix;
   $a .= $o->cmd_suffix;
  }
  if ( $o ne $pkg ) {
   $hnd = $pkg . "::" . $hnd;
  }

  my $existingHandler = $o->{handlers}{$a}{$t};

  $o->{handlers}{$a}{$t} =
    $o->overrideIfAppropriate( $overrideFlag, $existingHandler, $hnd );

  # if you can override, just do it. Otherwise warn if necessary

  # TODO check the aliases code below for effect of override

  if ( $o->has_aliases($a) ) {
   my @a = $o->get_aliases($a);
   for my $alias (@a) {
    substr( $alias, 0, 0 ) = $o->cmd_prefix;
    $alias .= $o->cmd_suffix;
    $o->{handlers}{$alias}{$t} = $hnd;
   }
  }
 }
}

=pod
The override flag is 'yes' or 'no'

The simple case is when there is no existing handler... this means
always take the proposedHandler as the newHandler.

If there is an existingHandler, then override determines whether or not 
to take it. 
  If 'no' then don't take it, leave as was
  
  If 'yes' then take it, but if there had been a different existing handler then warn the user.
  
  TODO: think about whether it should be 'yes' 'no' 'warn'

=cut

sub overrideIfAppropriate {
 my $self            = shift;
 my $override        = shift;
 my $existingHandler = shift;
 my $proposedHandler = shift;
 my $newHandler;

#  print "Override $existingHandler with $proposedHandler?\n\twhen override = $override?\n";

 if ( !defined $existingHandler ) {
  $newHandler = $proposedHandler;
 } else {
  if ( $override eq 'no' ) {
   $newHandler = $existingHandler;
  } elsif ( $override eq 'yes' ) {
   unless ( $proposedHandler eq $existingHandler ) {
    print "Warning: replacing $existingHandler with $proposedHandler\n";
   }
   $newHandler = $proposedHandler;
  }
 }

 #  print "\tResult = $newHandler\n";
 return $newHandler;
}

sub handler {
 my $o = shift;
 my ( $command, $type, $args, $preserve_args ) = @_;
 my $coderef = $o->SUPER::handler(@_);

# print join( " ", @$args ) . " ($command, $type, $args)\n";
 return $coderef;
}

#=============================================================================
# Term::Shell private methods
#=============================================================================
sub do_action {
 my $o       = shift;
 my $cmd     = shift;
 my $args    = shift || [];
 my $type    = shift || 'run';
 my $handler = $o->handler( $cmd, $type, $args );
 $o->{command}{$type} = {
  name    => $cmd,
  found   => defined $handler ? 1 : 0,
  handler => $handler,
 };
 if ( defined $handler ) {

  # We've found a handler. Set up a value which will call the postcmd()
  # action as the subroutine leaves. Then call the precmd(), then return
  # the result of running the handler.
  $o->precmd( \$handler, \$cmd, $args );
  my $postcmd = Term::Shell::OnScopeLeave->new(
   sub {
    $o->postcmd( \$handler, \$cmd, $args );
   }
  );

  # has its own context.
  print "HANDLER: $handler\n";
  if ( ref $handler ) {
   if ( UNIVERSAL::isa( $handler, "TWiki::Contrib::BuildContrib::TWikiShell" ) )
   {
    print "Handler is a shell object...\n";
    return $handler->do_action(@$args);
   }
  }
  return $o->$handler(@$args);
 }
}

sub prompt_str {
 my $self = shift;
 my $cmd = $self->{subcommand} || "";
 return "TWiki ". $cmd." >";
}

sub run_help {
    my $self = shift;
    $self->SUPER::run_help(@_);
    
}

sub catch_smry {
 my ( $self, $command ) = @_;

 my $result = eval {
  require Pod::Constants;

  my @summary;
  my $module = ( ref $self ) . ".pm";
  $module =~ s!::!/!g;
  $module = $INC{$module};

  Pod::Constants::import_from_file( $module, $command => \@summary );

  $summary[0];
 };
 if ($@) {
  return undef;
 }
 return $result;
}

sub catch_help {
 my ( $self, $command ) = @_;

 my @result = eval {
  require Pod::Constants;

  my @summary;
  my $module = ( ref $self ) . ".pm";
  $module =~ s!::!/!g;
  $module = $INC{$module};

  Pod::Constants::import_from_file( $module, $command => \@summary );

  @summary;
 };
 if ($@) {
  $self = ref $self;
  warn "Pod::Constants not available. Use perldoc $self for help.";
  return undef;
 }
 my $ans = join( "\n", @result );
 if ( length $ans == 0 ) {
  $ans = "No help available\n";
 }
 return $ans;
}

sub print {
 my $self = shift;
 return $self . " (for "
   . $self->{subcommand} . ") "
   . join( " ", sort ( keys %{ $self->{handlers} } ) ) . "\n";
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

=pod
   # sub {
     #my $delegateSelf = shift ; 
    # print "Delegate : $delegate\n";
#     print $delegate->print()."  delegate call:\n";
#     print $delegateSelf->run_dump();
#     $delegateSelf->do_action($step);
#     my $hnd = $delegateSelf->{handlers}{$step}{run}; 
#     print "for $step, found $hnd\n"; 
#     eval {print $delegateSelf->$hnd};
#     if ($@) {
#      print STDERR $@;
#     }
   #}
   #);
#   $lastObject->add_coderef_handler($step, $sub);
=cut

