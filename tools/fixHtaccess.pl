#! /usr/bin/perl -w
# See http://twiki.org/cgi-bin/view/Codev/FixUpHtaccess

my ($filePathToTwiki, $urlPathToTwiki) = getParams(@ARGV); 
# e.g. ("/home/mrjc/wikiconsulting.com/twiki", "http://wikiconsulting.com/twiki");

my %patterns = ("!FILE_path_to_TWiki!" => $filePathToTwiki,
		"!URL_path_to_TWiki!" => $urlPathToTwiki);

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
#    print "replacing $key with $value\n";
    $file =~ s/$key/$value/g;
}

my $htaccessFh = new FileHandle("> bin/.htaccess");

print $htaccessFh $file;
close $htaccessFh;

print `chmod og-w bin bin/*`;

sub getParams {
  my ($filePathToTwiki, $urlPathToTwiki)  = @_;

  unless ($filePathToTwiki) {
    die "FILE missing ".usage();
  }
  unless ($urlPathToTwiki) {
    die "URL missing: ".usage();
  }


  unless (-d $filePathToTwiki) {
    die "The directory for filePathToTwiki '$filePathToTwiki' does not exist";
  }


  unless ($urlPathToTwiki =~ m/^http:/) {
    die "The URL for urlPathToTwiki '$urlPathToTwiki' does not start with http:";
  }

  return  ($filePathToTwiki, $urlPathToTwiki);
}

sub usage {
  my $ans = <<EOM;
fixHtaccess.pl \$filePathToTwiki \$urlPathToTwiki

e.g.
fixHtaccess.pl /home/account/wikiconsulting.com/twiki http://wikiconsulting.com/twiki
EOM
  return $ans.".";
}
