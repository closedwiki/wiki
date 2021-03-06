# $Id: if.pm 476 2005-06-06 16:05:49Z nodine $

# This package implements the perl directive for the perl implementation
# of reStructuredText.

=pod
=begin reST
=begin Description
Executes its argument as a perl expression and returns its
content if the perl expression is true.  The content is
interpreted as reStructuredText.  It has no options. It processes
the following defines:

-D perl='perl-code'
                Specifies some perl code that is executed prior
                to evaluating the first perl directive.  This
                option can be used to specify variables on the
                command line; for example::

                  -D perl='$a=1; $b=2'

                defines constants ``$a`` and ``$b`` that can
                be used in the perl expression.
-D trusted      Must be specified for if directives to use any
                operators normally masked out in a Safe environment.
                This requirement is to prevent an if directive in a
                file written elsewhere from doing destructive things
                on your computer.
=end Description
=end reST
=cut

package RST::Directive::if;

BEGIN {
    RST::Directive::handle_directive('if', \&RST::Directive::if::main);
}

# Plug-in handler for if directives.
# Arguments: directive name, parent, source, line number, directive text, 
#            literal text
# Returns: array of DOM objects
sub main {
    my($name, $parent, $source, $lineno, $dtext, $lit) = @_;
    my $dhash = RST::Directive::parse_directive($dtext, $lit, $source, $lineno);
    my($args, $options, $content) =
	map(defined $dhash->{$_} ? $dhash->{$_} : '',
	    qw(args options content));
    return RST::Directive::system_message($name, 3, $source, $lineno,
					  qq(The $name directive must have an argument.),
					  $lit)
	if $args =~ /^$/;
    return RST::Directive::system_message($name, 3, $source, $lineno,
					  qq(The $name directive must have content.),
					  $lit)
	if $content =~ /^$/;
    return RST::Directive::system_message($name, 3, $source, $lineno,
					  qq(The $name directive has no options.),
					  $lit)
	if $options !~ /^$/;
    if (! $Perl::safe) {
	# Create a safe compartment for the Perl to run
	use Safe;
	$Perl::safe = new Safe "Perl::Safe";
	# Grant privileges to the safe if -D trusted specified
	$Perl::safe->mask(Safe::empty_opset()) if $main::opt_D{trusted};
	# Copy in VERSION
	$Perl::Safe::VERSION = $main::VERSION;
	# Share opt_ variables, %ENV, STDIN, STDOUT, STDERR
	my @opts = grep(/opt_/, keys %main::);
	foreach (@opts) {
	    local *opt = $main::{$_};
	    *{"Perl::Safe::$_"} = *opt;
	}
	# Share RST and DOM subroutines
	foreach (keys %RST::) {
	    local *opt = $RST::{$_};
	    no strict 'refs';
	    *{"Perl::Safe::RST::$_"} = \&{"RST::$_"} if defined &{"RST::$_"};
	}
	foreach (keys %DOM::) {
	    local *opt = $DOM::{$_};
	    no strict 'refs';
	    *{"Perl::Safe::DOM::$_"} = \&{"DOM::$_"} if defined &{"DOM::$_"};
	}
	*Perl::Safe::ENV = \%ENV;
	*Perl::Safe::STDIN = *STDIN;
	*Perl::Safe::STDOUT = *STDOUT;
	*Perl::Safe::STDERR = *STDERR;
    }
    $Perl::Safe::TOP_FILE = $main::TOP_FILE;

    if (defined $main::opt_D{perl}) {
	my $exp = $main::opt_D{perl};
	$Perl::safe->reval($exp);
	delete $main::opt_D{perl};
	my $err = $@ =~ /trapped by/ ? "$@Run with -D trusted if you believe the code is safe" : $@;
	return RST::system_message(4, $source, $lineno,
				   qq(Error executing "-D perl" option: $err.),
				   $exp)
	    if $@;
    }

    my $val = $Perl::safe->reval("$args");
    my $err = $@ =~ /trapped by/ ? "$@Run with -D trusted if you believe the code is safe" : $@;
    return RST::system_message(4, $source, $lineno,
			       qq(Error executing "$name" directive: $err.),
			       $lit)
	if $@;
    return unless $val;
    my $newsource = qq($name directive at $source, line $lineno);
    if ($parent->{tag} eq 'substitution_definition') {
	my @doms;
	my $fake = new DOM('fake');
	RST::Paragraphs($fake, $content, $newsource, 1);
	my $last = $fake->last();
	if (@{$fake->{content}} == 1 &&
	    $last->{tag} eq 'paragraph') {
	    my $lastidx = $#{$last->{content}};
	    chomp $last->{content}[$lastidx]{text};
	    return @{$last->{content}};
	}
	push(@doms, grep($_->{tag} eq 'system_message' && do {
	    delete $_->{attr}{backrefs}; 1}, @{$fake->{content}}));
	push @doms, RST::system_message(3, $source, $lineno,
					qq(Error in "$name" directive within substitution definition: may contain a single paragraph only.));
	return @doms;
    }
    else {
	&RST::Paragraphs($parent, "$content\n", $newsource, 1);
    }

    return;
}

1;
