# Tests for module ActionNotify.pm
use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use lib ('.');
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

{ package ActionNotifyTests;

  sub setUp {
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    TWiki::TestMaker::init("ActionTrackerPlugin");

    TWiki::TestMaker::writeTopic("Main", "ActorOne", "
   * Email: actor-1\@an-address.net
");
    TWiki::TestMaker::writeTopic("Main", "ActorTwo", "
   * Email: actorTwo\@another-address.net
");
    TWiki::TestMaker::writeTopic("Main", "ActorThree", "
   * Email: actor3\@yet-another-address.net
");
    TWiki::TestMaker::writeTopic("Main", "ActorFour", "
   * E-mail: actorfour\@yet-another-address.net
");
    TWiki::TestMaker::writeTopic("Main", "ActorFive", "
   * NoE-mailhere: actor5\@wrong-address
");
    TWiki::TestMaker::writeTopic("Main", "ActorSix", "
   * E-mail: actor6\@correct-address
");
    TWiki::TestMaker::writeTopic("Main", "TWikiFormGroup", "
\t\t* Set GROUP = ActorThree, ActorFour
");
    TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * Main.ActorFive - actor5\@correct.address
   * Main.ActorSix - actor6\@wrong.address
");
    TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.ActorEight - actor-8\@correct.address
");
    TWiki::TestMaker::writeTopic("Main", "EMailGroup", "
   * Set GROUP = actorTwo\@another-address.net,actorfour\@yet-another-address.net
");

    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,ActorSeven,ActorEight\" due=\"3 Jan 02\" state=open}% A1: ontime");
    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight\" due=\"3 Jan 02\" state=closed}% A2: closed");
    TWiki::TestMaker::writeTopic("Main", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight\",due=\"3 Jan 01\",state=open}% A3: late
%ACTION{who=TWikiFormGroup,due=\"3 Jan 01\",state=open}% A4: late ");
    TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=EMailGroup,due=\"3 Jan 01\",state=open}% A5: late
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,TWikiFormGroup,ActorFive,ActorSix,actor.7\@seven.net,ActorEight,EMailGroup\",due=\"3 Jan 99\",open}% A6: late");

    # Action changes are hard to fake because the RCS files are not there.
    TWiki::TestMaker::writeRcsTopic("Test", "ActionChanged", "head	1.2;
access;
symbols;
locks
	apache:1.2; strict;
comment	\@# \@;


1.2
date	2001.12.24.17.54.53;	author guest;	state Exp;
branches;
next	1.1;

1.1
date	2001.09.23.19.28.56;	author guest;	state Exp;
branches;
next	;


desc
\@none
\@


1.2
log
\@none
\@
text
\@%META:TOPICINFO{author=\"guest\" date=\"1032890093\" format=\"1.0\" version=\"1.2\"}%
%ACTION{who=ActorFive,due=\"22-jun-2002\",notify=Main.ActorFive}% A7: Date change
%ACTION{who=ActorFive,due=\"22-jun-2002\"}% Stuck in
%ACTION{who=ActorFour,due=\"22-jul-2001\",notify=\"Main.ActorSix,Main.ActorEight\"}% A8: Text change from original
\@


1.1
log
\@none
\@
text
\@d1 3
a3 3
%META:TOPICINFO{author=\"guest\" date=\"1032811587\" format=\"1.0\" version=\"1.1\"}%
%ACTION{who=ActorFive,due=\"22-jun-2001\",notify=Main.ActorFive}% A7: Date change
%ACTION{who=\"Main.ActorFour\",due=\"22-jul-2001\",notify=ActorFive}% A8: Text change
\@
");
  }

  sub testWholeShebang {
    # Do the whole shebang; the output generation is rather dependent on the
    # correct format of the template, however...
    ActionTrackerPlugin::ActionNotify::actionNotify( "late" );
    Assert::equals(scalar(@TWiki::Net::sent), 8);
    my $html;

# Actor 1 - wikiname in main, not a member of any groups
#actor-1\@an-address.net
#A3 A6
# Actor 2 - wikiname in main and member of emailgroup only
#actorTwo\@another-address.net
#A3 A5 A6
# Actor 3 - wikiname in main and member of twikigroup only
#actor3\@yet-another-address.net
#A3 A4 A6
# Actor 4 - wikiname in main and member of emailgroup and twikigroup
#actorfour\@yet-another-address.net
#A3 A4 A5 A6
# Actor 5 - wikiname in main, address in Main.WebNotify
#actor5\@correct.address
#A3 A6 A7
# Actor 6 - wikiname in main and wrong address in Main.WebNotify
#actor6\@correct-address
#A3 A6 A8
# Actor 7 - email address on action line
#actor.7\@seven.net
#A3 A6
# Actor 8 - no topic in main, address in Test.WebNotify
#actor-8\@correct.address
#A3 A6 A8

# A1 - on time
# A2 - closed
# A3 - open, late
# A4 - notify TWikiGroup
# A5 - notify EMailGroup
# A6 - notify everyone many times
    my $ok = "";
    while ( $html = shift(@TWiki::Net::sent)) {
      Assert::assert($html !~ /A[1|2]/, $html);
      Assert::assert($html !~ /^To: (.*),/os);
      #$html =~ /To: (.*)/;
      #print STDERR "Shebang $1\n";
      if ($html =~ /To: actor-1\@an-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "A";
      } elsif ($html =~ /To: actorTwo\@another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html =~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "B";
      } elsif ($html =~ /To: actor3\@yet-another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html =~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "C";
      } elsif ($html =~ /To: actorfour\@yet-another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html =~ /A4:/,$html);
	Assert::assert($html =~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "D";
      } elsif ($html =~ /To: actor5\@correct.address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "E";
      } elsif ($html =~ /To: actor6\@correct-address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "F";
      } elsif ($html =~ /To: actor\.7\@seven\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "G";
      } elsif ($html =~ /To: actor-8\@correct\.address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	$ok .= "H";
      } else {
	Assert::assert(0, $html);
      }
    }
    Assert::equals(length($ok),8);
    Assert::sContains($ok, "A");
    Assert::sContains($ok, "B");
    Assert::sContains($ok, "C");
    Assert::sContains($ok, "D");
    Assert::sContains($ok, "E");
    Assert::sContains($ok, "F");
    Assert::sContains($ok, "G");
    Assert::sContains($ok, "H");
  }
#actor5\@correct.address
#A3 A6 A7
# Actor 6 - wikiname in main and wrong address in Main.WebNotify
#actor6\@correct-address
#A3 A6 A8
# Actor 8 - no topic in main, address in Test.WebNotify
#actor-8\@correct.address
#A3 A6 A8

  sub testChangedSince {
    ActionTrackerPlugin::ActionNotify::actionNotify( "changedsince=\"1 dec 2001\"" );
    Assert::equals(scalar(@TWiki::Net::sent), 3);
    my %saw;
    while( $html = shift(@TWiki::Net::sent) ) {
      Assert::sContains($html, "From: mailsender");
      Assert::sContains($html, "Subject: Changes to actions on mailsender");
      if ($html=~ /To: actor5\@correct.address/) {
	Assert::sContains($html, "Subject: Changes to actions on mailsender");
	Assert::sContains($html, "Changes to actions since Sat Dec  1 00:00:00 2001");
	Assert::sContains($html, "Attribute \"due\" changed, was \"Fri, 22 Jun 2001 (LATE)\", now \"Sat, 22 Jun 2002\"");
	$saw{1} = 1;
      } elsif ($html =~ /To: actor6\@correct-address/) {
	Assert::assert($html !~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html !~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original\"");
	Assert::htmlContains($html, "<tr><td>text</td><td> A8: Text change</td><td> A8: Text change from original</td></tr>");
	$saw{2} = 1;
      } elsif ($html =~ /To: actor-8\@correct.address/) {
	Assert::assert($html !~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html !~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original\"");
	Assert::htmlContains($html, "<tr><td>text</td><td> A8: Text change</td><td> A8: Text change from original</td></tr>");
	$saw{3} = 1;
      } else {
	Assert::assert(0, "Not good $html");
      }
    }
    Assert::assert($saw{1} == 1,"Arg");
    Assert::assert($saw{2} == 1,"Arrgh");
    Assert::assert($saw{3} == 1,"Aaaaaargh");
  }
}

1;
