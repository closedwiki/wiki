use strict;

package MailerContribTests;

use base qw(BaseFixture);

use TWiki::Contrib::Mailer;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my @specs =
  (
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
   {
    entry => "person\@test.email",
    email => "person\@test.email",
    topicsout => "*"
   },
   {
    entry => "WikiName1",
    email => "WikiName1\@test.email",
    topicsout => "*"
   },
   {
    entry => "Main.WikiName2",
    email => "WikiName2\@test.email",
    topicsout => "*"
   },
   {
    entry => "%MAINWEB%.WikiName3",
    email => "WikiName3\@test.email",
    topicsout => "*"
   },
   {
    entry => "email1\@test.email: TestTopic1 (1)",
    email => "email1\@test.email",
    topicsout => "TestTopic1 TestTopic11 TestTopic12",
   },
   {
    entry => "email2\@test.email: TestTopic1 (2)",
    email => "email2\@test.email",
    topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122"
   },
   {
    email => "email3\@test.email",
    entry => "email3\@test.email: TestTopic1 (3)",
    topicsout => "TestTopic1 TestTopic11 TestTopic111 TestTopic112 TestTopic12 TestTopic121 TestTopic122 TestTopic1221"
   },
   {
    email => "email4\@test.email",
    entry => "email4\@test.email: TestTopic1 (0), TestTopic2 (3)",
    topicsout => "TestTopic1 TestTopic2 TestTopic21"
   },
   {
    email => "email5\@test.email",
    entry => "email5\@test.email: TestTopic1*1",
    topicsout => "TestTopic11 TestTopic111"
   }
  );

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  BaseFixture::writeTopic("Test", "TestTopic1",
                          "%META:TOPICPARENT{name=\"WebHome\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic11",
                          "%META:TOPICPARENT{name=\"TestTopic1\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic111",
                          "%META:TOPICPARENT{name=\"TestTopic11\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic112",
                          "%META:TOPICPARENT{name=\"TestTopic11\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic12",
                          "%META:TOPICPARENT{name=\"TestTopic1\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic121",
                          "%META:TOPICPARENT{name=\"TestTopic12\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic122",
                          "%META:TOPICPARENT{name=\"TestTopic12\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic1221",
                          "%META:TOPICPARENT{name=\"TestTopic122\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic2",
                          "%META:TOPICPARENT{name=\"WebHome\"}%\n");
  BaseFixture::writeTopic("Test", "TestTopic21",
                          "%META:TOPICPARENT{name=\"TestTopic2\"}%\n");

  my $s = "";
  foreach my $spec (@specs) {
      $s .= "   * $spec->{entry}\n";
  }

  BaseFixture::writeTopic("Test", "WebNotify", "Before\n${s}After");

  BaseFixture::writeFile("Test", ".changes", "",
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

sub testSimple {
    my $this = shift;

    # capture stdout
    my @webs = ( 'Te*' );
    TWiki::Contrib::Mailer::mailNotify( 1, 1, \@webs );

    my %matched;

    while ( my $message = shift(@TWiki::Net::sent)) {
        $message =~ /^To: (.*)$/m;
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
            $this->assert($matched{$spec->{email}}, "Expected ".$spec->{email});
        } else {
            $this->assert(!$matched{$spec->{email}}, "Unexpected ".$spec->{email});
        }
    }
}

1;
