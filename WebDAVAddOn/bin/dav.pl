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
use TWiki::UI::Upload;
use File::Copy;

my $jWeb = "Trash";
my $jTopic = "TrashAttachment";

#open(EF, ">>/tmp/vsnlog");
#print EF "<".join(" ",@ARGV).">\n";

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
my $theResource = $ARGV[3];

unless ( $theResource =~ m/(\w+)\/(\w+)\/(.*)$/o) {
  fail("Bad resource $theResource");
}
my ( $web, $topic, $att ) = ($1, $2, $3);
fail("No web in $theResource") unless ($web);
fail("No topic in $theResource") unless ($topic);
fail("No attachment in $theResource") unless ($att);

$web =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
$topic =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;
$att =~ s/%(\d[A-Fa-f\d])/&_decode($1)/geo;

# Delete environment variables that would cause RCS to
# take the lock as the named user rather than as the Apache user.
delete( $ENV{'USER'} );
delete( $ENV{'LOGNAME'} );

my $dummy;

( $topic, $web, $dummy, $user ) = TWiki::initialize( "/$web/$topic", $user );

if ( $function eq "delete" ) {
  # This has to be done by an attachment move. We assume the standard
  # target for the move.
  # Need to lock src and dest

  # CODE_SMELL: If there is no filename, moveAttachment tries to move
  # the f***ing topic!

  my $wikiUserName = TWiki::userToWikiName( $user );
  fail("Web $web does not exist")  unless TWiki::UI::webExists( $web, $topic );
  fail("Mirror") if TWiki::UI::isMirror( $web, $topic );
  fail("Access to $web/$topic denied") unless
	TWiki::UI::isAccessPermitted( $web, $topic,
								  "change", $wikiUserName );

  my $error = _lockTopic( $jWeb, $jTopic, $user );
  if ( !( $error )) {
	$error = _lockTopic( $web, $topic, $user );
	if ( !( $error )) {
	  $error = TWiki::Store::moveAttachment( $web, $topic,
											 $jWeb, $jTopic,
											 $att );
	  TWiki::Store::lockTopicNew( $web, $topic, 1 );
	}
	TWiki::Store::lockTopicNew( $jWeb, $jTopic, 1 );
  }

  fail( $error ) if ( $error );

} elsif ( $function eq "commit" ) {

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
} else {
  fail("Bad function $function");
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

1;
