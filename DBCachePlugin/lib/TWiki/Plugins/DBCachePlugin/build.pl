#!/usr/bin/perl -w
#
# Build class for DBCachePlugin
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

package DBCachePluginBuild;

@DBCachePluginBuild::ISA = ( "TWiki::Plugins::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "DBCachePlugin" ), $class );
}

$build = new DBCachePluginBuild();

$build->build($build->{target});
