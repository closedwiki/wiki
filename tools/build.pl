#!/usr/bin/perl -w
#
# Build for TWiki
# Crawford Currie
# Copyright (C) TWikiContributors, 2005

use strict;

BEGIN {
    use File::Spec;

    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS} || '../lib' )) {
        unshift @INC, $pc;
    }

    # designed to be run within a SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name

    while (scalar(@path) > 0) {
        last if -d join( '/', @path).'/twikiplugins/BuildContrib';
        pop( @path );
    }

    if(scalar(@path)) {
        unshift @INC, join( '/', @path ).'/twikiplugins/BuildContrib/lib';
    }
}

use TWiki::Contrib::Build;

# Declare our build package
package TWikiBuild;

@TWikiBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "TWiki" ), $class );
}

sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # generate the POD documentation
    print "Building documentation in $this->{basedir}....\n";
    print "  Building TWiki.SourceCode tree docs...\n";
    $this->sys_action("perl gendocs.pl -root $this->{basedir}");

    print "  Generating AUTHORS...\n";
    $this->cp( $this->{basedir}.'/AUTHORS',
               $this->{basedir}.'/pub/Main/TWikiContributor/AUTHORS' );
    print "  Generating HTML static docs...\n";
    $this->sys_action("cd ../bin ; ./view TWiki.TWikiDocumentation skin plain | ../tools/fix_local_links.pl > ../TWikiDocumentation.html ");
    $this->sys_action("cd ../bin ; ./view TWiki.TWikiHistory skin plain > ../TWikiHistory.html ");
    $this->sys_action("cd ../bin ; ./view TWiki.DakarReleaseNotes skin plain > ../DakarReleaseNotes.html ");

    print "Documentation built\n";
}

sub target_stage {
    my $this = shift;

    $this->SUPER::target_stage();

    #use a Cairo install to create new ,v files for the data, and pub
    #WARNING: I don't know how to get the 'last' release, so i'm hardcoding Cairo
    my $lastRelease = "http://svn.twiki.org:8181/svn/twiki/tags/twiki-20040902-release/";
    $this->stage_rcsfiles($lastRelease);
}

# check in a single file to RCS
sub _checkInFile {
    my( $this, $old, $new, $file ) = @_;

    return if ( shift =~ /\,v$/ ); #lets not check in ,v files

    my $currentRevision = 0;
    print "Checking in $new/$file\n" if ($this->{-v});
    if ( -e $old.'/'.$file.',v' ) {
        $this->cp($old.'/'.$file.',v', $new.'/'.$file.',v');
        #force unlock
        $this->sys_action("rcs -u -M $new/$file,v");
        #lock to this user
        $this->sys_action("rcs -l $new/$file");

        #try to get current revision number
        my ($rcsInfo) = "rlog -r $new/$file";
        $rcsInfo = `$rcsInfo`;
        if ( $rcsInfo =~ /revision \d+\.(\d+)/ ) {     #revision 1.2
            $currentRevision = $1;
        } else {
            #it seems that you can have a ,v file with no commit, if you get here, you have an invalid ,v file. remove that file.
            die 'failed to get revision: '.$file."\n";
        }
    } else {
        # create rcs file, and ci
    }
    #set revision number #TODO: what about topics with no META DATA?
    my $cmd = 'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'.($currentRevision+1).'\"$2/\' '.$new.'/'.$file;
    `$cmd`;

    #check in TODO: this commits as the current user, not TWikiContributor
    $this->sys_action("ci -mbuildrelease -t-new-topic $new/$file");
    #get a copy of the latest revsion, no lock
    $this->sys_action("co -u -M $new/$file");
}

# recursively check in files to RCS
sub _checkInDir {
    my( $this, $old, $new, $root, $filterIn ) = @_;
    my $dir;

    opendir( $dir, "$new/$root" ) || die "Failed to open $root: $!";
    print "Scanning $new/$root...\n" if ($this->{-v});
    foreach my $content ( grep { !/^\./ } readdir($dir)) {
        my $sub = "$root/$content";
        if( -d "$new/$sub" ) {
            $this->_checkInDir( $old, $new, $sub, $filterIn );
        } elsif( -f "$new/$sub" && &$filterIn( $sub )) {
            $this->_checkInFile( $old, $new, $sub );
        }
    }
    close($dir);
}

sub stage_rcsfiles() {
    my $this = shift;
    my $lastRelease = shift;

    $lastRelease or die "lastRelease not specified";

    # svn co cairo to a new dir
    #foreach file in data|pub in tmpDir, cp ,v file from svnCo 
    #do a ci
    #if there was no existing ,v file, make one and ci

    # TODO: make _getTmpDir public.
    my $lastReleaseDir = $this->_getTmpDir("LastRelease");

    $this->makepath($lastReleaseDir);
    $this->cd($lastReleaseDir);
    print 'Checking out last release to ', $lastReleaseDir, "\n";
    $this->sys_action("svn co $lastRelease .");

    print '  Unlocking ,v files', "\n";
    $this->_checkInDir( $lastReleaseDir, $this->{tmpDir}, 'data',
                       sub { return shift =~ /\.txt$/ } );

    $this->_checkInDir( $lastReleaseDir, $this->{tmpDir}, 'pub',
                       sub { return -f shift; } );
    print '  Done', "\n";
}

# Create the build object
my $build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

