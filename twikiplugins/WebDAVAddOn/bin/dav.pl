#!/usr/bin/perl -w
# Interaction script for twiki_dav, the mod_dav module.
BEGIN {
  $0 =~ m/^(.*)\/[^\/]*$/o;
  if ($1) {
    chdir $1;
  }
  unshift @INC, '.';
  require 'setlib.cfg';
}

use TWiki;
use TWiki::Store;
use TWiki::UI::Upload;
use File::Copy;

# default junk web and topic
my $defJWeb = "Trash";
my $defJTopic = "TrashAttachment";

my $rf = $ARGV[0];
die "ERROR: No response file" unless $rf;

sub fail {
  my $mess = shift;
  $mess = "ERROR: $mess\n";

  open(RF, ">$rf");
  $| = 1;
  print RF $mess;
  close(RF);

  #print EF $mess;

  die $mess;
}

my $user = $ARGV[1];
fail("No user") unless $user;
my $function = $ARGV[2];
fail("No function") unless $function;

my ( $web, $topic, $att ) = _parseResource( $ARGV[3] || "" );
fail("No topic in resource") unless ($topic);

# Delete environment variables that would cause RCS to
# take the lock as the named user rather than as the Apache user.
delete( $ENV{'USER'} );
delete( $ENV{'LOGNAME'} );

my $dummy;

( $topic, $web, $dummy, $user ) = TWiki::initialize( "/$web/$topic", $user );

if ( $function eq "delete" ) {
  # This has to be done by a move.
  my $jWeb = $defJWeb;
  my $jTopic = $defJTopic;

  if (!$att) {
	fail("Cannot delete TWiki topic");
	# If we were going to, here's how:
	# Make up a suitable non-existant target
	my $n = 1;
	$jTopic = $topic;
	while (-e "$TWiki::pubDir/$defJWeb/$jTopic") {
	  $jTopic = "$topic$n";
	  $n++;
	}
  }

  _move( $web, $topic, $att, $jWeb, $jTopic, $user );

} elsif ( $function eq "move" ) {

  my ( $web2, $topic2, $att2 ) = _parseResource( $ARGV[4] );
  fail("No topic in $ARGV[4]") unless ($topic);

  _move( $web, $topic, undef, $web2, $topic2, $user );

} elsif ( $function eq "attach" ) {

  _standardChecks( "change", $web, $topic, $user );

  fail("No attachment") unless ($att);
  $att =~ s/^\///o;
  $att =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;

  my $path = $ARGV[4];
  fail("No path") unless ($path);
  $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
  fail( "$path does not exist") unless (-e $path);

  # copy to temp file to avoid conflict over the actual file
  # this could be done to avoid the copy, but hey, who cares?
  my $safe = "/tmp/$web$topic$att";
  File::Copy::copy($path, $safe);

  my $err = _lockTopic( $web, $topic, $user );
  fail( $err) if ( $err );

  # Get the old attachment comment, if there is one
  # CODE_SMELL: this is jumping through hoops! updateAttachment
  # already reads the old text in order to extract the meta-data,
  # but it throws away the comment and replaces it with what we
  # pass in here. If we pass nothing, then it leaves a null comment.
  # It would be _much_ better to rearchitect the way updateAttachment
  # works, but that's not an option for a plugin.
  my $comment = "";
  if ($path =~ m/^.*[\/\\](.*?)[\/\\](.*?)[\/\\](.*?)$/o) {
	my ( $oweb, $otopic, $ofile ) = ( $1, $2, $3 );
	my ( $meta, $text ) = TWiki::Store::readTopic( $oweb, $otopic );
	my %attachment = $meta->findOne( "FILEATTACHMENT", $ofile );
	$comment = $attachment{"comment"} || "";
  }

  my @error =
	TWiki::UI::Upload::updateAttachment( $web,
										 $topic,
										 $user,     # remote user
										 0,         # createLink
										 0,         # propsOnly
										 $att,      # filepath
										 $safe,     # localfile
										 $att,      # attName
										 0,         # hideFile
										 $comment );

  TWiki::Store::lockTopicNew( $web, $topic, 1 );

  if ( ( @error ) && scalar( @error ) && defined( $error[0] )) {
	fail("Update failed $error[0] $error[1]");
  }

  unlink($safe);

  if ( ( @error ) && scalar( @error ) && defined( $error[0] )) {
	fail("Update failed $error[0]");
  }

} elsif ($function eq "unmeta") {

  # Get a topic, stripping meta-data, and write it to the path given
  # in $ARGV[4]
  my $path = $ARGV[4];
  fail("No path") unless ($path);

  # Put a topic, re-adding meta-data. The new text is passed in
  _standardChecks( "view", $web, $topic, $user );

  my ( $meta, $text ) = TWiki::Store::readTopic( $web, $topic );

  $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
  open(TXT, ">$path") or fail("Could not open $path");
  print TXT $text;
  close(TXT);

} elsif ($function eq "remeta") {

  # Put a topic, re-adding previous meta-data. The new text is passed in
  # the given pathname.
  my $path = $ARGV[4];
  fail( "No path" ) unless ($path);

  _standardChecks( "change", $web, $topic, $user );

  $error = _lockTopic( $web, $topic, $user );
  fail( $error ) if ( $error );

  my ( $meta, $text ) = TWiki::Store::readTopic( $web, $topic );

  $text = "";
  $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
  open(TXT, "<$path") or fail("Could not open $path");
  while (<TXT>) {
	$text .= $_;
  }
  close(TXT);

  $error = TWiki::Store::saveTopic( $web, $topic, $text, $meta, "", 0, 0 );

  TWiki::Store::lockTopicNew( $web, $topic, 1 );

  fail( $error ) if ( $error );

} else {
  fail("Bad function $function in ".join(" ", @ARGV));
}

sub _decode {
  return chr(hex(shift));
}

sub _lockTopic {
  my( $web, $topic ) = @_;

  my ( $lockUser, $lockTime ) =
	TWiki::Store::topicIsLockedBy( $web, $topic );
  if( $lockUser ) {
	return TWiki::userToWikiName( $lockUser ) .
	  " has $web/$topic locked";
  }

  TWiki::Store::lockTopicNew( $web, $topic, 0 );

  return undef;
}

sub _standardChecks {
  my ( $access, $web, $topic, $user ) = @_;
  my $wikiUserName = TWiki::userToWikiName( $user );
  fail("Web $web does not exist")  unless TWiki::UI::webExists( $web, $topic );
  fail("Mirror") if TWiki::UI::isMirror( $web, $topic );
  fail("Access to $access $web/$topic denied") unless
	TWiki::UI::isAccessPermitted( $web, $topic,
								  $access, $wikiUserName );
}

sub _parseResource {
  my $path = shift;
  my ( $web, $topic, $att );

  $path =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;

  if ( $path =~ m/^\/?(\w+)\/(\w+)\/([^\/]+)$/o ) {

	( $web, $topic, $att ) = ( $1, $2, $3 );
	$att =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;

  } elsif ( $path =~ m/^\/?(\w+)\/([^\/]+)\.txt$/o ) {

	( $web, $topic ) = ( $1, $2 );

  } else {

	fail("Bad resource $path");

  }
  fail("No web in $path") unless ($web);

  return ( $web, $topic, $att );
}

sub _move {
  my ( $srcWeb, $srcTopic, $srcAtt, $dstWeb, $dstTopic, $user ) = @_;

  _standardChecks( "change", $srcWeb, $srcTopic, $user );
  _standardChecks( "change", $dstWeb, $dstTopic, $user );

  my $error = _lockTopic( $dstWeb, $dstTopic, $user );
  if ( !( $error )) {
	$error = _lockTopic( $srcWeb, $srcTopic, $user );
	if ( !( $error )) {
	  if ($srcAtt) {
		# CODE_SMELL: If there is no filename, moveAttachment tries to move
		# the f***ing topic!
		# CODE_SMELL: if there is no file, fails silently, even when there
		# is meta-data in the topic.
		$error = TWiki::Store::moveAttachment( $srcWeb, $srcTopic,
											   $dstWeb, $dstTopic,
											   $srcAtt );
	  } else {
		# NOTE: DOES NOT CHANGE REFS TO THE TOPIC
		$error = TWiki::Store::renameTopic( $srcWeb, $srcTopic,
											$dstWeb, $dstTopic,
											0 );
	  }
	  TWiki::Store::lockTopicNew( $srcWeb, $srcTopic, 1 );
	}
	TWiki::Store::lockTopicNew( $dstWeb, $dstTopic, 1 );
  }

  fail( $error ) if ( $error );
}

1;
