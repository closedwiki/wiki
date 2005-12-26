#! perl -w

# Rewrite "/usr/bin/perl" shebang lines to "perl"
# SMELL: This script would not be necessary if there was a CommonFrontEndCgiScript
# i.e. use of the bin/twiki script
#
# bug/limitation: it can't be used more than once, it only makes changes
# if the existing path is "/usr/bin/perl" (e.g. you can't just re-run the 
# script if you mistype the new path).

use FileHandle;
use English;

my $old = "/usr/bin/perl";
my $new = $EXECUTABLE_NAME;

print <<END;

Rewrite #!/usr/bin/perl shebang lines to your local installation of perl.
This script will rewrite the first lines of all your TWiki cgi scripts so
they use a different shebang line. Use it if your perl is in a non-standard
location, or you want to use a different interpreter (such as 'speedy')

END

unless (-d "bin") {
  die "This must be run in the top level of your TWiki installation";
}

chdir "bin" || die "Can't cd into the bin dir";

while (1) {
    print "Enter path to perl executable [hit enter to choose '$new']: ";
    my $n = <>;
    chomp $n;
    last if( !$n );
    $new = $n;
};

opendir(D, ".") || die "Can't open bin dir";;
foreach my $file (grep { -f && /^\w+$/ } readdir D) {
   replaceLine($file, $old, $new);
}
closedir(D);

sub replaceLine {
  my ($file, $old, $new) = @_;
  
  my $fh = new FileHandle("<$file") || die "Can't open $file";
  local $/; undef $/;
  my $contents = <$fh>;
  close $fh;

  $replacementMade = ($contents =~ s/$old/$new/);

  if ($replacementMade) {
    my $fh = new FileHandle(">$file") || die "Can't open $file for writing";
    print $fh $contents;
    close $fh;   
    print "$file modified\n";
  } else {
    print "$file unmodified\n";
  }

}
