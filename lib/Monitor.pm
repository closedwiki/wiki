=pod

Monitoring package. Instrument the code like this:

use Monitor;
Monitor::MARK("Description of event");
Monitor::MARK("Another event");

Then set the environment variable TWIKI_MONITOR to a perl true value, and
run the script from the command line e.g:
$ cd bin
$ ./view -topic Myweb/MyTestTopic

The results will be printed to STDERR at the end of the run. Two times are
shown, a time relative to the last MARK and a time relative to the first MARK
(which is always set the first time this package is used). The final column
is total memory.

=cut

package Monitor;

use strict;

use vars qw(@times);

sub get_stat_info {
    # open and read the main stat file
    if( ! open(_INFO,"</proc/$_[0]/stat") ){
        # Failed
        return { vsize=> 0, rss => 0 };
    }
    my @info = split(/\s+/,<_INFO>);
    close(_INFO);

    # these are all the props (skip some)
    # pid(0) comm(1) state ppid pgrp session tty
    # tpgid(7) flags minflt cminflt majflt cmajflt
    # utime(13) stime cutime cstime counter
    # priority(18) timeout itrealvalue starttime vsize rss
    # rlim(24) startcode endcode startstack kstkesp kstkeip
    # signal(30) blocked sigignore sigcatch wchan

    # get the important ones
    return { vsize  => $info[22],
             rss    => $info[23] * 4};
}

sub mark {
    my $stat = get_stat_info($$);
    push(@times, [ shift, new Benchmark(), $stat ]);
}

BEGIN {
    my $caller = caller;
    if ($ENV{TWIKI_MONITOR}) {
        require Benchmark;
        import Benchmark ':hireswallclock';
        die $@ if $@;
        *MARK = \&mark;
        MARK('START');
    } else {
        *MARK = sub {};
    }
}

sub tidytime {
    my ($a, $b) = @_;
    my $s = timestr(timediff($a, $b));
    $s =~ s/\( [\d.]+ usr.*=\s*([\d.]+ CPU)\)/$1/;
    $s =~ s/wallclock secs/wall/g;
    return $s;
}

sub END {
    MARK('END');
    my $lastbm;
    my $firstbm;
    my %mash;
    foreach my $bm (@times) {
        $firstbm = $bm unless $firstbm;
        if ($lastbm) {
            my $s = tidytime($bm->[1], $lastbm->[1]);
            my $t = tidytime($bm->[1], $firstbm->[1]);
            $s = "\n| $bm->[0] | $s | $t | $bm->[2]->{vsize} |";
            print STDERR $s;
        }
        $lastbm = $bm;
    }
    print STDERR "\n";
}

1;
