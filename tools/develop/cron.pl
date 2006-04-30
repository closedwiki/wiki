#!/usr/bin/perl
# Cron script that refreshes the develop installs
# Must be run from twikisvn
use strict;

my $ROOT = $ENV{HOME};
my $COMMIT_FLAG = "$ROOT/svncommit";
my $UPDATE = "$ROOT/twikisvn/pub/latest_svn.txt";

print "Update started at ",`date`;
print "Last update was to ",`cat $UPDATE`;

# /tmp/svncommit is created by an svn hook on a checkin
# See post-commit.pl
if ( ! -f $COMMIT_FLAG ) {
    print "No new updates; exiting\n";
    exit 0;
}

# Uninstall plugins *before* the update, in case MANIFESTs change
chdir "$ROOT/twikisvn";
`perl pseudo-install.pl -uninstall default`;

undef $/;
open(F, "<$COMMIT_FLAG") || die $!;
my $c = <F>;
close(F);
unlink $COMMIT_FLAG;
my $rev = `svn update $c`;
`perl pseudo-install.pl -link default`;

$rev =~ s/^.*revision (\d+).*?$/$1/s;
print "Updated to $rev";
open(F, ">$UPDATE") || die $!;
print F "$rev\n";
close(F);
