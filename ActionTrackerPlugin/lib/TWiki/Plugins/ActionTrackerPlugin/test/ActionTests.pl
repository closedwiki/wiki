# Tests for module Action.pm
use lib ('fakewiki');
use lib ('.');
use lib ('..');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use Assert;
use Time::ParseDate;

#Assert::showProgress();

TWiki::TestMaker::init("ActionTrackerPlugin");

$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");

##################################################
# check lateness
Action::forceTime(Time::ParseDate::parsedate("31 May 2002"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());

Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002 24:59:59"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());

Action::forceTime(Time::ParseDate::parsedate("2 Jun 2002 00:00:01"));
Assert::assert(__FILE__,__LINE__, $action->isLate());

# make it late
Action::forceTime(Time::ParseDate::parsedate("3 Jun 2002"));
Assert::assert(__FILE__,__LINE__, $action->isLate());

Assert::assert(__FILE__,__LINE__, $action->matches(ActionTrackerPlugin::Attrs->new("late")));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == -1);

##################################################
# String formatting - open action
$fmt = Format->new("","","Who: \$who \$who\n");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Who: Main.JohnDoe Main.JohnDoe\n");
$fmt = Format->new("","","Due: \$due\n");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Due: Sun, 2 Jun 2002 (LATE)\n");
# make it ontime
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002"));
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Due: Sun, 2 Jun 2002\n");
# make it late again
Action::forceTime(Time::ParseDate::parsedate("3 Jun 2002"));
$fmt = Format->new("","", "State: \$state\n");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "State: open\n");
$fmt = Format->new("", "","Notify: \$notify\n");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Notify: Main.SamPeckinpah,Main.QuentinTarantino\n");
$fmt = Format->new("", "", "\$creator");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Main.ThomasMoore");
$fmt = Format->new("", "","|\$created|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "|Fri, 1 Jan 1999|");
$fmt = Format->new("", "","|\$edit|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "||");
$fmt = Format->new("", "","\$web.\$topic");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Test.Topic");
$fmt = Format->new("", "", "Text \"\$text\"");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "Text \"A new action\"");
$fmt = Format->new("", "","|\$n\$n()\$nop()\$quot\$percnt\$dollar|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "|\n\n\"%\$|");
$fmt = Format->new("","","Who: \$who Creator: \$creator");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s,
		"Who: Main.JohnDoe Creator: Main.ThomasMoore");

##################################################
# String formatting - closed action
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\"closer=\"LucBesson\"", "A new action");
$fmt = Format->new("", "", "|\$closed|\$closer|");
$s = $action->formatAsString($fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"|Wed, 1 Jan 2003|Main.LucBesson|");

##################################################
# String formatting - arbitrary fields
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 May 03\" f1=field1 f2=field2", "A new action");
$fmt = Format->new("", "","|\$f1|\$f2|");
$s = $action->formatAsString($fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"|field1|field2|");

##################################################
# HTML formatting - open action
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\" creator=\"ThomasMoore\"", "A new action");

$fmt = Format->new("", "|\$who|", "");
$s = $action->formatAsHTML("name", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"<a name=\"AcTion0\"></a><td>Main.JohnDoe</td>");
$fmt = Format->new("", "| \$due |", "");
#print STDERR "<".$fmt->getStringRow().">\n";
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"<td bgcolor=\"yellow\"> Sun, 2 Jun 2002 (LATE) </td>");
# make it ontime
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002"));
$fmt = Format->new("", "| \$due |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Sun, 2 Jun 2002 </td>");
# Make it late again
Action::forceTime(Time::ParseDate::parsedate("3 Jun 2002"));
$fmt = Format->new("", "| \$state |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> open </td>");
$fmt = Format->new("", "| \$notify |");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Main.SamPeckinpah,Main.QuentinTarantino </td>");
$fmt = Format->new("", "| \$creator |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Main.ThomasMoore </td>");
$fmt = Format->new("", "| \$created |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Fri, 1 Jan 1999 </td>");
$fmt = Format->new("", "| \$edit |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
$url="%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0";
Assert::sEquals(__FILE__,__LINE__, $s,
"<td> <a href=\"$url\">edit</a> </td>");
$fmt = Format->new("", "| \$edit |", "");
$s = $action->formatAsHTML("href", $fmt, 1);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> <a onClick=\"return editWindow('$url')\">edit</a> </td>");
$fmt = Format->new("", "| \$web.\$topic |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Test.Topic </td>");
$fmt = Format->new("", "| \$text |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> [[Test.Topic#AcTion0][A new action]] </td>");
$fmt = Format->new("", "| \$n\$n()\$nop()\$quot\$percnt\$dollar |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> <br /><br />\"%\$ </td>");
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002"));
$fmt = Format->new("", "| \$due |", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s, "<td> Sun, 2 Jun 2002 </td>");

$fmt = Format->new("", "|\$who|\$creator|", "");
$s = $action->formatAsHTML("name", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"<a name=\"AcTion0\"></a><td>Main.JohnDoe</td><td>Main.ThomasMoore</td>");

##################################################
# HTML formatting - closed action
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" closed=\"1-Jan-03\" closer=\"LucBesson\"", "A new action");
$fmt = Format->new("", "|\$closed|\$closer|", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"<td>Wed, 1 Jan 2003</td><td>Main.LucBesson</td>");

##################################################
# HTML formatting - arbitrary fields
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 May 03\" f1=field1 f2=field2", "A new action");
$fmt = Format->new("", "|\$f1|\$f2|", "");
$s = $action->formatAsHTML("href", $fmt, 0);
Assert::sEquals(__FILE__,__LINE__, $s,
		"<td>field1</td><td>field2</td>");

##################################################
# Auto-population
$action = Action->new( "Test", "Topic", 0, "due=\"2 Jun 02\" state=closed", "A new action");

Action::forceTime(Time::ParseDate::parsedate("31 May 2002"));
$action->populateMissingFields();
$fmt = Format->new("","","|\$uid|\$who|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "|TestTopic1025000n0|Main.TestRunner|");
$fmt = Format->new("","","|\$creator|\$created|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "|Main.TestRunner|Fri, 31 May 2002|");
$fmt = Format->new("","","|\$closer|\$closed|");
$s = $action->formatAsString($fmt);
Assert::sEquals(__FILE__,__LINE__, $s, "|Main.TestRunner|Fri, 31 May 2002|");

##################################################
# toString
$s = $action->toString();
$s =~ s/ uid=\"TestTopic1025000n0\"//o;
$s =~ s/ created=\"31-May-2002\"//o;
$s =~ s/ creator=\"Main\.TestRunner\"//o;
$s =~ s/ who=\"Main\.TestRunner\"//o;
$s =~ s/ due=\"2-Jun-2002\"//o;
$s =~ s/ closed=\"31-May-2002\"//o;
$s =~ s/ closer=\"Main\.TestRunner\"//o;
$s =~ s/ state=\"closed\"//o;
Assert::sEquals(__FILE__,__LINE__, $s, "%ACTION{ }% A new action");

##################################################
# Check matches
$action = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" creator=\"ThomasMoore\" created=\"1 Jan 1999\"", "A new action");

$attrs = ActionTrackerPlugin::Attrs->new("who=JohnDoe");
Assert::assert(__FILE__,__LINE__, $action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Main.JohnDoe");
Assert::assert(__FILE__,__LINE__, $action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Joe");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Main.Joe");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));

# make it on-time
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());
$attrs = ActionTrackerPlugin::Attrs->new("late");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == 1);

# Make it within 3 days
Action::forceTime(Time::ParseDate::parsedate("30 May 2002"));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == 3);
Assert::assert(__FILE__,__LINE__, $action->matches(ActionTrackerPlugin::Attrs->new("within=3")));
Assert::assert(__FILE__,__LINE__, !$action->matches(ActionTrackerPlugin::Attrs->new("within=2")));

$text = "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo\r
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
\r%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% AFour";

($action,$pre,$post) = Action::findActionByUID("Test", "Topic", $text, "AaAa");
Assert::sEquals(__FILE__,__LINE__, $action->{text}, "AOne");
Assert::sEquals(__FILE__,__LINE__,$pre,"
");
Assert::sEquals(__FILE__,__LINE__,$post,
"%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% AFour");
($action,$pre,$post) = Action::findActionByUID("Test", "Topic", $text, "BbBb");
Assert::sEquals(__FILE__,__LINE__, $action->{text}, "ATwo");
Assert::sEquals(__FILE__,__LINE__,$pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
");
Assert::sEquals(__FILE__,__LINE__,$post,"%ACTION{who=Three,due=\"30 May 2002\"}% AThree
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% AFour");
($action,$pre,$post) = Action::findActionByUID("Test", "Topic", $text, "AcTion2");
Assert::sEquals(__FILE__,__LINE__, $action->{text}, "AThree");
Assert::sEquals(__FILE__,__LINE__,$pre,"
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
");
Assert::sEquals(__FILE__,__LINE__,$post, "%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% AFour");

($action,$pre,$post) = Action::findActionByUID("Test", "Topic", $text, "DdDd");
Assert::sEquals(__FILE__,__LINE__, $action->{text}, "AFour");
Assert::sEquals(__FILE__,__LINE__,$pre, "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
");
Assert::sEquals(__FILE__,__LINE__,$post,"");

$oaction = Action->new( "Test", "Topic", 0, "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\"", "A new action");

$naction = Action->new( "Test", "Topic", 0, "who=JaneDoe due=\"2 Jun 09\" state=closed notify=\"SamPeckinpah,QuentinTarantino\" creator=\"ThomasMoore\"", "A new action<p>with more text");

$s = "|\$who|\$due|\$state|\$creator|\$created|\$text|";
$fmt = Format->new($s,$s,$s,"\$who,\$due,\$state,\$created,\$creator,\$text");
%not = ();
$naction->findChanges($oaction, $fmt, \%not);
$text = $not{"Main.SamPeckinpah"}{text};
Assert::sContains(__FILE__,__LINE__,$text,"|Main.JaneDoe|Tue, 2 Jun 2009|closed|Main.ThomasMoore|");
Assert::sContains(__FILE__,__LINE__,$text,"|A new action<p>with more text|");
Assert::sContains(__FILE__,__LINE__,$text,"Attribute \"state\" changed, was \"open\", now \"closed\"");
Assert::sContains(__FILE__,__LINE__,$text,"Attribute \"due\" changed, was \"Sun, 2 Jun 2002\", now \"Tue, 2 Jun 2009\"");
Assert::sContains(__FILE__,__LINE__,$text,"Attribute \"text\" changed, was \"A new action\", now \"A new action<p>with more text\"");
Assert::sContains(__FILE__,__LINE__,$text,"Attribute \"created\" was \"Fri, 1 Jan 1999\" now removed");
Assert::sContains(__FILE__,__LINE__,$text,"Attribute \"creator\" added with value \"Main.ThomasMoore\"");

$text = $not{"Main.QuentinTarantino"}{html};
Assert::htmlContains(__FILE__,__LINE__,$text,"<table><td>Main.JaneDoe</td><td>Tue, 2 Jun 2009</td><td>closed</td><td>Main.ThomasMoore</td><td>BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats</td><td>[[Test.Topic#AcTion0][A new action<p>with more text]]</td></table>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>who</td><td>Main.JohnDoe</td><td>Main.JaneDoe</td></tr>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>due</td><td>Sun, 2 Jun 2002</td><td>Tue, 2 Jun 2009</td></tr>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>state</td><td>open</td><td>closed</td></tr>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>created</td><td>Fri, 1 Jan 1999</td><td> *removed* </td></tr>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>creator</td><td> *missing* </td><td>Main.ThomasMoore</td></tr>");
Assert::htmlContains(__FILE__,__LINE__,$text,"<tr><td>text</td><td>A new action</td><td>A new action<p>with more text</td></tr>");

1;
