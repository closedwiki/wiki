use strict;

package ActionNotifyTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;
use TWiki::Contrib::Attrs;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();
  
  BaseFixture::loadPreferencesFor("ActionTrackerPlugin");
  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  @TWiki::Net::sent = ();

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
  
  BaseFixture::writeTopic("Main", "ActorOne", "
   * Email: actor-1\@an-address.net
");
  BaseFixture::writeTopic("Main", "ActorTwo", "
   * Email: actorTwo\@another-address.net
");
  BaseFixture::writeTopic("Main", "ActorThree", "
   * Email: actor3\@yet-another-address.net
");
  BaseFixture::writeTopic("Main", "ActorFour", "
   * E-mail: actorfour\@yet-another-address.net
");
  BaseFixture::writeTopic("Main", "ActorFive", "
   * NoE-mailhere: actor5\@wrong-address
");
  BaseFixture::writeTopic("Main", "ActorSix", "
   * E-mail: actor6\@correct-address
");
  BaseFixture::writeTopic("Main", "TWikiFormGroup", "
Garbage
\t\t* Set GROUP = ActorThree, ActorFour
More garbage
");
  BaseFixture::writeTopic("Main", "WebNotify", "
Garbage
   * Main.ActorFive - actor5\@correct.address
More garbage
   * Main.ActorSix
");
  BaseFixture::writeTopic("Test", "WebNotify", "
   * Main.ActorEight - actor-8\@correct.address
");
  BaseFixture::writeTopic("Main", "EMailGroup", "
   * Set GROUP = actorTwo\@another-address.net,ActorFour
");
  
  BaseFixture::writeTopic("Test", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,ActorSeven,ActorEight\" due=\"3 Jan 02\" state=open}% A1: ontime");
  BaseFixture::writeTopic("Test", "Topic2", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight\" due=\"2 Jan 02\" state=closed}% A2: closed");
  BaseFixture::writeTopic("Main", "Topic1", "
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7\@seven.net,ActorEight,NonEntity\",due=\"3 Jan 01\",state=open}% A3: late
%ACTION{who=TWikiFormGroup,due=\"4 Jan 01\",state=open}% A4: late ");
  BaseFixture::writeTopic("Main", "Topic2", "
%ACTION{who=EMailGroup,due=\"5 Jan 01\",state=open}% A5: late
%ACTION{who=\"ActorOne,ActorTwo,ActorThree,ActorFour,TWikiFormGroup,ActorFive,ActorSix,actor.7\@seven.net,ActorEight,EMailGroup\",due=\"6 Jan 99\",open}% A6: late");
  
  # Action changes are hard to fake because the RCS histories are not there.
  BaseFixture::writeRcsTopic("Test", "ActionChanged",
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

sub test_A_AddressExpansion {
  my $this = shift;
  my %ma = (
			'Main.BonzoClown' => "bonzo\@circus.com",
			'Main.BimboChimp' => "bimbo\@zoo.org",
			'Main.PaxoHen' => "chicken\@farm.net"
		   );
  my $who =
	TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("a\@b.c",\%ma);
  $this->assert_str_equals( "a\@b.c", $who);
  
  $who =
	TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("Main.BimboChimp",\%ma);
  $this->assert_str_equals( "bimbo\@zoo.org", $who);
  
  $who =
	TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("BimboChimp",\%ma);
  $this->assert_str_equals( "bimbo\@zoo.org", $who);
  
  $who =
	TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("PaxoHen,BimboChimp , BonzoClown",\%ma);
  $this->assert_str_equals( "chicken\@farm.net,bimbo\@zoo.org,bonzo\@circus.com", $who);
  
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorOne",\%ma);
  $this->assert_str_equals( "actor-1\@an-address.net", $who);
  
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("EMailGroup",\%ma);
  $this->assert_str_equals( "actorTwo\@another-address.net,actorfour\@yet-another-address.net", $who);
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("TWikiFormGroup",\%ma);
  $this->assert_str_equals( "actor3\@yet-another-address.net,actorfour\@yet-another-address.net", $who);
  
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
  $this->assert_null($who);
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
  $this->assert_null($who);
  TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_loadWebNotify("Main",\%ma);
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
  $this->assert_str_equals( "actor5\@correct.address", $who);
  TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_loadWebNotify("Test",\%ma);
  $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
  $this->assert_str_equals( "actor-8\@correct.address", $who);
}

sub test_B_NotifyLate {
  my $this = shift;
  my $html;
  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
  TWiki::Plugins::ActionTrackerPlugin::ActionNotify::actionNotify( "late" );
  if(scalar(@TWiki::Net::sent)!= 8) {
	my $mess = "";
	while ( $html = shift(@TWiki::Net::sent)) {
	  $html =~ m/^(To: .*)$/m;
	  $mess .= "$1\n";
	}
	$this->assert(0, $mess);
  }
  
  my $ok = "";
  while ( $html = shift(@TWiki::Net::sent)) {
	$this->assert_does_not_match(qr/A[12]:/, $html, $html);
	#print STDERR "Shebang $1\n";
	if ($html =~ /To: actor-1\@an-address\.net/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "A";
	} elsif ($html =~ /To: actorTwo\@another-address\.net/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_matches(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "B";
	} elsif ($html =~ /To: actor3\@yet-another-address\.net/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_matches(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "C";
	} elsif ($html =~ /To: actorfour\@yet-another-address\.net/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_matches(qr/A4:/,$html, $html);
	  $this->assert_matches(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "D";
	} elsif ($html =~ /To: actor5\@correct.address/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "E";
	} elsif ($html =~ /To: actor6\@correct-address/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_matches(qr/A8:/,$html, $html);
	  $ok .= "F";
	} elsif ($html =~ /To: actor\.7\@seven\.net/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "G";
	} elsif ($html =~ /To: actor-8\@correct\.address/) {
	  $this->assert_matches(qr/A3:/,$html, $html);
	  $this->assert_does_not_match(qr/A4:/,$html, $html);
	  $this->assert_does_not_match(qr/A5:/,$html, $html);
	  $this->assert_matches(qr/A6:/,$html, $html);
	  $this->assert_does_not_match(qr/A7:/,$html, $html);
	  $this->assert_does_not_match(qr/A8:/,$html, $html);
	  $ok .= "H";
	} else {
	  $this->assert(0, $html);
	}
  }
  $this->assert_num_equals(8, length($ok));
  $this->assert_matches(qr/A/, $ok);
  $this->assert_matches(qr/B/, $ok);
  $this->assert_matches(qr/C/, $ok);
  $this->assert_matches(qr/D/, $ok);
  $this->assert_matches(qr/E/, $ok);
  $this->assert_matches(qr/F/, $ok);
  $this->assert_matches(qr/G/, $ok);
  $this->assert_matches(qr/H/, $ok);
}

sub test_C_ChangedSince {
  my $this = shift;
  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
  TWiki::Plugins::ActionTrackerPlugin::ActionNotify::actionNotify( "changedsince=\"1 dec 2001\"" );
  my $saw = "";
  my $html;
  if(scalar(@TWiki::Net::sent)!= 3) {
	my $mess = "";
	while ( $html = shift(@TWiki::Net::sent)) {
	  $html =~ m/^(To: .*)$/m;
	  $mess .= "$1\n";
	}
	$this->assert(0, $mess);
  }
  while( $html = shift(@TWiki::Net::sent) ) {
	my $re = qr/From: wiki_web_master/;
	$this->assert_matches($re, $html);
	$re = qr/Subject: Changes to actions on wiki_tool_name/;
	$this->assert_matches($re, $html);
	if ($html=~ /To: actor5\@correct.address/) {
	  $re = qr/Subject: Changes to actions on wiki_tool_name/;
	  $this->assert_matches($re, $html);
	  $re = qr/Changes to actions since Sat Dec  1 00:00:00 2001/;
	  $this->assert_matches($re, $html);
	  $re = qr/Attribute \"due\" changed, was \"Fri, 22 Jun 2001 \(LATE\)\", now \"Sat, 22 Jun 2002\"/;
	  $this->assert_matches($re, $html);
	  $saw .= "A";
	} elsif ($html =~ /To: actor6\@correct-address/) {
	  $this->assert_does_not_match(qr/A[1234567]:/,$html, $html);
	  $this->assert_matches(qr/A8:/,$html, $html);
	  $re = qr/Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"/;
	  $this->assert_matches($re, $html);
	  $this->assert_html_matches("<tr><td>text</td><td>A8: Text change</td><td>A8: Text change from original, late</td></tr>", $html);
	  $saw .= "B";
	} elsif ($html =~ /To: actor-8\@correct.address/) {
	  $this->assert_does_not_match(qr/A[1234567]:/,$html, $html);
	  $this->assert_matches(qr/A8:/,$html, $html);
	  $this->assert_matches(qr/Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"/, $html);
	  $this->assert_html_matches("<tr><td>text</td><td>A8: Text change</td><td>A8: Text change from original, late</td></tr>", $html);
	  $saw .= "C";
	} else {
	  $this->assert(0, "Not good $html");
	}
  }
  $this->assert_num_equals(3, length($saw));
  $this->assert_matches(qr/A/, $saw);
  $this->assert_matches(qr/B/, $saw);
  $this->assert_matches(qr/C/, $saw);
}

# should notify A8, to Actor6 and Actor8, A7 to Actor5 and
# A8 to Actor 6 late
sub test_D_NotifyLateAndChanged {
  my $this = shift;
  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
  TWiki::Plugins::ActionTrackerPlugin::ActionNotify::actionNotify( "due=22-Jul-2001,changedsince=\"1 dec 2001\"" );
  my $html;
  
  my $ok = "";
  if(scalar(@TWiki::Net::sent)!= 3) {
	my $mess = "";
	while ( $html = shift(@TWiki::Net::sent)) {
	  $html =~ m/^(To: .*)$/m;
	  $mess .= "$1\n";
	}
	$this->assert(0, $mess);
  }
  while ( $html = shift(@TWiki::Net::sent)) {
	if ($html =~ /To: actor6\@correct-address/) {
	  $this->assert_does_not_match(qr/A[1234567]:/,$html, $html);
	  $this->assert_matches(qr/A8:/,$html);
	  $this->assert_matches(qr/Action for Main\.ActorSix, due Sun, 22 Jul 2001 \(LATE\), open/, $html);
	  $this->assert_matches(qr/Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"/, $html);
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
	  $this->assert_str_equals("", $acts);
	  $chgs =~ s/\s+//so;
	  $this->assert_str_equals("", $chgs);
	} elsif ($html =~ /To: actor-8\@correct\.address/) {
	  $this->assert_does_not_match(qr/A[1234567]:/,$html, $html);
	  $this->assert_matches(qr/A8:/,$html);
	  $this->assert_matches(qr/Action for Main.ActorSix, due Sun, 22 Jul 2001 \(LATE\), open/, $html);
	  $this->assert_matches(qr/Attribute \"text\" changed, was \"A8: Text change\", now \"A8: Text change from original, late\"/, $html);
	  $ok .= "B";
	} elsif ($html=~ /To: actor5\@correct.address/) {
	  $this->assert_matches(qr/Subject: Changes to actions on wiki_tool_name/, $html);
	  $this->assert_matches(qr/Changes to actions since Sat Dec  1 00:00:00 2001/, $html);
	  $this->assert_matches(qr/Attribute \"due\" changed, was \"Fri, 22 Jun 2001 \(LATE\)\", now \"Sat, 22 Jun 2002\"/, $html);
	  $ok .= "C";
	} else {
	  $this->assert(0, $html);
	}
  }
  $this->assert_num_equals(3, length($ok));
  $this->assert_matches(qr/A/, $ok);
  $this->assert_matches(qr/B/, $ok);
  $this->assert_matches(qr/C/, $ok);
}

1;
