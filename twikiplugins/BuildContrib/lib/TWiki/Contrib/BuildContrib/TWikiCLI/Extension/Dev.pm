package TWiki::Contrib::BuildContrib::TWikiCLI::Extension::Dev;
#use TWiki::Contrib::BuildContrib::TWikiCLI::Extension;
use base qw(TWiki::Contrib::BuildContrib::TWikiCLI::Extension);
no strict 'refs';

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = {};
        bless ($self, $class);
        return $self;
}

sub run_test {
  print "foo";
}

sub cli__init {
  my $self = shift;
  $self->SUPER::cli__init();

}

sub cli_new {
my ($extension) = @_;

 print "Doing making a new CVS area for Extension named $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);
 # TODO: check return value
 print "This is '$extension' - correct?"; 
 # TODO : get yes/no
 
 # get their base plugin development area
 # do a CVS export out of the Empty Plugin - (as stupidly named as it is)
 # Tell them to refresh $TWIKI_LIBS (its an env var) defined by settwikivars.sh
 # rename the export to $libFrag
 # rename the data file

 # Make the file lib/TWiki/$libFrag.pm
 # Make the dir lib/TWiki/$libFrag/
 
 # In the $libFrag.pm:
 # fix up the references from 'Empty ' to 'Whatever '
 # change the version number to 0.1
 
 # In the $libFrag.txt 
 # Fix up the table at the bottom
 
 # The build.pl script now needs to be copied (ugly, huh?)
 
}

sub cli_upload {
 my $self = shift;
 my ($extension) = @_;

 print "Doing upload for $extension\n\n";
 my $libFrag = $self->getLibFragmentForExtension($extension);
 my $dir     = $self->getTWikiLibFragDir($libFrag);

 if (! defined $dir) {
  die "Couldn't find the development copy of $extension";
 }

 chdir($dir) || die "$dir: $!";

 # CodeSmell: Yuk
 print "Type TWiki.org username <return> password <return>\n";
 my $ans = `perl build.pl upload`;
}


sub cli_checkout {
 my $self = shift;
 my ($extension) = @_;

die ("Not implemented (see code)");
# chdir TWIKI_PLUGINS_DEV DIR (set by settwikivars.sh)
 print "Doing cvs update for $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);

 my $ans = `cvs checkout $extension`;

}



# now this really ought to be in Extension::CVS, but that directory would clash
sub cli_cvsupdate {
 my $self = shift;
 my ($extension) = @_;

 print "Doing cvs update for $extension\n\n";
 my $libFrag = getLibFragmentForExtension($extension);

 my $dir = selectTWikiLibDir($libFrag) . "/..";    # codesmell: Lazy

 chdir($dir) || die "Couldn't CD to $dir - $!";

 my $ans = `cvs update`;

}


sub cli_install {
 my $self = shift;
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

1;
