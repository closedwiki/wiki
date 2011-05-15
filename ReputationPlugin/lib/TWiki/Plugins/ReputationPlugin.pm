# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2006 Fred Morris, m3047-twiki@inwa.net
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@DistributedINFORMATION.com
# Copyright (C) 2007 Arthur Clemens, arthur@visiblearea.com
# Copyright (C) 2009-2011 Joona Kannisto
# Copyright (C) 2010 Marko Helenius
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
# Much of the code for this plugin is taken from TagmePlugin.

package TWiki::Plugins::ReputationPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;
# Translation support
# TWiki's I18N support is not very fitting for plugins
# something needs to be developed
use TWiki::Plugins::ReputationPlugin::I18N;
use TWiki::Func;
use TWiki::Contrib::RatingContrib;
# Updated version with BerkeleyDB access
use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree) ;

# Global variables used in this plugin
use vars qw( $web $topic $user $sanitizedtopic $installWeb $VERSION $RELEASE $SHORTDESCRIPTION
             $debug $pluginName $NO_PREFS_IN_TOPIC $absolute $backlinkmax $LH $workAreaDir
             $attachUrl $voterreputation $recommendations $topfile $trustfile $topicfile
             $userfile $commentfile );

$VERSION = '$Rev: 12445$';
$RELEASE = '2011-05-14';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Build and manage reputation';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'ReputationPlugin';

our @systemTopics = qw(WebChanges
                       WebHome
                       WebIndex
                       WebLeftBar
                       WebNotify
                       WebPreferences
                       WebRss
                       WebSearch
                       WebSearchAdvanced
                       WebStatistics
                       WebTopicList);

BEGIN {
    #I18N initialization
    if ( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}


$LH = TWiki::Plugins::ReputationPlugin::I18N->get_handle()
|| die "Can't get a language handle";

our $wikiwordRegex=$TWiki::regex{'wikiWordRegex'};
our $smileybuttons=0;
# Weights assigned to each voting option
# Names shouldn't be changed if the plugin has been in use, if you want to change
# the labels on buttons change buttonstrings
our %votevalues = ("poor", -2, "negative", -1, "positive", 1, "excellent", 2);
our %commentvotevalues= ("poor", -2, "negative", -1, "positive", 1);
our $votenames=join("|",keys %votevalues);
our $voteRegex = "^[$votenames]";
our %buttonStrings=("poor",$LH->maketext("poor"),"negative",$LH->maketext("negative"),"positive", $LH->maketext("positive"),"excellent",$LH->maketext("excellent"));
# "Vote" clutters the interface, should remove from where it's called
our %actionStrings=("vote",$LH->maketext(""),"remove",$LH->maketext("Remove"), "commentvote",$LH->maketext(""), "commentremove",$LH->maketext("Remove"));
# Weight given to user's own votes
our $myweight=1;
our %quotatemplate=("excellent",2,"positive",2,"negative",2, "poor",2);

# Removing magic numbers
our $maxtrustvalue=999;
# Zero is not recommended, because it can be mixed up with undef,
# should use defined in if statements whenever possible, but just
# to be on the safe side.
our $mintrustvalue=1;
our $defaulttrustvalue=500;
# Needed in credibility function.
# Defined here for faster tuning at development stage
our $threshold=$defaulttrustvalue;
our $recommendationthreshold=$maxtrustvalue+1;
our $defaultcredibilityweight=5;
use constant DEFAULT_RECOMMENDATION=>800;
use constant TINY_FLOAT => 1e-200;

# Use html entities to escape everything returned back to the user in order to prevent XSS
use HTML::Entities;

sub initPlugin {
     ($topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
	TWiki::Func::registerTagHandler( 'REPUTATION', \&_REPUTATION, 'context-free' );
	TWiki::Func::registerTagHandler( 'REPCOMMENT', \&_REPCOMMENT, 'context-free' );
	TWiki::Func::registerTagHandler( 'REPCOMMENTVOTE', \&_REPCOMMENTVOTE, 'context-free' );
    $workAreaDir = TWiki::Func::getWorkArea($pluginName);
   	$userfile = "$workAreaDir/_users.mldbm";
   	$topfile = "$workAreaDir/_top.mldbm";
   	$topicfile = "$workAreaDir/_topics.mldbm";
   	$trustfile = "$workAreaDir/_trust.mldbm";
	$commentfile = "$workAreaDir/_comment.mldbm";
    # Set plugin preferences in LocalSite.cfg
    $debug = $TWiki::cfg{Plugins}{ReputationPlugin}{Debug} || 0;

    # Shows votes without taking voters reputation into account
    $absolute = TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_RATINGTYPE') || 1;
    if ($absolute eq "relative") {
    	$absolute = 0;
    }
	my $theme = TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_THEME') || 'smiley';
	if ( $theme eq "plain"){
	$smileybuttons=0;
	}
	else {
		$smileybuttons=1;
	}
    #
    $attachUrl = TWiki::Func::getPubUrlPath() . "/$installWeb/$pluginName";
    # This should be user configured
    $voterreputation=$TWiki::cfg{Plugins}{ReputationPlugin}{Voterreputation} || 0;
    if ($voterreputation) {
    	$threshold=0;
    }
    else {
    	$threshold=TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_TRUSTTHRESHOLD');
    	if (defined $threshold && $threshold =~ /(\d+)/) {
    		$threshold = $1;
    	}
    	else {
    		$threshold=$defaulttrustvalue;
    	}
	}
    $recommendationthreshold=TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_RECOMMENDATIONTHRESHOLD')|| DEFAULT_RECOMMENDATION;
    if ($recommendationthreshold =~ /(\d+)/) {
    	$recommendationthreshold = $1;
    }
    else {
    	$recommendationthreshold=$maxtrustvalue+1;
    }
	if ($recommendationthreshold<=$maxtrustvalue) {$recommendations = 1}
	else {$recommendations=0}

	# This doesn't work with mod_perl as it should, plugin initialized previously overrides
	# this setting.
    my $numberofoptions=TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_VOTEOPTIONS')||2;
	if ($numberofoptions==2) {
	    %votevalues =("negative", -1, "positive", 1);
    }
	# mod_perl makes it mandatory to reassign this value, if different voteoptions are
	# used in some other web or topic
	else {
		%votevalues = ("poor", -2, "negative", -1, "positive", 1, "excellent", 2);
	}
    # Plugin correctly initialized
    return 1;
}
sub _REPCOMMENT {
	my ($session, $params, $thetopic, $theweb) =@_;
	my $text='';
	my $twisty=$session->{twisty} || '';
	my $threshold=$session->{threshold} || 0;
	my $abusethreshold =$session->{abusethreshold};
	if (!defined $abusethreshold) {
	$abusethreshold = -1;
	}
	if (!$twisty eq 'on') {
		$twisty=0;
	}
	if (!defined $threshold && !$threshold =~ /^[-+]?[0-9]*\.?[0-9]+$/){
    	$threshold=0;
    }
	$text.=_commentInterface($twisty,$threshold,$abusethreshold);
	return $text;
}
sub _REPCOMMENTVOTE {
   	my ($session, $params, $thetopic, $theweb) = @_;
    my $action = $params->{rpaction} || '';
    my $vote = $params->{vote} || '';
	my $targetcomment=$params->{target};
	my $targetuser=$params->{targetuser};
	my $targetcomment=$params->{target};
	my $targetuser=$params->{targetuser};
    my $text = '';
	if ($action eq 'commentvote') {

		$text = _commentVote($vote,$targetcomment,$targetuser);
	}
	elsif ($action eq 'commentremove') {
		
		$text = _commentRemove($vote,$targetcomment,$targetuser);
	}
    elsif ($action) {
        $text = "Unrecognized action";
    }
	return $text;
}
sub _REPUTATION {
   	my ($session, $params, $thetopic, $theweb) = @_;
    my $action = $params->{rpaction} || '';
    my $vote = $params->{vote} || '';
    my $text = '';
    my $access=_accessVote();
    # called with rpaction's value vote, in typical case voting button has been pressed
    if ( $action eq "vote" && $access ) {
            $text = _ADDVOTE($vote);
    }
    elsif ( $action eq "remove" && $access) {
        $text = _REMOVEVOTE($vote);
    }
    elsif ($action eq "showtopics"){
    	$text = _SHOWTOPICS();
    }
    elsif ($action eq "showtrusted"){
	    $text = _SHOWTRUSTED();
    }
    elsif ($action eq "addtrust"){
		my $addvalue = $params->{addvalue};
		my $wikiname = $params->{user};
		my $oldvalue= $params->{oldvalue};
		my $slider = $params->{slider};
    	$text = _trustValueChange($addvalue,$wikiname,$oldvalue,$slider);
    }

    elsif ($action eq "showgroups" && $TWiki::Plugins::VERSION>=1.2) {
    	$text = _groupview();
    }
    elsif ($action eq "showtoplist") {
		my $currentweb= $params->{web};
    	$text= _showtoplist($currentweb);
    }
	elsif ($action eq 'commentvote') {
		my $targetcomment=$params->{target};
		my $targetuser=$params->{targetuser};
		$text = _showDefault()._commentVote($vote,$targetcomment,$targetuser);
	}
	elsif ($action eq 'commentremove') {
		my $targetcomment=$params->{target};
		my $targetuser=$params->{targetuser};
		$text = _showDefault()._commentRemove($vote,$targetcomment,$targetuser);
	}
    elsif ($action) {
        $text = "Unrecognized action";
    }
    # If plugin is called without action just show UI

    else {
    	$text = _showDefault();
    }
    return $text;
}
sub _commentVote {
	my ($addVote,$targetcomment, $targetuser) =@_;
	my $text="";
	return "Please log in or register to vote." if (TWiki::Func::isGuest);
	if ($targetcomment && $commentvotevalues{$addVote}) {
		my %commentdb ;
		tie %commentdb, 'MLDBM', -Filename => $commentfile,
    		-Flags    => DB_CREATE
       	  or die "Cannot open database '$commentfile: $!\n";
		my $votes = $commentdb{$targetcomment};
		$votes->{$addVote}->{$user}=1 unless ($votes->{$addVote});
		foreach my $vote (keys %$votes) {
			if ($vote eq $addVote) {
				$votes->{$addVote}->{$user}=1;
				$text.="Vote $buttonStrings{$addVote} added. <br>"; 
				if ($commentvotevalues{$vote}) {
					my $num=$commentvotevalues{$vote};
					$text.=_updateusers($num, $targetuser);#$text.=_removetrust($commentid);
				}
			}
			elsif ($votes->{$vote}->{$user}) {
				delete $votes->{$vote}->{$user};
				$text.="Existing vote $buttonStrings{$vote} removed. <br>";
				if ($commentvotevalues{$vote}) {
					my $num=$commentvotevalues{$vote}*-1;
					$text.=_updateusers($num, $targetuser );
				}
			}
		}
		$commentdb{$targetcomment}=$votes;
		untie %commentdb;
	}
	else {
		$text="Vote not valid, or missing target <br>";
	}

	return $text;
}
sub _commentRemove {
	my ($rmVote,$targetcomment,$targetuser) =@_;
	my $text="";
	if ($targetcomment && $rmVote) {
		my %commentdb ;
		tie %commentdb, 'MLDBM', -Filename => $commentfile,
    		-Flags    => DB_CREATE
         	or die "Cannot open database '$commentfile: $!\n";

		my $votes = $commentdb{$targetcomment};
		
		if ($votes->{$rmVote}->{$user}) {
			delete $votes->{$rmVote}->{$user};
			$text.="Vote $buttonStrings{$rmVote} removed. <br>";
			$commentdb{$targetcomment}=$votes;
			if ($commentvotevalues{$rmVote}) {
			my $num=$commentvotevalues{$rmVote}*-1;
				$text.=_updateusers($num, $targetuser);#$text.=_removetrust($commentid);
			}
		}
		else {
			$text.="Vote not found.<br>";
		}
	untie %commentdb;
	}
	else {
		$text="Missing target<br>";
	}
	
	return $text;
}
# Show the topics which the user has voted. 
sub _SHOWTOPICS {
	my $html='';
	my %topicdb ;
	tie %topicdb, 'MLDBM', -Filename => $userfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$userfile: $!\n";

	if (defined $topicdb{"$user"}) {
		my $votes = $topicdb{$user};
		# Build new assoc for sorting data in vote topic order
		# only the second level key is unique
		my %newassoc ;
		foreach $topic (keys %$votes) {
			$newassoc{$votes->{$topic}->{'vote'}}{$topic}{'rev'}= $votes->{$topic}->{'rev'};
			@{$newassoc{$votes->{$topic}->{'vote'}}{$topic}{'authors'}}=@{$votes->{$topic}->{'authors'}};
		}

		foreach my $votekey (sort _voteoptionsort keys %newassoc) {
    		$html.=$LH->maketext("---++Topics voted as [_1]\n", $buttonStrings{$votekey});
    		foreach my $topickey (sort keys %{$newassoc{$votekey}}) {
    			my $revision=$newassoc{$votekey}{$topickey}{'rev'};
    			my $authorlist="$TWiki::cfg{UsersWebName}.".join(", $TWiki::cfg{UsersWebName}.",@{$newassoc{$votekey}{$topickey}{'authors'}});
    			$html.=$LH->maketext("Topic: ~[~[[_1]~]~] Revision: [_2] Authors: [_3]",$topickey, $revision, $authorlist);
    			$html.="<br>\n";
    		}
    	}
    }
	untie %topicdb;
    return $html;
}

# Manually adjust some users trustvalue. Should support some kind of nonce, in order to
# prevent misuse. Another way to prevent misuse would be to restrict this function's use to spesific topic
sub _trustValueChange {
	my ($text, $wikiname)= @_;
	if (TWiki::Func::isGuest) {
		return _wrapHtmlFeedbackErrorInline ('Please log in to use this functionality');
	}
	my $exists=TWiki::Func::wikiToUserName($wikiname);
	my $nolimit=$TWiki::cfg{Plugins}{ReputationPlugin}{NoRestrictTrustValueChange} ||0;
	my $trustvaluechangetopic=$TWiki::cfg{Plugins}{ReputationPlugin}{TrustValueChangeTopic} || 'ReputationPluginChangeValues';
	if (!$nolimit && ($web ne $TWiki::cfg{SystemWebName} || $topic ne $trustvaluechangetopic)) {
		return _wrapHtmlFeedbackErrorInline("Trustvalues can be changed only in the provided template topic $TWiki::cfg{SystemWebName}.$trustvaluechangetopic"); 
	}
	$text=~/(\d*)/;
	if ($1 && $exists) {
		my $previous=0;
		($text,$previous)=_writeToTRDB($wikiname, $text);
		$text=$LH->maketext("Trustvalue updated from [_1] to [_2] points for user \"[_3]\"",$previous, $text, $wikiname);
	}
	# We didn't get a valid wikiname
	elsif ($2) {
		$text=_wrapHtmlFeedbackErrorInline($LH->maketext("Wikiname does not exist!"));
	}
	elsif ($exists){

		$text.=$LH->maketext(" Invalid number!");
		$text=_wrapHtmlFeedbackErrorInline($text);
	}
	# Both parameters exist, but they are invalid
	elsif ($text || $wikiname){
		$text=$text=_wrapHtmlFeedbackErrorInline($LH->maketext("You should submit existing WikiName and a negative or positive integer"));
	}
	# The user didn't input anything yet
	else {
		$text=$LH->maketext("Use the sliders or the free form down below.");
	}
	return $text;
}
sub _writeToTRDB {
	my ($wikiname,$number)=@_;
	$wikiname=TWiki::Func::getWikiName( $wikiname, 1); 
	$number=~ /\d*/;

	if ($wikiname && $number) {
		if ($number>$maxtrustvalue) {
			$number=$maxtrustvalue;
		}
		elsif ($number<$mintrustvalue){
			$number=$mintrustvalue;
		}
		my %trustdb;
    	tie %trustdb, 'MLDBM', -Filename => $trustfile,
    		-Flags    => DB_CREATE
		'Lock'      =>  'File',
     	'Lockfile'  =>  '/tmp/Tie-MLDBM-trust.lock'

         	or die "Cannot open database '$trustfile: $!\n";
		my $table = $trustdb{$user};
		my $previous=$table->{$wikiname};
		$previous="unknown" unless ($previous);
		$table->{$wikiname}=$number;
		$trustdb{$user}=$table;
		untie %trustdb;
		return $number,$previous;
	}
	else {return "NaN"}
}

# Simple toplist functionality
sub _showtoplist {
	my ($currentweb)=@_;
	if (!TWiki::Func::webExists( $currentweb)) {
	$currentweb=$web;
	}
 	my $text='';
	# Toplists public by default, preference from web (only the ones with writeaccess to webpreferences can change this)
	my $toplisthidden = TWiki::Func::getPreferencesFlag('REPUTATIONPLUGIN_TOPLISTHIDDEN',$currentweb)|| 0;
	# If the current user is not an admin and toplist is hidden
	if (!TWiki::Func::isAnAdmin() && $toplisthidden) {
		$text=$LH->maketext("The toplist is hidden in this web");
	}
 	# If the user has read permission to this web, it's okay to show topic names
 	# "empty" text, because we do not want the current topic text to be read
	elsif (TWiki::Func::checkAccessPermission( "VIEW", $user, 'empty', 'WebHome', $currentweb, '')&& _accessRead($currentweb)){
		my %toplist = _readTopfile($currentweb);
		$text.=$LH->maketext("No entries") if (!scalar keys %toplist);
		my $star = TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_STAR") || 0;
		# show only best 10
		my $loop=11;
		# Sorted by a bayesian rating scheme, perhaps a bit messy implementation
 		foreach my $key (sort { 
		($toplist{$b}{'sum'}+$toplist{'_MeanRatings'}{'meansum'})/($toplist{$b}{'count'} +$toplist{'_MeanRatings'}{'mean'})
		<=> ($toplist{$a}{'sum'}+$toplist{'_MeanRatings'}{'meansum'})/($toplist{$a}{'count'} +$toplist{'_MeanRatings'}{'mean'}) } keys %toplist ) {
			if ($key ne "_MeanRatings") {
			my $percent = sprintf("%.0f", ($toplist{$key}{'sum'}+$toplist{'_MeanRatings'}{'meansum'})/($toplist{$key}{'count'} + $toplist{'_MeanRatings'}{'mean'})*100/(sort {$a <=> $b} values %votevalues)[-1]);
			if ($star) {
				$percent=TWiki::Contrib::RatingContrib::renderRating("RPrating", "5", 0, $percent/20);
			}
			else {
			$percent = $percent."%";
			} 
 			$text.="$percent [[$currentweb.$key]]<br>\n";
			}
			--$loop;
			if(!$loop) {
			last;
			}
 		}
 	}
 	return $text;
}
# One option would be to save average values, or actually save the mean, count, and sum
sub _addtotoplist {
	my ($value,$remove)=@_;
	my %topdb ;
    tie %topdb, 'MLDBM', -Filename => $topfile,
    	-Flags    => DB_CREATE
	'Lock'      =>  'File',
	'Lockfile'  =>  '/tmp/Tie-MLDBM-toplist.lock'
         or die "Cannot open database '$topfile: $!\n";
	my  $webtop= $topdb{$web};
	if ($remove) {
		$remove=-1;
	}
	else {
		$remove=1;
	}

	if ($webtop->{$topic}){
		$webtop->{$topic}->{'sum'}=$webtop->{$topic}->{'sum'}+$value;
		$webtop->{$topic}->{'count'}=$webtop->{$topic}->{'count'}+1*$remove;
	}
	elsif ($remove == 1) {
		$webtop->{$topic}->{'sum'}=$value;
		$webtop->{$topic}->{'count'}=1;
	}
	# Reserving a word here, it would be better to do this out of band	
	if ($webtop->{'_MeanRatings'}) {
		$webtop->{'_MeanRatings'}->{'count'}=$webtop->{'_MeanRatings'}->{'count'}+1*$remove;
		$webtop->{'_MeanRatings'}->{'sum'}=$webtop->{'_MeanRatings'}->{'sum'}+$value;
		$webtop->{'_MeanRatings'}->{'meansum'}=($webtop->{'_MeanRatings'}->{'sum'})/(TINY_FLOAT+ (scalar keys %$webtop) -1);
		$webtop->{'_MeanRatings'}->{'mean'}=$webtop->{'_MeanRatings'}->{'count'}/(TINY_FLOAT+ (scalar keys %$webtop) -1);
	}
	else {
		$webtop->{'_MeanRatings'}->{'count'}=1;
		$webtop->{'_MeanRatings'}->{'sum'}=$value;
		$webtop->{'_MeanRatings'}->{'mean'}=$value;
	}
	$topdb{$web}=$webtop;
	untie %topdb;	
}

# Show the contents of user's own trusted file, values shown as sliders
sub _SHOWTRUSTED {
    my (%trusted)=_readTrusted($user);
	my $text='';
	# Insert external javascript to header
	my $headtext="<script type=\"text/javascript\" src=\"$attachUrl/js/slider.js\"></script>";
	my $id="REPUTATIONPLUGIN_SLIDERJS";
	TWiki::Func::addToHEAD( $id, $headtext);
	# Insert css for the sliders
	$text.="<link href=\"$attachUrl/slider/slider.css\" media=\"all\" rel=\"stylesheet\" type=\"text/css\" />";
	#$text.="<fieldset>";
	$text.='<style type="text/css" media="screen">
fieldset
        {
        margin:0;
        padding:1em;
        text-align:left;
        }
div.extraclass
        {
        width:20.6em;
        float:left;
        }
</style>';
	$text.='<table>';
	# Every line in trust file gets its own form (a form with only one submit button could be easier to use
	# but the parameters would be much harder to collect)
	foreach my $key (sort { $trusted{$b} <=> $trusted{$a} } keys %trusted ) {

	$text .="\n<form name\=\"new$key\"";
	$text .=' action="%TOPIC%" method="post">';
	$text .='<tr><td>';
    $text.="<input type=\"hidden\" name=\"rpaction\" value=\"addtrust\"/>";
    $text.="<input type=\"hidden\" name=\"user\" value=\"$key\"/>";
	$text .="<label for=\"slider-$key\">$key</label></td><td>
    <input name=\"addvalue\" id=\"slider-$key\" type=\"text\" title=\"Range: 1 - 999\" class=\"fd_range_$mintrustvalue";
     $text .="_$maxtrustvalue fd_classname_extraclass\" value=\"$trusted{$key}\"/>";
    $text.="<input type=\"hidden\" name=\"slider\" value=\"1\"/>";
    $text.="<input type=\"hidden\" name=\"oldvalue\" value=\"$trusted{$key}\"/>";
	$text.="</td><td><input type\=\"submit\" class\=\"twikiSubmit\" value=\"Save\"/><br>";
	$text .="</form>";
	$text .='</td></tr>';
	}
	$text.='</table>';
	#$text.="</fieldset>";
	return $text;
}
# In its own function for historical reasons
sub _accessRead {
    if (TWiki::Func::checkAccessPermission('RPREAD', $user, undef, $topic, $web, undef)) {
    return 1;
}
else{
	return 0;
}

}
# Similar access check
sub _accessVote {
if (TWiki::Func::checkAccessPermission('RPVOTE', $user, undef, $topic, $web, undef)){
    return 1;
}
else{
	return 0;
}
}
# The main interface, the code needs to be split up 
sub _showDefault {
    return '' unless ( TWiki::Func::topicExists( $web, $topic ) );
    return '' if (grep ($_ eq $topic, @systemTopics) && !TWiki::Func::getPreferencesFlag('REPUTATIONPLUGIN_INCLUDESYSTEMTOPICS'));
    my $voteaccess=_accessVote();
    my $readaccess=_accessRead();
	return '' if (!$readaccess && !$voteaccess); 
    my $webTopic = "$web.$topic";
	my %topicdb ;
    tie %topicdb, 'MLDBM', -Filename => $topicfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$topicfile: $!\n";
	my  $voteinfo= $topicdb{$webTopic};	
    my $text  = '';
    my $num   = '';
	my $line  = '';
    my $users = '';
    my %seen  = ();

    my $sum=0;
    # Backlinks should not be counted if $backlinkmax is set to zero
    $backlinkmax = TWiki::Func::getPreferencesValue("REPUTATIONPLUGIN_BACKLINKMAX");
	if (defined $backlinkmax && $backlinkmax =~ /(\d+)/){
    	$backlinkmax=$1;
    }
    else {
    	$backlinkmax=0;
    }
   	if ($smileybuttons){
   	$text.="<link href=\"$attachUrl/smiley/buttons.css\" media=\"all\" rel=\"stylesheet\" type=\"text/css\" />";
   	}
	if ($backlinkmax && ($readaccess || $voteaccess)){
	    my $backlinks=_backlinkcount();
	    $text.=$LH->maketext("Popularity: [_1]/[_2] ", $backlinks,$backlinkmax);
	}
	my %graphdata=();
	my $forget= TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_FORGET")||0;
	# Don't know how to set default value to 1 in prefFlags
	my $percent = TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_NOPERCENT") || 0;
	$percent=!$percent;
	# Use only if ratingcontrib installed 
	my $star = TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_STAR") || 0;
	my $bayes = TWiki::Func::getPreferencesValue("REPUTATIONPLUGIN_BAYES")|| "0.5"; 
	if ((defined $bayes && !$bayes =~ /^[-+]?[0-9]*\.?[0-9]+$/) || $bayes<0){
    	$bayes=0;
    }
	my $credaccumulator=0;
	my ( $date, $author, $currentrevision, $comment ) = TWiki::Func::getRevisionInfo($web, $topic)  if ($forget);
    foreach my $vote (keys %$voteinfo) {
	my $userfound=0;
    	foreach my $revision (keys %{$voteinfo->{$vote}}) { 
	    	$num=scalar keys %{$voteinfo->{$vote}->{$revision}};
			my @userarr=(keys %{$voteinfo->{$vote}->{$revision}});
	    	$users=\@userarr;
 		   	$userfound =1 if ($voteinfo->{$vote}->{$revision}->{$user});
			if($absolute && $forget) {
				$sum=$sum+$votevalues{$vote}*$num*$revision/$currentrevision;
			}
			elsif ($absolute) {
        		$sum=$sum+$votevalues{$vote}*$num;
        	}
        	else {
            	my $credibilityweight = TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_TRUSTEDWEIGHT')|| $defaultcredibilityweight;
    			# This could be also zero, so we can't do simple or

				if ( $credibilityweight =~ /(\d+)/){
    				$credibilityweight=$1;
    			}
    			else {
    				$credibilityweight=$defaultcredibilityweight;
    			}
    			my $unknownweight = TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_UNKNOWNWEIGHT') ||0;
    			if ( $unknownweight =~ /(\d+)/){
    				$unknownweight=$1;
    			}
    			else {
    				$unknownweight=0;
    			}
            	my $unknowns=$votevalues{$vote}*$num;
            	my $value=$votevalues{$vote};
            	my $cred=_credibility($users);
				if ($percent) {
				$credaccumulator+=$cred;
				$sum+=$cred*$value;
				}
				else {
            	$sum=$sum+$cred*$value;
				}
            }
			if ($graphdata{$vote}){
				$graphdata{$vote}=$graphdata{$vote}+$num;
				}
			else {
				$graphdata{$vote}=$num;
			}
		}
		
        # User has voted so a remove button is made
        if ( $userfound && $readaccess) {
        	$line = _votebutton('remove', $vote, $graphdata{$vote});
        }
		elsif ($userfound) {
			$line = _votebutton('remove', $vote, 1);
        }
        elsif ($readaccess) {
            $line = _votebutton('vote', $vote, $graphdata{$vote} );
        }
		else {
			$line = _votebutton('vote', $vote, 0 );
        }
        #push votes that have been voted before into associative array
        $seen{$vote} = $line;
    }
    $text.='<div>' if ($voteaccess);
    # print the score for the article
	if ( $percent || $star) {
			my $max=(sort {$a <=> $b} values %votevalues)[-1];
			my $min=(sort {$a <=> $b} values %votevalues)[0];
			my $avg=($max-$min)/2;
			if ($absolute) {
				my $votecount=0;
				($votecount+=$_) for values %graphdata;
				# Tiny float added to prevent div/0
				$percent = sprintf("%.0f",($sum+$votecount*$max+$bayes*$avg)/$max/2/($votecount+$bayes+TINY_FLOAT)*100*$votecount/($votecount+TINY_FLOAT));
			}
			else {
			$percent=sprintf("%.0f",($sum+$credaccumulator*$max+$bayes*$avg)/$max/2/($credaccumulator+$bayes+TINY_FLOAT)*100*$credaccumulator/($credaccumulator+TINY_FLOAT));
			}
	}
    if($readaccess){
		if ($star) {
		$text.=TWiki::Contrib::RatingContrib::renderRating("RPrating", "5", 0, $percent/20);
		}
		elsif ($percent && $sum) {
    	$text.=$LH->maketext("Rating: [_1] %", $percent);
		}
		elsif ($sum) {
		$sum=sprintf("%.2f", $sum) if(!$absolute|| $forget);
    	$text.=$LH->maketext("Rating: [_1] ", $sum);
		}
		else {
		$text.=$LH->maketext("No Ratings");
		}
		# Show link to graph, if there has been a vote
		my $graph.=_makePrettyBars(%graphdata) if ($num);
		#$graph.='<a href="%TOPIC%?rpaction=showgroups">Votes by groups</a>';
		$text.=_hideDiv($graph,'Graph','RPgraphDiv') if ($num);
    }
    if ($voteaccess){
    $text.='<span id="buttons">';
    	my @allVotes = keys %votevalues;
        	foreach (@allVotes) {
    		unless ( $seen{$_} ) {
       			$line = _votebutton('vote', $_, "0");
       			$seen{$_}=$line;
       		}
    	}
		$text.=
    	join( ' ', map { $seen{$_} } sort _voteoptionsort keys(%seen) );
		$text.='</span>';
    }
	
    $text.=$LH->maketext(" ~[~[[_1].ReputationPluginInfo~]~[Tell Me More~]~]",$TWiki::cfg{SystemWebName}) if ($readaccess || $voteaccess);
	#$text.=_hideDiv('%COMMENT{type="bottom"}%', "Comment" ,"RPcommentDiv");
    $text.=$LH->maketext(" Votes are hidden from others ") if ($voteaccess && !$readaccess);
	$text.='</div>' if ($voteaccess);
	my $reviewchanges= TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_REVIEWAUTHORS") ||0;
	if ($reviewchanges) {
		my ($currentrev,%authors)=_searchAuthors();
		my (%trust)=_readTrusted($user);
		my ($trustedcount,$untrustedcount,$unknowncount);
		$trustedcount=$untrustedcount=$unknowncount=0;
		foreach my $author (keys %authors) {
		if ($author eq TWiki::Func::userToWikiName($user,1)){
				$trustedcount++;
		}
	elsif ($trust{$author}>$threshold) {
			$trustedcount++;
		}
		elsif ($trust{$author}){
			$untrustedcount++;
		}
		else {
			$unknowncount++;
		}
	}

	$text.=$LH->maketext(" [_1]/[_2] trusted authors", $trustedcount, (scalar keys %authors)) if ($trustedcount);
	if ($untrustedcount && $unknowncount) {
		$text.=", ";
	}
	elsif (($untrustedcount || $unknowncount)&& $trustedcount) {
		$text.=$LH->maketext(" and ");
	}
	elsif ($trustedcount) {
		$text.=".";
	}
	$text.=$LH->maketext(" [_1]/[_2] untrusted authors", $untrustedcount, (scalar keys %authors)) if ($untrustedcount);
	if ( $unknowncount && $untrustedcount) {
		$text.=$LH->maketext(" and ");
	}
	elsif ($untrustedcount) {
		$text.=".";
	}
	$text.=$LH->maketext(" [_1]/[_2] unknown authors.", $unknowncount, (scalar keys %authors)) if ($unknowncount);	

	my ($author, $trust)=_checkLastEdit(\%trust);
	my $warning='';
	my $linksymbol='';
		if ($author && defined $trust && $trust<=$threshold) {
			$warning=$LH->maketext(" Latest change was made by an author you do not trust");
			$linksymbol='%X%';
		}
		elsif ($author) {
			$warning=$LH->maketext(" Latest change was made by a trusted author");		
			$linksymbol='%Y%';
		}
		else {
			$warning=$LH->maketext(" Latest change was made by a user unknown to you");
			if ($threshold==$defaulttrustvalue) {
				$linksymbol='%Q%';
			}
			else {
				$linksymbol='%X%';
			}
		}
		$text.=_hideDiv($warning,$linksymbol,'trustnotice');

	}
	
    return "<verbatim> $text </verbatim>" if ($debug);
    return $text;
}


sub _commentInterface {
	my ($twisty, $threshold,$abusethreshold)=@_;
	my $nocomment=TWiki::Func::getPreferencesFlag("REPUTATIONPLUGIN_NOCOMMENT") || 0;
	my $comment="";
	if (!$nocomment) {
		my $commentweb=TWiki::Func::getPreferencesValue("REPUTATIONPLUGIN_COMMENTWEB") || "Comment";
		my $commentthreshold=$threshold;
		my $commenttopic="$web"."_"."$topic"."_RPFeedback";
		# This should prevent TWikiGuest from commenting at least in the newer TWiki installations
		# 
		if (!TWiki::Func::isGuest()) {
		# These should be in the comments
		$comment="<h3>Feedback for $topic</h3>Feedback will include your name. %COMMENT{type=return,target=";
		$comment.=$commentweb.".".$commenttopic.',button="Submit Feedback" signed="on"}%';
		}
		if(TWiki::Func::topicExists( $commentweb, $commenttopic)) {
			$comment.="<h4>Previous comments:</h4>" unless (TWiki::Func::isGuest());
			$comment.="<h4>Comments:</h4>" unless (!TWiki::Func::isGuest());
			$comment.=_includeComments($commentweb,$commenttopic,$commentthreshold,$abusethreshold);
			#%INCLUDE{$web.$topic"."_RPFeedback}% <p>";
		}
		if ($twisty) {
		$comment=_hideDiv($comment,'Text Feedback','RPCommentDiv');
		}
	}
	return $comment;
}
sub _includeComments { 
	my ($commentweb, $commenttopic, $commentthreshold, $abusethreshold)=@_;
	my $commentid=1;
	my $n=0;
	my $text="";
	use Digest::SHA;
	while ($commentid) {
		$commentid=TWiki::Func::expandCommonVariables('%INCLUDE{"'.$commentweb.'.'.$commenttopic.'"  section="_SECTION'.$n.'"}%',$commentweb, $commenttopic,'');
		$commentid =~ s/\s//g;
		++$n;
		if ($commentid) {
			# A bit unefficient method
			my $commenttext=TWiki::Func::expandCommonVariables('%INCLUDE{"'.$commentweb.'.'.$commenttopic.'"  section="'.$commentid.'comment-text"}%',"", "",'');
			my $commenthash=TWiki::Func::expandCommonVariables('%INCLUDE{"'.$commentweb.'.'.$commenttopic.'"  section="'.$commentid.'hash"}%',"", "",'');
			my $commentauthor=TWiki::Func::expandCommonVariables('%INCLUDE{"'.$commentweb.'.'.$commenttopic.'"  section="'.$commentid.'WikiName"}%',"", "",'');
			# Make a persistent shared secret if one does not exist
			my $mackey=$TWiki::cfg{SharedSecret};
			if (!$mackey) {
				my $filename=$TWiki::cfg{WorkingDir}."/tmp/_SharedSecret.txt";
				$mackey=TWiki::Func::readFile( $filename );
				if (!$mackey) {
					$mackey=join "", map { unpack "H*", chr(rand(256)) } 1..16;
					TWiki::Func::saveFile( $filename, $mackey ); 
				}
			}
			# $TWiki::cfg{SharedSecret} || $TWiki::cfg{Password} || 'securitybyobscurity';
			# make a MAC code for the message
			my $hash=Digest::SHA::hmac_sha224_hex("$commentweb.$commenttopic".$commentauthor.$commentid.$commenttext,$mackey);
			# If the integrity is OK
			if ($commenthash eq $hash){
				# I know better than perl that this value is untainted, filter anyway.
				$commentid =~ /([a-z0-9]*)/;
				my $secureid=$1;
				my ($commentscore,$ratingwidget) =_commentReputation($secureid,$commentauthor);
				$commenttext=$ratingwidget . $commenttext; 
				if ($commentscore > $commentthreshold) {
					$text.='<div style="background-color:#fcfaf7; display: inline-block">'."Score: ".sprintf("%.2f",$commentscore)." ".$commenttext.'</div><p>';
				}
				# Hide abuse completely
				elsif ($commentscore > $abusethreshold) {
					$text.=_hideDiv('<div style="background-color:#fcfaf7; display: inline-block; max-width: 2000px">'.$commenttext.'</div>','Comment by '.$commentauthor." below threshold (".sprintf("%.2f",$commentscore).")<br>",'RPCommentDiv'.$commentid);
				}
			}
			else {
				$text.="$commentid Hash: \"$hash\" Original: \"$commenthash\"";
			}
		}
	}
	$text="No comments above abuse threshold ($abusethreshold)" if (!$text);
	return $text;
}
sub _commentReputation {
	my ($commentid, $commentauthor) = @_;
	my $commentscore=0;
	my %commentdb;
	my $text="";
    tie %commentdb, 'MLDBM', -Filename => $commentfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$topicfile: $!\n";
	my $voteinfo= $commentdb{$commentid};
	my %seen ;
	# Comment author reputation
	my @userarr=$commentauthor;
	my $cred=0;
	# default number of up votes for commment author is 3
	# he can vote his own comment up though
	# if the votes are counted without reputation this
	# needs to be higher, use 1 as the reputation threshold
	# so this value can be negative
	$cred=_credibility(\@userarr,1)*3 unless (TWiki::Func::isGuest());
	$commentscore=$cred;
	foreach my $vote (keys %$voteinfo) {
		my $action='commentvote';
		@userarr=(keys %{$voteinfo->{$vote}});
 		$action = 'commentremove' if ($voteinfo->{$vote}->{$user});
		$cred=scalar @userarr;
		$cred=_credibility(\@userarr) unless (TWiki::Func::isGuest());
	    my $value=$commentvotevalues{$vote};
		$commentscore+=$cred*$value;
		$seen{$vote}=_commentThumbs($action,$vote,(scalar @userarr), $commentid, $commentauthor) if($commentvotevalues{$vote});
	}
	$text.="Commentscore: $commentscore for $commentid" if ($debug);
	$text.='<span id="buttons">';
    my @allVotes = keys %commentvotevalues;
    foreach (@allVotes) {
    	unless ( $seen{$_} ) {
       		$seen{$_}=_commentThumbs('commentvote', $_, "0", $commentid, $commentauthor);
       	}
    }
	if (!TWiki::Func::isGuest()){
		$text.=
    	join( ' ', map { $seen{$_} } sort _commentvoteoptionsort keys(%seen) );
		$text.='</span><br>';
	}
	untie %commentdb;	
	return $commentscore,$text;	
}
# Check the trustvalue of latest editor
sub _checkLastEdit {
	my ($trustref)=@_;
	my ( $date, $author, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic);
	my (%trust)=%$trustref;
	if (TWiki::Func::userToWikiName($user,1) eq $author) {
		return ($author,1000);
	}
	elsif (defined $trust{$author}) {
		return ($author,$trust{$author});
	}
	else {
		return 0;
	}
}
# Sort voteoptions by value instead of the key
sub _voteoptionsort {
	$votevalues{$b} <=> $votevalues{$a}
}

sub _commentvoteoptionsort {
	$commentvotevalues{$b} <=> $commentvotevalues{$a}
}
#Basically this is what backlinktemplate does, but using | and # as separators for the results
#in order to filter out the codeparts from the search output.
# Obs! Because this function is not using only the API but parses TWiki topictext, it can break when TWiki version changes
sub _backlinkcount {
	#First search this topic's web for baclinks
	my %seen=();
	# Define the search term and formatting options for this web
	my $text="\%SEARCH\{ search\=\"$topic\(\[\^A\-Za\-z0\-9\]\|\$\)\|$web.$topic\(\[\^A\-Za\-z0\-9\]\|\$\)\" web\=\"$web\" scope\=\"text\" excludetopic\=\"$topic\" exclude\=\"@systemTopics\" type\=\"regex\" format\=\"\|\#\$web.\$topic \|\#\" nosearch\=\"on\" \}\%";
	# Get the search results
	my $newtext=TWiki::Func::expandCommonVariables( $text);
  	my $samewebcounter=0;
	#Split the search results using separators given in formatting options
   	my @backlinkarray=split ( /\|\#/, $newtext);
    # Add elements to seen if they aren't seen yet
   	foreach my $backlink (@backlinkarray) {
    	    $backlink=~s/\s//g;
    	    if ($backlink=~/$wikiwordRegex/ && !$seen{$backlink}) {
    		    ++$samewebcounter;
    			$seen{$backlink}=1;
    	    }
    	}
	# Do not check all webs if we have already reached the maximum
	if ($samewebcounter<=$backlinkmax){
		# Define the search term and formatting options for all webs
    	$text="\%SEARCH\{ search\=\"$web.$topic\" web\=\"all\" exclude\=\"@systemTopics\" type\=\"regex\" scope\=\"text\" format\=\"\|\#\$web.\$topic \|\#\" nosearch\=\"on\" \}\%";
    	$newtext=TWiki::Func::expandCommonVariables( $text);
    	@backlinkarray=split ( /\|\#/, $newtext);
    	my $counter=0;
    # Add elements to seen if they aren't seen yet
    	foreach my $backlink (@backlinkarray) {
        	$backlink=~s/\s//g;
        	#Wikiword regex from twiki libs
        	if ($backlink=~/$wikiwordRegex/ && !$seen{$backlink}) {
        		++$counter;
        		$seen{$backlink}=1;
        	}
    	}
    	$samewebcounter=$samewebcounter+$counter;
    }
    if ($samewebcounter>$backlinkmax){
    	$samewebcounter=$backlinkmax;
    }
    return $samewebcounter;
}
#This function counts voter's reputation
sub _credibility {
    my ($users,$minrep)=@_;
	$minrep=$threshold if (!$minrep);
    # This could be something lower and perhaps user configurable
    my $recommendationweight=1;
    my $result=0;
    my $score=0;
    my $value=0;
    my $username;
    my (%trust)=_readTrusted($user);
    my @userlist=@{$users};
	my @unknown=();
    foreach my $line (@userlist){
        $line=TWiki::Func::userToWikiName( $line,1);
        # the user has voted this topic
        if ($line eq $user) {
            $result=$result+$myweight;
        }
        elsif ($trust{$line}) {
            $score=$trust{$line};
            # We do not take into account users who aren't trustworthy enough
            # if threshold is set below 500, votes from users below the 500 are counted with negative value
            # If we consider them as noise, it's better just to ignore these people by keeping the threshold at 500
            if ($score>$minrep){
                $value=_numberfromscore($score);
                $result=$result+$value;
            }
        }
        elsif ($recommendations) {
        	push (@unknown, $line);
        }
    }
    if ($recommendations){
		$result=$result+_recommendationSearch( \@unknown, %trust)*$recommendationweight;
    }

    return $result;
}
# This searches all the trustworthy persons in users trust file for recommendations
# <500 recommendationthresholds are not advisable  
sub _recommendationSearch {
	my ($userlistref, %trust) = @_;
	# can't pass two arrays to function, first eats the second.
	my @userlist=@{$userlistref};
	my %result;
	my $sum=0;
	my $normalization=1;
	# Use the db directly since multiple entries may have to be
	# fetched
	my %trustdb;
    tie %trustdb, 'MLDBM', -Filename => $trustfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$trustfile: $!\n";
	foreach my $person(keys %trust){
        # If the person is considered trustworthy his opinion can be taken into account
        if ($trust{$person}>$recommendationthreshold) {
        	my @known;
        	$person=TWiki::Func::wikiToUserName($person);
            my $friend = $trustdb{$person};
            my $weight=_numberfromscore($trust{$person});
            if (scalar keys %$friend) {
        	   @known = grep( $friend->{$_}, @userlist );
        	   foreach my $found (@known){
        	   	if (defined $result{$found}) {
        	   		$result{$found}{"value"}=$result{$found}{"value"}+_numberfromscore($friend->{$found})*$weight;
        	   		++$result{$found}{"normalize"} if ($normalization);
        	   	}
        	   	else {
        	   		$result{$found}{"normalize"}=1;
        	   		$result{$found}{"value"}=_numberfromscore($friend->{$found})*$weight;
        	   	}
        	   }
			}
		}
	}
	foreach my $found (keys %result) {
		$sum=$sum+$result{$found}{"value"}/$result{$found}{"normalize"};
	}
	untie %trustdb;
	return $sum;
}
# This function is completely ad hoc, it's supposed to model a curve with
# fast changes at close to the default value and slower ones at the
# end of the range.
# Sin and sqrt do not need any extra math libraries.
sub _numberfromscore {
    my ($score)=@_;
    my $number=$score-$defaulttrustvalue;
	# Normalize the value
    $score=$number/$maxtrustvalue;
	# This approximation for pi should be enough for this purpose
    if ($number>0){
	    $number=sqrt(sin ($score*3.14159));
    }
    else {
	    $number=sqrt(abs(sin ($score*3.14159)))*-1;
    }
    return $number;
}
# What do we do if the user has more weight groups than 1
# First one will be the deciding one, but how we'll know the first
# if we shuffle it by making it assoc?
sub _checkWeight {
    my $weight=1;
    my $optionline = TWiki::Func::getPreferencesValue("REPUTATIONPLUGIN_WEIGHTGROUPS", $web) || "";
    my @weightgroups=split( /\,/,$optionline);
    if (scalar @weightgroups){
		# foreach would be simple but every other value is a number
        for (my $i=0; $i<scalar(@weightgroups); $i=$i+2){
		# Group names are wikiwords
            if ($weightgroups[$i] =~ /$wikiwordRegex/ && TWiki::Func::isGroupMember($weightgroups[$i])) {
				if (defined $weightgroups[$i+1]) {
                	$weight=$weightgroups[$i+1];
				}
                last; # we found the first matching group
            }
        }
    }
    if ($weight =~ /([0-9]+)/) {
		$weight=$1;
	}
	else {
		$weight=1;
	}
    return $weight;
}
# Removes vote from topic and calls remove from user dbs
sub _REMOVEVOTE {
    my ($rmVote) = @_;
	return _wrapHtmlFeedbackErrorInline($LH->maketext("Please log in to vote.")) if (TWiki::Func::isGuest());
    my $webTopic = "$web.$topic";
	my %topicdb ;
	tie %topicdb, 'MLDBM', -Filename => $topicfile,
    	-Flags    => DB_CREATE
	'Lock'      =>  'File',
     'Lockfile'  =>  '/tmp/Tie-MLDBM-topic.lock'

         or die "Cannot open database '$topicfile: $!\n";
	my $voteinfo= $topicdb{$webTopic};	
	
    my $text     = '';
    my $num      = '';
    my $users    = '';
    my $removed	 = 0;
	if ($voteinfo->{$rmVote}) {
		foreach my $rev (keys %{$voteinfo->{$rmVote}}) {
			#delete value  and unused tree, should I delete the DB also?
			if ($voteinfo->{$rmVote}->{$rev}->{$user}) {
				_addtotoplist($voteinfo->{$rmVote}->{$rev}->{$user}*$votevalues{$rmVote}*-1,1);
				delete $voteinfo->{$rmVote}->{$rev}->{$user};
				# Perl deletes the tree if it is unused
				_addQuota($rmVote) if (TWiki::Func::getPreferencesFlag('REPUTATIONPLUGIN_WEBQUOTA'));
                $text .=$LH->maketext(" removed vote for \"[_1]\" ", $buttonStrings{$rmVote});
				$topicdb{$webTopic}=$voteinfo;
				$text.=_removetrust($webTopic);
				last;
    		}
            
        }
        if (!$text) {
	        #User is probably submitting the same parameters again
            $text .= _wrapHtmlFeedbackErrorInline($LH->maketext("You haven't voted this, not removed."));
        }
   }
   else {
		$text .= _wrapHtmlFeedbackErrorInline($LH->maketext("You haven't voted this, not removed."));
   }   
	untie %topicdb;
    return _showDefault().$text;
}
sub _removetrust {
    my ($Targetwebtopic )=@_;
    my $text='';
	$Targetwebtopic="$web.$topic" if (!$Targetwebtopic);
	my %usersdb ;
	tie %usersdb, 'MLDBM', -Filename => $userfile,
    	-Flags    => DB_CREATE
'Lock'      =>  'File',
     'Lockfile'  =>  '/tmp/Tie-MLDBM-user.lock'

         or die "Cannot open database '$userfile: $!\n";

	my  $voteinfo= $usersdb{$user};	

    my $lastvote='';
    my $num=0;
	if ($voteinfo->{$Targetwebtopic}) {
    	$num=$votevalues{$voteinfo->{$Targetwebtopic}{'vote'}}*-1;
    	my @changedusers=@{$voteinfo->{$Targetwebtopic}->{'authors'}};
    	if (!scalar @changedusers) {
		my ($currentrev, %lastauthors)=_searchAuthors($voteinfo->{$Targetwebtopic}{'rev'});
        	@changedusers=keys %lastauthors;
    	}
        my $wikipages=join(" $TWiki::cfg{UsersWebName}",@changedusers) if ($debug);
        $text.=_updateusers($num, @changedusers);
        $text.=$LH->maketext(" affecting [quant,_1,user] [_3].[_2]", scalar(@changedusers), $wikipages, $TWiki::cfg{UsersWebName}) if ($debug);
    delete $voteinfo->{$Targetwebtopic}; 
	}
	$usersdb{$user}=$voteinfo;
	untie %usersdb;
	_trustvoters($Targetwebtopic,$lastvote,1) if ($voterreputation);
    return $text;
}
# Quota functionality added for restricted votings, such as
# only two positive votes per person in one web.
sub _substractQuota {
	my ($vote) = @_;
	my %quota = _readQuotafile();
	if (scalar keys %quota) {
		if($quota{$vote}){
			$quota{$vote}=$quota{$vote}-1;
			_writeQuotafile(%quota);
			return 1;
		}
		else {
			return 0;
		}
	}
	else {
		if (_writeQuotafile()){
			return _substractQuota($vote);
		}
		else {
			return 0;
		}
	}
}
# Add one point to quota file, used when vote is removed
sub _addQuota {
	my ($vote) = @_;
	my %quota = _readQuotafile();
	if (scalar keys %quota) {
		if(defined $quota{$vote}){
			$quota{$vote}=$quota{$vote}+1;
			_writeQuotafile(%quota);
			return 1;
		}
		else {
			return 0;
		}
	}
	else {
		# This is the first time user votes after quota has been set
		# in this case we do not add a vote to quota
		if (_writeQuotafile()){
			return 1;
		}
		else {
			return 0;
		}
	}
}
sub _ADDVOTE {
    my ($addVote, $revision) =@_;
	return _wrapHtmlFeedbackErrorInline($LH->maketext("Please log in to vote.")) if (TWiki::Func::isGuest());
	if (!$revision) {
	my ($date, $author,$comment);
	( $date, $author, $revision, $comment ) = TWiki::Func::getRevisionInfo($web, $topic);
	}
    my $webTopic = "$web.$topic";
	my %topicdb ;
    tie %topicdb, 'MLDBM', -Filename => $topicfile,
    	-Flags    => DB_CREATE
	'Lock'      =>  'File',
     'Lockfile'  =>  '/tmp/Tie-MLDBM-topic.lock'

         or die "Cannot open database '$topicfile: $!\n";
	my $voteinfo= $topicdb{$webTopic};	
    my $text     = '';
    my $num      = '';
    my $users    = '';
    my @result   = ();
	my $quotainuse= TWiki::Func::getPreferencesFlag('REPUTATIONPLUGIN_WEBQUOTA')||0;
    my $votedone = 0;
    my $weight = _checkWeight();
    # Topic exists and the vote value is legal
    if ( TWiki::Func::topicExists( $web, $topic ) && defined $addVote && $votevalues{$addVote}) {
		# The search is unefficient, luckily not done often 
        foreach my $vote (keys %$voteinfo) {
            foreach my $rev (keys %{$voteinfo->{$vote}}) {
                # This is the vote were interested in
                if (($vote eq $addVote) && $voteinfo->{$vote}->{$rev}->{$user} ) {
                	$text .=$LH->maketext("Vote already done, remove to add again");
                    $votedone=1;
					last;
                }
				elsif ($voteinfo->{$vote}->{$rev}->{$user} ) {
					_addtotoplist($voteinfo->{$vote}->{$rev}->{$user}*$votevalues{$addVote}*-1, 1);
					delete $voteinfo->{$vote}->{$rev}->{$user};
					# Perl deletes the tree if it is unused
					_addQuota($vote) if ($quotainuse);
                    $text .=$LH->maketext("Removed vote for \"[_1]\".", $buttonStrings{$vote});
					$text.=_removetrust($webTopic);
				}
			}
			if (!$votedone && ($vote eq $addVote)) {
                if ($quotainuse && !(_substractQuota($vote))){
                	$text .=$LH->maketext("You have no more \"[_1]\" votes for this web. Remove vote from another topic if you would like to vote this topic instead ~[~[[_2].ReputationPluginVoted~]~]", $buttonStrings{$vote}, $TWiki::cfg{SystemWebName});
					last;
				}
                # add user to existing vote
            	else {		 
					$voteinfo->{$vote}->{$revision}->{$user}=$weight;
					_addtotoplist($weight*$votevalues{$addVote});
                	$votedone=1;
                	$text .=$LH->maketext(" Vote for \"[_1]\" added.",$buttonStrings{$vote});
                }
            }
        }
    	unless ($votedone) {
    		# this vote is first of its type
        	if ($quotainuse &&!_substractQuota($addVote)){
    	   	$text .=$LH->maketext("You have no more \"[_1]\" votes for this web. Remove vote from another topic if you would like to vote this topic instead ~[~[[_2].ReputationPluginVoted~]~].", $buttonStrings{$addVote}, $TWiki::cfg{SystemWebName});
        	}
			else {
           		$voteinfo->{$addVote}->{$revision}->{$user}=$weight;
				_addtotoplist($weight*$votevalues{$addVote});
            	$votedone=1;
            	$text .=$LH->maketext(" Vote for \"[_1]\" added.",$buttonStrings{$addVote});	
        	}
    	}
    }
    else {
        $text.=
          _wrapHtmlFeedbackErrorInline($LH->maketext("Vote not added the option [_1] is not available",$addVote));
    }
    if ($votedone) {
    	$text.=_addTrust($webTopic,$addVote);
	    $topicdb{$webTopic}=$voteinfo;
	}
	untie %topicdb;
    return _showDefault() .$text;
}
sub _searchAuthors {
	my ($maxrev)=@_;
	my %authors=();
	my $loop=0;
	my ( $date, $author, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic);
	my $currentrev=$rev;
	if (!$maxrev){
	    $loop=$rev-1;
    	$authors{$author}=1;
	}
	else {
		$loop=$maxrev;
	}
    while ($loop) {
        ( $date, $author, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic, $loop);
        $loop--;
        #There is no use for this value, but it could be used in later revisions
        if ($authors{$author}){
            $authors{$author}=++$authors{$author};
        }
        else {
        	$authors{$author}=1;
        }
    }
    return $currentrev,%authors;
}
# We add trust to the authors,
sub _addTrust {
    my ($Targetwebtopic, $vote) = @_;
    #Find authors for the topic
    my ($currentrev,%authors)=_searchAuthors();
    # Put the authors into regular array
    my $text='';
    my $num=0;
    my $found=0;
    my $lastvote='';
	my %usersdb ;
	my %lastauthors;
    tie %usersdb, 'MLDBM', -Filename => $userfile,
    	-Flags    => DB_CREATE
	'Lock'      =>  'File',
     'Lockfile'  =>  '/tmp/Tie-MLDBM-user.lock'

         or die "Cannot open database '$userfile: $!\n";
	my  $voteinfo= $usersdb{$user};	
	# Vote is an update
	if (defined $usersdb{$user} && $voteinfo->{$Targetwebtopic}) {
		$lastvote=$voteinfo->{$Targetwebtopic}->{'vote'};
		$num=$votevalues{$lastvote}*-1;
		if (!$voteinfo->{$Targetwebtopic}->{'authors'}) {
			($currentrev,%lastauthors)=_searchAuthors($voteinfo->{$Targetwebtopic}->{'rev'});
			$text=_updateusers($num, keys %lastauthors);
		}
		else {
			$text=_updateusers($num,@{$voteinfo->{$Targetwebtopic}->{'authors'}});
		}
		_trustvoters($Targetwebtopic, $lastvote,1,$voteinfo->{$Targetwebtopic}->{'rev'}) if ($voterreputation);      
	}
	# update or create
	if ($vote) {
		my @authors=keys %authors;
		$voteinfo->{$Targetwebtopic}->{'vote'}=$vote;
		$voteinfo->{$Targetwebtopic}->{'rev'}=$currentrev;
		@{$voteinfo->{$Targetwebtopic}->{'authors'}}=@authors;
		$num=$votevalues{$vote};
		$text.=_updateusers($num, @authors);
    	_trustvoters($Targetwebtopic, $vote) if ($voterreputation);
	}
	$usersdb{$user}=$voteinfo;
	untie %usersdb;
    return $text;
}
# Optional function: add weight to people who have given similar reviews as the user
# This way we can balance the positive and negative bias some people have
# Security consideration! 
# This can have an effect on the anonymity of the votes, bad thing if anonymity is a goal
# so it will be optional and can be turned on only by site admins (crypting the names with a secret known to the site admins could be an additional option)
# perl Crypt::CBC with base64 would be a simple method, but the encryption key would have to be given in LocalSite.cfg
# Also the encypted wikinames and values have to be separated from plaintext user names by some method
# some options like ALLOW_IF_ENCRYPTED and ALLOW_PLAIN have to be developed in order to cope with missing
# libraries
sub _trustvoters {
    my ($Targetwebtopic, $vote, $remove, $maxrevision) = @_;
    my $text='';
    my %votes = _readVoteInfo($Targetwebtopic);
    foreach my $currentvote (keys %votes) {
        my $addedtrust=0;
		my @userarray;
		my @revisionarr=sort keys %{$votes{$vote}};
		if ($maxrevision) {
			while ($revisionarr[-1]>$maxrevision && scalar @revisionarr) {
				pop (@revisionarr);
			}
		}
		foreach my $revision (@revisionarr) {
			push (@userarray, keys %{$votes{$currentvote}{$revision}});
    	    $vote=~ s/\s//g;

    	    # we could use the difference of voting options eg. abs(score1-score2) in order to punish more those who
    	    # vote more wrong than others
    	    if ($currentvote eq $vote){
    			if ($remove) {
    				$addedtrust=-1;
    			}
    			else {
    				$addedtrust=1;
    			}
    		}
    	    else {
    	    	if ($remove) {
    		    	$addedtrust=1;
    	    	}
    	    	else {
    	    	$addedtrust=-1;
    	    	}
    	    }
		}
       	$text.=_updateusers($addedtrust, @userarray);
	}
	return $text;
}
# Update trust value with $num to usernames listed in @users
sub _updateusers {
    my ($num, @users )=@_;
	my %trustdb ;
	tie %trustdb, 'MLDBM', -Filename => $trustfile,
    	-Flags    => DB_CREATE
         
'Lock'      =>  'File',
     'Lockfile'  =>  '/tmp/Tie-MLDBM-trust.lock'
or die "Cannot open database '$trustfile: $!\n";
	my $trusted= $trustdb{$user};	
    my $value;
    my $text='';
    my $username;
    my @newinfo;
    foreach my $line (@users){
        $line=~s/\s//g;
        # Usernames can be different from wikinames, and they are used in
        # different places, we try to save with wikiname here
		$line=TWiki::Func::userToWikiName($line,1);
        if ($trusted->{$line} && defined $num){
        	$value=$trusted->{$line}+$num;
        	$text.=$value if ($debug);
        	#Prevent over/under flows
        	if ($value>$maxtrustvalue) {
        		$value=$maxtrustvalue;
        	}
        	elsif ($value<$mintrustvalue) {
        		$value=$mintrustvalue;
        	}
            $trusted->{$line} = $value;
        }
		# He is new to us if he exists and isn't the user
        elsif ($line && (TWiki::Func::wikiToUserName($line) ne $user || $line ne $user) && TWiki::Func::wikiToUserName($line)) {
			$value=sprintf( '%03d',$defaulttrustvalue+$num);
			$trusted->{$line}=$value;
			$text.="new $value $line $trusted->{$line} $num" if ($debug);
           
    	}
    }
	$trustdb{$user}=$trusted;
	untie %trustdb;
	return $text;
}

# URI::Escape doesn't work nicely with mod_perl for unknown reason
#use URI::Escape;
#my $topiclink=uri_escape($topic);
sub _percentescape {
	my ($text)=@_;
	my $forbidden='(!|\*|\'|\(|\)|\;|:|@|&|=|\+|\$|,|/|\?|#|\[|\])';
	my $link=$text;
	$link=~ s/$forbidden/'%'. unpack("H*", $1)/ge;
	return $link;
}
# make voting buttons for comments, currently almost the same as
# the normal votebuttons. Should change to a leaner and smaller interface
sub _commentButtons {
	my ($action, $vote, $count, $targetid) =@_;
 	my $text = '';
	my $htmlcode='';
	my $topiclink=_percentescape($topic);
	if ($vote && $action && $targetid) {
	   	$text="$actionStrings{$action} $buttonStrings{$vote}";
	    $htmlcode="<a class=\"reputationbutton\" href=\"$topiclink\?rpaction=$action&vote=$vote&target=$targetid\"><span><img src=\"$attachUrl/smiley/$vote.gif\" ondblclick=\"return false;\"></img> $text ($count) </span></a>\n";
	}
	return $htmlcode;
}
# the leaner and smaller interface is this
sub _commentThumbs {
	my ($action, $vote, $count, $targetid,$targetuser) =@_;
 	my $text = '';
	my $htmlcode='';
	my %flagtext=("poor", " Flag ");
	my %thumbimages= ("positive","thumbup.png", "negative","thumbdown.png", "poor" ,"poor.gif");
	my $topiclink=_percentescape($topic);
	if ($vote && $action && $targetid) {
	   	$text="$actionStrings{$action}";
	    $htmlcode='<a href="'.$topiclink.'?rpaction='.$action.'&vote='.$vote.'&target='.$targetid.'&targetuser='.$targetuser.'"><span>'.$flagtext{$vote}.'<img src="'."$attachUrl/smiley/".$thumbimages{$vote}.'"  ondblclick="return false;"></img> '."$text ($count)</span></a>\n";
	}
	return $htmlcode;
}

sub _smileybuttons {
	my ( $action, $vote, $count ) = @_;
	my $text = '';
	my $htmlcode='';
	my $topiclink=_percentescape($topic);
	if ($vote && $action) {
	   	$text="$actionStrings{$action} $buttonStrings{$vote}";
	    $htmlcode="<a class=\"reputationbutton\" href=\"$topiclink\?rpaction=$action&vote=$vote\"><span><img src=\"$attachUrl/smiley/$vote.gif\" ondblclick=\"return false;\"></img> $text ($count) </span></a>\n";
	}
	return $htmlcode;

}
# Html submit buttons
sub _votebutton {
    my ( $action, $vote, $count ) = @_;
    my $text = '';
 	# We check the theme
 	if ($smileybuttons && $vote) {
 		$text=_smileybuttons( $action, $vote, $count );
 	}
 	# simple form buttons if style is plaiṇ.
    elsif ($vote) {
	my $topiclink=_percentescape($topic);
        $text = "\<form name\=\"new$vote\" action\=\"$topiclink\"\ method=\"post\">
    \<input type\=\"hidden\" name=\"rpaction\" value=\"$action\"/\>
    \<input type\=\"hidden\" name\=\"vote\" value\=\"$vote\"\/\>
     \<input type\=\"submit\" class\=\"twikiSubmit\" value\=\"$actionStrings{$action} $buttonStrings{$vote}\ \($count\)\" \/\>
\<\/form\>";
    }
	return $text;
}
# Functions for writing and reading files

# Read votes file and return array of the non-comment lines
sub _readVoteInfo {
    my ($webTopic) = @_;
    $webTopic =~ s/[\/\\]/\./g;
	my %topicdb ;
    tie %topicdb, 'MLDBM', -Filename => $topicfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$topicfile: $!\n";
	my %info= %{$topicdb{$webTopic}};	
	untie %topicdb;
    return %info;
}

# read the toplist for a given web
sub _readTopfile {
	my ($currentweb)=@_;
	# Replace the slash in subweb with a dot
	$currentweb=~ s/[\/\\]/\./g;
	my %topdb;
    tie %topdb, 'MLDBM', -Filename => $topfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$topfile: $!\n";
	my %topics ;
	if (defined $topdb{$currentweb}) {
		%topics = %{$topdb{$currentweb}};
	}
	
	untie %topdb;
	return %topics;
}
# Return the contents of quotafile in an assoc array,
# array will be empty if its lines do not match the format
sub _readQuotafile {
    my $text = TWiki::Func::readFile("$workAreaDir/_quota_$web.$user.txt");
    my @info = grep { /^[0-9]/ } split( /\n/, $text );
    my %quota=();
    my $value=0;
    my $vote='';
   foreach my $line (@info){
        if ( $line =~ /(^[0-9]+),(.*)/ ) {
            $value = $1;
            $vote = $2;
            $vote =~s/\s//g;
            $quota{$vote}=$value;
        }
    }
    return %quota;
}
# Return false if the file to be written is empty
# this function is a bit more tricky than the others since it
# has to read parameters
sub _writeQuotafile {
	my (%quota)=@_;
	my @newinfo=();
	my $value=0;
	my $file = "$workAreaDir/_quota_$web.$user.txt";
	# If we didn't get anything as a parameter
	unless (scalar keys %quota) {
		my $text = TWiki::Func::getPreferencesValue('REPUTATIONPLUGIN_QUOTATMPL', $web);
		$text=~ s/\s//;
		my @quotacandidate = split( /\,/, $text );
		    if (scalar @quotacandidate){
    		    for (my $i=0; $i<scalar(@quotacandidate); $i=$i+2){
						# We could match this exactly but our quotaoptions can be different from our
						# current voteoptions on purpose as well.
		        	    if ($quotacandidate[$i] && $quotacandidate[$i]=~/($voteRegex)/) {
    		    	        $quota{$quotacandidate[$i]}=$quotacandidate[$i+1];
    		    	    }
    	    	}
    		}
    }
	# If we didn't get anything sensible from Preferences
    unless (scalar keys %quota) {
    	%quota=%quotatemplate;
    }
	foreach my $vote (keys %quota) {
        $value=$quota{$vote};
	    push (@newinfo, "$value\, $vote");
    }
	if ( scalar @newinfo ) {
    	my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", @newinfo ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    	}
    else {
    	return 0;
    }
	return 1;
}

sub _readTrusted {
    my ($username)=@_;
	my %trustdb;
    tie %trustdb, 'MLDBM', -Filename => $trustfile,
    	-Flags    => DB_CREATE
         or die "Cannot open database '$trustfile: $!\n";
	my %trust;
	if (defined $trustdb{$username}) {
		%trust = %{$trustdb{$username}};
	}
	untie %trustdb;
    return %trust;
}

# Return error messages without html and with alert theme
sub _wrapHtmlFeedbackErrorInline {
    my ($text) = @_;
    $text=HTML::Entities::encode($text);
    return "<span class=\"twikiAlert\">$text</span>";
}
# show votes according to user's groups
sub _groupview {
	return '' unless ( TWiki::Func::topicExists( $web, $topic ) );
	my $text='';
	my $webTopic = "$web.$topic";
	my %voteInfo= _readVoteInfo($webTopic);
	my %grouplines=();

	# Build twodimensional associative array from vote information
	foreach my $vote (keys %voteInfo) {
		my @userar;
		my $count=0;
		foreach my $revision (keys %{$voteInfo{$vote}}) {
			push (@userar,keys %{$voteInfo{$vote}{$revision}});
		}
		my $allgroups=TWiki::Func::eachMembership($user);
	   	while ($allgroups->hasNext()) {
			my $currentgroup=$allgroups->next();
			$text.=$currentgroup if ($debug);
			$count=_memberCount(\@userar,$currentgroup);
			#$text.="$users $count" if ($debug);
			if ($count) {
				$grouplines{$currentgroup}{$vote}=$count;
			}
		}
	}
	# Sort by group and display the results
	foreach my $key (sort keys %grouplines) {
		$text.="<div style=\"width:305px; height:42px; float:left; margin-rigth:5px;\">";
		$text.="[[$TWiki::cfg{UsersWebName}.$key]] ";
		$text.=_makePrettyBars(%{$grouplines{$key}});
    	$text.="</div>";
    }
	$text.=_showDefault();
	return $text;
}
# This function takes votes and their number as an argument and returns a percentage bar
sub _makePrettyBars {
	my %bardata=@_;
	my $sum=0;
	my $text='';
	($sum+=$_) for values %bardata;
	$text.="<link href=\"$attachUrl/bar/graph2.css\" media=\"all\" rel=\"stylesheet\" type=\"text/css\" />";
	$text.="<div class=\"reputationgraphcont\"><div class=\"reputationgraph\">";
	foreach my $key (sort {$votevalues{$a} <=> $votevalues{$b}} (keys %bardata)){
		my $percentage=$bardata{$key}/$sum*100;
		$percentage=sprintf("%.2f", $percentage);
		# all the voteoptions must exist as classes in the css file
		$text.="<strong class=\"$key";
		$text.="bar\" style=\"width:$percentage\%\">$buttonStrings{$key} ($bardata{$key})</strong>";
	}
	$text.="<div class=\"clear\"></div></div></div>";
	return $text;
}
# Count the number of users given in list belonging to the given group
sub _memberCount {
	my ($userarref,$group)=@_;
    my @userlist=@$userarref;
    my %voters=();
    my $count=0;
    foreach my $member (@userlist){
    	$member=~ s/\s//g;
    	$member=~ s/\:\d+\://g;
    	if(TWiki::Func::isGroupMember($group,$member)){
    	++$count;
    	}
    }
    return $count;
}
# Twisty seems to have some serious problems hiding my content
# Will use the old implementation for the time being
#sub _hideDiv {
#	my ($text,$message,$divname,$hide)=@_;
#	$message="Show more" if (!$message);
#	$hide="Hide" if (!$hide);
#	$divname='toHide' if (!$divname);
#	$text='%TWISTY{id="'.$divname.'
#mode="div"
#showlink="'.$message.'
#hidelink="'.$hide.'" remember="on"}%'.$text.' %ENDTWISTY%';
#	return $text;
#}

# subfunction for making hidden user interface elements, which appear from a link, message is the link text
# divname can be useful if there are multiple user elements. Future improvements could include option to
# have an element shown by default and maybe changing link text
# One could use twistyplugin as an alternative, I discovered it a bit too late...
sub _hideDiv {
	my ($text, $message,$divname)=@_;
	# If the message is empty
	$message="Show more" if (!$message);
	$divname='toHide' if (!$divname);
	# Some javascript that hides and shows the div original code
	my $headtext ='<script type="text/javascript" src="'.$attachUrl.'/js/hide.js"></script>';
	my $id="REPUTATIONPLUGIN_HIDEJS";
	TWiki::Func::addToHEAD( $id, $headtext);
	$text='<div id="'.$divname.'">'.$text.'</div>';
	# Button for toggling the visibility of the UI
	$text.='<a href="javascript:toggleDivOL(\''.$divname.'\');">'.$message.'</a>';
	# CSS to make the div hidden by default
	$text='	<style type="text/css" media="screen">
div#'.$divname.'
{
position:absolute;
left: -4000px ;
}
</style>'.$text;
	return $text;
}
