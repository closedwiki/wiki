#! perl -w

# This script would not be necessary if there was a CommonFrontEndCgiScript
# i.e. use of the bin/twiki script

use FileHandle;

my $old = "/usr/bin/perl";
my $new = "perl";
my @files = qw(actionnotify attach changes configure edit geturl mailnotify manage oops passwd preview rdiff register rename renameweb resetpasswd rest save search statistics twiki upload view viewfile);

unless (-d "bin") {
  die "This must be run in the top level bin directory";
}

chdir "bin" || die "Can't cd into the bin dir";

foreach my $file (@files) {
   replaceLine($file, $old, $new);
}

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
