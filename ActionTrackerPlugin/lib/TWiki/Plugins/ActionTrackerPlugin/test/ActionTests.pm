# Tests for module Action.pm
use lib ('fakewiki');
use lib ('.');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use Assert;
use Time::ParseDate;
require CGI;

{ package ActionTests;

  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
  }

  sub testNewNoState {
    # no state -> first state
    my $action = new ActionTrackerPlugin::Action("Test","Topic",0,"", "");
    Assert::sEquals($action->{state}, "open");
    # closed defined -> closed state
    $action = new ActionTrackerPlugin::Action("Test","Topic",0,"closed", "");
    Assert::sEquals($action->{state}, "closed");
    $action =
      new ActionTrackerPlugin::Action("Test","Topic",0,"closed=10-may-05", "");
    Assert::sEquals($action->{state}, "closed");
    $action =
      ActionTrackerPlugin::Action->new("Test","Topic",0,"closer=Flicka", "");
    Assert::sEquals($action->{state}, "open");
    # state def overrides closed defined
    $action =
      new ActionTrackerPlugin::Action("Test","Topic",0,"",
				      "closed,state=\"open\"");
    Assert::sEquals($action->{state}, "open");
  }

  sub testNewIgnoreAttrs {
    my $action =
      new ActionTrackerPlugin::Action("Test","Topic2",0,
				      "web=Wrong,topic=Wrong web=Right", "");
    Assert::sEquals($action->{web}, "Test");
    Assert::sEquals($action->{topic}, "Topic2");
  }

  sub testIsLateAndDaysToGo {
    my $action =
      new ActionTrackerPlugin::Action("Test","Topic",0,
				      "who=\"Who\" due=\"2 Jun 02\" open", "");
    ActionTrackerPlugin::Action::forceTime("31 May 2002");
    Assert::assert(!$action->isLate());
    Assert::equals($action->daysToGo(), 2);
    ActionTrackerPlugin::Action::forceTime("1 Jun 2002 24:59:59");
    Assert::assert(!$action->isLate());
    Assert::equals($action->daysToGo(), 0);
    ActionTrackerPlugin::Action::forceTime("2 Jun 2002 00:00:01");
    Assert::assert($action->isLate());
    Assert::equals($action->daysToGo(), -1);
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002 00:00:01");
    Assert::assert($action->isLate());
    Assert::equals($action->daysToGo(), -1);
    ActionTrackerPlugin::Action::forceTime("4 Jun 2002 00:00:01");
    Assert::assert($action->isLate());
    Assert::equals($action->daysToGo(), -2);
    $action = new
      ActionTrackerPlugin::Action("Test","Topic",0,
				  "who=\"Who\" due=\"2 Jun 02\" closed", "");
    Assert::assert(!$action->isLate());
  }

  sub testCommas {
    my $action =
      new ActionTrackerPlugin::Action( "Test", "Topic", 0,
				       "who=\"JohnDoe,SlyStallone\",due=\"2 Jun 02\",notify=\"SamPeckinpah,QuentinTarantino\",creator=\"ThomasMoore\"", "Sod");
    Assert::sEquals($action->{who},"Main.JohnDoe,Main.SlyStallone");
    Assert::sEquals($action->{notify},"Main.SamPeckinpah,Main.QuentinTarantino");
  }

  sub testMatches {
    my $action =
      new ActionTrackerPlugin::Action( "Test", "Topic", 0,
				       "who=\"JohnDoe,SlyStallone,TestRunner\" due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");

    my $attrs = new ActionTrackerPlugin::Attrs("who=JohnDoe"); 
    Assert::assert($action->matches($attrs),$attrs->toString());
    $attrs = new ActionTrackerPlugin::Attrs("who=Main.JohnDoe"); 
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("who=me"); 
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("who=JohnSmith"); 
    Assert::assert(!$action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("who=Main.SlyStallone"); 
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("who"); 
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("notify=\"SamPeckinpah\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("notify=\"QuentinTarantino\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("notify=\"JonasSalk,QuentinTarantino\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("notify=\"SamBrowne,OscarWilde\"");
    Assert::assert(!$action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("notify"); 
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("state=\"open\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("open");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("openday");
    Assert::assert(!$action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("closed");
    Assert::assert(!$action->matches($attrs));

    ActionTrackerPlugin::Action::forceTime("31 May 2002");
    $attrs = new ActionTrackerPlugin::Attrs("within=2");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("within=1");
    Assert::assert(!$action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("late");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("web=Test");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("web=\".*t\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("web=\"A.*\"");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("topic=Topic");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("topic=\".*c\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("topic=\"A.*\"");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("due=\"2 Jun 02\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("due=\"3 Jun 02\"");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("creator=ThomasMoore");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("creator=QuentinTarantino");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("created=\"1-Jan-1999\"");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("created=\"2 Jun 02\"");
    Assert::assert(!$action->matches($attrs));

    $attrs = new ActionTrackerPlugin::Attrs("closed=\"2 Jun 02\"");
    Assert::assert(!$action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("closed=\"1 Jan 1999\"");
    Assert::assert(!$action->matches($attrs));

    # make it late
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $attrs = new ActionTrackerPlugin::Attrs("late");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("within=1");
    Assert::assert($action->matches($attrs), $action->secsToGo());

    # now again, only closed
    $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0, "who=\"JohnDoe,SlyStallone\",due=\"2 Jun 02\" closed=\"2 Dec 00\" closer=\"Death\" notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
    $attrs = new ActionTrackerPlugin::Attrs("closed");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("closer=Death");
    Assert::assert($action->matches($attrs));
    $attrs = new ActionTrackerPlugin::Attrs("open");
    Assert::assert(!$action->matches($attrs));
  }

  sub testStringFormattingOpen {
    my $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0, "who=\"JohnDoe\" due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
    my $fmt = new ActionTrackerPlugin::Format("|Who|Due|","|\$who|","","Who: \$who \$who","\$who,\$due");
    my $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Who: Main.JohnDoe Main.JohnDoe\n",$fmt->toString());
    $fmt = new ActionTrackerPlugin::Format("","","","Due: \$due");
    # make it late
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Due: Sun, 2 Jun 2002 (LATE)\n");
    # make it ontime
    ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Due: Sun, 2 Jun 2002\n");
    # make it late again
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $fmt = new ActionTrackerPlugin::Format("","","", "State: \$state\n");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "State: open\n\n");
    $fmt = new ActionTrackerPlugin::Format("","", "","Notify: \$notify\n");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Notify: Main.SamPeckinpah,Main.QuentinTarantino\n\n");
    $fmt = new ActionTrackerPlugin::Format("","", "", "\$creator");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Main.ThomasMoore\n");
    $fmt = new ActionTrackerPlugin::Format("","", "","|\$created|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|Fri, 1 Jan 1999|\n");
    $fmt = new ActionTrackerPlugin::Format("","", "","|\$edit|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "||\n");
    $fmt = new ActionTrackerPlugin::Format("","", "","\$web.\$topic");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Test.Topic\n");
    $fmt = new ActionTrackerPlugin::Format("","", "", "Text \"\$text\"");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Text \"A new action\"\n");
    $fmt = new ActionTrackerPlugin::Format("","", "","|\$n\$n()\$nop()\$quot\$percnt\$dollar|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|\n\n\"%\$|\n");
    $fmt = new ActionTrackerPlugin::Format("","","","Who: \$who Creator: \$creator");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s,
		    "Who: Main.JohnDoe Creator: Main.ThomasMoore\n");
  }

  sub testStringFormattingClosed {
    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\"closer=\"LucBesson\"", "A new action");
    my $fmt = new ActionTrackerPlugin::Format("","", "", "|\$closed|\$closer|");
    my $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s,
		    "|Wed, 1 Jan 2003|Main.LucBesson|\n");
  }

  sub testVerticalOrient {
    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");
    my $fmt = new ActionTrackerPlugin::Format("|Who|Due|", "|\$who|\$due|", "rows");
    my $s = $fmt->formatHTMLTable([$action], "name", 0);

    $s =~ s/<table border=\"1\">//ios;
    $s =~ s/<\/table>//ios;
    Assert::sEquals($s, "<a name=\"AcTion0\"></a><tr><th bgcolor=\"orange\">Who</th><td>Main.JohnDoe</td></tr><tr><th bgcolor=\"orange\">Due</th><td>Sun, 2 Jun 2002</td></tr>");
  }

  sub testHTMLFormattingOpen {
    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");

    my $fmt = new ActionTrackerPlugin::Format("", "|\$who|");
    my $s = $fmt->formatHTMLTable([$action], "name", 0);
    Assert::sContains($s,
		    "<a name=\"AcTion0\"></a><td>Main.JohnDoe</td>");
    $fmt = new ActionTrackerPlugin::Format("", "| \$due |");
    # make it late
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s,
		    "<td bgcolor=\"yellow\"> Sun, 2 Jun 2002 </td>");

    # make it ontime
    ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $fmt = new ActionTrackerPlugin::Format("", "| \$due |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Sun, 2 Jun 2002 </td>");

    # Make it late again
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $fmt = new ActionTrackerPlugin::Format("", "| \$state |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> open </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$notify |");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Main.SamPeckinpah,Main.QuentinTarantino </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$uid |");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> &nbsp; </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$creator |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Main.ThomasMoore </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$created |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Fri, 1 Jan 1999 </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$edit |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    my $url="%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0";
    Assert::sContains($s,
		    "<td> <a href=\"$url\">edit</a> </td>");
    $fmt = new ActionTrackerPlugin::Format("", "| \$edit |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 1);
    Assert::sContains($s, "<td> <a href=\"$url\" onClick=\"return editWindow('$url')\">edit</a> </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$web.\$topic |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Test.Topic </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$text |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> A new action (<a href=\"http://host/view/Test/Topic#AcTion0\">go to action</a>) </td>");

    $fmt = new ActionTrackerPlugin::Format("", "| \$n\$n()\$nop()\$quot\$percnt\$dollar |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> <br /><br />\"%\$ </td>");

    ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $fmt = new ActionTrackerPlugin::Format("", "| \$due |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td> Sun, 2 Jun 2002 </td>");
    
    $fmt = new ActionTrackerPlugin::Format("", "|\$who|\$creator|", "");
    $s = $fmt->formatHTMLTable([$action], "name", 0);
    Assert::sContains($s,
		    "<a name=\"AcTion0\"></a><td>Main.JohnDoe</td><td>Main.ThomasMoore</td>");
  }

  sub testHTMLFormattingClose {
    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\" closer=\"LucBesson\"", "A new action");
    my $fmt = new ActionTrackerPlugin::Format("", "|\$closed|\$closer|", "");
    my $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s,
		    "<td>Wed, 1 Jan 2003</td><td>Main.LucBesson</td>");
  }

  sub testAutoPopulation {
    my $action =
      new ActionTrackerPlugin::Action( "Test", "Topic", 7,
				       "state=closed", "A new action");
    ActionTrackerPlugin::Action::forceTime("31 May 2002");
    my $tim = Time::ParseDate::parsedate("31 May 2002");
    $action->populateMissingFields();
    my $fmt = new ActionTrackerPlugin::Format("","","","|\$uid|\$who|");
    my $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|000001|Main.TestRunner|\n");
    $fmt = new ActionTrackerPlugin::Format("","","","|\$creator|\$created|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|Main.TestRunner|Fri, 31 May 2002|\n");
    $fmt = new ActionTrackerPlugin::Format("","","","|\$closer|\$closed|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|Main.TestRunner|Fri, 31 May 2002|\n");
    $action =
      new ActionTrackerPlugin::Action( "Test", "Topic", 8,
				       "who=me", "action");
    $action->populateMissingFields();
    $fmt = new ActionTrackerPlugin::Format("","","","|\$who|\$due|");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "|Main.TestRunner|Fri, 31 May 2002|\n");
  }

  sub testToString {
    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 5, "due=\"2 Jun 02\" state=closed", "A new action");
    ActionTrackerPlugin::Action::forceTime("30 Sep 2001");
    $action->populateMissingFields();
    my $s = $action->toString();
    $s =~ s/ uid=\"000003\"//o;
    $s =~ s/ created=\"30-Sep-2001\"//o;
    $s =~ s/ creator=\"Main\.TestRunner\"//o;
    $s =~ s/ who=\"Main\.TestRunner\"//o;
    $s =~ s/ due=\"2-Jun-2002\"//o;
    $s =~ s/ closed=\"30-Sep-2001\"//o;
    $s =~ s/ closer=\"Main\.TestRunner\"//o;
    $s =~ s/ state=\"closed\"//o;
    Assert::sEquals($s, "%ACTION{ }% A new action");

    $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 9, "due=\"2 Jun 06\" state=open", "Another new action<br/>EOF");
    $action->populateMissingFields();
    $s = $action->toString();
    Assert::assert($s =~ /% <<EOFF\nAnother new action\nEOF\nEOFF$/o);
  }

  sub testFindByUID {
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
    Assert::sEquals($action->{text}, "AOne");
    Assert::sEquals($pre,"
");
    Assert::sEquals($post,
		    "%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");
    ($action,$pre,$post) =
      ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
						   $text, "BbBb");
    Assert::sEquals($action->{text}, "ATwo");
    Assert::sEquals($pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
");
    Assert::sEquals($post,"%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");
    ($action,$pre,$post) =
      ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
						   $text, "AcTion2");
    Assert::sEquals($action->{text}, "AThree");
    Assert::sEquals($pre,"
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
");
    Assert::sEquals($post, "%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF\nAFour\nEOF\n");

    ($action,$pre,$post) =
      ActionTrackerPlugin::Action::findActionByUID("Test", "Topic",
						   $text, "DdDd");
    Assert::sEquals($action->{text}, "AFour");
    Assert::sEquals($pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
");
    Assert::sEquals($post,"");
  }

  sub testFindChanges {
    my $oaction = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\"", "A new action");

    my $naction = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JaneDoe due=\"2 Jun 09\" state=closed notify=\"SamPeckinpah,QuentinTarantino\" creator=\"ThomasMoore\"", "A new action<p>with more text");

    my $s = "|\$who|\$due|\$state|\$creator|\$created|\$text|";
    my $fmt = new ActionTrackerPlugin::Format($s,$s,"cols",$s,"\$who,\$due,\$state,\$created,\$creator,\$text");
    my %not = ();
    $naction->findChanges($oaction, $fmt, \%not);
    $text = $not{"Main.SamPeckinpah"}{text};
    Assert::sContains($text,"|Main.JaneDoe|Tue, 2 Jun 2009|closed|Main.ThomasMoore|");
    Assert::sContains($text,"|A new action<p>with more text|");
    Assert::sContains($text,"Attribute \"state\" changed, was \"open\", now \"closed\"");
    Assert::sContains($text,"Attribute \"due\" changed, was \"Sun, 2 Jun 2002\", now \"Tue, 2 Jun 2009\"");
    Assert::sContains($text,"Attribute \"text\" changed, was \"A new action\", now \"A new action<p>with more text\"");
    Assert::sContains($text,"Attribute \"created\" was \"Fri, 1 Jan 1999\" now removed");
    Assert::sContains($text,"Attribute \"creator\" added with value \"Main.ThomasMoore\"");

    $text = $not{"Main.QuentinTarantino"}{html};
    my $jane = $fmt->formatHTMLTable([$naction],"href",0);
    Assert::htmlContains($text,$jane);
    Assert::htmlContains($text,"<tr><td>who</td><td>Main.JohnDoe</td><td>Main.JaneDoe</td></tr>");
    Assert::htmlContains($text,"<tr><td>due</td><td>Sun, 2 Jun 2002</td><td>Tue, 2 Jun 2009</td></tr>");
    Assert::htmlContains($text,"<tr><td>state</td><td>open</td><td>closed</td></tr>");
    Assert::htmlContains($text,"<tr><td>created</td><td>Fri, 1 Jan 1999</td><td> *removed* </td></tr>");
    Assert::htmlContains($text,"<tr><td>creator</td><td> *missing* </td><td>Main.ThomasMoore</td></tr>");
    Assert::htmlContains($text,"<tr><td>text</td><td>A new action</td><td>A new action<p>with more text</td></tr>");
  }

  sub testXtendTypes {
    my $s = ActionTrackerPlugin::Action::extendTypes("| plaintiffs,names,16| decision, text, 16|sentencing,date|sentence,select,17,life,\"5 years\",\"community service\"|");
    Assert::assert(!defined($s), $s);

    my $action = ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open,plaintiffs=\"fred.bloggs\@limp.net,JoeShmoe\",decision=\"cut off their heads\" sentencing=2-mar-2006 sentence=\"5 years\"", "A court action");

    $s = $action->toString();
    $s =~ s/ who=\"Main.JohnDoe\"//o;
    $s =~ s/ A court action//o;
    $s =~ s/ state=\"open\"//o;
    $s =~ s/ due=\"2-Jun-2002\"//o; 
    $s =~ s/ plaintiffs=\"fred.bloggs\@limp.net,Main.JoeShmoe\"//o;
    $s =~ s/ decision=\"cut off their heads\"//o;
    $s =~ s/ who=\"Main\.TestRunner\"//o;
    $s =~ s/ sentencing=\"2-Mar-2006\"//o;
    $s =~ s/ sentence=\"5 years\"//o;
    Assert::sEquals($s, "%ACTION{ }%");

    my $fmt = new ActionTrackerPlugin::Format("", "|\$plaintiffs|","","\$plaintiffs");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "fred.bloggs\@limp.net,Main.JoeShmoe\n");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td>fred.bloggs\@limp.net,Main.JoeShmoe</td>");
    
    $fmt = new ActionTrackerPlugin::Format("", "|\$decision|","","\$decision");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "cut off their heads\n");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td>cut off their heads</td>");
    
    $fmt = new ActionTrackerPlugin::Format("", "|\$sentence|","","\$sentence");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "5 years\n");
    $s = $fmt->formatHTMLTable([$action], "href", 0);
    Assert::sContains($s, "<td>5 years</td>");
    
    $fmt = new ActionTrackerPlugin::Format("", "","","\$sentencing");
    $s = $fmt->formatStringTable([$action]);
    Assert::sEquals($s, "Thu, 2 Mar 2006\n");
    
    my $attrs = ActionTrackerPlugin::Attrs->new("sentence=\"5 years\"");
    Assert::assert($action->matches($attrs));
    $attrs = ActionTrackerPlugin::Attrs->new("sentence=\"life\"");
    Assert::assert(!$action->matches($attrs));
    $attrs = ActionTrackerPlugin::Attrs->new("sentence=\"\\d+ years\"");
    Assert::assert($action->matches($attrs));

    $s = ActionTrackerPlugin::Action::extendTypes("|state,select,17,life,\"5 years\",\"community service\"|");
    Assert::assert(!defined($s),$s);
    ActionTrackerPlugin::Action::unextendTypes();
    $s = ActionTrackerPlugin::Action::extendTypes("|who,text,17|");
    Assert::sEquals($s,"Attempt to redefine attribute 'who' in EXTRAS" );
    $s = ActionTrackerPlugin::Action::extendTypes("|fleegle|");
    Assert::sEquals($s,"Bad EXTRAS definition 'fleegle' in EXTRAS" );
    ActionTrackerPlugin::Action::unextendTypes();
  }

  sub testCreateFromQuery {
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
    Assert::sEquals($chosen, "%ACTION{ }% Text");
  }

  sub testFormatForEditHidden {
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
    Assert::assert($s !~ /NAME=\"text\"/io);
    Assert::assert($s !~ /TYPE=\"hidden\"/io, $s);
  }

  sub testFormatForEdit {
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
      Assert::assert($s =~ s/<th>$n<\/th>//, "$n in $s");
      $n = "\\\$" if ( $n eq "dollar" );
      $n = "<br />" if ( $n eq "n" );
      $n = "" if ( $n eq "nop" );
      $n = "%" if ( $n eq "percnt" );
      $n = "\"" if ( $n eq "quot" );
      Assert::assert($s =~ s/<td>$n<\/td>//s, $n);
    }
    Assert::assert($s =~ s/<th>state<\/th>//, $n);

    foreach my $n (split(/\|/,$expand)) {
      Assert::assert($s =~ s/<th>$n<\/th>//, $n);
      $s =~ s/<td><input type=\"text\" name=\"$n\" value=\"(.*?)\" size=\"(.*?)\/><\/td>//gim;
    }
    Assert::assert($s =~ s/<td><SELECT NAME=\"state\" SIZE=\"1\"><OPTION NAME=\"open\" SELECTED>open<\/OPTION><OPTION NAME=\"closed\">closed<\/OPTION><\/SELECT><\/td>//om);
    Assert::assert($s =~ s/<table border=\"1\">//mo);
    $s =~ s/<tr( bgcolor=\"orange\")?>//gom;
    $s =~ s/<tr valign=\"top\">//gos;
    $s =~ s/<\/?(tr|table)>//gom;
    $s =~ s/\s+//gos;
    Assert::sEquals($s, "");

    $action =
      new ActionTrackerPlugin::Action("Web", "Topic", 9,
				      "state=\"open\" due=\"4-May-2001\"", "Test");
    ActionTrackerPlugin::Action::forceTime("31 May 2002");
    $fmt = new ActionTrackerPlugin::Format( "|Due|", "|\$due|", "","");
    $s = $action->formatForEdit($fmt);
    $s =~ /VALUE=\"(.*?)\"/;
    Assert::sEquals($1, "Fri, 4 May 2001");
  }

  sub testExtendStates {
    my $s = ActionTrackerPlugin::Action::extendTypes("|state,select,17,life,\"5 years\",\"community service\"|");
    Assert::assert(!defined($s));
    my $action =
      new ActionTrackerPlugin::Action("Web", "Topic", 10,
				      "state=\"5 years\"", "Text");
    my $fmt = new ActionTrackerPlugin::Format( "|State|", "|\$state|", "","");
    $s = $action->formatForEdit($fmt);
    $s =~ s/<OPTION NAME=\"life\">life<\/OPTION>//io;
    $s =~ s/<OPTION NAME=\"5 years\" SELECTED>5 years<\/OPTION>//io;
    $s =~ s/<OPTION NAME=\"community service\">community service<\/OPTION>//io;
    $s =~ s/<SELECT NAME=\"state\" SIZE=\"17\"><\/SELECT>//io;
    $s =~ s/<\/?table.*?>//gio;
    $s =~ s/<\/?tr.*?>//gio;
    $s =~ s/<\/?t[hd].*?>//gio;
    $s =~ s/<INPUT TYPE=\"hidden\".*?>//gio;
    $s =~ s/\s+//go;
    Assert::sEquals($s, "State");
    ActionTrackerPlugin::Action::unextendTypes();
  }
}

1;
