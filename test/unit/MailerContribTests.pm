use strict;

package MailerContribTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki::Contrib::Mailer;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $testweb = "MailerContribTestWeb";

my @specs =
  (
   # traditional subscriptions
   {
    entry => "Main.TWikiGuest - example\@test.email",
    email => "example\@test.email",
    topicsout => ""
   },
   {
    entry => "Main.NonPerson - nonperson\@test.email",
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

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  my $twiki =
      new TWiki( "", $TWiki::cfg{DefaultUserLogin}, "", "" );
  my $user = $twiki->{users}->findUser($TWiki::cfg{DefaultUserLogin});

  mkdir("$TWiki::cfg{DataDir}/$testweb",0777) ||
    die "$TWiki::cfg{DataDir}/$testweb fixture setup failed: $!";

  my $meta = new TWiki::Meta($twiki,$testweb,"testTopic1");
  $meta->put( "TOPICPARENT", { name => "WebHome" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic1", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic11");
  $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic11", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic111");
  $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic111", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic112");
  $meta->put( "TOPICPARENT", { name => "TestTopic11" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic112", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic12");
  $meta->put( "TOPICPARENT", { name => "TestTopic1" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic12", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic121");
  $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic121", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic122");
  $meta->put( "TOPICPARENT", { name => "TestTopic12" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic122", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic1221");
  $meta->put( "TOPICPARENT", { name => "TestTopic122" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic1221", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic2");
  $meta->put( "TOPICPARENT", { name => "WebHome" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic2", "", $meta);

  $meta = new TWiki::Meta($twiki,$testweb,"TestTopic21");
  $meta->put( "TOPICPARENT", { name => "$testweb.TestTopic2" } );
  $twiki->{store}->saveTopic( $user, $testweb, "TestTopic21", "", $meta);

  my $s = "";
  foreach my $spec (@specs) {
      $s .= "   * $spec->{entry}\n";
  }

  $meta = new TWiki::Meta($twiki,$testweb,"WebNotify");
  $meta->put( "TOPICPARENT", { name => "$testweb.WebHome" } );
  $twiki->{store}->saveTopic( $user, $testweb, "WebNotify", "Before\n${s}After",
                              $meta);

  $meta = new TWiki::Meta($twiki,"Main","WikiName1");
  $twiki->{store}->saveTopic( $user, "Main", "WikiName1",
                              "   * email: WikiName1\@test.email\n",
                              $meta);
  $twiki->{store}->saveTopic( $user, "Main", "WikiName2",
                              "   * email: WikiName2\@test.email\n",
                              $meta);

  $twiki->{store}->saveMetaData($testweb,"changes",
"TestTopic1\tTopic1Changer\t1083404832\t1
TestTopic11\tTopic11Changer\t1083405832\t2
TestTopic111\tTopic111Changer\t1083406832\t3
TestTopic112\tTopic112Changer\t1083407832\t4
TestTopic12\tTopic12Changer\t1083408832\t5
TestTopic121\tTopic121Changer\t1083409832\t6
TestTopic122\tTopic122Changer\t1083410832\t7
TestTopic1221\tTopic1221Changer\t1083411832\t8
TestTopic2\tTopic2Changer\t1083412832\t8
TestTopic21\tTopic21Changer\t1083413832\t8
");
}

sub tear_down {
    `rm -rf $TWiki::cfg{DataDir}/$testweb`;
    `rm -f $TWiki::cfg{DataDir}/Main/WikiName1.txt*`;
    `rm -f $TWiki::cfg{DataDir}/Main/WikiName2.txt*`;
    print STDERR "tear_down $TWiki::cfg{DataDir}/$testweb failed: $!\n" if $!;
}

sub testSimple {
    my $this = shift;

    # capture stdout
    my @webs = ( 'Mail*' );
    my $report = TWiki::Contrib::Mailer::mailNotify( 0, 1, \@webs );

    my @mails = split(/Please tell /, $report);
    my %matched;

    foreach my $message ( @mails ) {
        next unless $message;
        $message =~ /^(.*?)\s/;
        my $mailto = $1;
        foreach my $spec (@specs) {
            if ($mailto eq $spec->{email}) {
                $this->assert(!$matched{$mailto});
                $matched{$mailto} = 1;
                my $xpect = $spec->{topicsout};
                if ($xpect eq '*') {
                    $xpect = "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221 TestTopic2 TestTopic21";
                }
                foreach my $x (split(/\s+/, $xpect)) {
                    $this->assert_matches(qr/^- $x \(/m, $message);
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
                          "Expected ".$spec->{email} . " got " .
                         join(" ", keys %matched));
        } else {
            $this->assert(!$matched{$spec->{email}},
                          "Unexpected ".$spec->{email} . " got " .
                         join(" ", keys %matched));
        }
    }
}

1;
