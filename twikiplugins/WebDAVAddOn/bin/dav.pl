#!/usr/bin/perl -w
# Interaction script for twiki_dav, the mod_dav module.
BEGIN {
print "$0\n";
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

sub fail {
  my $mess = shift;

  print STDERR "PERL: $mess\n";
  die;
}

open(STDERR, ">>/tmp/vsnlog");
open(STDOUT, ">>/tmp/vsnlog");

my $function = $ARGV[0];
fail("ERROR: No function") unless $function;
my $theWeb = $ARGV[1];
fail("ERROR: No web") unless $theWeb;
my $theTopic = $ARGV[2];
fail("ERROR: No topic") unless $theTopic;
my $fileName = $ARGV[3];
fail("ERROR: No file") unless $fileName;
my $theUser = $ARGV[4];
fail("ERROR: No user") unless $theUser;

my ( $topic, $webName, $dummy, $userName, $dataDir) = 
  TWiki::initialize( "/$theWeb/$theTopic", $theUser );

if ($function eq "commit") {

  print STDERR "Committing $theWeb/$theTopic,$fileName for $theUser\n";

  # PUT - checking new version of file. This will also check
  # for permission to change.

  my $safe = "up$$$fileName";
  File::Copy::move($fileName, $safe);
  my @error = TWiki::UI::Upload::updateAttachment( $theWeb,
                                                   $theTopic,
                                                   $theUser,  # remote user
                                                   0,         # createLink
                                                   0,         # propsOnly
                                                   $fileName, # filepath
                                                   $safe,     # localfile
                                                   undef,     # attName
                                                   0,         # hideFile
                                                   "Updated by WebDAV" );
  unlink($safe);
  if ( ( @error ) && scalar( @error ) && defined( $error[0] )) {
    fail("Update failed $error[0]");
  }
#}
# elsif ($function eq "check") {#
#
#  # GET for edit - check for permission to change.

#  my $wikiUserName = &TWiki::userToWikiName( $theUser );
#  fail("No access") unless
#    TWiki::Access::checkAccessPermission( "change", $wikiUserName, "",
#                                          $theTopic, $theWeb );
#} elsif ($function eq "commit" ) {

#  # CODE_SMELL: Assumes implementation of a topic as an RCS'ed file, where
#  # the checked-out version can be read before checking back in.
#  ( $meta, $text ) = TWiki::Store::readTopic( $theWeb, $theTopic );
#  fail("Store") if TWiki::Store::saveTopic( $theWeb, $theTopic, $text, $meta, "", 1, 0 );
#
} else {
  fail("ERROR: Bad function $function");
}

1;
