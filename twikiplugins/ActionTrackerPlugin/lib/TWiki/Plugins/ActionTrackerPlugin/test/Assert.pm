use strict;
use integer;

{ package Assert;

  my $debug = 0;

  # call from test to get a print every time an assert is executed
  sub showProgress() {
    $debug = 1;
  }

  sub assert {
    my ($test,$mess) = @_;
    
    if (!$test) {
      $mess = "" unless $mess;
      my ($p,$f,$l);
      my $i = 0;
      while (($p, $f, $l) = caller($i++)) {
	last if ($f =~ /^\(eval/);
	$mess .= "\n$f: $l";
      }
      #print STDERR "FAILURE Assert failed: $mess\n";
      die "Assert failed: $mess\ndied";
    }
    #print "Passed $mess\n" if ($debug);
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
    my ($pass,$saw,$exp) = @_;

    # Would like to do this by extracting subexpressions from the re and
    # matching them, and keep adding subexpressions until there's
    # a match, but it's too complicated. Just rely on a visual match
    # (after all, this *is* for saw, and shouldn't fail often!)

    my $beforeSaw = $saw;
    my $afterSaw = "";
    my $beforeExp = $exp;
    my $afterExp = "";

    if (!$pass) {
      # find the first mismatched character
      $pass = 1;
      my $i = 0;
      while ($i < length($saw) && $i < length($exp)) {
	my $sawCh = substr($saw, $i, 1);
	my $expCh = substr($exp, $i, 1);
	if ($sawCh ne $expCh) {
	  $beforeSaw = substr($saw, 0, $i);
	  if (length($beforeSaw) > 30) {
	    $beforeSaw = "....".substr($beforeSaw,length($beforeSaw)-30);
	  }
	  
	  $afterSaw = substr($saw, $i, length($saw));
	  if (length($afterSaw) > 30) {
	    $afterSaw = substr($afterSaw, 0, 30) . "....";
	  }
	  
	  $beforeExp = substr($exp, 0, $i);
	  if (length($beforeExp) > 30) {
	    $beforeExp = "....".substr($beforeExp,length($beforeExp)-30);
	  }
	  
	  $afterExp = substr($exp, $i, length($exp));
	  if (length($afterExp) > 30) {
	    $afterExp = substr($afterExp, 0, 30) . "....";
	  }
	  $pass = 0;
	  last;
	}
	$i++;
      }
    }
    assert($pass,
	   "\nsaw      \"$beforeSaw***** HERE->$afterSaw\"".
	   "\nexpected \"$beforeExp***** HERE->$afterExp\"");
  }

  sub sContains {
    my ($test,$expected) = @_;
    my $re = unregex($expected);
    my $pass = $test =~ m/$re/s ? 1 : 0;
    assert($pass,
	   "\nsaw      \"$test\"\nsContains\"$expected\"");
  }
  
  sub sEquals {
    my ($test,$expected) = @_;
    if ($expected eq "") {
      assert($test eq "", "saw \"$test\" expected \"\"");
    }
    my $re = unregex($expected);
    my $pass = $test =~ m/^$re$/s ? 1 : 0;
    _assertMismatch($pass, $test, $expected);
  }

  sub htmlContains {
    my ($test,$expected) = @_;
    my $re = unhtml($expected);

    my $pass = $test =~ m/$re/s ? 1 : 0;
    assert($pass,
	   "\n$test\n*********failed htmlContains\n$expected");
  }
  
  sub htmlEquals {
    my ($test,$expected) = @_;
    my $re = unhtml($expected);

    my $pass = ($test =~ m/^$re$/s ? 1 : 0);
    _assertMismatch($pass, $test, $expected);
  }

  sub equals {
    my ($test,$expected) = @_;
    my $pass = ($test == $expected);
    assert($pass, "saw $test expected $expected");
  }

  sub fileContains {
    my ($fn, $expected) = @_;

    undef $/; # set to read to EOF
    assert(open(IN_FILE, "<$fn"), "open $fn");
    my $text = "";
    my $l;
    while ($l = <IN_FILE>) {
      $text = $text . $l;
    }
    close(IN_FILE);

    sContains($text, $expected);
  }

  sub runTests {
    my $pkg = shift;
    print STDERR "Running tests in $pkg\n";
    $pkg .= "::";
    my $fn = "${pkg}setUp";
    if (defined(&{$fn})) {
      eval "&$fn()";
    }
    my $cnt = 0;
    foreach $fn ( eval "sort keys %$pkg" ) {
      if ($fn =~ /^test/) {
	print STDERR "\t...$fn\n";
	$fn = "$pkg$fn";
	die "OMIGOD $fn $@" unless defined( eval "&$fn()" );
	$cnt++;
      }
    }
    $fn = "${pkg}tearDown";
    if (defined(&{$fn})) {
      eval "&$fn()";
    }
    print STDERR "$cnt tests run from $pkg\n";
  }
}

1;
