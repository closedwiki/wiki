#! /usr/bin/perl -w
# See http://twiki.org/cgi-bin/view/Codev/FixUpHtaccess

my ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers) = getParams(@ARGV); 
# e.g. ("/home/mrjc/wikiconsulting.com/twiki", "wikiconsulting.com/twiki");

# {DataDir}
#    Get the value from =configure=
# {DefaultUrlHost}
#    Get the value from =configure=
# {ScriptUrlPath}
#    Get the value from =configure=
# {Administrators}


my %patterns = ("{DataDir}" => $dataDir,
		"{DefaultUrlHost}" => $defaultUrlHost,
		"{ScriptUrlPath}" => $scriptUrlPath,
	        "{Administrators}" => $adminUsers);

unless (-d "bin") {
  die "This must be run in the top level bin directory";
}

use FileHandle;
chdir ($filePathToTwiki) || die "Can't get to $filePathToTwiki";

my $htaccessTXTfh = new FileHandle("< bin/.htaccess.txt");
local $/; undef $/;
my $file = <$htaccessTXTfh>;
close $htaccessTXTfh;

foreach my $key (keys %patterns) {
    my $value = $patterns{$key};
    print "Replaced $key with $value ";
    my $count = $file =~ s/$key/$value/g;
    print "$count times\n";
}

my $htaccessFh = new FileHandle("> bin/.htaccess");

print $htaccessFh $file;
close $htaccessFh;

print `chmod og-w bin bin/*`;

sub getParams {
    my ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers) = @_;

  unless ($dataDir) {
    die "ERROR: dataDir missing\n".usage();
  }
  unless ($defaultUrlHost) {
    die "ERROR: defaultUrlHost missing\n".usage();
  }

  unless ($scriptUrlPath) {
    die "ERROR: scriptUrlPath missing\n".usage();
  } 

   unless ($adminUsers) {
	die "ERROR: adminUsers missing\n".usage();
    }


  unless (-d $dataDir) {
    die "The directory for dataDir '$dataDir' does not exist";
  }
  return ($dataDir, $defaultUrlHost, $scriptUrlPath, $adminUsers)

}

sub usage {
  my $ans = <<EOM;
Usage
=====

fixHtaccess.pl \$dataDir, \$defaultUrlHost, \$scriptUrlPath, \$adminUsers

dataDir = location on the disk for TWiki root dir
defaultUrlHost = hostname TWiki is running on
scriptUrlPath  = base URL of TWiki when accessed by web 
adminUsers      = which .htpasswd users can access configure

e.g.
fixHtaccess.pl /home/account/wikiconsulting.com/twiki wikiconsulting.com /twiki YourAdminLoginName

Note that you are responsible for putting an Admin LoginName into .htpasswd.
On UNIX you can use the htpasswd tool for this.

EOM
  return $ans.".";
}
