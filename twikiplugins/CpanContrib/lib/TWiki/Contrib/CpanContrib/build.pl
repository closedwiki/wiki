#!/usr/bin/perl -w
#
# Requires the environment variable TWIKI_LIBS (a colon-separated path
# list) to be set to point at the build system and any required dependencies.
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.`
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#

# Standard preamble
BEGIN {
  unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}

use File::Find;
use TWiki::Contrib::Build;

# Declare our build package
package BuildBuild;
use base qw( TWiki::Contrib::Build );

use File::Path qw( mkpath rmtree );
use FindBin;

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "CpanContrib" ), $class );
}


sub target_stage {
    my $this = shift;
    
    $this->SUPER::target_stage();
    
    $this->stage_cpan();
}


sub stage_cpan {
    my $this = shift;

    # copy the generated files from CPAN build directory

    my $base_lib_dir = "$this->{basedir}/lib/CPAN";

    $this->cd( $base_lib_dir );
    File::Find::find( { wanted => sub { $this->cp( $_, "$this->{tmpDir}/lib/CPAN/$_" ) }, 
			no_chdir => 1 }, 
		      '.' );
}
  

sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    chdir $FindBin::Bin or die $!;

    {
	package CpanContrib::Modules;
	use vars qw( @CPAN );		# grrr, not sure why this is needed
	unless ( my $return = do "./CPAN" )
	{ 
	    die "unable to load CPAN module list to build: $!";
	}
    }

    # Do other build stuff here
    # get cpan minimirror up-to-date
    # create twiki mini-minicpan mirror (also publish this)
    # only rebuild if CPAN module is newer than the already-built files! (*big* timesaver!)

    use Cwd;
    my $base_lib_dir = getcwd . "/../../../../lib/CPAN";
    -e $base_lib_dir && rmtree $base_lib_dir;
    mkpath $base_lib_dir or die $!;
    chdir 'bin' or die $!;
    ++$|;

    foreach my $module ()
#    foreach my $module ( @CpanContrib::Modules::CPAN )
    {
	# clean out old build stuff (in particular, ExtUtils::MakeMaker leaves bad stuff lying around)
	my $dirCpanBuild = "$base_lib_dir/.cpan/build/";
	# SMELL: fixed unix-specific chmod shell call
	system( chmod => '-R' => 'a+rwx' => $dirCpanBuild ), rmtree $dirCpanBuild if -d $dirCpanBuild;

	print "Installing $module\n";
	print "-" x 80, "\n";
	`perl install-cpan.pl --mirror=../../../../../../../../MIRROR/MINICPAN/ --baselibdir=$base_lib_dir $module </dev/null`;
    }

    # cleanup the intermediate CPAN build directories
    `chmod -R 777 $base_lib_dir/.cpan`;
    rmtree "$base_lib_dir/.cpan";
}

package main;
# Create the build object
$build = new BuildBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );
