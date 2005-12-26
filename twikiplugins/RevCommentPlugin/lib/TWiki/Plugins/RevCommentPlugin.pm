# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::RevCommentPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug 
    );

use vars qw(
    $commentFromUpload $attachmentComments $useRCS $rcsComment
    $cachedComment $cachedCommentWeb $cachedCommentTopic
    $minorMark $rlogCmd $rcsMsgCmd
);

if ( my $rcsDir = $TWiki::cfg{RCS}{BinDir} || $TWiki::rcsDir ) {
    $rlogCmd   = "$rcsDir/rlog %FILE%";
    $rcsMsgCmd = "$rcsDir/rcs -q -m:%MSG% %FILE%";
}

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'RevCommentPlugin';  # Name of this Plugin

$minorMark = '%MINOR%';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    return 0 unless defined( $rlogCmd );

    $commentFromUpload = undef;

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $attachmentComments = TWiki::Func::getPluginPreferencesValue( "ATTACHMENT_COMMENTS" ) || 1;

    $useRCS = TWiki::Func::getPluginPreferencesValue( "USE_RCS" ) || 0;
    $useRCS = 0;

    $cachedCommentWeb = '';
    $cachedCommentTopic = '';

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    TWiki::Func::writeDebug( "- --- attachmentComments = ".$attachmentComments ) if $debug;
    return 1;
}

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%REVCOMMENT%/&handleRevComment()/ge;
    $_[0] =~ s/%REVCOMMENT{(.*?)}%/&handleRevComment($1)/ge;
    $_[0] =~ s/%REVCOMMENT\[(.*?)\]%/&handleRevComment($1)/ge;
}

sub beforeSaveHandler
{
### my ( $text, $topic, $web, $meta ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my ( $topic, $web, $meta ) = @_[1..3];

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    my $query = TWiki::Func::getCgiQuery();

    # Get current revision
    my ($date, $user, $currev) = TWiki::Func::getRevisionInfo( $_[2], $_[1] );
    $currev ||= 0;

    my @comments = _extractComments($meta);

    # Set correct rev of comment
    foreach my $comment ( @comments ) {
	$comment->{rev} = $currev unless $comment->{rev} =~ /\d+/;
    }

    # Delete old comments
    @comments = grep {$_->{rev} >= $currev} @comments;

    # Check for new comments
    my $newComment;
    if ($commentFromUpload) {			# File upload
	$newComment = {
	    comment => $commentFromUpload,
	    t       => 'Upload'.time(),
	    minor   => 0,
	    rev     => undef,
	};
    } elsif ($attachmentComments &&
	     $query->url(-relative) =~ /upload/) { # Attachment changed
	$newComment = {
	    comment => 'Changed properties for attachment !'.
		       $query->param('filename'),
	    t       => 'PropChanged'.time(),
	    minor   => 0,
	    rev     => undef,
	};
    } elsif ($query->param('comment') || $query->param('dontnotify') ) {
	my $commentFromForm = $query->param('comment') || ' ';
	my $t = $query->param('t') || 0;
	my $thisComment = $newComment = {};
	    
	foreach my $oldComment (@comments) {
	    if ($t == $oldComment->{t}) {
		$thisComment = $oldComment;
		last;
	    }
	}
	$thisComment->{comment} = $commentFromForm;
	$thisComment->{minor} = defined $query->param('dontnotify');
	$thisComment->{t} = $t;
	$thisComment->{rev} = undef;
    }

    if ( ($newComment->{comment} || '') =~ /\S/ ||
	 ($newComment->{minor} && !@comments) ) {
	push @comments, $newComment;
    }
    $meta->remove('REVCOMMENT');
    _putComments($meta,@comments);

    # Save comment for later use with rcs
    return unless $useRCS;

    map {$_->{comment} = $minorMark.$_->{comment} if $_->{minor} } @comments;
    $rcsComment = join("\n", map($_->{comment}, @comments) );
    ( $rcsComment ) =~ /^(.*)$/s;
}

# =========================
sub afterSaveHandler
{
### my ( $text, $topic, $web, $error, $meta ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    return unless $rcsComment; 

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

    # SMELL: for Dakar, should use something related to the Store class
#    $_[2] =~ s|\.|/|g;		# as this is going to be used in the filesystem, changed subweb .'s into /'s
    my $file = TWiki::Func::getDataDir() . '/' . $_[2] . '/' . $_[1] . '.txt';
    die "File does not exist ? " unless -r $file;
    my $cmd = $rcsMsgCmd;
    $cmd =~ s/%FILE%/$file/g;
    my @cmd = split(' ',$cmd);
    map {s/%MSG%/$rcsComment/g} @cmd;
    system(@cmd);
}

sub beforeAttachmentSaveHandler
{
    TWiki::Func::writeDebug( "- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;

    return unless $attachmentComments;
    TWiki::Func::writeDebug( "--- still here" ) if $debug;

    my $query = TWiki::Func::getCgiQuery;
    if (defined($query->param('filename')) && 
	$query->param('filename') eq $_[0]->{attachment}) {

	$commentFromUpload = 'Updated attachment !' . $_[0]->{attachment};
    } else {
	$commentFromUpload = 'Attached file !' . $_[0]->{attachment};                        
    }
}


# =========================

sub _extractComments {

    my $meta = shift;
    my @comments = ();

    if ( my $code = $meta->get( 'REVCOMMENT' ) ) {
	for ( my $i=1; $i <= $code->{ncomments}; ++$i ) {
	    push @comments, {
		    minor => $code->{'minor_'.$i},
		    comment => $code->{'comment_'.$i},
		    t => $code->{'t_'.$i},
		    rev => $code->{'rev_'.$i},
	    };
	}
    }

    return @comments;
}

sub _putComments {

    my $meta = shift;
    my @comments = @_;
    my %args = (
	ncomments => scalar @comments,
    );

    for ( my $i=1; $i <= scalar @comments; ++$i ) {
	$args{'comment_'.$i} = $comments[$i-1]->{comment};
	$args{'t_'.$i} = $comments[$i-1]->{t};
	$args{'minor_'.$i} = $comments[$i-1]->{minor};
	$args{'rev_'.$i} = $comments[$i-1]->{rev};
    }

    $meta->put('REVCOMMENT', \%args);
}

sub handleRevComment {

    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::handleRevComments: Args=>$_[0]<\n") if $debug;
    my $params = $_[0] || '';
    # SMELL: this "convenience" should probably be removed; you can \" in Attributes
    $params =~ s/''/"/g;

    my %params = TWiki::Func::extractParameters($params);

    my $web = $params{web} || $web;
    my $topic = $params{topic} || $topic;
    my $rev = $params{rev} ||
              $params{_DEFAULT} ||
              ( TWiki::Func::getRevisionInfo( $web, $topic ) )[2];
    $rev =~ s/^1\.//;
    my $delimiter = $params{delimiter};
    $delimiter = '</li><li style="margin-left:-1em;">' unless defined($delimiter);
    $delimiter =~ s/\\n/\n/g;
    $delimiter =~ s/\\t/\t/g;
    my $pre = $params{pre};
    $pre = '<ul><li style="margin-left:-1em;">' unless defined($pre);
    my $post = $params{post};
    $post = '</li></ul>' unless defined($post);
    my $minor = $params{minor};
    $minor = '<i>(minor)</i> ' unless defined($minor);

    unless ( TWiki::Func::topicExists( $web, $topic) ) {
        return "Topic $web.$topic does not exist";
    }
    my @comments;

    if ($useRCS) {

	if ($web ne $cachedCommentWeb ||
	    $topic ne $cachedCommentTopic) {

	    cacheComments($web, $topic);
	}
	@comments = split(/\n/, $cachedComment->[$rev] || '');
    } else {

	# SMELL: doesn't respect access permissions (too bad there isn't a version that does, like readTopic() does...)
	my ( $meta, undef ) = TWiki::Func::readTopic($web, $topic, $rev);

	@comments = _extractComments($meta);
	foreach my $comment ( @comments ) {
	    $comment->{rev} = $rev unless $comment->{rev} =~ /\d+/;
	}
	@comments = grep {$_->{rev} == $rev} @comments;
	map {$_->{comment} = $minorMark.$_->{comment} if $_->{minor} } @comments;
	@comments = map {$_->{comment}} @comments;
    }

    my $text =  scalar @comments > 0 ?
		$pre . join($delimiter, @comments) . $post :
		'';
    $text =~ s/$minorMark/$minor/g;
    return $text;
}

sub cacheComments {

    my ($web, $topic) = @_;

    # SMELL: see Store
#    $web =~ s|\.|/|g;		# as this is going to be used in the filesystem, changed subweb .'s into /'s
    my $file = TWiki::Func::getDataDir() . '/' . $web . '/' . $topic . '.txt';
    die "File $file does not exist ?" unless -r $file;

    my $pid = open(KID_TO_READ, "-|");

     if ($pid) {   # parent
	$cachedComment = [];
	while (<KID_TO_READ>) {
	    next if 1../^-+\s*$/;
	    /revision\s+1.(\d+)/;
	    my $rev = $1;
	    $_=<KID_TO_READ>;
	    while (<KID_TO_READ>) {
		last if /^-+\s*$/ || /^=+\s*$/;
		$cachedComment->[$rev] .= $_;
	    }
	    chomp($cachedComment->[$rev]);
	    last if /^=+\s*$/;
	}
	close(KID_TO_READ) || warn "kid exited $?";

     } else {      # child
	($EUID, $EGID) = ($UID, $GID); # suid only
	my $cmd = $rlogCmd;
	$cmd =~ s/%FILE%/$file/g;
	exec(split(' ',$cmd))
	     || die "can't exec $rlogCmd: $!";
	# NOTREACHED
     }

     $chchedCommentWeb = $web;
     $cachedCommentTopic = $topic;
}


1;
