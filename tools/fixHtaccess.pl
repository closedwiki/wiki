#! /usr/bin/perl -w
# See http://twiki.org/cgi-bin/view/Codev/FixUpHtaccess

my ($filePathToTwiki, $urlPathToTwiki, $adminUsers) = getParams(@ARGV); 
# e.g. ("/home/mrjc/wikiconsulting.com/twiki", "wikiconsulting.com/twiki");

my %patterns = ("!FILE_path_to_TWiki!" => $filePathToTwiki,
		"!URL_path_to_TWiki!" => $urlPathToTwiki,
	        "!ADMIN_users!" => $adminUsers);

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
    print "Replacing $key with $value\n";
    $file =~ s/$key/$value/g;
}

my $htaccessFh = new FileHandle("> bin/.htaccess");

print $htaccessFh $file;
close $htaccessFh;

print `chmod og-w bin bin/*`;

sub getParams {
  my ($filePathToTwiki, $urlPathToTwiki, $adminUsers)  = @_;

  unless ($filePathToTwiki) {
    die "ERROR: filePathToTwiki missing\n".usage();
  }
  unless ($urlPathToTwiki) {
    die "ERROR: urlPathToTwiki missing\n".usage();
  }

  unless ($adminUsers) {
    die "ERROR: adminUsers missing\n".usage();
  } 

  unless (-d $filePathToTwiki) {
    die "The directory for filePathToTwiki '$filePathToTwiki' does not exist";
  }

  if ($urlPathToTwiki =~ m/^http/) {
    die "The URL for urlPathToTwiki '$urlPathToTwiki' must not start with http";
  }

  return  ($filePathToTwiki, $urlPathToTwiki, $adminUsers);
}

sub usage {
  my $ans = <<EOM;
Usage
=====

fixHtaccess.pl \$filePathToTwiki \$urlPathToTwiki \$adminUsers

filePathToTwiki = location on the disk for TWiki root dir
urlPathToTwiki  = base URL of TWiki when accessed by web 
adminUsers      = which .htpasswd users can access configure

e.g.
fixHtaccess.pl /home/account/wikiconsulting.com/twiki wikiconsulting.com/twiki YourAdminLoginName

Note that you are responsible for putting an Admin LoginName into .htpasswd.
On UNIX you can use the htpasswd tool for this.

EOM
  return $ans.".";
}
