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
    $re =~ s/\|/\\|/go;
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

  sub _assertMismatch {
    my ($file,$line,$cond,$saw,$exp) = @_;

    if ($cond) {
      print "Passed line $line\n" if ( $debug );
      return 1;
    }

    # Would like to do this by extracting subexpressions from the re and
    # matching them, and keep adding subexpressions until there's
    # a match, but it's too complicated. Just rely on a visual match
    # (after all, this *is* for saw, and shouldn't fail often!)

    # find the first mismatched character
    my $i = 0;
    while ($i < length($saw) && $i < length($exp)) {
      my $sawCh = substr($saw, $i, 1);
      my $expCh = substr($exp, $i, 1);
      if ($sawCh ne $expCh) {
	my $beforeSaw = substr($saw, 0, $i);
	if (length($beforeSaw) > 30) {
	  $beforeSaw = "....".substr($beforeSaw,length($beforeSaw)-30);
	}

	my $afterSaw = substr($saw, $i, length($saw));
	if (length($afterSaw) > 30) {
	  $afterSaw = substr($afterSaw, 0, 30) . "....";
	}

	my $beforeExp = substr($exp, 0, $i);
	if (length($beforeExp) > 30) {
	  $beforeExp = "....".substr($beforeExp,length($beforeExp)-30);
	}

	my $afterExp = substr($exp, $i, length($exp));
	if (length($afterExp) > 30) {
	  $afterExp = substr($afterExp, 0, 30) . "....";
	}
	assert($file, $line, 0,
	       "\nsaw      \"$beforeSaw***** HERE->$afterSaw\"".
	       "\nexpected \"$beforeExp***** HERE->$afterExp\"");
      }
      $i++;
    }
    return 1;
  }

  sub sContains {
    my ($file,$line,$test,$expected) = @_;
    my $re = unregex($expected);
    my $pass = $test =~ m/$re/s ? 1 : 0;
    assert($file,$line, $pass,
	   "\nsaw      \"$test\"\nsContains\"$expected\"" );
    return 1;
  }
  
  sub sEquals {
    my ($file,$line,$test,$expected) = @_;
    my $re = unregex($expected);
    my $pass = $test =~ m/^$re$/s ? 1 : 0;
    _assertMismatch($file,$line, $test, $expected);
    return 1;
  }

  sub htmlContains {
    my ($file,$line,$test,$expected) = @_;
    my $re = unhtml($expected);

    my $pass = $test =~ m/$re/s ? 1 : 0;
    assert($file,$line, $pass,
	   "\n$test\n*********failed htmlContains\n$expected");
    return 1;
  }
  
  sub htmlEquals {
    my ($file,$line,$test,$expected) = @_;
    my $re = unhtml($expected);

    my $pass = ($test =~ m/^$re$/s ? 1 : 0);
    _assertMismatch($file,$line, $pass, $test, $expected);
    return 1;
  }

  sub equals {
    my ($file,$line,$test,$expected) = @_;
    my $pass = ($test == $expected);
    assert($file,$line, $pass, "saw $test expected $expected");
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
