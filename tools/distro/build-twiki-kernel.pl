#! /usr/bin/perl -w
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

use Cwd qw( cwd );
use File::Copy qw( cp );
use File::Path qw( rmtree );
use File::Find::Rule;
use File::Slurp::Tree;
#use File::Spec::Functions qw( abs2rel rel2abs );
#use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use LWP::UserAgent;
#use Error;

################################################################################
{
    package TWikiGuestAgent;
    our @ISA = qw(LWP::UserAgent);
    sub new			{ my $self = LWP::UserAgent::new(@_); $self->agent("TWikiKernel Builder/0.5"); $self; }
    sub get_basic_credentials	{ qw( TWikiGuest guest ) }
}

################################################################################

# commonly-used File::Find::Rule rules
my $discardSVN = File::Find::Rule->directory
    ->name(".svn")
    ->prune          # don't go into it
    ->discard;       # don't report it
my $all = File::Find::Rule->file;

my $installBase = cwd() . "/twiki";

################################################################################

( rmtree( $installBase ) or die $! ) if -e $installBase;
my $tar = 'TWiki20040901.tar.gz';
unless ( -e $tar )
{
    my $ua = TWikiGuestAgent->new or die $!;
    my $status = $ua->mirror( "http://twiki.org/release/$tar", $tar );
    # TODO: check for error
#    print Dumper( $status );
#    execute( "wget --http-user=TWikiGuest --http-passwd=guest -O $tar http://twiki.org/release/$tar" ) unless -e $tar;
}
execute( "tar xzf $tar" ) or die $!;
print scalar File::Find::Rule->file->in( 'twiki' ), " original files\n";

################################################################################

my $pwdStart = cwd();
chdir( '../..' ) or die $!;

#-[bin]-------------------------------------------------------------------------------
##my @bin = qw( attach changes edit geturl installpasswd mailnotify manage oops passwd preview rdiff rdiffauth
##	      register rename save search setlib.cfg statistics testenv upload view viewauth viewfile );
rmtree "$installBase/bin" or die $!;
my $treeBin = slurp_tree( 'bin', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'bin' ) );
spew_tree( "$installBase/bin" => $treeBin );
# ??? execute( "chmod a+rx,o+w $bin/*" );

#-[lib]-------------------------------------------------------------------------------
rmtree "$installBase/lib" or die $!;
my $treeLib = slurp_tree( 'lib', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'lib' ) );
spew_tree( "$installBase/lib" => $treeLib );

#-[templates]-------------------------------------------------------------------------------
rmtree "$installBase/templates" or die $!;
my $treeTemplates = slurp_tree( 'templates', rule => File::Find::Rule->or( $discardSVN, $all )->start( 'templates' ) );
spew_tree( "$installBase/templates" => $treeTemplates );

################################################################################
# some cleanup
unlink "$installBase/data/warning.txt", "$installBase/data/debug.txt";
# ??? what else?

################################################################################

chdir $pwdStart;
print scalar File::Find::Rule->file->in( 'twiki' ), " new files\n";

################################################################################
# create TWikiKernel distribution file
chomp( my $now = `date +'%Y%m%d.%H%M%S'` );
chomp( my $branch = `head -n 1 branch` || 'MAIN' );
my $newDistro = "TWikiKernel-$branch-$now";
execute( "tar czf $newDistro.tar.gz twiki" );	# .tar.gz goes *here* because *z* is here

exit 0;

################################################################################
################################################################################

sub execute 
{
    my ($cmd) = @_;

    chomp( my @output = `$cmd` );
    my $error = $?;

    print "$error: $cmd\n";
    print join( "\n", @output );
}

__END__
1352 -rw-r--r--    1 twiki  twiki  692162 31 Aug 12:35 TWikiDocumentation.html
 248 -rw-r--r--    1 twiki  twiki  123154 31 Aug 12:35 TWikiHistory.html
  24 -rwxr-xr-x    1 twiki  twiki   10283 21 Aug 18:35 UpgradeTwiki*
   8 -rw-r--r--    1 twiki  twiki     837 30 Aug 03:02 index.html
  40 -rw-r--r--    1 twiki  twiki   19696 30 Aug 02:52 license.txt
   8 -rw-r--r--    1 twiki  twiki     475 29 May 02:51 pub-htaccess.txt
  16 -rw-r--r--    1 twiki  twiki    4516 31 Aug 12:35 readme.txt
   8 -rw-r--r--    1 twiki  twiki     564 30 Aug 02:37 robots.txt
   8 -rw-r--r--    1 twiki  twiki     554 29 May 02:51 root-htaccess.txt
   8 -rw-r--r--    1 twiki  twiki     516 29 May 02:51 subdir-htaccess.txt

[X] /bin (SVN)

[X] /lib (on down, from SVN)

[x] /templates (SVN)

/data
   * Main/, Sandbox/, TWiki/, Trash/, _default/
   * .htpasswd
   * mime.types
   * delete debug.txt, warning.txt

/pub
   * Main/, Sandbox/, TWiki/, Trash/, _default/
   * icn/_filetypes.txt, icn/*.gif
   * favicon.ico [blasted robot]
   * wikiHome.gif [blasted robot]
