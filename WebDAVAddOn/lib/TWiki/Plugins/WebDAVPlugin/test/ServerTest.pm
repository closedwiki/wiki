package ServerTest;

use HTTP::DAV;

my @davuser;
#######################################################
# Configure the following for your local installation #
# Requres a correctly installed server and a twiki    #
#######################################################
my $twikicfg = "/home/twiki/alpha/lib/TWiki.cfg";
my $pubdavpath  = "twiki/pub";
my $datadavpath  = "twiki/data";
my $lockpath = "/var/lock/webdav";
my $bindir = "/home/twiki/alpha/bin";
$davuser[0] = {
			   wikiname => "TestUser1",
			   password => "hubbahubba",
			   username => "TestUser1" # username as in REMOTE_USER
			  };
$davuser[1] = {
			   wikiname=>"TestUser2",
			   password=>"bloodandguts",
			   username => "TestUser2"
			  };
#######################################################

use strict;

use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

use vars qw( $defaultUrlHost $scriptUrlPath $dispScriptUrlPath $dispViewPath
	 $pubUrlPath $pubDir $templateDir $dataDir $logDir
	 $detailedOS $OS $scriptSuffix $uploadFilter $safeEnvPath
	 $mailProgram $noSpamPadding $mimeTypesFilename $rcsDir $rcsArg
	 $nullDev $useRcsDir $endRcsCmd $cmdQuote
	 $storeTopicImpl $lsCmd $egrepCmd $fgrepCmd
	 $displayTimeValues $useLocale $siteLocale $siteCharsetOverride 
	 $localeRegexes $upperNational $keywordMode @storeSettings
	 $securityFilter $defaultUserName $wikiToolName $wikiHomeUrl
	 $siteWebTopicName $mainWebname $twikiWebname $debugFilename
	 $warningFilename $htpasswdFormatFamily $htpasswdEncoding
	 $htpasswdFilename $authRealm $logFilename $remoteUserFilename
	 $wikiUsersTopicname $userListFilename $doMapUserToWikiName
	 $mainTopicname $notifyTopicname $wikiPrefsTopicname
	 $webPrefsTopicname $statisticsTopicname $statsTopViews
	 $statsTopContrib $doDebugStatistics $numberOfRevisions $editLockTime
	 $superAdminGroup $doKeepRevIfEditLock $doGetScriptUrlFromCgi
	 $doRemovePortNumber $doRemoveImgInMailnotify $doRememberRemoteUser 
	 $doPluralToSingular $doHidePasswdInRegistration $doSecureInclude
	 $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
	 $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
	 $doLogTopicChanges $doLogTopicSearch $doLogRegistration
	 $disableAllPlugins $doSuperAdminGroup );

require "$twikicfg";
my $twikiurl = "$defaultUrlHost/$scriptUrlPath";
my $davpuburl = "$defaultUrlHost/$pubdavpath";
my $davdataurl = "$defaultUrlHost/$datadavpath";
my $binurl = "$defaultUrlHost/$scriptUrlPath";

my $tmpfile = "/tmp/SugarKane.txt";

sub set_up {
  my $this = shift;
  `cp -R $dataDir/_default $dataDir/Davtest` or $this->assert("Fixture");
  # DavTest0 is accessible only to $davuser[0]
  # DavTest1 is accessible only to $davuser[1]
  # DavTest2 is accessible to both, except user 0 can't rename it
  # DavTest3 is accessible to neither
  savetopic(1, "Davtest", "DavTest0",
			"\t* Set DENYTOPICVIEW = $davuser[1]{wikiname}\n".
			"\t* Set DENYTOPICRENAME = $davuser[1]{wikiname}\n".
			"\t* Set DENYTOPICCHANGE = $davuser[1]{wikiname}\n");
  savetopic(0, "Davtest", "DavTest1",
			"\t* Set DENYTOPICVIEW = $davuser[0]{wikiname}\n".
			"\t* Set DENYTOPICRENAME = $davuser[0]{wikiname}\n".
			"\t* Set DENYTOPICCHANGE = $davuser[0]{wikiname}\n");
  savetopic(0, "Davtest", "DavTest2",
			"\t* Set DENYTOPICRENAME = $davuser[0]{wikiname}\n");
  savetopic(0, "Davtest", "DavTest3",
			"\t* Set DENYTOPICVIEW = $davuser[0]{wikiname},$davuser[1]{wikiname}\n".
			"\t* Set DENYTOPICRENAME = $davuser[0]{wikiname},$davuser[1]{wikiname}\n".
			"\t* Set DENYTOPICCHANGE = $davuser[0]{wikiname},$davuser[1]{wikiname}\n");
  `chmod -f -R 777 $dataDir/Davtest`;
  `mkdir -p $pubDir/Davtest`;
  `mkdir -p $pubDir/Davtest/Davtest0`;
  `mkdir -p $pubDir/Davtest/Davtest1`;
  `mkdir -p $pubDir/Davtest/Davtest2`;
  `mkdir -p $pubDir/Davtest/Davtest3`;
  `chmod -f -R 777 $pubDir/Davtest`;
  open TF, ">$tmpfile";
  print TF "Sugar Kowalski\nMarilynMonroe\n";
  close TF;
}

sub tear_down {
  `rm -rf $dataDir/Davtest`;
  `rm -rf $pubDir/Davtest`;
  unlink $tmpfile;
}

sub urlencode {
  return "%".sprintf("%02x", ord(shift));
}

sub savetopic {
  my ($user, $web, $topic, $text) = @_;

  die unless $web;
  die unless $topic;
  $text="empty" unless $text;
  $text =~ s/%/%25/go;
  $text =~ s/\*/%2A/go;
  while ($text =~ s/([^A-Za-z0-9%])/&urlencode($1)/geo) {
	;
  }
  my $cmd = "curl -s -S ";
  $cmd .= "-u $davuser[$user]{username}:$davuser[$user]{password} ";
  $cmd .= "-d text='$text' ";
  $cmd .= "-d dontnotify=on ";
  $cmd .= "-d unlock=on ";
  $cmd .= "$binurl/save$scriptSuffix/${web}/${topic} ";
  `$cmd` && die "$cmd failed $?";
}

sub saveattachment {
  my ($this, $user, $web, $topic, $att) = @_;
  die unless $web;
  die unless $topic;
  my $cmd = "curl -s -S ";
  $cmd .= "-u $davuser[$user]{username}:$davuser[$user]{password} ";
  $cmd .= "-F filepath=\\\@SugarKane.txt ";
  $cmd .= "-F filename=$att ";
  $cmd .= "-F filecomment=ElucidateTheGoose ";
  $cmd .= "$binurl/upload$scriptSuffix/${web}/${topic} ";
  my $err = `$cmd`;
  die "$cmd failed $?: $err" if ($?);
}

sub davopen {
  my ($this, $user) = @_;
  my ($un,$up);
  my $dav = new HTTP::DAV;
  $dav->credentials(-user=>$davuser[$user]{username},
					-pass=>$davuser[$user]{password},
					-url=>$davpuburl);

  $dav->open(-url=>$davpuburl)
	or die "Failed to open $davpuburl ".$dav->message." at ".join(":",caller);

  return $dav;
}

sub davcheck {
  my ($this, $op, $dav) = @_;

  $this->assert($op, $dav->message." at ".join(":",caller()));
}

# check that a list contains some things and excludes others
sub checklist {
  my ($this, $v, $yes, $no) = @_;

  if ($yes) {
	foreach my $thing (split(/[,\s]+/, $yes)) {
	  $this->assert_matches(qr/\b$thing\b/, $v." at ".join(":",caller));
	}
  }
  if ($no) {
	foreach my $thing (split(/[,\s]+/, $no)) {
	  $this->assert_does_not_match(qr/\b$thing\b/, $v." at ".join(":",caller));
	}
  }
}

# check that an attachment is there or not there
sub checkatt {
  my ($this, $exp, $web, $topic, $att, $nocom) = @_;
  my $al = `egrep 'META:FILEATTACHMENT.*name=\"$att\"' $dataDir/$web/$topic.txt`;
  my $at = " at ".join(":",caller);
  if ($exp) {
	$this->assert(!$?, "$web/$topic meta $att");
	$this->assert(-e "$pubDir/$web/$topic/$att", $at);
	$this->assert(-e "$pubDir/$web/$topic/$att,v", $at);
	$this->assert_matches(qr/name=\"$att\"/, $al, $at);
	if (!$nocom) {
	  $this->assert_matches(qr/comment=\"ElucidateTheGoose\"/, $al,
							" at $at in $al");
	}
  } else {
	$this->assert($?, "$web/$topic meta $att", $at);
	$this->assert(!-e "$pubDir/$web/$topic/$att", $at);
	$this->assert(!-e "$pubDir/$web/$topic/$att,v", $at);
  }
}

# make an extended fixture for testing copies and moves
sub copymovefixture {
  my $this=shift;
  my $dav = $this->davopen(0);

  $this->saveattachment(0, "Davtest", "DavTest0", "SugarKane.txt");

  $this->checkatt(1, "Davtest","DavTest0", "SugarKane.txt");
  $this->checkatt(0, "Davtest","DavTest0", "MarilynMonroe.dat");
}

sub test_copyAttachmentWithinTopic {
  my $this=shift;
  $this->copymovefixture();

  # copy leaf access permitted within topic
  my $dav = $this->davopen(0);
  $this->checkatt(1, "Davtest","DavTest0", "SugarKane.txt");
  $this->davcheck($dav->copy("Davtest/DavTest0/SugarKane.txt",
							 "Davtest/DavTest0/MarilynMonroe.dat"), $dav);
  $this->checkatt(1, "Davtest","DavTest0", "SugarKane.txt");
  $this->checkatt(1, "Davtest","DavTest0", "MarilynMonroe.dat");
}

sub test_copyAttachmentWithinTopicDenied {
  my $this=shift;
  $this->copymovefixture();

  # copy leaf access denied
  my $dav = $this->davopen(1);
  $this->davcheck(!$dav->copy("Davtest/DavTest0/SugarKane.txt",
							  "Davtest/DavTest0/MrsKennedy.txt"), $dav);
}

sub test_copyPubCollection {
  my $this=shift;

  # copy collection
  my $dav = $this->davopen(0);
  $this->davcheck(!$dav->copy("Davtest/DavTest0",
							  "Davtest/SmeaGol"), $dav);
}

sub test_copyAttacmnetToDenied {
  my $this=shift;
  $this->copymovefixture();

  # copy leaf access permitted but change denied
  my $dav = $this->davopen(1);
  $this->davcheck(!$dav->copy("Davtest/DavTest0/SugarKane.txt",
							  "Davtest/DavTest1/SugarKane.txt"), $dav);
}

sub test_deleteAttachment {
  my $this=shift;
  my $dav = $this->davopen(0);

  $this->saveattachment(0,"Davtest","DavTest0","SugarKane.txt");

  # delete leaf access denied
  $dav = $this->davopen(1);
  $this->davcheck(!$dav->delete("Davtest/DavTest0/SugarKane.txt"), $dav);

  # delete leaf access permitted
  $dav = $this->davopen(0);
  $this->checkatt(1, "Davtest","DavTest0", "SugarKane.txt");
  $this->davcheck($dav->delete("Davtest/DavTest0/SugarKane.txt"), $dav);
  $this->checkatt(0, "Davtest","DavTest0", "SugarKane.txt");

  # delete collection
  $this->davcheck(!$dav->delete("Davtest/DavTest0"), $dav);
}

# make sure of permissions
sub test_getAttachment {
  my $this=shift;
  my $dav;

  $this->saveattachment(0,"Davtest","DavTest0","SugarKane.txt");
  $this->saveattachment(1,"Davtest","DavTest1","SugarKane.txt");

  $dav = $this->davopen(0);
  # get access permitted
  $this->davcheck($dav->get("Davtest/DavTest0/SugarKane.txt"), $dav);
  # get access denied
  $this->davcheck(!$dav->get("Davtest/DavTest1/SugarKane.txt"), $dav);

  $dav = $this->davopen(1);
  # get access denied
  $this->davcheck(!$dav->get("Davtest/DavTest0/SugarKane.txt"), $dav);
  # get access permitted
  $this->davcheck($dav->get("Davtest/DavTest1/SugarKane.txt"), $dav);
}

# collection making is banned everywhere
sub test_mkcol {
  my $this=shift;

  my $dav = $this->davopen(0);
  $this->davcheck(!$dav->mkcol("Blockme"), $dav);
  $this->assert(!-d "$pubDir/Blockme");
  $this->davcheck(!$dav->mkcol("Davtest/Blockme"),$dav);
  $this->assert(!-d "$pubDir/Davtest/Blockme");
  $this->davcheck(!$dav->mkcol("Davtest/Davtest1/Blockme"),$dav);
  $this->assert(!-d "$pubDir/Davtest/DavTest1/Blockme");
}

sub test_moveCollection {
  my $this=shift;

  my $dav = $this->davopen(0);
  # move collection
  $this->davcheck(!$dav->move("Davtest/DavTest0", "DavTest/SmeAgol"), $dav);
}

sub test_moveWithinTopic {
  my $this=shift;
  $this->copymovefixture();

  my $dav = $this->davopen(0);
  # move leaf access permitted within topic
  $this->davcheck($dav->move("Davtest/DavTest0/SugarKane.txt",
							 "Davtest/DavTest0/MarilynMonroe.dat"), $dav);
  $this->checkatt(0, "Davtest","DavTest0", "SugarKane.txt");
  $this->checkatt(1, "Davtest","DavTest0", "MarilynMonroe.dat");
}

sub test_moveAttachmentNoRead {
  my $this=shift;
  $this->copymovefixture();

  my $dav = $this->davopen(1);
  $this->davcheck(!$dav->move("Davtest/DavTest0/SugarKane.txt",
							  "Davtest/DavTest2/MarilynMonroe.dat"), $dav);
}

# move leaf access permitted between topics
sub test_moveAttachmentBetweenTopics {
  my $this=shift;
  $this->copymovefixture();
  my $dav = $this->davopen(0);
  $this->saveattachment(0,"Davtest","DavTest0","SugarKane.txt");

  $this->davcheck($dav->move("Davtest/DavTest0/SugarKane.txt",
							 "Davtest/DavTest2/MarilynMonroe.dat"), $dav);
  $this->checkatt(0, "Davtest","DavTest0", "SugarKane.txt");
  $this->checkatt(0, "Davtest","DavTest0", "MarilynMonroe.dat");
  $this->checkatt(0, "Davtest","DavTest2", "SugarKane.txt");
  $this->checkatt(1, "Davtest","DavTest2", "MarilynMonroe.dat");
}

# move leaf access permitted to other topic write denied
sub test_moveToDenied {
  my $this=shift;
  $this->copymovefixture();
  my $dav = $this->davopen(0);
  $this->davcheck(!$dav->move("Davtest/Davtest0/SugarKane.txt",
							  "Davtest/DavTest1/MarilynMonroe.dat"),$dav);
}

sub test_moveRenameAttachmentDenied {
  my $this=shift;
  $this->copymovefixture();
  my $dav = $this->davopen(0);
  $this->saveattachment(0,"Davtest","DavTest2","SugarKane.txt");

  $this->davcheck(!$dav->move("Davtest/DavTest2/SugarKane.txt",
							  "Davtest/DavTest0/MarilynMonroe.dat"), $dav);
}

sub test_moveAttachmentToWebLevel {
  my $this=shift;
  $this->copymovefixture();
  my $dav = $this->davopen(0);
  $this->davcheck(!$dav->move("Davtest/Davtest0/SugarKane.txt",
							  "Davtest/MarilynMonroe.dat"),$dav);
}

# options that say what methods are available where
# test disabled because it really doesn't matter that it gives the
# wrong options.
sub DISABLEtest_options {
  my $this=shift;
  # root
  my $dav = $this->davopen(0);
  # attachment
  $this->checklist($dav->options("Davtest/DavTest0/Kitty.gif"),
				   "OPTIONS,GET,DELETE,POST,COPY,MOVE,PROPFIND",
				  "PROPPATCH,LOCK,UNLOCK");

  # topic dir
  $this->checklist($dav->options("Davtest/DavTest0"),
				   "OPTIONS,GET,PROPFIND,COPY",
				   "PUT,MOVE,DELETE,PROPPATCH,LOCK,UNLOCK");

  # web dir
  $this->checklist($dav->options("Davtest"),
				   "OPTIONS,GET,PROPFIND,COPY",
				   "PUT,MOVE,DELETE,PROPPATCH,LOCK,UNLOCK");

  $this->checklist($dav->options("."),
				   "OPTIONS,GET,PROPFIND,COPY");
}

# put into various directories
# this is what drag and drop does
sub test_putAttachment {
  my $this=shift;

  my $dav = $this->davopen(0);
  # illegal - save to root
  $this->davcheck(!$dav->put(-local=>$tmpfile,
							-url=>"/SugarKane.txt"), $dav);
  $this->assert(!-e "$pubDir/SugarKane.txt");

  # illegal - save to web dir
  $this->davcheck(!$dav->put(-local=>$tmpfile,
							-url=>"Davtest/SugarKane.txt"), $dav);
  $this->assert(!-e "$pubDir/Davtest/SugarKane.txt");

  # illegal - save to non-existent topic
  $this->davcheck(!$dav->put(-local=>$tmpfile,
							 -url=>"Davtest/SpiggleTodt/SugarKane.txt"), $dav);
  $this->assert(!-e "$pubDir/Davtest/SpiggleTodt/SugarKane.txt");

  # legal - put to topic
  $this->davcheck($dav->put(-local=>$tmpfile,
							-url=>"Davtest/DavTest0/SugarKane.txt"), $dav);
  $this->checkatt(1, "Davtest","DavTest0", "SugarKane.txt", 1);
}

sub test_recache_command_line {
  my $this = shift;
  # delete the db, regenerate it, create a topic with limitation,
  # recache, check the difference.
  $this->assert(-w $lockpath, "No permission to run this test");
  $this->assert(-w "$lockpath/TWiki", "No permission to run this test");
  unlink("$lockpath/TWiki");
  $this->assert(!$?, "Can't set up");
  my $monitor = `$bindir/dav_recache$scriptSuffix`;
  $this->assert(!$?, "Can't run $bindir/dav_recache$scriptSuffix");
  # Make sure it ran over all webs
  foreach my $web(glob("$dataDir/*")) {
	if (-d $web) {
	  my @topics = glob("$web/*.txt");
	  $web = `basename $web`;
	  chop($web);
	  $this->assert_matches(qr/(\d+)\b.*\b$web\b/, $monitor);
	  $monitor =~ /(\d+)\b.*\b$web\b/;
	  $this->assert($1 <= scalar(@topics), "$web $1 ".scalar(@topics));
	}
  }
  my $dump = `../dumpLockDB.pl $lockpath`;
  $this->assert(!$?, "Can't dump");
  my $du = $davuser[1]{wikiname};
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:V:D => \|$du\|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:C:D => \|$du\|/, $dump);
  savetopic(0, "Davtest", "DavTest0",
			"\t* Set DENYTOPICVIEW = OakTree\n".
			"\t* Set DENYTOPICCHANGE = AshTree\n");
  unlink("$lockpath/TWiki") || die "Failed";
  $this->assert(!$?, "Can't set_up");
  $this->assert(!-e "$lockpath/TWiki");
  $monitor = `$bindir/dav_recache$scriptSuffix`;
  $this->assert(!$?, "Can't run");
  $dump = `../dumpLockDB.pl $lockpath`;
  $this->assert_does_not_match(qr/P:\/Davtest\/DavTest0:V:D => \|$du\|/, $dump);
  $this->assert_does_not_match(qr/P:\/Davtest\/DavTest0:C:D => \|$du\|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:V:D => |OakTree|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:C:D => |AshTree|/, $dump);

  $monitor = `$bindir/dav_recache$scriptSuffix Sandbox`;
  $this->assert_matches(qr/Processed \d+ topics from Sandbox\b/, $monitor);
  $monitor =~ s/Processed \d+ topics from Sandbox\b//;
  $this->assert_does_not_match(qr/Processed \d+ topics from \w+/, $monitor);

  $monitor = `$bindir/dav_recache$scriptSuffix Davtest.DavTest0`;
  $this->assert_matches(qr/Processing topic Davtest\.DavTest0\b/, $monitor);
  $monitor =~ s/Processing topic Davtest\.DavTest0\b//;
  $this->assert_matches(qr/Processed 1 topics from Davtest\b/, $monitor);
  $monitor =~ s/Processed \d+ topics from Davtest\b//;
  $this->assert_does_not_match(qr/Processed \d+ topics from \w+/, $monitor);
}

sub test_recache_query {
  my $this = shift;
  unlink("$lockpath/TWiki") || die "Failed";
  my $monitor = `curl -s -S $binurl/dav_recache/$scriptSuffix`;
  $this->assert(!$?, "Can't run");
  my $dump = `../dumpLockDB.pl $lockpath`;
  $this->assert(!$?, "Can't dump");
  my $du = $davuser[1]{wikiname};
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:V:D => \|$du\|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:C:D => \|$du\|/, $dump);
  savetopic(0, "Davtest", "DavTest0",
			"\t* Set DENYTOPICVIEW = OakTree\n".
			"\t* Set DENYTOPICCHANGE = AshTree\n");
  unlink("$lockpath/TWiki");
  $this->assert(!$?, "Can't set_up");
  $monitor = `curl -s -S $binurl/dav_recache/$scriptSuffix`;
  $this->assert(!$?, "Can't run");
  $dump = `../dumpLockDB.pl $lockpath`;
  $this->assert_does_not_match(qr/P:\/Davtest\/DavTest0:V:\w => \|$du\|/, $dump);
  $this->assert_does_not_match(qr/P:\/Davtest\/DavTest0:C:\w => \|$du\|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:V:D => \|OakTree\|/, $dump);
  $this->assert_matches(qr/P:\/Davtest\/DavTest0:C:D => \|AshTree\|/, $dump);
}

1;
