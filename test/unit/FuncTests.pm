use strict;

#
# Unit tests for TWiki::Func
#

package FuncTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Func;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub test_getViewUrl {
    my $this = shift;

    $TWiki::Plugins::SESSION = new TWiki();
    my $ss = 'view'.$TWiki::cfg{ScriptSuffix};
    my $result = TWiki::Func::getViewUrl ( "Main", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $result = TWiki::Func::getViewUrl ( "", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $TWiki::Plugins::SESSION = new TWiki("/Sausages/AndMash");

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

    $TWiki::Plugins::SESSION = new TWiki("/Sausages/AndMash");

    $result = TWiki::Func::getScriptUrl ( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );

    $result = TWiki::Func::getScriptUrl ( "", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/AndMash!, $result );
}

1;
