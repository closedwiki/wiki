#CommentPlugin written by David Weller (dgweller@yahoo.com)
#Rev 1.0 -- Initial release
#Rev 1.1 -- Incorporate changes suggested by Andrea Sterbini and John Rouillard
#Rev 1.2 -- Additional user feedback incorporated
#Rev 1.3 -- Added checks for $debug flag - JonLambert
#Rev 1.3 -- Added checks for locked pages - JonLambert
#Rev 1.4 -- refactored form, disabled comment in preview mode, passing comments to oops template -- Peter Masiar
#Rev 2.0 -- 80% rewrite: use templates for input/output, move COMMENT-specific code from savecomment script to plugin

package TWiki::Plugins::CommentPlugin;

use strict;
# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $debug
	    $exampleCfgVar
	   );

$VERSION = '1.1';

# =========================
sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;
  
  # Plugin correctly initialized
  &TWiki::Func::writeDebug( "- TWiki::Plugins::CommentPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================
sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  
  &TWiki::Func::writeDebug( "- CommentPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
  
}

# =========================
sub handleComment {
  
  my ( $attributes ) = @_;
  
  &TWiki::Func::writeDebug( "- CommentPlugin:: Parsing begins...." ) if $debug;
  &TWiki::Func::writeDebug( "- CommentPlugin:: attributes is $attributes" ) if $debug;
  
  my $text ="";
  my $mode = &TWiki::extractNameValuePair( $attributes, "mode" );
  my $commentId =  &TWiki::extractNameValuePair( $attributes, "id" );
  my $refresh = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_REFRESH");
  my $templateFile = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_TEMPLATE");
  my $defaultMode = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_MODE");
  $mode = $defaultMode unless $mode;
  
  my $scriptname = $ENV{'SCRIPT_NAME'};
  my $preview = ( $scriptname =~ /^.*\/preview/ );
  
  my $displayId = '';
  $displayId = $commentId if $commentId;
  if (! $commentId || $commentId eq "" ) { $commentId = "__default__" }
  
  # PeterMasiar: refactored to create form for all modes in one place, using $disabled parameter if needed
  my $disabled = 'disabled';  # is commenting disabled?
  my $msg = '';
  # Check for locks - JonLambert
  my( $lockUser, $lockTime ) = &TWiki::Store::topicIsLockedBy( $web, $topic );
  if( $lockUser ) { # save
    # warn user that other person is editing this topic
    $lockUser = &TWiki::userToWikiName( $lockUser );
    use integer;
    $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
    $msg = "You cannot comment as the topic is locked temporarily\nby $lockUser for $lockTime minutes.";
    # comments remains disabled
  } elsif ( $preview ) {
    $msg  = "(Edit - Preview)";
    # comments remains disabled
  } else { # view
    $msg  = $refresh;
    $disabled = '';   # commenting is OK
  }
  
  my $script = 'disabled'; # bogus name if disabled - so SUBMIT will fail
  $script = 'savecomment' unless $disabled;
  my $actionUrlPath = "";
  $actionUrlPath = &TWiki::Func::getScriptUrl($web, $topic, $script);
  
  #    $msg .= $nonexistPar;
  $templateFile =~ m{(\w*)[\/.](.*)};
  my ($tfWeb, $tfTopic) = ( $1, $2);
  my $allFrm = 'NONE';
  
  my $webBgColor = '%WEBBGCOLOR%';
  #    $webBgColor = &TWiki::getRenderedVersion( $webBgColor );
  #    $webBgColor = &TWiki::expandCommonVariables( $webBgColor );
  #die "color= $webBgColor";
  
  ($tfWeb, $allFrm) = &TWiki::Store::readTopic( $tfWeb, $tfTopic);
  my @formats = split /\-\-\-\+\+ \!\!/, $allFrm; # format items are separated by header markup
  my ($frm) = grep m/$mode:INPUT/, @formats;  # pick INPUT for current format
  $frm =~ s/$mode:INPUT//; # and remove it from the format - rest is template
  #$frm = &TWiki::getRenderedVersion( $frm ); # twiki markup - useless, called after TOC
  #$frm = &TWiki::decodeSpecialChars( $frm ); # variables
  $frm =~ s/\{DISABLED\}/$disabled/g;
  $frm =~ s/\{LOCKMSG\}/$msg/g;
  $frm =~ s/\{ID\}/$displayId/g;
  $frm =~ tr/{}/<>/; # convert to HTML tags
  #$msg .= $frm;
  
  #<div  style=\"background:$webBgColor;\"></div>
  $text="\n\n<form name=\"comment\" action=\"$actionUrlPath\" method=\"post\" >\n";
  $text .= $frm;
  $text .= "<input $disabled type=\"hidden\" name=\"mode\" value=\"$mode\" />\n";
  $text .= "<input $disabled type=\"hidden\" name=\"id\" value=\"$commentId\" />\n";
  $text .= "</form>\n";
  
  &TWiki::Func::writeDebug( "- CommentPlugin:: parsing ends......" ) if $debug;
  
  return $text;
}


# =========================
sub endRenderingHandler {
  ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
  
  &TWiki::Func::writeDebug( "- CommentPlugin::endRenderingHandler( $web.$topic )" ) if $debug;
  
  # This handler is called by getRenderedVersion just after the line loop
  
  
  $_[0] =~ s/%COMMENT%/&handleComment()/geo;
  $_[0] =~ s/%COMMENT{(.*?)}%/&handleComment($1)/geo;
  
} # handleComment


sub getLocaltime {
  my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
  my $time = sprintf( "%.2u:%.2u:%.2u", $hour, $min, $sec );
  return $time;
}

# =========================
sub saveComment {
  # returns formatted text to save, UNDEF if no save needed, or '' if error
  my $query        = shift   || return 'ERROR: missing query';  # CGI query
  my $wikiUserName = shift   || return "ERROR: missing user " ;
  my $text         = shift   || return undef;
  
  #return 'param OK'; #undef;
  
  my $commentId  = $query->param( 'id' ); # ID of the comment if multiple comments on same page
  my $mode = $query->param( 'mode' );
  
  # get text and other parameters
  my $comment = $query->param( "comment" );
  
  #OMFG...what a hack!
  $comment = &TWiki::decodeSpecialChars( $comment );
  $comment =~ s/ {3}/\t/go;
  my $cUrl = $query->param( "comment_url" );
  $cUrl = &TWiki::decodeSpecialChars( $cUrl );
  my $cLink = $query->param( "comment_link" );
  $cLink = &TWiki::decodeSpecialChars( $cLink );
  $cLink =~ s/ {3}/\t/go;
  
  my $errMsg = '<font color="red">(attempt to change authorization settings detected)</font>';
  
  $comment =~ s/\s*\*\s+Set\s+(ALLOW|DENY)(TOPIC|WEB)(CHANGE|RENAME|POST)\s*=.*/$errMsg/go;
  
  my $refresh = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_REFRESH");
  my $templateFile = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_TEMPLATE");
  my $defaultMode = &TWiki::Prefs::getPreferencesValue("COMMENTPLUGIN_MODE");
  $mode = $defaultMode unless $mode;
  
  $templateFile =~ m{(\w*)[\/.](.*)};
  my ($tfWeb, $tfTopic) = ( $1, $2);
  my $allFrm = 'NONE';
  ($tfWeb, $allFrm) = &TWiki::Store::readTopic( $tfWeb, $tfTopic);
  my @formats = split /\-\-\-\+\+ \!\!/, $allFrm;
  my ($frm) = grep m/$mode:OUTPUT/, @formats;
  $frm =~ s/$mode:OUTPUT//;
  
  my $localDate = TWiki::getLocaldate();
  my $localTime = getLocaltime();
  $frm =~ s/{USERNAME}/$wikiUserName/go;
  $frm =~ s/{DATE}/$localDate/go;
  $frm =~ s/{TIME}/$localTime/go;
  $frm =~ s/{COMMENT}/$comment/;
  $frm =~ s/{URL}/$cUrl/;
  $frm =~ s/{LINK}/$cLink/;
  
  my $growHead = '';
  $growHead = $frm =~ m/{GROWHEAD}/;
  $frm =~ s/{GROWHEAD}//g;
  $frm =~ s/{GROWTAIL}//g;
  my $formattedPost = $frm; #"----\n\n$comment\n\n";
  
  
  #Thanks to Laurent AMON for finding/killing this bug...
  #$formattedPost .= TWiki::Func::expandCommonVariables("$defaultSignature\n\n", $topic, $webName);
  
  # no post if no comment - only default refresh text
  if ($comment ne "$refresh") {
    my $cid = "";
    if ($commentId ne "__default__") { #Find a comment by its given name
      $cid = "id\\s*=\\s*\\\"$commentId.*?";
    }
    if ($growHead){
      $text =~ s/(%COMMENT.*?$cid%)/$1\n$formattedPost/g;
    } else {
      $text =~ s/(%COMMENT.*?$cid%)/$formattedPost$1/g;
    }
  }
  
  return $text;
} # saveComment
1;
