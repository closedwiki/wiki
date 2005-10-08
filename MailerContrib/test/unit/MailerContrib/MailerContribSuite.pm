use strict;

package MailerContribTests;

use base qw(TWikiTestCase);

use TWiki::Contrib::Mailer;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $testWeb = "TemporaryMailerContribTestWeb";
my $peopleWeb = "TemporaryMailerContribPeopleWeb";
my $savePeople;

my @specs =
  (
   # traditional subscriptions
   {
    entry => "$peopleWeb.TWikiGuest - example\@test.email",
    email => "example\@test.email",
    topicsout => ""
   },
   {
    entry => "$peopleWeb.NonPerson - nonperson\@test.email",
    email => "nonperson\@test.email",
    topicsout => "*"
   },
   # email subscription
   {
    entry => "person\@test.email",
    email => "person\@test.email",
    topicsout => "*"
   },
   # wikiname subscription
   {
    entry => "WikiName1",
    email => "WikiName1\@test.email",
    topicsout => "*"
   },
   # wikiname subscription
   {
    entry => "%MAINWEB%.WikiName2",
    email => "WikiName2\@test.email",
    topicsout => "*"
   },
   # single topic with one level of children
   {
    entry => "email1\@test.email: TestTopic1 (1)",
    email => "email1\@test.email",
    topicsout => "TestTopic1 TestTopic11 TestTopic12",
   },
   # single topic with 2 levels of children
   {
    entry => "email2\@test.email: TestTopic1 (2)",
    email => "email2\@test.email",
    topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122"
   },
   # single topic with 3 levels of children
   {
    email => "email3\@test.email",
    entry => "email3\@test.email: TestTopic1 (3)",
    topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221"
   },
   # Comma separated list of subscriptions
   {
    email => "email4\@test.email",
    entry => "email4\@test.email: TestTopic1 (0), TestTopic2 (3)",
    topicsout => "TestTopic1 TestTopic2 TestTopic21"
   },
   # mix of commas, pluses and minuses
   {
    email => "email5\@test.email",
    entry => "email5\@test.email: TestTopic1 + TestTopic2(3), -TestTopic21",
    topicsout => "TestTopic1 TestTopic2"
   },
   # wildcard
   {
    email => "email6\@test.email",
    entry => "email6\@test.email: TestTopic1*1",
    topicsout => "TestTopic11 TestTopic111"
   },
   # wildcard unsubscription
   {
    email => "email7\@test.email",
    entry => "email7\@test.email: TestTopic*1 - \\\n   TestTopic2*",
    topicsout => "TestTopic1 TestTopic11 TestTopic121"
   },
  );

my %expectedRevs =
  (
   TestTopic1 => "r1->r3",
   TestTopic11 => "r1->r2",
   TestTopic111 => "r1->r2",
   TestTopic112 => "r1->r2",
   TestTopic12 => "r1->r2",
   TestTopic121 => "r1->r2",
   TestTopic122 => "r1->r2",
   TestTopic1221 => "r1->r2",
   TestTopic2 => "r2->r3",
   TestTopic21 => "r1->r2",
  );

my %finalText =
  (
   TestTopic1 => "beedy-beedy-beedy oh dear, said TWiki, shortly before exploding into a million shards of white hot metal as the concentrated laser fire of a thousand angry public website owners poured into it.",
   TestTopic11 => "fire laser beams",
   TestTopic111 => "Doctor Theopolis",
   TestTopic112 => "Buck, I'm dying",
   TestTopic12 => "Wow! A real Wookie!",
   TestTopic121 => "Where did I put my silver jumpsuit?",
   TestTopic122 => "That danged robot",
   TestTopic1221 => "What's up, Buck?",
   TestTopic2 => "roast my nipple-nuts",
   TestTopic21 => "smoke me a kipper, I'll be back for breakfast",
  );

my $twiki;
my @mails;

# callback used by Net.pm
sub sentMail {
    my($net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  $twiki = new TWiki();
  $TWiki::cfg{UsersWebName} = $peopleWeb;

  $twiki->{net}->setMailHandler(\&sentMail);

  my $user = $twiki->{user};
  my $text;

  $twiki->{store}->createWeb($user, $testWeb);
  $twiki->{store}->createWeb($user, $peopleWeb);

  my $s = "";
  foreach my $spec (@specs) {
      $s .= "   * $spec->{entry}\n";
  }

  my $meta = new TWiki::Meta($twiki,$testWeb,"WebNotify");
  $meta->put( "TOPICPARENT", { name => "$testWeb.WebHome" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "WebNotify",
                              "Before\n${s}After",
                              $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic1");
  $meta->put( "TOPICPARENT", { name => "WebHome" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic1",
                              "This is TestTopic1 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic11");
  $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic11",
                              "This is TestTopic11 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic111");
  $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic111",
                              "This is TestTopic111 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic112");
  $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic112",
                              "This is TestTopic112 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic12");
  $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic12",
                              "This is TestTopic12 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic121");
  $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic121",
                              "This is TestTopic121 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic122");
  $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic122",
                              "This is TestTopic122 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic1221");
  $meta->put( "TOPICPARENT", { name => "TestTopic122" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic1221",
                              "This is TestTopic1221 so there", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic2");
  $meta->put( "TOPICPARENT", { name => "WebHome" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic2",
                              "Dylsexia rules", $meta);

  $meta = new TWiki::Meta($twiki,$testWeb,"TestTopic21");
  $meta->put( "TOPICPARENT", { name => "$testWeb.TestTopic2" } );
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic21",
                              "This is TestTopic21 so there", $meta);

  # add a second rev to TestTopic2 so the base rev is 2
  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic2");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic2",
                              "This is TestTopic2 so there", $meta,
                              { forcenewrevision=>1 });

  # stamp the baseline
  $twiki->{store}->saveMetaData($testWeb, "mailnotify", time());

  $meta = new TWiki::Meta($twiki,$peopleWeb,"WikiName1");
  $twiki->{store}->saveTopic( $user, $peopleWeb, "WikiName1",
                              "   * email: WikiName1\@test.email\n",
                              $meta);
  $twiki->{store}->saveTopic( $user, $peopleWeb, "WikiName2",
                              "   * email: WikiName2\@test.email\n",
                              $meta);

  # wait a wee bit for the clock to tick over
  sleep(1);

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic1");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic1",
                              "not the last word", $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic11");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic11",
                              $finalText{TestTopic11}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic111");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic111",
                              $finalText{TestTopic111}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic112");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic112",
                              $finalText{TestTopic112}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic12");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic12",
                              $finalText{TestTopic12}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic121");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic121",
                              $finalText{TestTopic121}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic122");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic122",
                              $finalText{TestTopic122}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic1221");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic1221",
                              $finalText{TestTopic1221}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic2");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic2",
                              $finalText{TestTopic2}, $meta,
                              { forcenewrevision=>1 });

  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic21");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic21",
                              $finalText{TestTopic21}, $meta,
                              { forcenewrevision=>1 });

  # wait a wee bit more for the clock to tick over again
  sleep(1);

  # TestTopic1 should now have two change records in the period, so
  # should be going from rev 1 to rev 3
  ( $meta, $text ) = $twiki->{store}->readTopic(undef,$testWeb,"TestTopic1");
  $twiki->{store}->saveTopic( $user, $testWeb, "TestTopic1",
                              $finalText{TestTopic1}, $meta,
                              { forcenewrevision=>1 });

  @mails = ();

  # OK, we should have a bunch of changes
  #print "MN: ",cat $TWiki::cfg{DataDir}/$testWeb/.mailnotify;
  #print cat $TWiki::cfg{DataDir}/$testWeb/.changes;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $peopleWeb);
}

sub testSimple {
    my $this = shift;

    # capture stdout
    my @webs = ( $testWeb, $peopleWeb );
    TWiki::Contrib::Mailer::mailNotify( \@webs, $twiki, 0 );
    #print "REPORT\n",join("\n\n", @mails);

    my %matched;
    foreach my $message ( @mails ) {
        next unless $message;
        $message =~ /^To: (.*)$/m;
        my $mailto = $1;
        $this->assert($mailto, $message);
        foreach my $spec (@specs) {
            if ($mailto eq $spec->{email}) {
                $this->assert(!$matched{$mailto});
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                if ($xpect eq '*') {
                    $xpect = "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221 TestTopic2 TestTopic21";
                }
                foreach my $x (split(/\s+/, $xpect)) {
                    $this->assert_matches(qr/^- $x \(.*\) $expectedRevs{$x}/m, $message);
                    #$this->assert_matches(qr/$finalText{$x}/m, $message);
                    $message =~ s/^- $x \(.*\n//m;
                }
                $this->assert_does_not_match(qr/^- \w+ \(/, $message);
                last;
            }
        }
    }
    foreach my $spec (@specs) {
        if ($spec->{topicsout} ne "") {
            $this->assert($matched{$spec->{email}},
                          "Expected mails for ".$spec->{email} . " got " .
                         join(" ", keys %matched));
        } else {
            $this->assert(!$matched{$spec->{email}},
                          "Unexpected mails for ".$spec->{email} . " got " .
                         join(" ", keys %matched));
        }
    }
}

1;
