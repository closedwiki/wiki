package TWiki::Users::ProxyPasswdUser;
use strict;
# By Martin Cleaver
# Hacky, but it seems to work :)

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
      $self->{session}->writeDebug("Calling $subname(".join(' ', @_).")");
      $sub->( @_ ); # TODO capture result, but preserve ANY return type
      $self->{session}->writeDebug("After");
    } else {
      die "In $delegate cannot call <$subname>\n";
    }
  }
  
1;
