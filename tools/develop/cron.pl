#!/usr/bin/perl
# Cron script that refreshes the develop installs
use strict;

my $ROOT = $ENV{HOME};
my $COMMIT_FLAG = "$ROOT/svncommit";
my $UPDATE_FLAG = "$ROOT/update_in_progress";
my $LATEST = "$ROOT/twikisvn/pub/latest_svn.txt";

chdir("$ROOT/twikisvn") || die $!;

if( -e $UPDATE_FLAG) {
    exit 0;
}

print "Update started at ",`date`;
print "Last update was to ",`cat $LATEST`;

# /tmp/svncommit is created by an svn hook on a checkin
# See post-commit.pl
if ( ! -f $COMMIT_FLAG ) {
    print "No new updates; exiting\n";
}

open(F, ">$UPDATE_FLAG") || die $!;
print F time();
close(F);

eval {
    undef $/;
    open(F, "<$COMMIT_FLAG") || die $!;
    my $c = <F>;
    close(F);
    unlink $COMMIT_FLAG;
    print "Updating\n";
    my $rev = `svn update $ROOT/twikisvn`;

    # Remove all links before refreshing from the manifests
    print `find $ROOT/twikisvn -type l -exec rm \\{\\} \\;`;
    print `perl pseudo-install.pl -link default`;

    print "Updated $rev";
    $rev =~ s/^.*revision (\d+).*?$/$1/s;
    open(F, ">$LATEST") || die $!;
    print F "$rev\n";
    close(F);
};
my $e = $@;
unlink($UPDATE_FLAG);
die $e if $e;
