#!/usr/bin/perl -w
#
# Build class for FormQueryPlugin
# Requires the environment variable TWIKI_SHARED to be
# set to point at the shared code repository

# Standard preamble
BEGIN {
  use File::Spec;
  my $cwd = `dirname $0`; chop($cwd);
  my $basedir = File::Spec->rel2abs("../../../..", $cwd);
  die "TWIKI_SHARED not set" unless ($ENV{TWIKI_SHARED});
  unshift @INC, "$ENV{TWIKI_SHARED}/lib";
  unshift @INC, $basedir;
  unshift @INC, $cwd;
}
use TWiki::Plugins::Build;

package FormQueryPluginBuild;

@FormQueryPluginBuild::ISA = ( "TWiki::Plugins::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "FormQueryPlugin" ), $class );
}

$build = new FormQueryPluginBuild();

$build->build($build->{target});
