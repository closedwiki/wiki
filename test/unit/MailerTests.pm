use strict;

package MailerTests;

use TestCaseStdOutCapturer;
use base qw(Test::Unit::TestCase);
use lib "../../lib";
use Error qw( :try );
use CGI;

use TWiki::UI::Mailer;

my $temporaryWeb = "ZzzzTestMailerzzzz";
my $twiki;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my @specs =
  (
   # traditional subscriptions
   {
    entry => "Main.TWikiGuest - example\@test.email",
    email => "example\@test.email",
    topicsout => ""
   },
   # subscription for a non-existant user
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
   # no-web wikiname subscription
   {
    entry => "TestUser1",
    email => "TestUser1\@test.email",
    topicsout => "*"
   },
   # with-web wikiname subscription
   {
    entry => "Main.TestUser2",
    email => "TestUser2\@test.email",
    topicsout => "*"
   },
   # mainweb var
   {
    entry => "%MAINWEB%.TestUser3",
    email => "WikiName3\@test.email",
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

    mkdir "$TWiki::dataDir/$temporaryWeb";
    chmod 0777, "$TWiki::dataDir/$temporaryWeb";
    $Error::Debug = 1;

    my $query = new CGI ({
                          '.path_info' => '/$temporaryWeb/WebHome',
                         });
    $twiki = new TWiki("/$temporaryWeb", "guest", "", $query->url, $query);

    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic1",
       "%META:TOPICPARENT{name=\"WebHome\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic11",
       "%META:TOPICPARENT{name=\"TestTopic1\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic111",
       "%META:TOPICPARENT{name=\"TestTopic11\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic112",
       "%META:TOPICPARENT{name=\"TestTopic11\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic12",
       "%META:TOPICPARENT{name=\"TestTopic1\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic121",
       "%META:TOPICPARENT{name=\"TestTopic12\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic122",
       "%META:TOPICPARENT{name=\"TestTopic12\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic1221",
       "%META:TOPICPARENT{name=\"TestTopic122\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic2",
       "%META:TOPICPARENT{name=\"WebHome\"}%\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $temporaryWeb, "TestTopic21",
       "%META:TOPICPARENT{name=\"TestTopic2\"}%\n",
       undef, "", 1, 1, 0, 0);

    $twiki->{store}->saveTopic
      ("guest", $TWiki::mainWebname, "TestUser1",
       "\t* Email: TestUser1\@test.email\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $TWiki::mainWebname, "TestUser2",
       "\t* Email: TestUser2\@test.email\n",
       undef, "", 1, 1, 0, 0);
    $twiki->{store}->saveTopic
      ("guest", $TWiki::mainWebname, "TestUser3",
       "\t* Email: WikiName3\@test.email\n",
       undef, "", 1, 1, 0, 0);

    my $s = "";
    foreach my $spec (@specs) {
        $s .= "   * $spec->{entry}\n";
    }

    $twiki->{store}->saveTopic("guest", $temporaryWeb, "WebNotify",
                               "Before\n${s}After",
                               undef, "", 1, 1, 0, 0);

    $twiki->{store}->saveFile("$TWiki::dataDir/$temporaryWeb/.changes",
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
    my $query = $twiki->{cgiQuery};
    $query->param(-name=>"sendmail", -value=>0);
    $query->param(-name=>"verbose", -value=>1);
    $query->param(-name=>"webs", -value=>$temporaryWeb);
    my $result = Test::Unit::IO::StdoutCapture::do {
        TWiki::UI::Mailer::notify( $twiki );
    };
    my @messages;
    my $message = "";
    my $to;
    foreach my $line ( split /\n/, $result ) {
        if ( $line =~ /Please tell (.*) about/ ) {
            push(@messages,$message) if ( $to );
            $to = $1;
            $message = "To: $to\n";
        } else {
            $message .= "$line\n";
        }
    }
    push(@messages,$message) if ( $to );

    my %matched;

    while ( $message = shift(@messages)) {
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
            $this->assert($matched{$spec->{email}},
                          "Expected ".$spec->{email} . ", but only got " .
                         join(" ", keys %matched));
        } else {
            $this->assert(!$matched{$spec->{email}},
                          "Unexpected ".$spec->{email} . " got " .
                         join(" ", keys %matched));
        }
    }
}

1;
