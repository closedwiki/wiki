package TWiki::Users::ProxyPasswdUser;
use strict;
# By Martin Cleaver
# Hacky, but it seems to work :)
use Data::Dumper;
$Data::Dumper::Maxdepth = 2;
$Data::Dumper::Pad = "                                    ";

use vars qw( $AUTOLOAD );
my $delegate = 'TWiki::Users::HtPasswdUser'; #SMELL should be delegateClass
eval "use $delegate";
my $self;

sub new {
    my( $class, $session ) = @_;
#    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;
    $this->{proxy} = new $delegate ($session); # needed?
    $self = $this;

    return $this;
}

  sub AUTOLOAD {
    my ($subname) = $AUTOLOAD =~ /([^:]+)$/;
    if (my $sub = UNIVERSAL::can( $delegate, # SMELL - should be proxy?
				  $subname )) {
      my ($ppackage, $pfilename, $pline, $psubroutine) = caller(2);
      my ($package, $filename, $line, $subroutine, $hasargs,
    $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1); 
      $self->{session}->writeDebug("$psubroutine:$pline => $subroutine:$line");
      $self->{session}->writeDebug("[ hasargs = $hasargs, wantarray = $wantarray, evaltext = $evaltext, is_require = $is_require, hints = $hints, bitmask = $bitmask ]");
      $self->{session}->writeDebug("        => Calling $delegate:$subname (\n".Dumper(@_).$Data::Dumper::Pad.")");
      my $ans = $sub->( @_ ); # TODO capture result, but preserve ANY return type
      $self->{session}->writeDebug("$subname returned:\n".Dumper($ans));
      $ans;
    } else {
      die "In $delegate cannot call <$subname>\n";
    }
  }
  
1;
