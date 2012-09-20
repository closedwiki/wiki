use strict;
package TWiki::Plugins::IncludeXMLPlugin::XPathModifier;

=begin twiki

---+ TWiki::Plugins::IncludeXMLPlugin::XPathModifier

Parses a text as comma-separated XPath expressions leniently,
and prepends a prefix (either // or .//) to each expression if it does not starts with a slash (/).

During parsing, it also retrieves appropriate names that can be used as variable names.

For example, if the prefix is '//' and the input text is

    foo, bar, baz

then the result will be

    //foo, //bar, //baz

where the variable names 'foo', 'bar', and 'baz' are recognized.

If the prefix is './/' and the input text is

    /abc/def[@id="1"], ghi[jkl="mno"], (pqr | stu/vwx)

then the result will be

    /abc/def[@id="1"], .//ghi[jkl="mno"], (.//pqr | .//stu/vwx)

where the variable names 'def', 'ghi', and 'vwx' are recognized.
Each variable name is the last word outside of any brackets.

An explicit variable name can also be annotated to each expression.

For example, if the input text is

   $var1 := /abc/def, $var2 := ghi/jkl

the variable names 'var1' and 'var2' are recognized as explicit variable names.

=cut

=begin twiki

---++ StaticMethod new()

Creates a new object.

=cut

sub new {
    my ($class) = @_;
    
    bless {
        text     => '',
        tokens   => [],
        xpaths   => [],
        mxpaths  => [],
        exnames  => [], # explicity specified var names ($varname := ...)
        varnames => [], # extracted from xpath (last word in each xpath expr)
    }, $class;
}

our $SEP = quotemeta q!/|()[],!;
our $QUOT = quotemeta q!'"!; #'

=begin twiki

---++ ObjectMethod parse($text)

Parses $text as XPath expressions.

The return value is the object itself.
Then the C<addPrefix()> method should be called.

=cut

sub parse {
    my ($self, $text) = @_;
    $text = _trim($text);
    $self->{text} = $text;

    $self->{xpaths} = [];
    $self->{mxpaths} = [];
    $self->{exnames} = [];
    $self->{varnames} = [];

    my $len = length($text);
    my @tokens = ();

    # Scan the input text to split into tokens consisting of:
    # - characters / | ( ) [ ] ,
    # - quoted strings '...' or "..."
    # - and any other strings

    for (my $i = 0; $i < $len; $i++) {
        my $c = substr $text, $i, 1;

        if ($c =~ /[$SEP]/o) {
            my $j = $i;

            for ($i++; $i < $len; $i++) {
                last if substr($text, $i, 1) !~ /\s/;
            }

            push @tokens, substr($text, $j, $i - $j);
            $i--;
        } elsif ($c =~ /[$QUOT]/o) {
            my $j = $i;

            for ($i++; $i < $len; $i++) {
                my $d = substr($text, $i, 1);
                last if $d eq $c;
                $i++ if $d eq '\\';
            }

            push @tokens, substr($text, $j, $i - $j + 1);
        } else {
            my $j = $i;

            for ($i++; $i < $len; $i++) {
                last if substr($text, $i, 1) =~ /[$SEP$QUOT]/o;
            }

            push @tokens, substr($text, $j, $i - $j);
            $i--;
        }
    }

    $self->{tokens} = \@tokens;
    $self;
}

sub _trim {
    my ($input) = @_;
    $input =~ s/^\s+|\s+$//g;
    $input;
}

sub _getLastWord {
    my ($token) = @_;
    my $word = '';

    while ($token =~ /([A-Za-z_][A-Za-z0-9_]*)/g) {
        $word = $1;
    }

    return $word;
}

=begin twiki

---++ ObjectMethod addPrefixes($prefix)

Prepends $prefix to each expression.

The return value is the object itself.
Each getter method should be called to retrieve the result.

=cut

sub addPrefixes {
    my ($self, $prefix) = @_;
    $self->{prefix} = $prefix;

    # Divide the tokens into components seprated by commas (,)
    # Add a prefix (// or .//) to each component if it doesn't start with a '/'

    my $begin = 1;    # whether the current position is at the beginning of an
                      # xpath component.
    my $slash = 0;    # whether '/' has appeared at the current nesting level
    my $ready = 1;    # whether the prefix can be added at the current position
    my $qname = 0;    # whether an open parenthesis follows a QName,
                      # which indicates a function call or node test
    my @nesting = (); # stack of ($open_paren, $slash) pairs
    my $parens = 0;   # number of nested parentheses '()'
    my $brackets = 0; # number of nested brackets '[]'
    my $enclose = 0;  # whether to enclose the component by a pair of parens
    my $a = 0;        # anchor position index for a component

    $self->{xpaths} = [];
    $self->{mxpaths} = [];
    $self->{exnames} = [];
    $self->{varnames} = [];

    my @tokens = @{$self->{tokens}};
    my @mtokens = @tokens;
    my @varnames = ();
    my $varname = '';
    my $exname = '';

    for my $i (0..$#tokens) {
        my $token = $tokens[$i];
        my $c = substr $token, 0, 1;

        if ($c eq '/') {
            $slash = 1;
        } elsif ($c eq '|') {
            if ($brackets == 0) {
                if ($parens == 0) {
                    $enclose = 1;
                }

                $slash = 0;
            }

            if (@nesting == 0) {
                push @varnames, $varname if $varname ne '';
                $varname = '';
            }
        } elsif ($c eq '(') {
            push @nesting, [$c, $slash];
            $parens++;
        } elsif ($c eq '[') {
            push @nesting, [$c, $slash];
            $brackets++;
        } elsif ($c eq ')') {
            my ($p, $s) = @{pop(@nesting)};
            last if $p ne '(';
            $parens--;
            $slash = $s;
        } elsif ($c eq ']') {
            my ($p, $s) = @{pop(@nesting)};
            last if $p ne '[';
            $brackets--;
            $slash = $s;
        } elsif ($c eq ',') {
            if (@nesting == 0) {
                # Fold tokens into a component
                push @{$self->{xpaths}}, _trim(join('', @tokens[$a..$i - 1]));

                my $component = _trim(join('', @mtokens[$a..$i - 1]));

                if ($enclose) {
                    push @{$self->{mxpaths}}, "($component)";
                } else {
                    push @{$self->{mxpaths}}, $component;
                }

                push @varnames, $varname if $varname ne '';
                push @{$self->{varnames}}, [@varnames];
                push @{$self->{exnames}}, ($exname ne '' ? [$exname] : []);

                $a = $i + 1;
                $enclose = 0;
                $slash = 0;
                @varnames = ();
                $varname = '';
                $exname = '';
            }
        } else {
            if ($begin and $token =~ /^\s*\$([A-Za-z_][A-Za-z_0-9]*)\s*:?=\s*(.*)$/) {
                $exname = $1;
                $token = $2;
                $tokens[$i] = $token;
                $mtokens[$i] = $token;
                $c = substr $token, 0, 1;
            }

            if ($c =~ /^[a-z@\*]/i) {
                if ($ready and !$slash and $brackets == 0) {
                    # Add prefix
                    $mtokens[$i] = $prefix.$token;
                }
            }

            if ($c ne '"' and $c ne "'" and @nesting == 0) {
                my $word = _getLastWord($token);
                $varname = $word if $word ne '';
            }
        }

        $begin = ($c eq ',' && @nesting == 0);
        $ready = ($c eq ',') || ($c eq '|') || ($c eq '(' && !$qname);
        $qname = ($token =~ /[0-9a-z]\s*$/i);
    }

    # Fold the rest of tokens into a component
    if ($a <= $#tokens) {
        push @{$self->{xpaths}}, _trim(join('', @tokens[$a..$#tokens]));

        my $component = _trim(join('', @mtokens[$a..$#mtokens]));

        if ($enclose) {
            push @{$self->{mxpaths}}, "($component)";
        } else {
            push @{$self->{mxpaths}}, $component;
        }

        push @varnames, $varname if $varname ne '';
        push @{$self->{varnames}}, [@varnames];
        push @{$self->{exnames}}, ($exname ne '' ? [$exname] : []);
    }

    $self;
}

=begin twiki

---++ ObjectMethod getXPaths()

Retrieves an array ref of the parsed but unmodified XPaths.

=cut

sub getXPaths {
    my ($self) = @_;
    @{$self->{xpaths}};
}

=begin twiki

---++ ObjectMethod getModifiedXPaths()

Retrieves an array ref of the parsed and modified XPaths.

=cut

sub getModifiedXPaths {
    my ($self) = @_;
    @{$self->{mxpaths}};
}

=begin twiki

---++ ObjectMethod getExplicitNames()

Retrieves an array ref of the explicit variable names.

=cut

sub getExplicitNames {
    my ($self) = @_;
    @{$self->{exnames}};
}

=begin twiki

---++ ObjectMethod getVariableNames()

Retrieves an array ref of the variable names extracted from the expressions.

=cut

sub getVariableNames {
    my ($self) = @_;
    @{$self->{varnames}};
}

=begin twiki

---++ ObjectMethod count()

Counts the number of the recognized XPath expressions.

=cut

sub count {
    my ($self) = @_;
    scalar(@{$self->{xpaths}});
}

1;
