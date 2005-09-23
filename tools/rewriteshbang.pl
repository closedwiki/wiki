#! perl -w

# This script would not be necessary if there was a CommonFrontEndCgiScript
# i.e. use of the bin/twiki script

use FileHandle;

my $old = "/usr/bin/perl";
my $new = "perl";
# FIXME: @files should be generated from what actually exists in bin
my @files = qw(edit preview resetpasswd view attach geturl manage rdiff rest statistics  viewfile changes login oops register save twiki configure logon passwd rename search upload);

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
