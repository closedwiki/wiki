use strict;

use TWiki::Contrib::Publish;

{ package PublishContribSuite;

  use base qw(Test::Unit::TestSuite);

  sub name { 'PublishContrib' };

  sub include_tests { qw(PublishTests) };
}

{ package PublishTests;

  use base qw(Test::Unit::TestCase);

  sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
  }

  sub test_write_me {
	my $this = shift;

    TWiki::Contrib::Publish::main();
  }
}
1;
