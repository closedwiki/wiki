# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
#
# Jul 2004 - copied almost completely from Sven's updateTopics.pl script:
#            put in a package and made a subroutine to work with UpgradeTWiki 
#             by Martin "GreenAsJade" Gregory.

# This version ignores symlinks in the existing wiki data: it creates a new 
# wiki data tree updating the topics in the existing wiki data, even the
# linked-in topics, but does not create new links like the old ones.

package UpdateTopics;

use strict;

use File::Find;
use File::Copy;
use Text::Diff;

# Try to upgrade an installation's TWikiTopics using the rcs info in it.

use vars qw($CurrentDataDir $NewReleaseDataDir $DestinationDataDir $BaseDir $debug @DefaultWebTopics %LinkedDirPathsInWiki $RcsLogFile);

sub UpdateTopics 
{
    $CurrentDataDir = shift or die "UpdateTopics not provided with existing data directory!\n";

    $NewReleaseDataDir = shift or die "UpdateTopics not provided with new data directory!\n";

    $DestinationDataDir = (shift or "$BaseDir/newData");

    my $whoCares = `which rcsdiff`;   # we should use File::Which to do this, except that would mean
                                      # getting yet another .pm into lib, which seems like hard work?
    ($? >> 8 == 0) or die "Uh-oh - couldn't see an rcs executable on your path!  I really need one of those!\n";

    $whoCares = `which patch`;

    ($? >> 8 == 0) or die "Uh-oh - couldn't see a patch executable on your path!  I really need one of those!\n";

    $BaseDir = `pwd`;
    chomp ($BaseDir);

#Set if you want to see the debug output
#$debug = "yes";

    if ($debug) {print "$CurrentDataDir, $NewReleaseDataDir\n"; }

    if ((! -d $CurrentDataDir ) || (! -d $NewReleaseDataDir)) {
	print "\nUsage: UpdateTopics <CurrentDataDir> <NewReleaseDataDir> [<DestinationDataDir]>\n";
	exit;
    }

    print "\n";
    print "\t...new upgraded data will be put in $DestinationDataDir\n";
    print "\t   there will be no changes made to either the source data directory or $NewReleaseDataDir.\n\n"; 
    print "\t This progam will attempt to use the rcs versioning information to upgrade the\n";
    print "\t   contents of your distributed topics in $CurrentDataDir to the content in $NewReleaseDataDir.\n\n";
    print "Output:\n";
    print "\tFor each file that has no versioning information a _v_ will be printed\n";
    print "\tFor each file that has no changes from the previous release a _c_ will be printed\n";
    print "\tFor each file that has changes and a patch is generated a _p_ will be printed\n";
    print "\tFor each file that is new in the NewReleaseDataDir a _+_ will be printed\n";
    print "\t When the script has attempted to patch the $NewReleaseDataDir, 
\t *.rej files will contain the failed merges\n";
    print "\t although many of these rejected chages will be discarable, 
\t please check them to see if your configuration is still ok\n\n";

    sussoutDefaultWebTopics();

    mkdir $DestinationDataDir;

#redirect stderr into a file (rcs dumps out heaps of info)

    $RcsLogFile = $BaseDir."/rcs.log";

    unlink($RcsLogFile);  # let's have just the messages from this session!

    open(PATCH, "> $DestinationDataDir/patchTopics");
    
    print "\n\n ...checking existing files from $CurrentDataDir\n";
#TODO: need to find a way to detect non-Web directories so we don't make a mess of them..
# (should i just ignore Dirs without any ,v files?) - i can't upgrade tehm anyway..
#upgrade templates..?

    my %findOptions;

    $findOptions{'wanted'} = \&getRLog;
    $findOptions{'follow_fast'} = 1;   # surely the user hasn't put loops of links etc in their data!?

    find(\%findOptions, $CurrentDataDir);

    close(PATCH);

#do a find through $NewReleaseDataDir and copy all missing files & dirs
    print "\n\n ... checking for new files in $NewReleaseDataDir";
    find(\&copyNewTopics, $NewReleaseDataDir);
    
#run `patch patchTopics` in $DestinationDataDir
    print "\nPatching topics (manually check the rejected patch (.rej) files)";
    chdir($DestinationDataDir);
    `patch -p0 < patchTopics > patch.log`;
#TODO: examing the .rej files to remove the ones that have already been applied
    find(\&listRejects, ".");
#TODO: run `ci` in $DestinationDataDir
    
    print "\n\n";
    
}
    
# ============================================
sub listRejects
{
    my ( $filename ) = @_;
    
    $filename = $File::Find::name;

    if ($filename =~ /.rej$/ ) {
        print "\nPatch rejected: $filename";
    }
}

# ============================================
sub copyNewTopics
{
    my ( $filename ) = $File::Find::name;

    my $destinationFilename = $filename;
    $destinationFilename =~ s/$NewReleaseDataDir/$DestinationDataDir/g;

# Sven had these commeted out, so I've left them here commented out.
#    return if $filename =~ /,v$/;
#    return if $filename =~ /.lock$/;
#    return if $filename =~ /~$/;

    if ( -d $filename) {
        print "\nprocessing directory $filename";
	if ( !-d $destinationFilename ) {
	    print " (creating $destinationFilename)";
	    mkdir($destinationFilename);
	}
	print "\n";
        return;
    }
    
    if (! -e $destinationFilename ) { 
        print "\nadding $filename (new in this release)" if ($debug);
        print "+" if (!$debug);
        copy( $filename, $destinationFilename);
    }
    
}

# ============================================
sub getRLog
{
    my ( $filename ) = $File::Find::name;

# (see above)
#    my ( $filename ) = @_;
#    $filename = $BaseDir."/".$File::Find::name if (! $filename );

    my ( $newFilename ) = $filename;
    if (!$filename =~ /^$CurrentDataDir/)
    {
	die "getRLog found $filename that appears not to be in $CurrentDataDir tree! That's not supposed to happen: sorry!\n";
    }
	
    $newFilename =~ s/$CurrentDataDir/$NewReleaseDataDir/g;
    print "\n$filename -> $newFilename : "  if ( $debug);

    my $destinationFilename = $filename;
    $destinationFilename =~ s/$CurrentDataDir/$DestinationDataDir/g;

    if ($filename =~ /,v$/ or $filename =~ /.lock$/ or $filename =~ /~$/) {
	print "skipping\n" if $debug;
	return;
    }

    if ( -d $filename ) {
	print "\nprocessing directory (creating $destinationFilename)\n";
        mkdir($destinationFilename);
        return;
    }
    
    if ( isFromDefaultWeb($filename) )
    {
        $newFilename =~ s|^(.*)/[^/]*/([^/]*)|$1/_default/$2|g;
        print "\n$filename appears to have been generated from from _default - merging with $newFilename from the new distribution!" if ($debug);
    }
    
    if (! -e $filename.",v" ){
#TODO: maybe copy this one too (this will inclure the .htpasswd file!!)   
        if ( $filename =~ /.txt$/ ) {
#TODO: in interactive mode ask if they want to create this topic's rcs file..        
            print "\nWarning: $filename does not have any rcs information" if ($debug);
            print "v" if (! $debug);
        }
        copy( $filename, $destinationFilename);
        return;
    }

    if ( -e $newFilename ) { 
        #file that may need upgrading
        my $highestCommonRevision = findHighestCommonRevision( $filename, $newFilename);
#print "-r".$highestCommonRevision."\n";
#is it the final version of $filename (in which case 
#TODO: what about manually updated files?
        if ( $highestCommonRevision =~ /\d*\.\d*/ ) {
            my $diff = doDiffToHead( $filename, $highestCommonRevision );
#print "\n========\n".$diff."\n========\n";            
            patchFile( $filename, $destinationFilename, $diff );
            print "\npatching $newFilename from $filename ($highestCommonRevision)" if ($debug);
            print "\n$newFilename: p\n" if (!$debug);
            copy( $newFilename, $destinationFilename);
            copy( $newFilename.",v", $destinationFilename.",v");
        } elsif ($highestCommonRevision eq "head" ) {
	    # I made this use the existing file instead of the new one, in case they manually
	    # changed the exisiting one without using RCS.
            print "\nhighest revision also final revision in oldTopic (using existing Version)" if ($debug);
            print "c" if (!$debug);
            copy( $filename, $destinationFilename);
            copy( $filename.",v", $destinationFilename.",v");
        } else {
            #no common versions - this might be a user created file, 
            #or a manual attempt at creating a topic off twiki.org?raw=on
#TODO: do something nicer about this.. I think i need to do lots of diffs 
            #to see if there is any commonality
            print "\nWarning: copying $filename (no common versions)" if ($debug);
            print "c" if (!$debug);
            copy( $filename, $destinationFilename);
            copy( $filename.",v", $destinationFilename.",v");
        }
    } else {
        #new file created by users
#TODO: this will include topics copied using ManagingWebs (createWeb)
        print "\ncopying $filename (new user's file)" if ($debug);
        print "c" if (!$debug);
        copy( $filename, $destinationFilename);
        copy( $filename.",v", $destinationFilename.",v");
    }
}

# ==============================================
sub isFromDefaultWeb
{
    my ($filename) = @_;
    
    $filename =~ /^(.*)\/[^\/]*\/([^\/]*)/;
    my $topic = $2;    
    return $topic if grep(/^$filename$/, @DefaultWebTopics);
}

sub sussoutDefaultWebTopics
{
    opendir(DEFAULTWEB, './data/_default') or die "Yikes - couldn't open ./data/_default: $! ... not safe to proceed!\n";
    @DefaultWebTopics = grep(/.txt$/, readdir(DEFAULTWEB));
    if ($debug) 
    {
	print "_default topics in new distro: @DefaultWebTopics\n";
    }
}

# ==============================================
sub doDiffToHead
{
    my ( $filename, $highestCommonRevision ) = @_;
   
#    print "$highestCommonRevision to ".getHeadRevisionNumber($filename)."\n";
#    print "\n----------------\n".getRevision($filename, $highestCommonRevision);
#     print "\n----------------\n".getRevision($filename, getHeadRevisionNumber($filename)) ;
#    return diff ( getRevision($filename, $highestCommonRevision), getRevision($filename, getHeadRevisionNumber($filename)) );

    my $cmd = "rcsdiff -r".$highestCommonRevision." -r".getHeadRevisionNumber($filename)." $filename";
    print "\n----------------\n".$cmd  if ($debug);
    return `$cmd 2>>$RcsLogFile`;
}

# ==============================================
sub patchFile
{
    my ( $oldFilename, $destinationFilename, $diff ) = @_;

    print(PATCH "--- $oldFilename\n");
    print(PATCH "--- $destinationFilename\n");
    print(PATCH "$diff\n");

#    print(PATCH, "");
    
    #patch ($newFilename, $diff);
# and then do an rcs ci (check-in)
}

# ==============================================
sub getHeadRevisionNumber
{
    my ( $filename ) = @_;
    
    my ( $cmd ) = "rlog ".$filename.",v";

    my $line;

    my @response = `$cmd 2>>$RcsLogFile`;
    foreach $line (@response) {
        next unless $line =~ /^head: (\d*\.\d*)/;
        return $1;
    }
    return "";    
}

# ==============================================
#returns, as a string, the highest revision number common to both files
#Note: we return nothing if the highestcommon verison is also the last version of $filename
#TODO: are teh rcs versions always 1.xxx ? if not, how do we know?
sub findHighestCommonRevision 
{
    my ( $filename, $newFilename) = @_;
    
    my $rev = 1;
    my $commonRev = "";

    my $oldContent = "qwer";
    my $newContent = "qwer";
    while ( ( $oldContent ne "" ) & ($newContent ne "") ) {
        print "\ncomparing $filename and $newFilename revision 1.$rev " if ($debug);
        $oldContent = getRevision( $filename, "1.".$rev);
        $newContent = getRevision( $newFilename, "1.".$rev);
        if ( ( $oldContent ne "" ) & ($newContent ne "") ) {
            my $diffs = diff( \$oldContent, \$newContent, {STYLE => "Unified"} );
#            print "\n-----------------------|".$diffs."|-------------------\n";
#            print "\n-------------------[".$oldContent."]----|".$diffs."|-------[".$newContent."]--------------\n";
            if ( $diffs eq "" ) {
                #same!!
                $commonRev = "1.".$rev;
            }
        }
        $rev = $rev + 1;
    }

    print "\nlastCommon = $commonRev (head = ".getHeadRevisionNumber( $filename).")" if ($debug);
    
    if ( $commonRev eq getHeadRevisionNumber( $filename) ) {
        return "head";
    }
    
    return $commonRev;
}

# ==============================================
#returns an empty string if the version does not exist
sub getRevision
{
    my ( $filename, $rev ) = @_;

# use rlog to test if the revision exists..
    my ( $cmd ) = "rlog -r".$rev." ".$filename;

#print $cmd."\n";
    my @response = `$cmd 2>>$RcsLogFile`;

    my $revision;
    my $line;
    foreach $line (@response) {
        next unless $line =~ /^revision (\d*\.\d*)/;
        $revision = $1;
    }

    my $content = "";

    if ( $revision and ($revision eq $rev) ) {
        $cmd = "co -p".$rev." ".$filename;
        $content = `$cmd 2>>$RcsLogFile`;
    }

    return $content;
}

1;
