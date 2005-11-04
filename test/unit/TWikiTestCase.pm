package TWikiTestCase;
#
# Base class of all TWiki tests. Establishes base paths and adds
# some useful functionality such as comparing HTML
#
# The basic strategy in all unit tests is to never write to normal
# TWiki data areas; only ever write to temporary test areas. If you
# have to create a test fixture that duplicates an existing area,
# you can always create a new web based on that web.
#
use base qw(Test::Unit::TestCase);
use vars qw( $has_TestFixturePlugin );

use TWiki;
eval "use TWiki::Plugins::TestFixturePlugin::HTMLDiffer";
$has_TestFixturePlugin = 1 unless $@;
use strict;
use Error qw( :try );

BEGIN {
    push( @INC, "$ENV{TWIKI_HOME}/lib" ) if defined($ENV{TWIKI_HOME});
    unshift @INC, '../../bin';
    require 'setlib.cfg';
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
};

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Use this to save the TWiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # force a read of $TWiki::cfg
    my $tmp = new TWiki();
    # This needs to be a deep copy
    $this->{__TWikiSafe} = _copy( \%TWiki::cfg );
}

# Restores TWiki::cfg from backup and deletes any fake users created
sub tear_down {
    my $this = shift;
    %TWiki::cfg = %{$this->{__TWikiSafe}};
    if(defined($this->{fake_users})) {
        for my $i (@{$this->{fake_users}}) {
            unlink("$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$i.txt");
            unlink("$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$i.txt,v");
        }
    }
}

sub _copy {
    my $n = shift;

    return undef unless defined( $n );

    if (UNIVERSAL::isa($n, 'ARRAY')) {
        my @new;
        for ( 0..$#$n ) {
            push(@new, _copy( $n->[$_] ));
        }
        return \@new;
    }
    elsif (UNIVERSAL::isa($n, 'HASH')) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif (UNIVERSAL::isa($n, 'REF') || UNIVERSAL::isa($n, 'SCALAR')) {
        $n = _copy($$n);
        return \$n;
    }
    else {
        return $n;
    }
}

# Like it says on the tin; creates a fake user, that is guaranteed not to
# conflict with any existing user. Fake users will be killed during tear_down.
# Be aware that if you fail to call tear-down, for example if you ctrl-C the
# tests, you may leave fake users around, so it is better to change
# $TWiki::cfg{UsersWebName} to a test-specific web first.
# The first parameter is a TWiki object and is required.
# The optional parameter is the text to put in the user topic.
# Only the user topic is created; the user is _not_ added to TWikiUsers.
# The wikiname of the new user topic is returned.
sub createFakeUser {
    my( $this, $twiki, $text, $name ) = @_;
    $this->assert($twiki->{store}->webExists($TWiki::cfg{UsersWebName}));
    $name ||= '';
    my $base = "TemporaryTestUser".$name;
    my $i = 0;
    while($twiki->{store}->topicExists($TWiki::cfg{UsersWebName},$base.$i)) {
        $i++;
    }
    $text ||= '';
    my $meta = new TWiki::Meta($twiki, $TWiki::cfg{UsersWebName}, $base.$i);
    $meta->put( "TOPICPARENT", {
        name => $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{HomeTopicName} } );
    $twiki->{store}->saveTopic($twiki->{user},
                               $TWiki::cfg{UsersWebName},
                               $base.$i,
                               $text, $meta);
    push( @{$this->{fake_users}}, $base.$i);
    return $base.$i;
}

# 1:1 HTML comparison. Correctly compares attributes in tags. Uses HTML::Parser
# which is tolerant of unbalanced tags, so the actual may have unbalanced
# tags which will _not_ be detected.
sub assert_html_equals {
    my( $this, $e, $a, $mess ) = @_;

    $this->assert(0, "Failed loading TWiki::Plugins::TestFixturePlugin::HTMLDiffer, TestFixturePlugin's lib directory should be in \@INC.") unless $has_TestFixturePlugin;
    
    my ($package, $filename, $line) = caller(0);
    my $opts =
      {
       options => 'rex',
       reporter =>
       \&TWiki::Plugins::TestFixturePlugin::HTMLDiffer::defaultReporter,
       result => ''
      };

    $mess ||= "$a\ndoes not equal\n$e";
    $this->assert($e, "$filename:$line\n$mess");
    $this->assert($a, "$filename:$line\n$mess");
    unless( TWiki::Plugins::TestFixturePlugin::HTMLDiffer::diff($e, $a, $opts)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

# Uses a regular-expression match to try to match a block of HTML in a larger
# block of HTML. Not too clever about tag attributes.
sub assert_html_matches {
    my ($this, $e, $a, $mess ) = @_;

    $this->assert(0, "Failed loading TWiki::Plugins::TestFixturePlugin::HTMLDiffer, TestFixturePlugin's lib directory should be in \@INC.") unless $has_TestFixturePlugin;
    
    $mess ||= "$a\ndoes not match\n$e";
    my ($package, $filename, $line) = caller(0);
    unless( TWiki::Plugins::TestFixturePlugin::HTMLDiffer::html_matches($e, $a)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

# invoke a subroutine while grabbing stdout, so the "http
# response" doesn't flood the console that you're running the
# unit test from.
# $this->capture(\&proc, ...) -> $stdout
# ... params get passed on to &proc
sub capture {
    my $this = shift;
    my $proc = shift;

    # take copy of the file descriptor
    open(OLDOUT, ">&STDOUT");
    open(STDOUT, ">/tmp/cgi");

    my $text = undef;
    my @params = @_;
    my $result;

    try {
        $result = &$proc( @params );
    } finally {
        close(STDOUT)            or die "Can't close STDOUT: $!";
        open(STDOUT, ">&OLDOUT") or die "Can't restore stderr: $!";
        close(OLDOUT)            or die "Can't close OLDOUT: $!";
    };

    $text = '';
    open(FH, '/tmp/cgi');
    local $/ = undef;
    $text = <FH>;
    close(FH);
    unlink('/tmp/cgi');

    return ( $text, $result );
}

1;
