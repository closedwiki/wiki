# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# Copyright (c) 2006 Fred Morris, m3047-twiki@inwa.net
# Copyright (c) 2007 Crawford Currie, http://c-dot.co.uk
# Copyright (c) 2007 Sven Dowideit, SvenDowideit@DistributedINFORMATION.com
# Copyright (c) 2007 Arthur Clemens, arthur@visiblearea.com
# Copyright (c) 2009 Joona Kannisto 
# Copyright (C) 2006-2010 TWiki Contributors
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

# change the package name and $pluginName!!!
package TWiki::Plugins::ReputationPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
# Global variables used in this plugin
use vars qw($web $topic $user $installWeb $VERSION $RELEASE $SHORTDESCRIPTION
   $debug $initialized $pluginName  $NO_PREFS_IN_TOPIC $workAreaDir
   $logAction $tagLinkFormat $action $absolute $backlinkmax);

$VERSION = '$Rev: 12445$';
$RELEASE = '2010-07-26';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Create and maintain user reputation in a TWiki site';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
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
$initialized = 0;
#This parser is for topic's vote file, taken from TagmePlugin
our $lineRegex   = "^0*([0-9]+), ([^,]+), (.*)";
# Parser for user's trust file
our $userRegex   = "^0*([0-9]+), (.*)";
# Parser for user's topics file
our $topicRegex = "([^,]+), ([^,]+), (.*)";
# Weights assigned to each voting option
our %votevalues = ("negative", -1, "positive", 1, "excellent", 2);

# Needed in credibility function. 
# These could be user defined.  
# Defined here for faster easier tuning.
our $threshold=500;
our $recommendationthreshold=500;
our $recommendations=1;
# Weight given to user's own votes
our $myweight=1;


# Maximum number for articles votevalue, not implemented yet
# Votes will be counted even after this, but this is the highest number displayed
our $votemax=20;
# Removing magic numbers
our $maxtrustlinevalue=999;
our $mintrustlinevalue=1;
our $defaulttrustlinevalue=500;
sub initPlugin {
     ($topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

    # Set plugin preferences in LocalSite.cfg, like this:
    # $TWiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} = 1;
    # Then recover it like this. Always provide a default in case the
    # setting is not defined in LocalSite.cfg

    $debug = $TWiki::cfg{Plugins}{ReputationPlugin}{Debug} || 0;
    # Maximum number of backlinks to prevent turning interlinking to a game 
	# Can be used to disable the backlink search feature if set to 0
	# Backlinksearch may have poor performance with huge number of topics
	$backlinkmax = $TWiki::cfg{Plugins}{ReputationPlugin}{Backlinkmax} || 20;
    # Shows votes without taking voters reputation into account
    $absolute = $TWiki::cfg{Plugins}{ReputationPlugin}{Absolute} || 0;
    #
    $initialized = 0;
    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    #_writeDebug("commonTagsHandler( $_[2].$_[1] )");
    $_[0] =~ s/%REPUTATION{(.*?)}%/_REPUTATION($1)/ge;
}
sub _initialize {
    return if ($initialized);

    # Initialization, this returns /tmp on huuliharppu for some reason (perhaps access rights to /var/lib/twiki/working are wrong or the plugin shouldn't be used in Sandbox Web for the first time
    $workAreaDir = TWiki::Func::getWorkArea($pluginName);
  
    $initialized = 1;
}
sub _REPUTATION {
    my ($attr) = @_; # attributes which come with TWiki function call 
	#isGuest function doesn't work (in all TWiki versions) so below is a simple version. 
    #return '' if (TWiki::Func::isGuest());
    if ($user eq 'guest' || TWiki::Func::getWikiName($user) eq 'TWikiGuest' ){
	return '';
}
    $action = TWiki::Func::extractNameValuePair( $attr, 'rpaction' );
	
    my $text = '';
    _initialize();
    # called with rpaction's value vote, in typical case voting button has been pressed
    if ( $action eq "vote" ) {
        $text = _ADDVOTE($attr);
    }
    elsif ( $action eq "remove") {
        $text = _REMOVEVOTE($attr);
    }
    # 
    elsif ($action eq "showtopics"){
    	$text = _SHOWTOPICS($attr);
    }
    elsif ($action eq "showtrusted"){
	    $text = _SHOWTRUSTED($attr);
    }
    elsif ($action eq "addtrust"){
    	$text = _trustvalueaddition($attr);
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
# Just printing file's contents, future improvements could include e.g. parsing of the file
# and turning usernames into links. Links could point to either users' homepages or to a generated page made 
# for checking and updating that user's trust value 
sub _SHOWTOPICS {
    my $text = TWiki::Func::readFile("$workAreaDir/_topics_$user.txt");
	#Remove comments
	$text =~ s/^#.*//g;
	# Make newlines new paragraphs, quick and dirty
	$text =~ s/\n/<p>/g;
    return $text;

}
# Manually adjust some users trustvalue. Should support some kind of nonce, in order to 
# prevent misuse. 
sub _trustvalueaddition {
	my ($attr) =@_;
	my $text = TWiki::Func::extractNameValuePair( $attr, 'addvalue' );
	my $wikiname = TWiki::Func::extractNameValuePair( $attr, 'user' );

	# Get sign, if any and the number part
	$text=~/(\-?|\+?)(\d*)/;
	
	if ($2 && TWiki::Func::wikiToUserName($wikiname)) {
		my $num="$1$2";
		_updateusers($num,$wikiname);
		$text="Trustvalue updated for user \"$wikiname\"";
	}
	elsif ($2) {
		$text="Wikiname does not exist";
	}
	elsif (TWiki::Func::wikiToUserName($wikiname)){
		$text.=" does not contain a valid number";
	}
	else {
		$text="Submit existing Wikiname and a negative or positive integer";
	}
	return $text;
}
# Same as the earlier function. Could include also buttons for trust value manipulation
sub _SHOWTRUSTED {
    my $text = TWiki::Func::readFile("$workAreaDir/_trusted_$user.txt");
	#Remove comments
	$text =~ s/^#.*//g;
	# Make newlines new paragraphs, quick and dirty
	$text =~ s/\n/<p>/g;
    return $text;

}
sub _showDefault {
    my (@voteInfo) = @_;

    return '' unless ( TWiki::Func::topicExists( $web, $topic ) );
    

    my $webTopic = "$web.$topic";
    @voteInfo = _readVoteInfo($webTopic); 
    my $text  = '';
    my $vote   = '';
    my $num   = '';
    my $users = '';
    my $line  = '';
    my %seen  = ();
    my $sum=0;
    # Backlinks should not be counted if $backlinkmax is zero
	if ($backlinkmax){

	    my $backlinks=_backlinkcount(); 
	    $text.="Popularity: $backlinks/$backlinkmax ";
	}
    foreach (@voteInfo) {
        # Format:  number of votes, given vote, users for this vote 
        if (/$lineRegex/) {
            $num   = $1;
            $vote   = $2;
            $users = $3;
            if ($absolute) {
            $sum=$sum+_votetovalue($vote)*$num;
            }
            else {
            
            my $value=_votetovalue($vote);
            my $cred=_credibility($users);
            $sum=$sum+$cred*$value;
            #$text.="\"$sum\"\"$value\"\"$cred\"\:\"$users\"\:";
            }
            # User has voted so a remove button is made
            if ( $users =~ /\b$user\b/ ) {
                $line = _votebutton( 'Remove ',
                    'remove', $vote, $num);
            }
            # 
            else {
                $line = _votebutton(  'Vote ',
                    'vote', $vote, $num );
            }
            #push votes that have been voted before into associative array
            $seen{$vote} = $line;
        }
    }
    # print the score for the article
    $sum=sprintf("%.2f", $sum); 
   $text.="Rating $sum ";
    # uppercase characters are possible, so sort with lowercase comparison
    $text .=
    join( ' ', map { $seen{$_} } sort { lc $a cmp lc $b } keys(%seen) );
    my @allVotes = keys %votevalues;
    my @notSeen = ();
    # This could be done in another way
    # using the previous associative array and joining it later
    foreach (@allVotes) {
        push( @notSeen, $_ ) unless ( $seen{$_} );
    }
    if ( scalar @notSeen ) {
    
        foreach (@notSeen) {
            
            $line = _votebutton(  'Vote ','vote', $_, "0");
            $text.=$line;
        }
    }    
    $text.=" [[TWiki.ReputationPluginChangeValues][Change trustvalues]]";
  return "<verbatim> $text </verbatim>" if ($debug);
    return $text;
}
#Basically what backlinktemplate does, but using | and # as separators for the results
#in order to filter out the codeparts from the search output
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
    	    if ($backlink=~/^[A-Z]/ && !$seen{$backlink}) {
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
        	#Wikinames should begin with capital letter
        	if ($backlink=~/^[A-Z]/ && !$seen{$backlink}) {
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
#This function makes articlescores dependant on the voter's reputation
sub _credibility {
    my ($users)=@_;
    my $result=0; 
    my $score=0;
    my $value=0;
    my $username;
    my (%trust)=_readTrusted($user);

    my @userlist=split( /\,/, $users );
    foreach my $line (@userlist){
        $line=~s/\s//g;
        if ($trust{$line}) {
            $score=$trust{$line};
            # We do not take into account users who aren't trustworthy enough
            # if threshold is set below 500 votes from users below the 500 are counted with negated value
            #  it's better just to ignore these people by keeping the threshold at 500
            if ($score>$threshold){
                $value=_numberfromscore($score);
                $result=$result+$value;
            }
        }
        # the user has voted this topic 
        elsif ($line eq $user) {
            $result=$result+$myweight;
        }
    }
    #This searches all the trustworthy persons in users trust file for recommendations
    # heavily nested, 
    # <500 recommendationthreshold can be used to negate untrusted user's vote 
    if ($recommendations){
        foreach my $person(keys %trust){
        # If the person is considered trustworthy his opinion can be taken into account
            if ($trust{$person}>$recommendationthreshold) {
                $person=TWiki::Func::wikiToUserName($person);
                my (%friend)=_readTrusted($person);
                my $weight=_numberfromscore($trust{$person});
                if (%friend) {
                    foreach my $line (@userlist){
                        $line=~s/\s//g;
                        if ($friend{$line}) {
                            $score=$friend{$line};
							# If our trusted friend has something good to say about this particular voter
                            if ($score>$threshold){
                                $value=_numberfromscore($score);
                                $result=$result+$value*$weight;
                             }
                       }
                    }
                }
            }
        } 
    }
    
    return $result;
}
# This function is completely ad hoc, it's supposed to model a curve with 
# fast changes at close to the default value and slower ones at the
# end of the range. 
# Sin and sqrt do not need any extra math libraries.  
sub _numberfromscore {
    my ($score)=@_;
    my $number=$score-$defaulttrustlinevalue;
	# Normalize the value
    $score=$number/$maxtrustlinevalue;
	# This approximation for pi should be enough for this purpose
	# use Math::Trig gives more exact value but introduces a performance penalty
    if ($number>0){
	    $number=sqrt(sin ($score*3.14159));
    }
    else {
	    $number=sqrt(abs(sin ($score*3.14159)))*-1;
    }
    
    return $number;
}
# Removes given vote for the article
sub _REMOVEVOTE {
    my ($attr) = @_;
    my $rmVote = TWiki::Func::extractNameValuePair( $attr, 'vote' );
    my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );

    my $webTopic = "$web.$topic";
    my @voteInfo  = _readVoteInfo($webTopic);
    my $text     = '';
    my $vote      = '';
    my $num      = '';
    my $users    = '';
    my @result   = ();
    my $removed=0;

    if ( TWiki::Func::topicExists( $web, $topic ) ) {
        foreach my $line (@voteInfo) {
            if ( $line =~ /$lineRegex/ ) {
                $num   = $1;
                $vote   = $2;
                $users = $3;
             
                if ( $vote eq $rmVote ) {
                    if ( $users =~ /\b$user\b/ ) {
                        $users =~ s/, $user\b//;
                        # If the previous substitution didn't work user is the first one 
                        $users =~ s/$user,//;
                        $num--;
                        $text .=
                            _wrapHtmlFeedbackInline(
                            "removed vote on $vote");
                        if($num) {
                            $line = _tagDataLine( $num, $vote, $users);
                             push( @result, $line );
                        }
                        $removed=1;

                    }
                    else {
                    #User is probably submitting same parameters again
                        $text .= _wrapHtmlFeedbackErrorInline("You haven't voted this, not removed.");
                        
                    }
                }
                else {
                    push( @result, $line );
                }
                
            }
            else{
         push( @result, $line );
        }
        }
    @voteInfo = reverse sort(@result);
    _writeVoteInfo( $webTopic, @voteInfo );
    }
    $text.=_removetrust($webTopic) if ($removed);
    
        
    return _showDefault(@voteInfo) . ( ($noStatus) ? '' : $text );
}
sub _removetrust {
    my ($Targetwebtopic )=@_;
    my $lastauthors;
    my $webtopic='';
    my $lastvote='';
    my $num=0;
    my @newinfo='';
    my $text = TWiki::Func::readFile("$workAreaDir/_topics_$user.txt");
    # This shouldn't use literals, but keys from %votevalues 
    my @info = grep { /^[negative|positive|excellent]/ } split( /\n/, $text );
     foreach my $line (@info){
             if ( $line =~ /$topicRegex/ ) {
                $lastvote   = $1;
                $webtopic = $2;
                $lastauthors = $3;
                if ($webtopic=~$Targetwebtopic) {
                    $num=_votetovalue($lastvote)*-1;
                    my @changedusers=split( /\,/, $lastauthors );
                    $text=_updateusers($num, @changedusers);
                    $text.=  _wrapHtmlFeedbackInline(
                            "removed $lastvote vote on users $lastauthors");
                }
                else {
                push (@newinfo, $line);
                }
                
             }
             else {
                push (@newinfo, $line);
                }
                      }
      $text.=_writeTrustTopic(@newinfo);
      return $text;
}
sub _ADDVOTE {    
   my ( $attr ) = @_;

    my $addVote = TWiki::Func::extractNameValuePair( $attr, 'vote' );
    my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );

    my $webTopic = "$web.$topic";
    my @voteInfo  = _readVoteInfo($webTopic);
    my $text     = '';
    my $vote      = '';
    my $num      = '';
    my $users    = '';
    my @result   = ();
    my $votedone = 0;
    # Topic exists and the vote value is legal
    if ( TWiki::Func::topicExists( $web, $topic ) &&  $votevalues{$addVote}) {
        foreach my $line (@voteInfo) {
            if ( $line =~ /$lineRegex/ ) {
                $num   = $1;
                $vote   = $2;
                $users = $3;
                if ( $vote eq $addVote ) {
                    if ( $users =~ /\b$user\b/ ) {
                        $text .="Vote already done, remove to add again";
                        return _showDefault(@voteInfo) . ( ($noStatus) ? '' : $text );
                    }
                    else {

                        # add user to existing vote
                        $line = _tagDataLine( $num + 1, $vote, $users, $user );
                        $votedone=1;
                        $text .=
                          _wrapHtmlFeedbackInline("voted \"$vote\"");
                    }
                    push( @result, $line );
                }
                elsif ( $users =~ /\b$user\b/ ) {
                        $users =~ s/, $user//;
                        # In case the user is first
                        $users =~ s/$user,//;
                        --$num;

                        _removeTrust($webTopic);

                        if($num) {
                            $line = _tagDataLine( $num, $vote, $users);
                            $text .=
                              _wrapHtmlFeedbackInline(
                                "removed \"$vote\"");
                            push( @result, $line );
                        }
                        else {
                              $text .=
                              _wrapHtmlFeedbackInline(
                                "removed \"$vote\"");  
                        }
                }
                else {
                            push( @result, $line );
                }
            }

        }
        unless ($votedone) {

            # this vote is first of its type 
                push( @result, "001, $addVote, $user" );
                $text .= _wrapHtmlFeedbackInline("voted \"$addVote\"");

                $votedone=1;
        }
        @voteInfo = reverse sort(@result);
        _writeVoteInfo( $webTopic, @voteInfo );
    }
    else {
        $text .=
          _wrapHtmlFeedbackErrorInline("vote not added, topic does not exist or $addVote is not valid");
    }


    
    if ($votedone) {
    _addTrust($webTopic,$addVote);
    }
    return _showDefault(@voteInfo) . ( ($noStatus) ? '' : $text );

}
sub _addTrust {
    my ($Targetwebtopic, $vote) = @_;
    
    #List authors for the topic
    # 
    my %authors=();
    my ( $date, $author, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic);
    my $loop=$rev-1;
    $authors{$author}=1;
    while ($loop) {
        my ( $date, $author, $rev, $comment ) = TWiki::Func::getRevisionInfo($web, $topic, $loop);
        $loop--;
        #There isn't use for this value, but it could be used in later revisions
        if ($authors{$author}){
            $authors{$author}=++$authors{$author};
        }
        else {
        $authors{$author}=1;
        }
    }
    # Put the authors into regular array
    my @authorlist=keys %authors;
    my $lastauthors;
    my $webtopic;
    my $lastvote;
    my $num=0;
    my $found=0;
    my @newinfo;
    
    my $text = TWiki::Func::readFile("$workAreaDir/_topics_$user.txt");
    my @info = grep { /^[negative|positive|excellent]/ } split( /\n/, $text );
     foreach my $line (@info){
             if ( $line =~ /$topicRegex/ ) {
                $lastvote   = $1;
                $webtopic = $2;
                $lastauthors = $3;
                # Get rid of the whitespace
                $webtopic=~s/\s//g;
                if ($webtopic eq $Targetwebtopic) {
                    $num=_votetovalue($lastvote)*-1;
                    my @changedusers=split( /\,\s+/, $lastauthors );
                    $text=_updateusers($num, @changedusers);
                    $num=_votetovalue($vote);
                    $text.=_updateusers($num,@authorlist);
                    $line=_voteDataLine($vote,$webtopic,@authorlist);
                    $found=1;
                }
             }
                push (@newinfo, $line);
      
       }
    unless($found) {
      $num=_votetovalue($vote);
      $text=_updateusers($num,@authorlist);
            
      push (@newinfo, _voteDataLine($vote,$Targetwebtopic,@authorlist));
    }
    $text.="\:@authorlist\:" if ($debug);
    $text.=_writeTrustTopic(@newinfo);
    return $text;     
}
sub _removeTrust {
    my ($Targetwebtopic) = @_;
    my $authors;
    my @newinfo;
    my $webtopic;
    my $vote;
    my $num=0;

    my $text = TWiki::Func::readFile("$workAreaDir/_topics_$user.txt");
    my @info = grep { /^[negative|positive|excellent]/ } split( /\n/, $text );
    foreach my $line (@info){
             if ( $line =~ /$topicRegex/ ) {
                $vote   = $1;
                $webtopic = $2;
                $authors = $3;
                if ($webtopic eq $Targetwebtopic) {
                    $num=_votetovalue($vote)*-1;
                    my @changedusers=split( /\,/, $authors );
                    $text=_updateusers($num, @changedusers);
                }
                else {
                push (@newinfo, $line);
                }
             }
    }
    $text.=_writeTrustTopic(@newinfo);
    return $text;
}
sub _updateusers {
    my ($num, @users )=@_;
    my $value;
    my $text='';
    my $username;
    my (%trusted)=_readTrusted($user);
    my @newinfo;
    foreach my $line (@users){
        $line=~s/\s//g;
        
        if ($trusted{$line}){
        	$num=$trusted{$line}+$num;
        	#Prevent over/under flows 
        	if ($num>$maxtrustlinevalue) {
        		$num=$maxtrustlinevalue;
        	}
        	elsif ($num<$mintrustlinevalue) {
        		$num=$mintrustlinevalue;
        	}
            $trusted{$line} = $num;
         }
         # He is new to us if he exists and isn't the user 
         elsif ($line && $line ne $user && TWiki::Func::wikiToUserName($line)) {
            $value=$defaulttrustlinevalue+$num;
            $trusted{$line}=$value;
         }
    }
    # Associative array back to normal for saving
    foreach my $person (keys %trusted) {
        $value=$trusted{$person};
	    push (@newinfo, "$value\, $person");
    }

   _writeTrusted(@newinfo);
   return $text;
}
# Function makes an assosiative array from the trust file
sub _readTrusted {
    my ($username)=@_;
    my $text = TWiki::Func::readFile("$workAreaDir/_trusted_$username.txt");
    my @info = grep { /^[0-9]/ } split( /\n/, $text );
    my %trust=();
    my $value=0;
    my $username='';
   foreach my $line (@info){
        if ( $line =~ /$userRegex/ ) {
            $value = $1;
            $username = $2;
            $username =~s/\s//g;
            $trust{$username}=$value;
        }
    }
    return %trust;
}
# Function will only write current users own trusted file
sub _writeTrusted {
    my (@info) = @_;
    my $file = "$workAreaDir/_trusted_$user.txt";
    if ( scalar @info ) {
        my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    }
    elsif ( -e $file ) {
        unlink($file);
    }
}
# Html submit buttons
sub _votebutton {
    my ( $title, $action, $vote, $count ) = @_;
    my $text = '';
    if ($vote) {
        $text = "\<form name\=\"new$vote\" action\=\"$topic\"\>
    \<input type\=\"hidden\" name=\"rpaction\" value=\"$action\"/\>
    \<input type\=\"hidden\" name\=\"vote\" value\=\"$vote\"\/\>
     \<input type\=\"submit\" class\=\"twikiSubmit\" value\=\"$title $vote\ \($count\)\" \/\>
\<\/form\>";
    }
	return $text;
}
#function is the stupid way to do "keys %votevalues", made before %votevalues existed
#sub _notvoted {
#return options that should be in every article
#    my @all;
#    push (@all, 'negative');
#    push (@all, 'positive');
#    push (@all, 'excellent');
#    return @all;
#}

# this function isn't necessary either
sub _votetovalue{
    my ($vote)=@_;
    my $num=0;
    if ($votevalues{$vote}){
    $num=$votevalues{$vote}
    }
    else { 
    $num=0;
    }
    return $num;
    
}    
# Read votes file and return array of the non-comment lines
sub _readVoteInfo {
    my ($webTopic) = @_;
    $webTopic =~ s/[\/\\]/\./g;
    my $text = TWiki::Func::readFile("$workAreaDir/_votes_$webTopic.txt");
    my @info = grep { /^[0-9]/ } split( /\n/, $text );
    return @info;
}
# Write array's contents into a file if the array is not empty
sub _writeTrustTopic {
    my ( @info ) = @_;
    my $file = "$workAreaDir/_topics_$user.txt";
    if ( scalar @info ) {
        my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    }
    elsif ( -e $file ) {
        unlink($file);
    }
}
sub _readTrust {
    my ($username) = @_;
    my $text = TWiki::Func::readFile("$workAreaDir/_trust_$username.txt");
    my @info = grep { /^[0-9]/ } split( /\n/, $text );
    return @info;
}
# Taken from TagmePlugin
sub _tagDataLine {
    my ( $num, $vote, $users, $user ) = @_;

    my $line = sprintf( '%03d', $num );
    $line .= ", $vote, $users";
    $line .= ", $user" if $user;
    return $line;
}
sub _voteDataLine {
    my ( $vote, $webtopic, @users) = @_;
    $"=', ';
    my $line .= "$vote, $webtopic, @users";
    return $line;
}
# Doesn't do anything at the moment, add style if needed
sub _wrapHtmlFeedbackMessage {
    my ( $text,  ) = @_;
    return $text;
}

# ========================
sub _wrapHtmlErrorFeedbackMessage {
    my ( $text, $note ) = @_;
    return _wrapHtmlFeedbackMessage( "<span class=\"twikiAlert\">$text</span>",
        $note );
}

# =========================
sub _wrapHtmlFeedbackInline {
    my ($text) = @_;
    return $text;
}

# =========================
sub _wrapHtmlFeedbackErrorInline {
    my ($text) = @_;
    return _wrapHtmlFeedbackInline("<span class=\"twikiAlert\">$text</span>");
}




sub _writeVoteInfo {
    my ( $webTopic, @info ) = @_;
    $webTopic =~ s/[\/\\]/\./g;
    my $file = "$workAreaDir/_votes_$webTopic.txt";
    if ( scalar @info ) {
        my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    }
    elsif ( -e $file ) {
        unlink($file);
    }
}
sub _writeTrust {
    my ( $username, @info ) = @_;
    my $file = "$workAreaDir/_trust_$username.txt";
    if ( scalar @info ) {
        my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    }
    elsif ( -e $file ) {
        unlink($file);
    }
}
# =========================
#sub _htmlPostChangeRequestFormField {
#    return '<input type="hidden" name="postChangeRequest" value="on" />';
#}

