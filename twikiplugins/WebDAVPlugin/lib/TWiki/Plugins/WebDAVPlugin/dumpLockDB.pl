#!/usr/bin/perl
use TDB_File;

die "Usage: $0 <DAVLockDB>" unless $ARGV[0];

$DAVLockDB = $ARGV[0];

print "Dumping $DAVLockDB/TWiki\n";

tie(%hash,'TDB_File',"$DAVLockDB/TWiki",TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "open failed $!";
foreach $key (keys %hash) {
  print "$key => $hash{$key}\n";
}
untie(%hash);
