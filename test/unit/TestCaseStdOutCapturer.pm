## http://masarl.cocolog-nifty.com/main/2004/07/dynamic_scope.html

package Test::Unit::IO::StdoutCapture;
use strict;
use File::Temp qw(tempfile);
sub do(&) {
  my $block = shift;
  my ($f, $filename) = &tempfile();
  {
    local *STDOUT;
    open(STDOUT, ">$filename") || die "Can't redirect stdout";
    $block->();
  }
  open(TEMPFILE, "<$filename");
  my @out;
  while(<TEMPFILE>) {
    push @out, $_;
  }
  close(TEMPFILE);
  unlink($filename);
  return join("",@out);
}
1;
