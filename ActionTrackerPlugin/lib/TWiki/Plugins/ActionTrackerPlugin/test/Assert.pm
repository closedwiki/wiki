use strict;
use integer;

{ package Assert;

  my $debug = 0;

  # call from test to get a print every time an assert is executed
  sub showProgress() {
    $debug = 1;
  }

  sub assert {
    my ($file,$line,$test,$mess) = @_;
    $mess = "" unless $mess;
    die "Assert at $file line $line failed: $mess" unless $test;
    print "Passed line $line\n" if ( $debug );
  }

  # escape regular expression chars in string
  sub unregex {
    my ($re) = @_;
    $re =~ s/\\/\\\\/go;
    $re =~ s/\./\\./go;
    $re =~ s/\?/\\?/go;
    $re =~ s/\*/\\*/go;
    $re =~ s/\+/\\+/go;
    $re =~ s/\(/\\(/go;
    $re =~ s/\)/\\)/go;
    $re =~ s/\[/\\[/go;
    $re =~ s/\]/\\]/go;
    $re =~ s/\^/\\^/go;
    $re =~ s/\$/\\\$/go;
    return $re;
  }

  # 'free' the format of html
  sub unhtml {
    my ($re) = @_;
    $re = unregex($re);
    $re =~ s/<([^>]+)\s+(\w+)\s*=\s*([^>]+)>/<$1\\s+(?i)$2(?-i)\\s*=\\s*$3>/go;
    $re =~ s/<(\/?\w+)/<(?i)$1(?-i)/go;
    $re =~ s/<([^>]+)\s+/$1\\s+/go;
    $re =~ s/\s*(<[^>]*>)\s*/\\s*$1\\s*/go;
    $re =~ s/\n+/\\s*/go;
    $re =~ s/\\s\*\\s\*/\\s*/go;
    $re =~ s/\s+/\\s+/go;

    return $re;
  }

  sub assertMismatch {
    my ($file,$line,$test,$expected) = @_;

    # Would like to do this by extracting subexpressions from the re and
    # matching them, and keep adding subexpressions until there's
    # a match, but it's too complicated. Just rely on a visual match
    # (after all, this *is* for test, and shouldn't fail often!)

    # find the first mismatched character
    my $i = 1;
    while ($i < length($test) && $i < length($expected)) {
      my $ts = substr($test, 0, $i);
      my $es = substr($expected, 0, $i);
      if ($ts ne $es) {
	my $rest = substr($test, $i, length($test));
	$rest = substr($rest, 0, 10) . "....";
	assert($file,$line, 0,
	       "\nsaw      \"$ts***** Maybe here *****$rest\"\nexpected \"$expected\"");
      }
      $i++;
    }
    assert($file,$line, 0, "\nsaw      \"$test\"\nexpected \"$expected\"");
  }

  sub sContains {
    my ($file,$line,$test,$expected) = @_;
    my $re = unregex($expected);
    if ($test !~ m/$re/s) {
      assert($file,$line, 0,
	     "\nsaw      \"$test\"\nsContains\"$expected\"" );
    }
    return 1;
  }
  
  sub sEquals {
    my ($file,$line,$test,$expected) = @_;
    my $re = unregex($expected);
    if ($test !~ m/^$re$/s) {
      assertMismatch($file,$line, $test, $expected);
    }
    return 1;
  }

  sub htmlContains {
    my ($file,$line,$test,$expected) = @_;
    my $re = unhtml($expected);

    if ($test !~ m/$re/s) {
      assert($file,$line, 0,
	     "\nsaw      \"$test\"\nnContains\"$expected\"");
    }
    return 1;
  }
  
  sub htmlEquals {
    my ($file,$line,$test,$expected) = @_;
    my $re = unhtml($expected);

    if ($test !~ m/^$re$/s) {
      assertMismatch($file,$line, $test, $expected);
    }
    return 1;
  }

  sub equals {
    my ($file,$line,$test,$expected) = @_;
    assert($file,$line, $test == $expected, "saw $test expected $expected");
  }

  sub fileContains {
    my ($file,$line, $fn, $expected) = @_;

    undef $/; # set to read to EOF
    assert($file,$line, open(IN_FILE, "<$fn"), "open $fn");
    my $text = "";
    my $l;
    while ($l = <IN_FILE>) {
      $text = $text . $l;
    }
    close(IN_FILE);

    sContains($file,$line, $text, $expected);
  }
}

1;
