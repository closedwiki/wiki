# Tests for module Action.pm
use strict;

package ActionTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Contrib::Attrs;
use Time::ParseDate;
use CGI;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();
  ActionTrackerPlugin::Action::forceTime("31 May 2002");
}

sub testNewNoState {
  my $this = shift;

  # no state -> first state
  my $action = new ActionTrackerPlugin::Action("Test","Topic",0,"", "");
  $this->assert_str_equals("open", $action->{state});
  # closed defined -> closed state
  $action = new ActionTrackerPlugin::Action("Test","Topic",0,"closed", "");
  $this->assert_str_equals("closed", $action->{state});
  $action =
	new ActionTrackerPlugin::Action("Test","Topic",0,"closed=10-may-05", "");
  $this->assert_str_equals("closed", $action->{state});
  $action =
	ActionTrackerPlugin::Action->new("Test","Topic",0,"closer=Flicka", "");
  $this->assert_str_equals("open", $action->{state});
  # state def overrides closed defined
  $action =
	new ActionTrackerPlugin::Action("Test","Topic",0,"",
									"closed,state=\"open\"");
  $this->assert_str_equals("open", $action->{state});
}

sub testNewIgnoreAttrs {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action("Test","Topic2",0,
									"web=Wrong,topic=Wrong web=Right", "");
  $this->assert_str_equals("Test", $action->{web});
  $this->assert_str_equals("Topic2", $action->{topic});
}

sub testIsLateAndDaysToGo {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action("Test","Topic",0,
									"who=\"Who\" due=\"2 Jun 02\" open", "");
  $this->assert(!$action->isLate());
  $this->assert_num_equals(2, $action->daysToGo());
  ActionTrackerPlugin::Action::forceTime("1 Jun 2002 24:59:59");
  $this->assert(!$action->isLate());
  $this->assert_num_equals(0, $action->daysToGo());
  ActionTrackerPlugin::Action::forceTime("2 Jun 2002 00:00:01");
  $this->assert($action->isLate());
  $this->assert_num_equals(-1, $action->daysToGo());
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002 00:00:01");
  $this->assert($action->isLate());
  $this->assert_num_equals(-1, $action->daysToGo());
  ActionTrackerPlugin::Action::forceTime("4 Jun 2002 00:00:01");
  $this->assert($action->isLate());
  $this->assert_num_equals(-2, $action->daysToGo());
  $action = new
	ActionTrackerPlugin::Action("Test","Topic",0,
								"who=\"Who\" due=\"2 Jun 02\" closed", "");
  $this->assert(!$action->isLate());
}

sub testCommas {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action( "Test", "Topic", 0,
									 "who=\"JohnDoe, SlyStallone\",due=\"2 Jun 02\",notify=\"SamPeckinpah, QuentinTarantino\",creator=\"ThomasMoore\"", "Sod");
  $this->assert_str_equals("Main.JohnDoe, Main.SlyStallone", $action->{who});
  $this->assert_str_equals("Main.SamPeckinpah, Main.QuentinTarantino", $action->{notify});
}

sub testMatches {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action( "Test", "Topic", 0,
									 "who=\"JohnDoe,SlyStallone,TestRunner\" due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
  
  my $attrs = new TWiki::Contrib::Attrs("who=JohnDoe"); 
  $this->assert($action->matches($attrs),$attrs->toString());
  $attrs = new TWiki::Contrib::Attrs("who=Main.JohnDoe"); 
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("who=me"); 
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("who=JohnSmith"); 
  $this->assert(!$action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("who=Main.SlyStallone"); 
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("who"); 
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("notify=\"SamPeckinpah\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("notify=\"QuentinTarantino\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("notify=\"JonasSalk,QuentinTarantino\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("notify=\"SamBrowne,OscarWilde\"");
  $this->assert(!$action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("notify"); 
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("state=\"open\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("open");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("openday");
  $this->assert(!$action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("closed");
  $this->assert(!$action->matches($attrs));
  
  ActionTrackerPlugin::Action::forceTime("31 May 2002");
  $attrs = new TWiki::Contrib::Attrs("within=2");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("within=1");
  $this->assert(!$action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("late");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("web=Test");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("web=\".*t\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("web=\"A.*\"");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("topic=Topic");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("topic=\".*c\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("topic=\"A.*\"");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("due=\"2 Jun 02\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("due=\"3 Jun 02\"");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("creator=ThomasMoore");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("creator=QuentinTarantino");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("created=\"1-Jan-1999\"");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("created=\"2 Jun 02\"");
  $this->assert(!$action->matches($attrs));
  
  $attrs = new TWiki::Contrib::Attrs("closed=\"2 Jun 02\"");
  $this->assert(!$action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("closed=\"1 Jan 1999\"");
  $this->assert(!$action->matches($attrs));
  
  # make it late
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  $attrs = new TWiki::Contrib::Attrs("late");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("within=1");
  $this->assert($action->matches($attrs), $action->secsToGo());
  
  # now again, only closed
  $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0, "who=\"JohnDoe,SlyStallone\",due=\"2 Jun 02\" closed=\"2 Dec 00\" closer=\"Death\" notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
  $attrs = new TWiki::Contrib::Attrs("closed");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("closer=Death");
  $this->assert($action->matches($attrs));
  $attrs = new TWiki::Contrib::Attrs("open");
  $this->assert(!$action->matches($attrs));
}

sub testStringFormattingOpen {
  my $this = shift;

  my $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0, "who=\"JohnDoe\" due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
  my $fmt = new ActionTrackerPlugin::Format("|Who|Due|","|\$who|","","Who: \$who \$who","\$who,\$due");
  my $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Who: Main.JohnDoe Main.JohnDoe\n",$s,$fmt->toString());
  $fmt = new ActionTrackerPlugin::Format("","","","Due: \$due");
  # make it late
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Due: Sun, 2 Jun 2002 (LATE)\n", $s);
  # make it ontime
  ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Due: Sun, 2 Jun 2002\n", $s);
  # make it late again
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  $fmt = new ActionTrackerPlugin::Format("","","", "State: \$state\n");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("State: open\n\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "","Notify: \$notify\n");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Notify: Main.SamPeckinpah, Main.QuentinTarantino\n\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "", "\$creator");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals($s, "Main.ThomasMoore\n");
  $fmt = new ActionTrackerPlugin::Format("","", "","|\$created|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|Fri, 1 Jan 1999|\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "","|\$edit|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("||\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "","\$web.\$topic");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Test.Topic\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "", "Text \"\$text\"");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Text \"A new action\"\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","", "","|\$n\$n()\$nop()\$quot\$percnt\$dollar|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|\n\n\"%\$|\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","","","Who: \$who Creator: \$creator");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals($s,
				  "Who: Main.JohnDoe Creator: Main.ThomasMoore\n");
}

sub testStringFormattingClosed {
  my $this = shift;

  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\"closer=\"LucBesson\"", "A new action");
  my $fmt = new ActionTrackerPlugin::Format("","", "", "|\$closed|\$closer|");
  my $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals($s,
				  "|Wed, 1 Jan 2003|Main.LucBesson|\n");
}

sub testVerticalOrient {
  my $this = shift;

  ActionTrackerPlugin::Action::forceTime("31 May 2002");
  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
  my $fmt = new ActionTrackerPlugin::Format("|Who|Due|", "|\$who|\$due|", "rows");
  my $s = $fmt->formatHTMLTable([$action], "name", 0);
  
  $s =~ s/<table border=\"1\">//ios;
  $s =~ s/<\/table>//ios;
  $s =~ s/\n//g;
  $this->assert_str_equals("<a name=\"AcTion0\"></a><tr><th bgcolor=\"orange\">Who</th><td>Main.JohnDoe</td></tr><tr><th bgcolor=\"orange\">Due</th><td>Sun, 2 Jun 2002</td></tr>", $s);
}

sub testHTMLFormattingOpen {
  my $this = shift;

  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino, DavidLynch\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
  
  my $fmt = new ActionTrackerPlugin::Format("", "|\$who|");
  my $s = $fmt->formatHTMLTable([$action], "name", 0);
  $this->assert_html_matches("<a name=\"AcTion0\"><\/a><td>Main.JohnDoe</td>", $s);
  $fmt = new ActionTrackerPlugin::Format("", "| \$due |");
  # make it late
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td bgcolor=\"yellow\"> Sun, 2 Jun 2002 </td>", $s);
  
  # make it ontime
  ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
  $fmt = new ActionTrackerPlugin::Format("", "| \$due |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Sun, 2 Jun 2002 </td>", $s);
  
  # Make it late again
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
  $fmt = new ActionTrackerPlugin::Format("", "| \$state |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> open </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$notify |");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Main.SamPeckinpah, Main.QuentinTarantino, Main.DavidLynch </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$uid |");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> &nbsp; </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$creator |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Main.ThomasMoore </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$created |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Fri, 1 Jan 1999 </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$edit |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  my $url= "%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic\\?skin=action&action=AcTion0&t=";
  $s =~ s/\n//g;
  my $r = ($s =~ s/<td> <a href="$url\d+">edit<\/a> <\/td>//);
  $this->assert($r, $s." is not ".$url);
  $fmt = new ActionTrackerPlugin::Format("", "| \$edit |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 1);
  $r = ($s =~ s/<td>\s*<a href="$url\d+" onClick="return editWindow\('$url\d+'\)">edit<\/a>\s*<\/td>//);
  $this->assert($r, $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$web.\$topic |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Test.Topic </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$text |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> A new action (<a href=\"http:\/\/twiki\/view.cgi\/Test\/Topic#AcTion0\">go to action</a>) </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "| \$n\$n()\$nop()\$quot\$percnt\$dollar |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> <br /><br />\"%\$ </td>", $s );
  
  ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
  $fmt = new ActionTrackerPlugin::Format("", "| \$due |", "");
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td> Sun, 2 Jun 2002 </td>", $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "|\$who|\$creator|", "");
  $s = $fmt->formatHTMLTable([$action], "name", 0);
  $this->assert_html_matches("<a name=\"AcTion0\"></a><td>Main.JohnDoe</td><td>Main.ThomasMoore</td>", $s
					);
}

sub testHTMLFormattingClose {
  my $this = shift;

  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\" closer=\"LucBesson\"", "A new action");
  my $fmt = new ActionTrackerPlugin::Format("", "|\$closed|\$closer|", "");
  my $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_html_matches("<td>Wed, 1 Jan 2003</td><td>Main.LucBesson</td>", $s
					);
}

sub testAutoPopulation {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action( "Test", "Topic", 7,
									 "state=closed", "A new action");
  ActionTrackerPlugin::Action::forceTime("31 May 2002");
  my $tim = Time::ParseDate::parsedate("31 May 2002");
  $action->populateMissingFields();
  my $fmt = new ActionTrackerPlugin::Format("","","","|\$uid|\$who|");
  my $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|000001|Main.TestRunner|\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","","","|\$creator|\$created|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|Main.TestRunner|Fri, 31 May 2002|\n", $s);
  $fmt = new ActionTrackerPlugin::Format("","","","|\$closer|\$closed|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|Main.TestRunner|Fri, 31 May 2002|\n", $s);
  $action =
	new ActionTrackerPlugin::Action( "Test", "Topic", 8,
									 "who=me", "action");
  $action->populateMissingFields();
  $fmt = new ActionTrackerPlugin::Format("","","","|\$who|\$due|");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("|Main.TestRunner|Fri, 31 May 2002|\n", $s);
}

sub testToString {
  my $this = shift;

  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 5, "due=\"2 Jun 02\" state=closed", "A new action");
  ActionTrackerPlugin::Action::forceTime("30 Sep 2001");
  $action->populateMissingFields();
  my $s = $action->toString();
  $s =~ s/ uid=\"\d+\"//o;
  $s =~ s/ created=\"30-Sep-2001\"//o;
  $s =~ s/ creator=\"Main\.TestRunner\"//o;
  $s =~ s/ who=\"Main\.TestRunner\"//o;
  $s =~ s/ due=\"2-Jun-2002\"//o;
  $s =~ s/ closed=\"30-Sep-2001\"//o;
  $s =~ s/ closer=\"Main\.TestRunner\"//o;
  $s =~ s/ state=\"closed\"//o;
  $this->assert_str_equals("%ACTION{ }% A new action", $s);
  
  $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 9, "due=\"2 Jun 06\" state=open", "Another new action<br/>EOF");
  $action->populateMissingFields();
  $s = $action->toString();
  $this->assert_matches(qr/% <<EOFF\nAnother new action\nEOF\nEOFF$/, $s);
}

sub testFindByUID {
  my $this = shift;

  my $text = "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo\r
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF
AFour
EOF";
  
  my ($action,$pre,$post) = 
	ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
												 $text, "AaAa");
  $this->assert_str_equals($action->{text}, "AOne");
  $this->assert_str_equals($pre,"
");
  $this->assert_str_equals($post,
				  "%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");
  ($action,$pre,$post) =
	ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
												 $text, "BbBb");
  $this->assert_str_equals($action->{text}, "ATwo");
  $this->assert_str_equals($pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
");
  $this->assert_str_equals($post,"%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");
  ($action,$pre,$post) =
	ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
												 $text, "AcTion2");
  $this->assert_str_equals($action->{text}, "AThree");
  $this->assert_str_equals($pre,"
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
");
  $this->assert_str_equals($post, "%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");
  
  ($action,$pre,$post) =
	ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
												 $text, "DdDd");
  $this->assert_str_equals($action->{text}, "AFour");
  $this->assert_str_equals($pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
");
  $this->assert_str_equals($post,"");
}

sub testFindChanges {
  my $this = shift;

  my $oaction = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\"", "A new action");
  
  my $naction = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JaneDoe due=\"2 Jun 09\" state=closed notify=\"SamPeckinpah,QuentinTarantino\" creator=\"ThomasMoore\"", "A new action<p>with more text");
  
  my $s = "|\$who|\$due|\$state|\$creator|\$created|\$text|";
  my $fmt = new ActionTrackerPlugin::Format($s,$s,"cols",$s,"\$who,\$due,\$state,\$created,\$creator,\$text");
  my %not = ();
  $naction->findChanges($oaction, $fmt, \%not);
  my $text = $not{"Main.SamPeckinpah"}{text};
  $this->assert_matches(qr/\|Main.JaneDoe\|Tue, 2 Jun 2009\|closed\|Main.ThomasMoore\|/, $text);
  $this->assert_matches(qr/\|A new action<p>with more text\|/, $text);
  $this->assert_matches(qr/Attribute \"state\" changed, was \"open\", now \"closed\"/, $text);
  $this->assert_matches(qr/Attribute \"due\" changed, was \"Sun, 2 Jun 2002\", now \"Tue, 2 Jun 2009\"/, $text);
  $this->assert_matches(qr/Attribute \"text\" changed, was \"A new action\", now \"A new action<p>with more text\"/, $text);
  $this->assert_matches(qr/Attribute \"created\" was \"Fri, 1 Jan 1999\" now removed/, $text);
  $this->assert_matches(qr/Attribute \"creator\" added with value \"Main.ThomasMoore\"/, $text);
  
  $text = $not{"Main.QuentinTarantino"}{html};
  my $jane = $fmt->formatHTMLTable([$naction],"href",0);
  $this->assert_html_matches($jane, $text);
  $this->assert_html_matches("<tr><td>who</td><td>Main.JohnDoe</td><td>Main.JaneDoe</td></tr>", $text);
  $this->assert_html_matches("<tr><td>due</td><td>Sun, 2 Jun 2002</td><td>Tue, 2 Jun 2009</td></tr>", $text);
  $this->assert_html_matches("<tr><td>state</td><td>open</td><td>closed</td></tr>", $text);
  $this->assert_html_matches("<tr><td>created</td><td>Fri, 1 Jan 1999</td><td> *removed* </td></tr>", $text);
  $this->assert_html_matches("<tr><td>creator</td><td> *missing* </td><td>Main.ThomasMoore</td></tr>", $text);
  $this->assert_html_matches("<tr><td>text</td><td>A new action</td><td>A new action<p>with more text</td></tr>", $text);
}

sub testXtendTypes {
  my $this = shift;

  my $s = ActionTrackerPlugin::Action::extendTypes("| plaintiffs,names,16| decision, text, 16|sentencing,date|sentence,select,17,life,\"5 years\",\"community service\"|");
  $this->assert(!defined($s), $s);
  
  my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open,plaintiffs=\"fred.bloggs\@limp.net,JoeShmoe\",decision=\"cut off their heads\" sentencing=2-mar-2006 sentence=\"5 years\"", "A court action");
  
  $s = $action->toString();
  $s =~ s/ who=\"Main.JohnDoe\"//o;
  $s =~ s/ A court action//o;
  $s =~ s/ state=\"open\"//o;
  $s =~ s/ due=\"2-Jun-2002\"//o; 
  $s =~ s/ plaintiffs=\"fred.bloggs\@limp.net, Main.JoeShmoe\"//o;
  $s =~ s/ decision=\"cut off their heads\"//o;
  $s =~ s/ who=\"Main\.TestRunner\"//o;
  $s =~ s/ sentencing=\"2-Mar-2006\"//o;
  $s =~ s/ sentence=\"5 years\"//o;
  $this->assert_str_equals("%ACTION{ }%", $s);
  
  my $fmt = new ActionTrackerPlugin::Format("", "|\$plaintiffs|","","\$plaintiffs");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("fred.bloggs\@limp.net, Main.JoeShmoe\n", $s);
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_matches(qr/<td>fred.bloggs\@limp.net, Main.JoeShmoe<\/td>/, $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "|\$decision|","","\$decision");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("cut off their heads\n", $s);
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_matches(qr/<td>cut off their heads<\/td>/, $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "|\$sentence|","","\$sentence");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("5 years\n", $s);
  $s = $fmt->formatHTMLTable([$action], "href", 0);
  $this->assert_matches(qr/<td>5 years<\/td>/, $s );
  
  $fmt = new ActionTrackerPlugin::Format("", "","","\$sentencing");
  $s = $fmt->formatStringTable([$action]);
  $this->assert_str_equals("Thu, 2 Mar 2006\n", $s);
  
  my $attrs = TWiki::Contrib::Attrs->new("sentence=\"5 years\"");
  $this->assert($action->matches($attrs));
  $attrs = TWiki::Contrib::Attrs->new("sentence=\"life\"");
  $this->assert(!$action->matches($attrs));
  $attrs = TWiki::Contrib::Attrs->new("sentence=\"\\d+ years\"");
  $this->assert($action->matches($attrs));
  
  $s = ActionTrackerPlugin::Action::extendTypes("|state,select,17,life,\"5 years\",\"community service\"|");
  $this->assert(!defined($s),$s);
  ActionTrackerPlugin::Action::unextendTypes();
  $s = ActionTrackerPlugin::Action::extendTypes("|who,text,17|");
  $this->assert_str_equals($s,"Attempt to redefine attribute 'who' in EXTRAS" );
  $s = ActionTrackerPlugin::Action::extendTypes("|fleegle|");
  $this->assert_str_equals($s,"Bad EXTRAS definition 'fleegle' in EXTRAS" );
  ActionTrackerPlugin::Action::unextendTypes();
}

sub testCreateFromQuery {
  my $this = shift;

  my $query = new CGI ("");
  $query->param( changedsince => "1 May 2003");
  $query->param( closed       => "2 May 2003");
  $query->param( closer       => "Closer");
  $query->param( created      => "3 May 2003");
  $query->param( creator      => "Creator");
  $query->param( dollar       => 1);
  $query->param( due          => "4 May 2003");
  $query->param( edit         => 1);
  $query->param( format       => 1);
  $query->param( header       => 1);
  $query->param( late         => 1);
  $query->param( n            => 1);
  $query->param( nop          => 1);
  $query->param( notify       => "Notifyee");
  $query->param( percnt       => 1);
  $query->param( quot         => 1);
  $query->param( sort         => 1);
  $query->param( state        => "open" );
  $query->param( text         => "Text");
  $query->param( topic        => "BadTopic");
  $query->param( uid          => "UID");
  $query->param( web          => "BadWeb");
  $query->param( who          => "Who");
  $query->param( within       => 2);
  $query->param( ACTION_NUMBER=> -99);
  my $action =
	ActionTrackerPlugin::Action::createFromQuery("Web","Topic",10,$query);
  my $chosen = $action->toString();
  $chosen =~ s/ state=\"open\"//o;
  $chosen =~ s/ creator=\"Main.Creator\"//o;
  $chosen =~ s/ notify=\"Main.Notifyee\"//o;
  $chosen =~ s/ closer=\"Main.Closer\"//o;
  $chosen =~ s/ due=\"4-May-2003\"//o;
  $chosen =~ s/ closed=\"2-May-2003\"//o;
  $chosen =~ s/ who=\"Main.Who\"//o;
  $chosen =~ s/ created=\"3-May-2003\"//o;
  $chosen =~ s/ uid=\"UID\"//o;
  $this->assert_str_equals($chosen, "%ACTION{ }% Text");
}

sub testFormatForEditHidden {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action("Web", "Topic", 9,
									"state=\"open\" creator=\"Main.Creator\" notify=\"Main.Notifyee\" closer=\"Main.Closer\" due=\"4-May-2003\" closed=\"2-May-2003\" who=\"Main.Who\" created=\"3-May-2003\" uid=\"UID\"", "Text");
  my $fmt = new ActionTrackerPlugin::Format( "|Who|", "|\$who|", "cols","","");
  my $s = $action->formatForEdit($fmt);
  # only the who field should be a text; the rest should be hiddens
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"state\" VALUE=\"open\">//io;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"creator\" VALUE=\"Main\.Creator\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"notify\" VALUE=\"Main\.Notifyee\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"closer\" VALUE=\"Main\.Closer\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"due\" VALUE=\"Sun, 4 May 2003\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"closed\" VALUE=\"Fri, 2 May 2003\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"created\" VALUE=\"Sat, 3 May 2003\">//o;
  $s =~ s/<INPUT TYPE=\"hidden\" NAME=\"uid\" VALUE=\"UID\">//o;
  $this->assert_does_not_match(qr/NAME=\"text\"/i, $s);
  $this->assert_does_not_match(qr/TYPE=\"hidden\"/i, $s);
}

sub testFormatForEdit {
  my $this = shift;

  my $action =
	new ActionTrackerPlugin::Action("Web", "Topic", 9,
									"state=\"open\" creator=\"Main.Creator\" notify=\"Main.Notifyee\" closer=\"Main.Closer\" due=\"4-May-2003\" closed=\"2-May-2003\" who=\"Main.Who\" created=\"3-May-2003\" uid=\"UID\"", "Text");
  my $expand = "closed|creator|closer|created|due|notify|uid|who";
  my $noexpand = "changedsince|dollar|edit|format|header|late|n|nop|percnt|quot|sort|text|topic|web|within|ACTION_NUMBER";
  my $all = "|state|$expand|$noexpand|";
  my $bods = $all;
  $bods =~ s/(\w+)/\$$1/go;
  
  my $fmt = new ActionTrackerPlugin::Format( $all, $bods, "","");
  my $s = $action->formatForEdit($fmt);
  foreach my $n (split(/\|/,$noexpand)) {
	$this->assert($s =~ s/<th>$n<\/th>//, "$n in $s");
	$n = "\\\$" if ( $n eq "dollar" );
	$n = "<br />" if ( $n eq "n" );
	$n = "" if ( $n eq "nop" );
	$n = "%" if ( $n eq "percnt" );
	$n = "\"" if ( $n eq "quot" );
	$this->assert($s =~ s/<td>$n<\/td>//s, $n);
  }
  $this->assert($s =~ s/<th>state<\/th>//);
  foreach my $n (split(/\|/,$expand)) {
	$this->assert($s =~ s/<th>$n<\/th>//, $n);
    my $r;
    eval '$r = TWiki::Contrib::JSCalendarContrib::VERSION';
    if ($r && ($n eq "closed" || $n eq "due" || $n eq "created")) {
      $s = $this->assert_html_matches("<td><input type=\"text\" name=\"$n\" value=\"\" size=\"\" id=\"date_$n\"/><a onclick=\"return showCalendar\('date_$n', '\%e \%B \%Y'\)\"><img src=\"%PUBURL%/%TWIKIWEB%/JSCalendarContrib/img.gif\"/></a></td>", $s);
    } else {
      $s = $this->assert_html_matches("<td><input type=\"text\" name=\"$n\" value=\"{*.*?*}\" size=\"{*.*?*}\"/></td>", $s);
    }
  }
  $s = $this->assert_html_matches("<td><SELECT NAME=\"state\" SIZE=\"1\"><OPTION NAME=\"open\" SELECTED>open<\/OPTION><OPTION NAME=\"closed\">closed<\/OPTION><\/SELECT><\/td>", $s);
  $s = $this->assert_html_matches("<table border=\"1\">", $s);
  $s =~ s/<tr( bgcolor=\"orange\")?>//gom;
 $s = $this->assert_html_matches("<tr valign=\"top\">", $s);
  $s =~ s/<\/?(tr|table)>//gom;
  $this->assert_matches(qr/^\s*$/, $s);
  
  $action =
	new ActionTrackerPlugin::Action("Web", "Topic", 9,
									"state=\"open\" due=\"4-May-2001\"", "Test");
  ActionTrackerPlugin::Action::forceTime("31 May 2002");
  $fmt = new ActionTrackerPlugin::Format( "|Due|", "|\$due|", "","");
  $s = $action->formatForEdit($fmt);
  $s =~ /VALUE=\"(.*?)\"/;
  $this->assert_str_equals($1, "Fri, 4 May 2001");
}

sub testExtendStates {
  my $this = shift;

  my $s = ActionTrackerPlugin::Action::extendTypes("|state,select,17,life,\"5 years\",\"community service\"|");
  $this->assert(!defined($s));
  my $action =
	new ActionTrackerPlugin::Action("Web", "Topic", 10,
									"state=\"5 years\"", "Text");
  my $fmt = new ActionTrackerPlugin::Format( "|State|", "|\$state|", "","");
  $s = $action->formatForEdit($fmt);
  $s =~ s/\n/ /g;
  $s =~ s/<OPTION NAME=\"life\">life<\/OPTION>//i;
  $s =~ s/<OPTION NAME=\"5 years\" SELECTED>5 years<\/OPTION>//i;
  $s =~ s/<OPTION NAME=\"community service\">community service<\/OPTION>//i;
  $s =~ s/<SELECT NAME=\"state\" SIZE=\"17\">\s*<\/SELECT>//i;
  $s =~ s/<\/?table.*?>//gio;
  $s =~ s/<\/?tr.*?>//gio;
  $s =~ s/<\/?t[hd].*?>//gio;
  $s =~ s/<INPUT TYPE=\"hidden\".*?>//gio;
  $s =~ s/\s+//go;
  $this->assert_str_equals("State", $s);
  ActionTrackerPlugin::Action::unextendTypes();
}

1;
