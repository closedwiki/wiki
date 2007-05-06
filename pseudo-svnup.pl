#! perl
use strict;
use warnings;

my $ignorefileslistedin = "SVN_UP_PRESERVE";
my $svnupcachefile = "svn-up-temp.txt";

# (C) Martin@Cleaver.org Nov 2005. 
# Released on the same terms as Perl itself
#
# This script runs svn up on all files except those listed in SVN_UP_PRESERVE
# It works by 
#   (1) getting a list of all updates from 'svn up -u' 
#     (That command shows what would change, but does not change the filespace)
#   (2) removing from the list anything listed in the file SVN_UP_PRESERVE
#   (3) performing svn up on the other files.
#
# For background see http://twiki.org/cgi-bin/view/Codev/IgnoringSvnCommits
#
# A shell equivalent would be something like:
#svn st -u | grep -v 'Status against revision' | perl -n -e 's|^.{20}||g; print' | grep -v -f SVN_UP_PRESERVE | xargs -r svn up
# (Thanks to darix@irc.freenode.net#svn)
#
# In EdinburghRelease this will be a TWikiShell CommandSet
#
# The alternative to this script would have been to take copies of the 
# files we want to preserve and then restore them after an update
# I did not do this because I didn't want SVN to fundementally believe 
# that I'd ever taken the update. Doing svn up and then overwriting would
# have those semantics.
#
# It would be fairly easy to make it show you which update you are missing
# I'd leave it as an exercise for any interested reader
#
# If you do make modifications please do send them back to me or check them in.

$ENV{LC_ALL}='POSIX';
my $debug = 0;
my @alllines = getFilesUpdated($svnupcachefile);

my %filesToBeIgnored = getFilesToNotTakeUpdatesFrom($ignorefileslistedin);

my @updateFiles;

my @updatedFiles = filterForUpdatedFiles(@alllines);
my @wantedUpdates = filterForWantedFiles(@updatedFiles);

printUpdateStatus();
print "\n";

if ($#wantedUpdates > 0) {
    print "Want updates for: ".join("\n", @wantedUpdates)."\n";
    svnUp(@wantedUpdates);
} else {
    print "No updates to take. Perhaps you need to refresh the cache by deleting $svnupcachefile and running this script again?\n\n";
}



sub printUpdateStatus {
    my @noUpdate;
    foreach my $file (keys %filesToBeIgnored) {
	if ($filesToBeIgnored{$file}) {
	    print "Didn't take update to $file, $filesToBeIgnored{$file}\n";
	} else {
	    push @noUpdate,$file;
	}
    }
    print "No updates for:\n", join("\n  ", @noUpdate)."\n";
}

sub svnUp {
    my (@files) = @_;
    my $cmd = "echo ".join(" ", @files)." | xargs -r svn up";
    print "cmd: $cmd\n";
    print `$cmd`;
}

# side-effect: updates %filesToBeIgnored with any files actually ignored
sub filterForWantedFiles {
    my @allUpdates = @_;
    my @wantedUpdates;
    print "Filtering $#allUpdates updates for wanted files\n";
  UPDATE:
    foreach my $update (@allUpdates) {
	# SMELL - This is inefficient. 
	foreach my $ignore (keys %filesToBeIgnored) {
	    print "Testing $ignore against $update\n" if $debug >= 2;
	    if ($update =~ m/$ignore/) {
		$filesToBeIgnored{$update} = "update ignored"; # would be good to know the revision number.
		print "  Skipping $update\n" if $debug >= 1;
		next UPDATE;
	    }
	}
	# No ignore objected...
	push @wantedUpdates, $update;
	print "  Taking $update\n" if $debug >= 1;
    }
    return @wantedUpdates;
}

sub filterForUpdatedFiles {
    my @alllines = @_;
    foreach my $line (@alllines) {
	print "Processing $line\n" if $debug >=2 ;
	next if $line =~ /Status against revision/;
	next if $line =~ /^\?/;
	next unless ($line =~ s|^.{20}(.*)||g);
	my $file = $1;
	push @updateFiles, $file;
	print "... $file has been updated\n" if $debug >=1;
    };
    return @updateFiles;
}



sub getFilesUpdated {
    my ($updatedFilesCache, $refresh) = @_;
    if ($refresh || ! -f $updatedFilesCache) {
	print "Please wait while getting list of files that have changed in SVN... Refreshing $updatedFilesCache. (This can take ~10mins) \n";
	`svn st -u > $updatedFilesCache`;
    }
    print "Reading $updatedFilesCache\n";
    my @ans = split(/\n/, `cat $updatedFilesCache`);
    return @ans;

}

sub getFilesToNotTakeUpdatesFrom {
    my ($filename) = @_;
    my @files = split(/\n/, `cat $filename`);
    my %filesToBeIgnored;
    foreach my $file (@files) {
	print "Registering ignored file $file\n" if $debug >= 1;
	$filesToBeIgnored{$file} = '';
    }
    return %filesToBeIgnored;
}



#grep -f
