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
{ package TWikiBuild;

  @TWikiBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "TWiki" ), $class );
  }

  sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # generate the POD documentation
    print "Building documentation....\n";
    print `perl gendocs.pl -root $this->{basedir}`;
    print "Documentation built\n";
  }

  sub target_stage {
    my $this = shift;

    $this->SUPER::target_stage();

    #use a Cairo install to create new ,v files for the data, and pub
    #WARNING: I don't know how to get the 'last' release, so i'm hardcoding Cairo
    $this->stage_rcsfiles();
  }

  sub stage_rcsfiles() {
    my $this = shift;

    # svn co cairo to a new dir
    #foreach file in data|pub in tmpDir, cp ,v file from svnCo 
    #do a ci
    #if there was no existing ,v file, make one and ci

    my $lastReleaseDir = '/tmp/lastRel'.($$ +1);

    $this->makepath($lastReleaseDir);
    $this->cd($lastReleaseDir);
    print 'last Release is being put in '.$lastReleaseDir."\n";
    `svn co http://svn.twiki.org:8181/svn/twiki/tags/twiki-20040902-release/ .`;

#TODO: and pub dir too!!
    $this->cd($this->{tmpDir}.'/data');
    #foreach web
    opendir(DATADIR, '.');
    my $web;
    while ($web = readdir(DATADIR)) {
        unless (-d $web) {next;}  #only consider directories
        if ($web eq '.' || $web eq '..') {next;}
 #       print 'found web: '.$web."\n";
        opendir(WEBDIR, $web);
        my $topic;
        while ($topic = readdir(WEBDIR)) {
            unless ($topic =~ /.*\.txt$/) {next;} #consider only topics
            print "-------\tfound topic: $topic\n";

            my $currentRevision = 1;
    		if ( -e $lastReleaseDir.'/data/'.$web.'/'.$topic.',v' ) {
                $this->cp($lastReleaseDir.'/data/'.$web.'/'.$topic.',v', $web);
                `rcs -u -M $web/$topic,v`;
                `rcs -l $web/$topic`;

                my ($rcsInfo) = "rlog -r  $web/$topic";
#                print $rcsInfo."\n";
                $rcsInfo = `$rcsInfo`;
#                print $rcsInfo;
                if ( $rcsInfo =~ /revision \d+\.(\d+)/ ) {     #revision 1.2
                    $currentRevision = $1;
#                    print 'existing topic: (rev = '.$currentRevision.') '.$web.'/'.$topic."\n";
                } else {
#                    print "=========\n$rcsInfo\n=======\n";
                    die 'failed to get revision: '.$web.'/'.$topic."\n";
                }
            } else {
                #create rcs file, and ci
                print 'new topic: '.$web.'/'.$topic."\n";
            }
#TODO: need to update the META"TOPICINFO with the correct verion number :(
            my $cmd = 'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'.($currentRevision+1).'\"$2/\' '.$web.'/'.$topic;
            `$cmd`;

            `ci -mbuildrelease -t-new-topic $web/$topic`;
            `co -u -M $web/$topic`;
		}
		closedir(WEBDIR);
    }
    closedir(DATADIR);

  }
}

# Create the build object
my $build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

