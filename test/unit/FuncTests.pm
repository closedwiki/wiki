use strict;

#
# Unit tests for TWiki::Func
#

package FuncTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Func;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

my $twiki;
my $testweb = "TemporaryFuncModuleTestWeb";

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert_null($twiki->{store}->createWeb($twiki->{user}, $testweb));
    $this->assert($twiki->{store}->webExists($testweb));
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user},$testweb);
}

sub test_getViewUrl {
    my $this = shift;

    $TWiki::Plugins::SESSION = new TWiki();
    my $ss = 'view'.$TWiki::cfg{ScriptSuffix};
    my $result = TWiki::Func::getViewUrl ( "Main", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $result = TWiki::Func::getViewUrl ( "", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $TWiki::Plugins::SESSION = new TWiki(
        undef,
        new CGI( { topic=>"Sausages.AndMash" } ));

    $result = TWiki::Func::getViewUrl ( "Sausages", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );
    $this->assert_matches(qr!!, $result );

    $result = TWiki::Func::getViewUrl ( "", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );
}

sub test_getScriptUrl {
    my $this = shift;

    $TWiki::Plugins::SESSION = new TWiki();
    my $ss = 'wibble'.$TWiki::cfg{ScriptSuffix};
    my $result = TWiki::Func::getScriptUrl ( "Main", "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $result = TWiki::Func::getScriptUrl ( "", "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    my $q = new CGI( {} );
    $q->path_info( '/Sausages/AndMash' );
    $TWiki::Plugins::SESSION = new TWiki(undef, $q);

    $result = TWiki::Func::getScriptUrl ( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );

    $result = TWiki::Func::getScriptUrl ( "", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/AndMash!, $result );
}

sub test_leases {
    my $this = shift;

    my $testtopic = $TWiki::cfg{HomeTopicName};

    my( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert(!$oops, $oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);

    my $locker = $twiki->{user}->login();
    TWiki::Func::setTopicEditLock($testweb, $testtopic, 1);

    # check the lease
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert_equals($locker,$login);
    $this->assert($time > 0);
    $this->assert_matches(qr/leaseconflict/,$oops);
    $this->assert_matches(qr/active/,$oops);

    # change user and check the lease again
    $twiki->{user} = $twiki->{users}->findUser('TestUser1');
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert_equals($locker,$login);
    $this->assert($time > 0);
    $this->assert_matches(qr/leaseconflict/,$oops);
    $this->assert_matches(qr/active/,$oops);

    # try and clear the lease. This should always succeed, even
    # though the user has changed
    TWiki::Func::setTopicEditLock($testweb, $testtopic, 0);
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert(!$oops,$oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);
}

1;
