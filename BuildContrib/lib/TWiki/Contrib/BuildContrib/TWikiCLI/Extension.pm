package TWiki::Contrib::BuildContrib::TWikiCLI::Extension;
use TWiki::Contrib::DistributionContrib::DistributionFetcher;
use TWiki::Contrib::Build;
use TWiki;    # TODO why do I have to use this? Why not just TWiki::Func?
use TWiki::Func;
use strict;
use Cwd;
my $oldPwd;

# Ultimately we'd like to ask the Extension to handle this command
# itself. For now we just call build.pl

sub cli__init {
 $oldPwd = cwd();
}

sub cli_upload {
 my ($extension) = @_;

 print "Doing upload for $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);
 my $dir     = getTWikiLibFragDir($libFrag);

 chdir($dir) || die "$!";

 # CodeSmell: Yuk
 print "Type TWiki.org username <return> password <return>\n";
 my $ans = `perl build.pl upload`;
}

# now this really ought to be in Extension::CVS, but that directory would clash
sub cli_cvsupdate {
 my ($extension) = @_;

 print "Doing cvs update for $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);

 my $dir = selectTWikiLibDir($libFrag) . "/..";    # codesmell: Lazy

 chdir($dir) || die "Couldn't CD to $dir - $!";

 my $ans = `cvs update`;

}

=pod

sub cli_install_download 

This just takes the zip file and does a Build::target_install on it.
Note that this is actually the wrong thing, because it is different to 
what happens if you do a install_dev, which is to run build.pl - as 
I understand it people using BuildContrib will have packaged their PkgPluginBuild
class into the build.pl.

Have I misunderstood? Is it too late to change this?

If I can be bothered, I'll do something like this....

    print "Installing $extension\n\n";
    my $libFrag = getLibFragmentForExtension($extension);

     my $buildDotPlDir = $localCopy."/lib/TWiki/$libFrag/";
     
     if (-f $buildDotPlDir."/build.pl") {
      print "Woah! Found it!!\n";
     } else {
      print "boo :( failed - no build.pl in $buildDotPlDir \n";
     }


=cut

sub cli_install_download {
 my ($extension) = @_;

 print "Installing download $extension\n\n";

 my $localFile = getFilenameForDistributionDownload($extension);
 print "$localFile\n";

 my $dirInInstallation = getDistributionTopicDir();
 print "from $dirInInstallation.... \n";
 chdir ($dirInInstallation) || die "Can't cd to $dirInInstallation";
# TODO : Find out whether we can get rid of the need to be in here
# TODO : Find out why its called both Build and BuildContrib...
 my $buildObj = TWiki::Contrib::Build->new($extension);
 $buildObj->manifest();

}

sub cli_install_dev {
 my ($extension) = @_;

 print "Installing dev $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);

 my $outputLog;

 my $buildDotPlDir = getTWikiLibFragDir($libFrag);
 if ($buildDotPlDir) {
  chdir($buildDotPlDir) || die "Couldn't cd to $buildDotPlDir - $!";
  print "From $buildDotPlDir...\n";
  foreach my $home ( getHomes() ) {
   if ( $home !~ m!^/! ) {
    $home = $ENV{"HOME"} . "/" . $home;
   }
   print "\tInstalling to $home\n";
   $ENV{"TWIKI_HOME"} = $home;

   $outputLog .= `perl build.pl install`;
  }
 }
 else {
  print "Failed to find build.pl for $extension\n";
 }
 chdir($oldPwd);    # Not strictly necessary, but...
 return $outputLog;
}

sub cli_download {
 my ($extension) = @_;

 my $localFile = getFilenameForDistributionDownload($extension);
 my $localCopy =
   TWiki::Contrib::DistributionContrib::DistributionFetcher::fetchLatestDistributionVersion(
  $extension, $extension . '.zip', $localFile );
 if ( $localCopy eq "" ) {
  return "Couldn't get it";
 }
 else {
  return "okay - got it as $localCopy";
 }


}

sub getHomes {
 die "Set TWIKI_HOMES to : separated locations to install to"
   unless $ENV{"TWIKI_HOMES"};
 return split / /, $ENV{"TWIKI_HOMES"};
}

sub getTWikiLibFragDir {
 my ($libFrag) = @_;
 return selectTWikiLibDir($libFrag) . "/TWiki/$libFrag/";
}

sub selectTWikiLibDir {
 my ($frag) = @_;
 unless ( $ENV{"TWIKI_LIBS"} ) {
  die "No TWIKI_LIBS set?";
 }
 my $result;
 my $lookedIn;
 foreach my $libDir ( split( /:/, $ENV{TWIKI_LIBS} ) ) {
  my $buildDotPlDir = "$libDir";
  if ( -f $libDir . "/TWiki/$frag/build.pl" ) {
   $lookedIn .= "\tFound it\n";
   return $libDir;
  }
  else {
   $lookedIn .= "\tNot $buildDotPlDir\n";
  }
 }
 print "Didn't find it: - \n$lookedIn";
 return "";
}

sub getLibFragmentForExtension {
 my ($extension) = @_;
 my $dir;
 if ( $extension =~ "Plugin" ) {
  $dir = "Plugins/$extension";
 }
 elsif ( $extension =~ "AddOn" ) {
  $dir = "Plugins/$extension";
 }
 elsif ( $extension =~ "Contrib" ) {
  $dir = "Contrib/$extension";
 }
 return $dir;

}

=pod
  sub getFilenameForDistributionDownload 
  
  In: distribution name (e.g. TWiki20030201, KoalaSkin) 
  Out: local file name that it would be stored in, usually an attachment on BuildContrib

=cut

sub getFilenameForDistributionDownload {
 my ($distribution)   = @_;
 my $attachmentDir    = getDistributionTopicDir();
 my $distributionFile = $distribution . '.zip';

 my $attachmentPath = $attachmentDir . '/' . $distributionFile;
 return $attachmentPath;
}

=pod
Returns where downloaded distribution files should be stored
=cut

sub getDistributionTopicDir {
 my $pubDir      = TWiki::Func::getPubDir();
 my $webTopicDir =
   TWiki::Contrib::DistributionContrib::DistributionFetcher::getDistributionTopic
   ();
 $webTopicDir =~ s!\.!/!;
 my $attachmentDir = $pubDir . "/" . $webTopicDir;
 return $attachmentDir;
}
1;
