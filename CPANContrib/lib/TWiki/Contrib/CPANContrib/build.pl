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
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
{ package BuildBuild;

  @BuildBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "CPANContrib" ), $class );
  }

  # Example: Override the build target
  sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # Do other build stuff here
    use Cwd;
    my $base_lib_dir = getcwd . "/../../../../lib/CPAN";
    use File::Path qw( mkpath rmtree );
    -e $base_lib_dir && rmtree $base_lib_dir;
    mkpath $base_lib_dir or die $!;
    chdir '../../../../../TWikiInstallerContrib/lib/TWiki/Contrib/TWikiInstallerContrib/cpan/' or die $!;

    foreach my $module (
		    qw( ExtUtils::MakeMaker Storable Test::Harness Test::More YAML Compress::Zlib IO::Zlib IO::String Archive::Tar Data::Startup Math::BigInt File::Package File::Where File::AnySpec Tie::Gzip Archive::TarGzip ExtUtils::CBuilder ExtUtils::ParserXS Tree::DAG_Node 
			Carp::Assert
			Class::Data::Inheritable
			Class::ISA Class::Virtually::Abstract 
				Archive::Zip 
			Archive::Any ),
		    # Module::Build
		    qw( Error URI HTML::Tagset HTML::Parser LWP LWP::UserAgent XML::Parser XML::Simple Algorithm::Diff Text::Diff HTML::Diff ),
#		    qw( HTML::Form HTML::HeadParser HTTP::Status HTML::TokeParser HTTP::Daemon HTTP::Request ),
		    	qw( Test::Builder::Tester Test::LongString ),
		    qw( WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki ),
		    # Net::SSLeay IO::Socket::SSL
		    qw( Number::Compare Text::Glob File::Find::Rule File::Slurp File::Slurp::Tree ),
		    qw( CGI::Session ),
		    qw( Encode Locale::Maketext::Lexicon ),
		    qw( Digest::base Digest::SHA1 ),
		    qw( Unicode::Map Unicode::Map8 Jcode Unicode::String Unicode::MapUTF8 ),
			)
    {
	print "Installing $module\n";
	print "-" x 80, "\n";
	`perl install-cpan.pl --mirror=MIRROR/MINICPAN/ --baselibdir=$base_lib_dir $module`;
    }

      `chmod -R 777 $base_lib_dir/.cpan`;
      rmtree "$base_lib_dir/.cpan";	# cleanup CPAN build directories

# HAVE TO GENERATE THE MANIFEST FILE BY HAND ATM:
# twikibuilder@ubuntu:~/twiki/DEVELOP/twikiplugins/CPANContrib/lib/TWiki/Contrib/CPANContrib$ pushd ../../../../ ; find lib/CPAN/ >>lib/TWiki/Contrib/CPANContrib/MANIFEST ; popd

      if ( 0 ) {
	  chomp( my @files = `find $base_lib_dir` );

	  # update MANIFEST
	  open( MANIFEST, '<', 'MANIFEST-base' ) or die $!;
	  local $/ = undef;
	  my @manifest = <MANIFEST>;
	  close MANIFEST;
	  
	  open( MANIFEST, '>', 'MANIFEST' ) or die $!;
	  print join( "\n", @manifest );
	  print join( "\n", @files );
	  close MANIFEST;
      }
  }
}

# Create the build object
$build = new BuildBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

