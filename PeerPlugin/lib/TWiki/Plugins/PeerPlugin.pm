# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2001 DrKW
# Copyright (C) 2007-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

# =========================

package TWiki::Plugins::PeerPlugin;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2011-07-21';

my $web;
my $topic;
my $user;
my $installWeb;
my $myConfigVar;
my %wikiToUserList;
my $mainWebname;
my $linkIcon;
my $ratingSuffix;
my $listIconPrefix;
my $listIconHeight;
my $listIconWidth;
my $ratingIconPrefix;
my $ratingIconHeight;
my $ratingIconWidth;

# =========================
use TWiki::Plugins::PeerPlugin::Review;

# =========================

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    
    # Get preferences
    $linkIcon         = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_LINKICON" )         || "";
    $ratingSuffix     = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_RATINGSUFFIX" )     || "";
    $listIconPrefix   = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_LISTICONPREFIX" )   || "";
    $listIconHeight   = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_LISTICONHEIGHT" )   || "13";
    $listIconWidth    = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_LISTICONWIDTH" )    || "75";
    $ratingIconPrefix = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_RATINGICONPREFIX" ) || "";
    $ratingIconHeight = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_RATINGICONHEIGHT" ) || "13";
    $ratingIconWidth  = &TWiki::Func::getPreferencesValue( "PEERPLUGIN_RATINGICONWIDTH" )  || "75";    
    
    return 1;
}
    
# peer review subroutines

# ==========================
sub prTestVal #check input values in range 1-5
{
    my $prVal = shift;
    if( $prVal >= 1 && $prVal <= 5 )
    {
        return 0;
    } else {
        return 1;
    }
}

# ==========================
sub prTestTopic #check if topic is an internal wiki page
{
    my $prTopic = shift;
    my $urlHost = TWiki::Func::getUrlHost();
    if( $prTopic =~ /$urlHost/ )
    {
        return 1;
    } else {
        return 0;
    }
}

# ==========================
sub prDispPrTopicRev #format db revision (INT) to wiki rev 1.INT if internal wiki topic
{
    my $prTopic = shift;
    my $prRev = shift;
    my $format = shift;

    my ( $webName, $topicName ) = "";

    if( &prTestTopic( $prTopic ) )
    {
        if( ( $prTopic =~ /.*\/(.*)\/(.*)/ ) ) 
        {
            $webName = $1;
            $topicName = $2;
        }
        if( $format eq 'topicview' ) {
            return "$webName.$topicName revision 1.$prRev";
        } elsif( $format eq 'userview' ) {
            return "[[$webName.$topicName][$webName.$topicName]] revision 1.$prRev";
        }
    } else {
        return "$prTopic";
    }
}

# ==========================
sub prDispPrDateTime #format db datetime for wiki
{
    my $epSecs = shift;
    return( TWiki::Func::formatTime( $epSecs ) );
}

# ===========================
sub prTitleColor #set color of title bar
{
    my $prRev = shift;
    if( &prTestRev( $prRev ) eq "latest" )
    {
        return( "%WEBBGCOLOR%" );
    } else {
        return( "#cccccc" );
    }
}

# ===========================
sub prTextColor #set class of body text
{
    my $prRev = shift;
    if( &prTestRev( $prRev ) eq "latest" )
    {
        return( "#000000" );
    } else {
        return( "#999999" );
    }
}

# ===========================
sub prTestRev #test if review rev matches latest topic rev
{
    my $prRev = shift;
    #&TWiki::Func::writeDebug( "PeerPlugin: page rev is $TWiki::revision" );
    if( $prRev == TWiki::Func::getCgiQuery()->param( 'prrevinfo' ) )
    {
        return( "latest" );
    } else {
        return( "oldngrey" );
    }
}

# ============================
sub prLink
{
    my ( $revdate, $revuser, $maxrev ) = &TWiki::Func::getRevisionInfo( $web, $topic );
    my $link = "";
    
    my $linkImg = "";
    if( $linkIcon ) {
    	$linkImg = qq{<img align='absMiddle' border='0' height='16' src='$linkIcon' width='16' alt="review this topic" />};
    }

    if( &prTestUserTopic() )
    {
        $link = qq{<span class=greyButton>Review $linkImg </span>};
    } else {    
        $link = qq{<a class=menuButton href="%SCRIPTURLPATH{view}%/%SYSTEMWEB%/PeerPluginView?prurl=%SCRIPTURL{view}%/%WEB%/%TOPIC%&prweb=%WEB%&prtopic=%TOPIC%&prrevinfo=$maxrev">Review $linkImg </a>};
    }
    return( $link );
}

# ============================
sub prObject
{
    my $prTopic = TWiki::Func::getCgiQuery()->param( 'prtopic' );
    my $prUrl = TWiki::Func::getCgiQuery()->param( 'prurl' );
        
    my $opText = "";
    
    if( ! $prTopic ) {
        $opText = $prUrl;
    } else {
        my $prWeb = TWiki::Func::getCgiQuery()->param( 'prweb' );
        my $prRevInfo = TWiki::Func::getCgiQuery()->param( 'prrevinfo' );
        $opText = "[[$prUrl][$prTopic]]";
    }
    return( $opText );
}

# ============================
sub prFormUrl
{ 
    return "%SCRIPTURL{view}%/%SYSTEMWEB%/PeerPluginView";
}

# =========================
sub prDoForm
{
    my $dbh = shift;
    
    my $prUrl = TWiki::Func::getCgiQuery()->param( 'prurl' );
    my $prWeb = TWiki::Func::getCgiQuery()->param( 'prweb' );
    my $prTopic = TWiki::Func::getCgiQuery()->param( 'prtopic' );    
    
    # add new review (if form filled)
    if( TWiki::Func::getCgiQuery()->param( 'praction' ) eq "add" ) {
        #grab params from form
        my $fmQuality = TWiki::Func::getCgiQuery()->param( 'quality' );
        my $fmRelevance = TWiki::Func::getCgiQuery()->param( 'relevance' ) || 0;
        my $fmCompleteness = TWiki::Func::getCgiQuery()->param( 'completeness' ) || 0;
        my $fmTimeliness = TWiki::Func::getCgiQuery()->param( 'timeliness' ) || 0;
        my $fmComment = TWiki::Func::getCgiQuery()->param( 'comment' );
          
        # check access permission - FIXME if we want to manage access permission on the PeerReviewView page - need one for each web
        my $changeAccessOK = &TWiki::Func::checkAccessPermission( "CHANGE", $user, $_[0] , $topic, $web );
        if( ! $changeAccessOK )
        {
            $opText .= "<p><font color='red'>You do not have permission to add reviews.</font></p>";
        # check param values
        } elsif( &prTestVal( $fmQuality ) ) {
            $opText .= "<p><font color='red'>Please select a quality rating in the range 1-5.</font></p>";
        } elsif( &prTestVal( $fmRelevance ) ) {
            $opText .= "<p><font color='red'>Please select a relevance rating in the range 1-5.</font></p>";
        #FIXME - control these fields/values through config vars???
        #} elsif( &prTestVal( $fmCompleteness ) ) {
        #    $opText .= "<p><cont color='red'>Please select a completeness rating in the range 1-5.</font></p>";
        #} elsif( &prTestVal( $fmQuality ) ) {
        #    $opText .= "<p><font color='red'>Please select a timeliness rating in the range 1-5.</font></p>";            
        } elsif( ! $fmComment ) {
            $opText .= "<p><font color='red'>Please enter some text in the comment field.</font></p>";
        } else {
            my @rvItems = ();
            
            push( @rvItems, $user );
            push( @rvItems, $prUrl );
            push( @rvItems, TWiki::Func::getCgiQuery()->param( 'prrevinfo' ) || 0 );
            push( @rvItems, 1 );    #FIXME - Hardwire notify for now
            push( @rvItems, $fmQuality );
            push( @rvItems, $fmRelevance );
            push( @rvItems, $fmCompleteness );
            push( @rvItems, $fmTimeliness );
            push( @rvItems, $fmComment );
            
            my $error = &Review::rvAdd( $dbh, @rvItems );
            
            if( ! $error )
            {
                $opText .= "<p><font color='red'>Thank you for adding a review. To edit your comments just submit a new review - only the most recent will be displayed.</font></p>";
            } else {
                $opText .= "<p><font color='red'>$error</font></p>";
            }
            #&TWiki::Func::writeDebug( "PeerPlugin: Add rvItems is @rvItems" );
        }
    }    
    return $opText;
}


# =========================
sub prList
{
    my $dbh = shift;
    my $attributes = shift;
    my $prUrl  = "";
    
    # get list format from TWiki var attributes
    my $format = TWiki::Func::extractNameValuePair( $attributes, "format" );    
    if( $format eq "topicview" || $format eq "userview" )
    {
        $prUrl = TWiki::Func::getCgiQuery()->param( 'prurl' );
    } else {
        $prUrl = TWiki::Func::extractNameValuePair( $attributes, "topic" );
    }
    
    if(! $prUrl )
    {
        return "No review list available.";
    }
    
    my $prWeb = TWiki::Func::getCgiQuery()->param( 'prweb' );
    my $prTopic = TWiki::Func::getCgiQuery()->param( 'prtopic' );
   
    # load table template
    my $tbTemp = &TWiki::Func::readTemplate( "peerview" );
    my $tbText = "";
    my $opText = "";
    
    # get a list of refs to reviews
    my @rvList = ();
    if( $format eq "topicview" ) {
        @rvList = &Review::rvList( $dbh, $format, "Topic" => $prUrl );
    } elsif( $format eq "userview" ) {
       @rvList = &Review::rvList( $dbh, $format, "Reviewer" => TWiki::Func::wikiToUserName( $prTopic ) );
    }
    
    #&TWiki::Func::writeDebug( "PeerPlugin: rvList is @rvList" );  
    
    #FIXME - add error handling
    foreach my $rv ( @rvList )
    {
        $tbText = $tbTemp;
    
        $tbText =~ s/%PRREVIEWER%/&TWiki::Func::userToWikiName( $rv->reviewer() )/geo;
        $tbText =~ s/%PRTOPICREV%/&prDispPrTopicRev( $rv->topic(), $rv->topicRev(), $format )/geo;
        $tbText =~ s/%PRDATETIME%/&prDispPrDateTime( $rv->epSecs( $dbh ) )/geo;
        $tbText =~ s/%PRTITLECOLOR%/&prTitleColor( $rv ->topicRev )/geo;
        $tbText =~ s/%PRTEXTCOLOR%/&prTextColor( $rv->topicRev )/geo;
        $tbText =~ s/%PRQUALITY%/{$rv->quality()}/geo;
        $tbText =~ s/%PRRELEVANCE%/{$rv->relevance()}/geo;
        $tbText =~ s/%PRCOMMENT%/{$rv->comment()}/geo;
        $tpText =~ s/%LISTICONPREFIX%/$listIconPrefix/geo;
        $tpText =~ s/%LISTICONHEIGHT%/$listIconHeight/geo;
        $tpText =~ s/%LISTICONWIDTH%/$listIconWidth/geo;       
        
        $opText .= $tbText;
    }
    
    if( ! $opText )
    {
        $opText = "No reviews have been written for this topic yet...";
    }    
    return $opText;
}

# ============================
sub prRating
{
    my $dbh = shift;
    my $format = "";    
    my $prUrl  = "";
    my $prWeb = "";
    my $prTopic = "";
    my $prUser = "";
    my $rating = 0;
    
    # handle url according to normal view or review
    if( TWiki::Func::getCgiQuery()->param( 'prurl' ) ) {
        $prUrl = TWiki::Func::getCgiQuery()->param( 'prurl' );
    } else {
        $prUrl = TWiki::Func::getCgiQuery()->url().TWiki::Func::getCgiQuery()->path_info();
    } 
    
    # test if url internal to wiki - then extract object web & topic
    if( &prTestTopic( $prUrl ) && $prUrl =~ /.*\/(.*)\/(.*)/ )
    {
        $prWeb = $1;
        $prTopic = $2;
    }  
   
    # find out if this is a personal topic
    my $login = TWiki::Func::wikiToUserName( $prTopic );
    if( $prWeb eq $TWiki::cfg{UsersWebName} && $login ) {
        $format = "usertherm";
        $prUser = $login;
    } else {
        $format = "topictherm";
    }    

    if( $format eq "topictherm" ) {
        $rating = &Review::rvRating( $dbh, $format, "Topic" => $prUrl ) || 0;
    } elsif( $format eq "usertherm" ) {
        $rating = &Review::rvRating( $dbh, $format, "Reviewer" => $prUser ) || 0;
    }    
    
    my $opText = "";
    if( &prTestUserTopic() )
    {
        $zero = "0";
        $opText = qq{&nbsp;<img src="$ratingIconPrefix$zero.gif" width="$ratingIconWidth" height="$ratingIconHeight" border="0" alt="personal topic - review disabled">&nbsp;$ratingSuffix};
    } else {    
        $opText = qq{&nbsp;<img src="$ratingIconPrefix$rating.gif" width="$ratingIconWidth" height="$ratingIconHeight" border="0" alt="quality=$rating">&nbsp;$ratingSuffix};
    }

    return( $opText );
}

# =========================
sub prTestUserTopic
# find out if this is a personal topic or the Wiki.PeerPluginUser topic
{
    if( $web eq $TWiki::cfg{UsersWebName} && TWiki::Func::wikiToUserName( $topic ) ) { return 1; } 
    elsif( $topic eq "PeerPluginUser" ) { return 1; } 
    elsif( $topic eq "PeerPluginForm" ) { return 1; } 
    elsif( $topic eq "PeerPluginView" ) { return 1; } 
    elsif( $topic eq "PeerPluginExtForm" ) { return 1; } 
    elsif( $topic eq "PeerPluginExtView" ) { return 1; } 
    else { return; }
}

# ============================
sub prDispStatsItem
{
    # test if url internal to wiki - then extract object web & topic
    my $item = shift;
    my $opText = "";
    
    if( &prTestTopic( $item ) && $item =~ /.*\/(.*)\/(.*)/ )
    {
        $prWeb = $1;
        $prTopic = $2;
        $opText .= "[[$prWeb.$prTopic][$prWeb.$prTopic]] <br /> ";
    } else {    
        $opText .= "[[%SCRIPTURL{view}%/%SYSTEMWEB%/PeerPluginExtView?prurl=$item][Wiki:$item]] <br /> ";
    }
    
    return $opText;
}


# ============================
sub prStats
{
    my $dbh = shift;
    my $attributes = shift;
    my $item = "";
    my $opText = "";
    my $prWeb = "";
    my $prTopic = "";
    
    my $atUrl = TWiki::Func::extractNameValuePair( $attributes, "web" );
    my $limit = TWiki::Func::extractNameValuePair( $attributes, "limit" ) || 10;
    
    if( $atUrl ne "all") {
        $opText .= "Sorry - only stats for \"all\" webs supported.";
        #FIXME - convert web list to params pair list for rvStats - I guess this would be an url mask that drives a db "like"
        return;
    }

    #FIXME - may be better formed by using references - ie making the stats list be an object
    
    $opText .= "| *Topic <br /> Reviews:* | *Best <br /> Rated <br /> Topics:* | *Most <br /> Reviewed <br /> Topics:* | *Most <br /> Active <br /> Reviewers:* |\n";
    
    my( $rvCount ) = &Review::rvStats( $dbh, 'count' );        
    $opText .= "|  $rvCount |  ";
    
    my( @rvBestTen ) = &Review::rvStats( $dbh, 'bestten', $limit );    
    while( @rvBestTen ) {
        $item = shift( @rvBestTen );
        $opText .= "$item ";
        $item = shift( @rvBestTen );
        $opText .= &prDispStatsItem( $item );
    }
    $opText .= "|  ";
    
    my( @rvMostTen ) = &Review::rvStats( $dbh, 'mostten', $limit );    
    while( @rvMostTen ) {
        $item = shift( @rvMostTen );
        $opText .= "$item ";
        $item = shift( @rvMostTen );
        $opText .= &prDispStatsItem( $item );
    }
    $opText .= "|  ";
    
    my( @rvUserTen ) = &Review::rvStats( $dbh, 'userten', $limit );    
    while( @rvUserTen ) {
        $item = shift( @rvUserTen );
        $opText .= "$item ";
        $item = shift( @rvUserTen );
        $item = TWiki::Func::userToWikiName( $item );
        $opText .= "$item <br /> ";
    }
    
    $opText .= "|";
    return( $opText ); 
}

# ========================
sub prExtUrl
{
    return TWiki::Func::getCgiQuery()->param( 'prexturl' ) || "http://www.google.com/";
}

# ========================
sub prInclude
{
    my $attributes = shift;
    my $item = TWiki::Func::extractNameValuePair( $attributes, "prurl" );
    
    &TWiki::Func::writeDebug( "PeerPlugin: prInclude" );
    
    if( &prTestTopic( $item ) && $item =~ /.*\/(.*)\/(.*)/ )
    {
        $prWeb = $1;
        $prTopic = $2;
        my $opText = TWiki::Func::expandCommonVariables( "\%INCLUDE{$prWeb.$prTopic}\%", $topic, $web );
        return $opText;
    } else {    
        return "<iframe name='content' width='800' height='800' src='$item'></iframe>";
    }    
}

# =========================
sub prUserView
{
    my $text = qq{<a href="%SCRIPTURLPATH{view}%/%SYSTEMWEB%/PeerPluginUser?};
    $text   .= qq{prurl=%SCRIPTURL{view}%/%WEB%/%TOPIC%&prweb=%WEB%&prtopic=%TOPIC%&prrevinfo=$maxrev">};
    $text   .= qq{ViewMyReviews</a>};
    return $text;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

#    print "PeerreviewPlugin::commonTagsHandler called<br>";

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    
    #&TWiki::Func::writeDebug( "PeerPlugin: opening DB connection" );
    # open db
    my $dbh = &Review::rvOpen();
	
    $_[0] =~ s/%PRDOFORM%/&prDoForm( $dbh )/geo;   #Must run before PRLIST
    $_[0] =~ s/<!--%PRLINK%-->/&prLink()/geo;
    $_[0] =~ s/%PRLIST{([^}]*)}%/&prList( $dbh, $1 )/geo;
    $_[0] =~ s/%PROBJECT%/&prObject()/geo;
    $_[0] =~ s/%PRFORMURL%/&prFormUrl()/geo;
    $_[0] =~ s/%PRURL%/TWiki::Func::getCgiQuery()->param( 'prurl' )/geo;
    $_[0] =~ s/%PRWEB%/TWiki::Func::getCgiQuery()->param( 'prweb' )/geo;
    $_[0] =~ s/%PRTOPIC%/TWiki::Func::getCgiQuery()->param( 'prtopic' )/geo;
    $_[0] =~ s/%PRREVINFO%/TWiki::Func::getCgiQuery()->param( 'prrevinfo' )/geo;
    $_[0] =~ s/<!--%PRRATING%-->/&prRating( $dbh )/geo;
    $_[0] =~ s/%PRSTATS{([^}]*)}%/&prStats( $dbh, $1 )/geo;
    $_[0] =~ s/%PREXTURL%/&prExtUrl()/geo;
    $_[0] =~ s/%PRINCLUDE{([^}]*)}%/&prInclude( $1 )/geo;
    $_[0] =~ s/%PRUSERVIEW%/&prUserView/geo;
    
    # close db
    &Review::rvClose( $dbh );
}

# =========================

1;
