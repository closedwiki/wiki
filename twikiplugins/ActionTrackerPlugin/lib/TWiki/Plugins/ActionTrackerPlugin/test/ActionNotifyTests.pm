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

  # Actor 1 - wikiname in main, not a member of any groups
  # email: actor-1\@an-address.net
  # Should be notified with: A3 A6
  # Actor 2 - wikiname in main and member of emailgroup only
  # email: actorTwo\@another-address.net
  # Should be notified with: A3 A5 A6
  # Actor 3 - wikiname in main and member of twikigroup only
  # email: actor3\@yet-another-address.net
  # Should be notified with: A3 A4 A6
  # Actor 4 - wikiname in main and member of emailgroup and twikigroup
  # email: actorfour\@yet-another-address.net
  # Should be notified with: A3 A4 A5 A6
  # Actor 5 - wikiname in main, address in Main.WebNotify
  # email: actor5\@correct.address
  # Should be notified with: A3 A6 A7
  # Actor 6 - wikiname in main and wrong address in Main.WebNotify
  # email: actor6\@correct-address
  # Should be notified with: A3 A6 A8
  # Actor 7 - email address on action line
  # email: actor.7\@seven.net
  # Should be notified with: A3 A6
  # Actor 8 - no topic in main, address in Test.WebNotify
  # email: actor-8\@correct.address
  # Should be notified with: A3 A6 A8

  # A1 - on time - should never be notified
  # A2 - closed - should never be notified
  # A3 - open, late - notify everybody
  # A4 - notify TWikiFormGroup, Actor3,Actor4
  # A5 - notify EMailGroup, Actor2,Actor4
  # A6 - notify everyone many times
  # A7 - notify changes to Actor5
  # A8 - notify changes to Actor6, Actor8
  sub setUp {
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
   * Main.ActorSix
");
    TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.ActorEight - actor-8\@correct.address
");
    TWiki::TestMaker::writeTopic("Main", "EMailGroup", "
   * Set GROUP = actorTwo\@another-address.net,ActorFour
");

    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,ActorSeven,ActorEight\" due=\"3 Jan 02\" state=open}% A1: ontime");
    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight\" due=\"2 Jan 02\" state=closed}% A2: closed");
    TWiki::TestMaker::writeTopic("Main", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight,NonEntity\",due=\"3 Jan 01\",state=open}% A3: late
%ACTION{who=TWikiFormGroup,due=\"4 Jan 01\",state=open}% A4: late ");
    TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=EMailGroup,due=\"5 Jan 01\",state=open}% A5: late
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,TWikiFormGroup,ActorFive,ActorSix,actor.7\@seven.net,ActorEight,EMailGroup\",due=\"6 Jan 99\",open}% A6: late");

    # Action changes are hard to fake because the RCS files are not there.
    TWiki::TestMaker::writeRcsTopic("Test", "ActionChanged",
"head	1.2;
access;
symbols;
locks
	crawford:1.2; strict;
comment	\@# \@;


1.2
date	2003.05.21.20.18.01;	author crawford;	state Exp;
branches;
next	1.1;

1.1
date	2001.05.21.20.16.54;	author crawford;	state Exp;
branches;
next	;


desc
\@\@


1.2
log
\@*** empty log message ***
\@
text
\@%META:TOPICINFO{author=\"guest\" date=\"1032890093\" format=\"1.0\" version=\"1.2\"}%
%ACTION{who=ActorFive,due=\"22-jun-2002\",notify=Main.ActorFive}% A7: Date change
%ACTION{who=EMailGroup,due=\"5 Jan 01\",state=open,notify=nobody}% No change
%ACTION{who=ActorFive,due=\"22-jun-2002\" notify=Main.ActorOne}% Stuck in
%ACTION{who=ActorSix,due=\"22-jul-2001\",notify=\"Main.ActorSix,Main.ActorEight\"}% A8: Text change from original, late
%ACTION{uid=1234 who=NonEntity notify=ActorFive}% A9: No change
\@


1.1
log
\@Initial revision
\@
text
\@d1 5
a5 3
%META:TOPICINFO{author=\"guest\" date=\"1032811587\" format=\"1.0\" version=\"1.1\"}%
%ACTION{who=ActorFive,due=\"22-jun-2001\",notify=Main.ActorFive}% A7: Date change
%ACTION{who=\"Main.ActorFour\",due=\"22-jul-2001\",notify=ActorFive}% A8: Text change
\@
");
  }

  sub testANotifyLate {
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    ActionTrackerPlugin::ActionNotify::actionNotify( "late" );
    if(scalar(@TWiki::Net::sent)!= 8) {
      while ( $html = shift(@TWiki::Net::sent)) {
	$html =~ m/^(To: .*)$/m;
	print "$1\n";
      }
      Assert::equals(scalar(@TWiki::Net::sent), 8);
    }
    my $html;

    my $ok = "";
    while ( $html = shift(@TWiki::Net::sent)) {
      Assert::assert($html !~ /A[12]:/, $html);
      #Assert::assert($html !~ /^To: (.*),/os);
      #$html =~ /To: (.*)/;
      #print STDERR "Shebang $1\n";
      if ($html =~ /To: actor-1\@an-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "A";
      } elsif ($html =~ /To: actorTwo\@another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html =~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "B";
      } elsif ($html =~ /To: actor3\@yet-another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html =~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "C";
      } elsif ($html =~ /To: actorfour\@yet-another-address\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html =~ /A4:/,$html);
	Assert::assert($html =~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "D";
      } elsif ($html =~ /To: actor5\@correct.address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "E";
      } elsif ($html =~ /To: actor6\@correct-address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	$ok .= "F";
      } elsif ($html =~ /To: actor\.7\@seven\.net/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
	$ok .= "G";
      } elsif ($html =~ /To: actor-8\@correct\.address/) {
	Assert::assert($html =~ /A3:/,$html);
	Assert::assert($html !~ /A4:/,$html);
	Assert::assert($html !~ /A5:/,$html);
	Assert::assert($html =~ /A6:/,$html);
	Assert::assert($html !~ /A7:/,$html);
	Assert::assert($html !~ /A8:/,$html);
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

  sub testBChangedSince {
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    ActionTrackerPlugin::ActionNotify::actionNotify( "changedsince=\"1 dec 2001\"" );
    Assert::equals(scalar(@TWiki::Net::sent), 3);
    my $saw = "";
    while( $html = shift(@TWiki::Net::sent) ) {
      Assert::sContains($html, "From: mailsender");
      Assert::sContains($html, "Subject: Changes to actions on WIKITOOLNAME");
      if ($html=~ /To: actor5\@correct.address/) {
	Assert::sContains($html, "Subject: Changes to actions on WIKITOOLNAME");
	Assert::sContains($html, "Changes to actions since Sat Dec  1 00:00:00 2001");
	Assert::sContains($html, "Attribute \"due\" changed, was \"Fri, 22 Jun 2001 (LATE)\", now \"Sat, 22 Jun 2002\"");
	$saw .= "A";
      } elsif ($html =~ /To: actor6\@correct-address/) {
	Assert::assert($html !~ /A[1234567]:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"");
	Assert::htmlContains($html, "<tr><td>text</td><td> A8: Text change</td><td> A8: Text change from original, late</td></tr>");
	$saw .= "B";
      } elsif ($html =~ /To: actor-8\@correct.address/) {
	Assert::assert($html !~ /A[1234567]:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"");
	Assert::htmlContains($html, "<tr><td>text</td><td> A8: Text change</td><td> A8: Text change from original, late</td></tr>");
	$saw .= "C";
      } else {
	Assert::assert(0, "Not good $html");
      }
    }
    Assert::equals(length($saw), 3, $saw);
    Assert::sContains($saw, "A");
    Assert::sContains($saw, "B");
    Assert::sContains($saw, "C");
  }

  # should notify A8, to Actor6 and Actor8, A7 to Actor5 and
  # A8 to Actor 6 late
  sub testCNotifyLateAndChanged {
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    ActionTrackerPlugin::ActionNotify::actionNotify( "due=22-Jul-2001,changedsince=\"1 dec 2001\"" );
    Assert::equals(scalar(@TWiki::Net::sent), 3);
    my $html;

    my $ok = "";
    while ( $html = shift(@TWiki::Net::sent)) {
      if ($html =~ /To: actor6\@correct-address/) {
	Assert::assert($html !~ /A[1234567]:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Action for Main.ActorSix, due Sun, 22 Jul 2001 (LATE), open");
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"");
	$ok .= "A";
	# deconstruct
	$html =~ /.*?attention follow:(.*?)Changes to.*?with the action\.(.*?)For help /so;
	my $acts = $1;
	my $chgs = $2;
	$acts =~ s/Action for Main.ActorSix, due Sun, 22 Jul 2001 \(LATE\), open//so;
	$acts =~ s/A8: Text change from original, late//so;
	$chgs =~ s/Action for Main.ActorSix, due Sun, 22 Jul 2001 \(LATE\), open//so;
	$chgs =~ s/- Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"//so;
	$chgs =~ s/A8: Text change from original, late//so;
	$acts =~ s/\s+//so;
	Assert::sEquals($acts,"");
	$chgs =~ s/\s+//so;
	Assert::sEquals($chgs,"");
      } elsif ($html =~ /To: actor-8\@correct\.address/) {
	Assert::assert($html !~ /A[1234567]:/,$html);
	Assert::assert($html =~ /A8:/,$html);
	Assert::sContains($html, "Action for Main.ActorSix, due Sun, 22 Jul 2001 (LATE), open");
	Assert::sContains($html, "Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"");
	$ok .= "B";
      } elsif ($html=~ /To: actor5\@correct.address/) {
	Assert::sContains($html, "Subject: Changes to actions on WIKITOOLNAME");
	Assert::sContains($html, "Changes to actions since Sat Dec  1 00:00:00 2001");
	Assert::sContains($html, "Attribute \"due\" changed, was \"Fri, 22 Jun 2001 (LATE)\", now \"Sat, 22 Jun 2002\"");
	$ok .= "C";
      } else {
	Assert::assert(0, $html);
      }
    }
    Assert::equals(length($ok),3);
    Assert::sContains($ok, "A");
    Assert::sContains($ok, "B");
    Assert::sContains($ok, "C");
  }

  sub testAAddressExpansion {
    my %ma = (
	      'Main.BonzoClown' => "bonzo\@circus.com",
	      'Main.BimboChimp' => "bimbo\@zoo.org",
	      'Main.PaxoHen' => "chicken\@farm.net"
	     );
    my $who =
      ActionTrackerPlugin::ActionNotify::_getMailAddress("a\@b.c",\%ma);
    Assert::sEquals($who, "a\@b.c");

    $who =
      ActionTrackerPlugin::ActionNotify::_getMailAddress("Main.BimboChimp",\%ma);
    Assert::sEquals($who, "bimbo\@zoo.org");

    $who =
      ActionTrackerPlugin::ActionNotify::_getMailAddress("BimboChimp",\%ma);
    Assert::sEquals($who, "bimbo\@zoo.org");

    $who =
      ActionTrackerPlugin::ActionNotify::_getMailAddress("PaxoHen,BimboChimp , BonzoClown",\%ma);
    Assert::sEquals($who, "chicken\@farm.net,bimbo\@zoo.org,bonzo\@circus.com");

    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorOne",\%ma);
    Assert::sEquals($who, "actor-1\@an-address.net");

    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("EMailGroup",\%ma);
    Assert::sEquals($who, "actorTwo\@another-address.net,actorfour\@yet-another-address.net");
    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("TWikiFormGroup",\%ma);
    Assert::sEquals($who, "actor3\@yet-another-address.net,actorfour\@yet-another-address.net");

    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
    Assert::assert(!defined($who),$who);
    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
    Assert::assert(!defined($who));
    ActionTrackerPlugin::ActionNotify::_loadWebNotify("Main",\%ma);
    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
    Assert::sEquals($who, "actor5\@correct.address");
    ActionTrackerPlugin::ActionNotify::_loadWebNotify("Test",\%ma);
    $who = ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
    Assert::sEquals($who, "actor-8\@correct.address");
  }
}

1;
